import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/trip_model.dart';
import '../services/api_service.dart';
import '../config/api_config.dart';

/// Loading state enum for UI feedback.
enum LoadState { idle, loading, success, error }

/// Central state for trip creation workflow with Cloud Sync.
class TripProvider extends ChangeNotifier {
  static const _keyHistory = 'trip_history';
  final ApiService _api = ApiService();

  // ─── State ───────────────────────────────────────────────────────────────────
  LoadState _itineraryState = LoadState.idle;
  LoadState _imageState     = LoadState.idle;
  LoadState _storyState     = LoadState.idle;

  String? _userId;
  TripModel? _currentTrip;
  List<TripModel> _tripHistory = [];
  List<File> _selectedImages   = [];
  String? _errorMessage;
  int _processingStep = 0; // 0=analyzing, 1=story, 2=reel
  String? _generatedVideoUrl;
  String? _videoEngine;
  String? _videoMessage;

  TripProvider() {
    _loadHistory();
  }

  void setUserId(String? id) {
    if (_userId != id) {
      _userId = id;
      _loadHistory();
    }
  }

  // ─── Getters ─────────────────────────────────────────────────────────────────
  LoadState get itineraryState => _itineraryState;
  LoadState get imageState     => _imageState;
  LoadState get storyState     => _storyState;
  TripModel? get currentTrip   => _currentTrip;
  List<TripModel> get tripHistory => List.unmodifiable(_tripHistory);
  List<File> get selectedImages   => List.unmodifiable(_selectedImages);
  String? get errorMessage        => _errorMessage;
  int get processingStep          => _processingStep;
  bool get isFullyProcessed       => _currentTrip?.storyTitle != null;
  String? get generatedVideoUrl   => _generatedVideoUrl;
  String? get videoEngine         => _videoEngine;
  String? get videoMessage        => _videoMessage;

  String _normalizeVideoUrl(String rawUrl) {
    if (rawUrl.isEmpty) return rawUrl;
    if (!rawUrl.startsWith('http')) return '${ApiConfig.baseUrl}$rawUrl';
    final raw = Uri.tryParse(rawUrl);
    final base = Uri.tryParse(ApiConfig.baseUrl);
    if (raw == null || base == null) return rawUrl;
    if (raw.host == '127.0.0.1' || raw.host == 'localhost' || raw.host == '0.0.0.0') {
      return base.replace(path: raw.path, query: raw.query.isEmpty ? null : raw.query).toString();
    }
    return rawUrl;
  }

  void _ensureCurrentTripForReel({required String destination, required List<String> sceneTags}) {
    _currentTrip ??= TripModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      destination: destination,
      days: 0,
      budget: 'Medium',
      interests: sceneTags,
      createdAt: DateTime.now(),
    );
  }

  // ─── Image selection ─────────────────────────────────────────────────────────
  void setImages(List<File> files) {
    _selectedImages = files;
    _imageState = LoadState.idle;
    _processingStep = 0;
    notifyListeners();
  }

  void removeImage(int index) {
    _selectedImages.removeAt(index);
    _imageState = LoadState.idle;
    _processingStep = 0;
    notifyListeners();
  }

  // ─── Generate itinerary ──────────────────────────────────────────────────────
  Future<bool> generateItinerary({required String destination, required int days, required String budget, required List<String> interests}) async {
    _itineraryState = LoadState.loading;
    _errorMessage = null;
    notifyListeners();
    final result = await _api.generateItinerary(destination: destination, days: days, budget: budget, interests: interests);
    if (result.isSuccess) {
      _currentTrip = result.data;
      _itineraryState = LoadState.success;
      notifyListeners();
      return true;
    } else {
      _errorMessage = result.error;
      _itineraryState = LoadState.error;
      notifyListeners();
      return false;
    }
  }

  // ─── Full AI processing pipeline with Cloud Sync ──────────────────────────────
  Future<bool> processAll({required String destination, required List<String> sceneTags, String tone = 'cinematic', String? localAudioPath}) async {
    _errorMessage = null;
    _generatedVideoUrl = null;
    _videoEngine = null;
    _videoMessage = null;
    List<String> serverImagePaths = [];

    _ensureCurrentTripForReel(destination: destination, sceneTags: sceneTags);

    // Image Analysis
    if (_selectedImages.isNotEmpty) {
      _processingStep = 0;
      _imageState = LoadState.loading;
      notifyListeners();
      final imgResult = await _api.uploadImages(_selectedImages);
      _imageState = imgResult.isSuccess ? LoadState.success : LoadState.error;
      if (!imgResult.isSuccess) { _errorMessage = imgResult.error; notifyListeners(); return false; }
      serverImagePaths = List<String>.from(imgResult.data?['analysis_results']?['selected_images'] ?? const []);
    }

    // Story Gen
    _processingStep = 1;
    _storyState = LoadState.loading;
    notifyListeners();
    final storyResult = await _api.generateStory(destination: destination, sceneTags: sceneTags, tone: tone);
    if (storyResult.isSuccess) {
      _currentTrip = _currentTrip?.copyWithStory(storyResult.data!);
      _storyState = LoadState.success;
    } else {
      _errorMessage = storyResult.error;
      _storyState = LoadState.error;
      notifyListeners();
      return false;
    }

    // Reel Gen
    _processingStep = 2;
    notifyListeners();
    if (_selectedImages.isNotEmpty) {
      final captions = _currentTrip?.captions ?? [];
      String? finalAudioPath = localAudioPath;
      if (localAudioPath != null && !localAudioPath.startsWith('static/') && !localAudioPath.startsWith('backend/')) {
         final audioUpload = await _api.uploadAudio(File(localAudioPath));
         if (audioUpload.isSuccess) finalAudioPath = audioUpload.data;
      }

      final startJob = await _api.startCinematicVideo(imagePaths: serverImagePaths, captions: captions, destination: destination, audioPath: finalAudioPath, theme: tone);
      if (startJob.isSuccess) {
        final jobId = startJob.data?['job_id']?.toString();
        if (jobId != null && await _pollJob(jobId)) {
          // Success!
        } else {
           _errorMessage = 'Video generation failed or timed out.';
           notifyListeners();
           return false;
        }
      }
    }

    // Finalize & Save
    if (_currentTrip != null) {
      _tripHistory.insert(0, _currentTrip!);
      _saveHistory();
      
      // SYNC TO CLOUD if logged in
      if (_userId != null) {
        _api.saveTripToCloud(userId: _userId!, trip: _currentTrip!, videoUrl: _generatedVideoUrl);
      }
    }

    notifyListeners();
    return true;
  }

  void reset() {
    _itineraryState = LoadState.idle; _imageState = LoadState.idle; _storyState = LoadState.idle;
    _currentTrip = null; _selectedImages = []; _errorMessage = null; _processingStep = 0;
    _generatedVideoUrl = null; _videoEngine = null; _videoMessage = null;
    notifyListeners();
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(_tripHistory.map((t) => t.toJson()).toList());
    await prefs.setString(_keyHistory, jsonStr);
  }

  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_keyHistory);
      if (jsonStr != null) {
        final List<dynamic> data = jsonDecode(jsonStr);
        _tripHistory = data.map((item) => TripModel.fromJson(item)).toList();
      }
      
      // SYNC FROM CLOUD if user is logged in
      if (_userId != null) {
        final cloudRes = await _api.getUserHistory(_userId!);
        if (cloudRes.isSuccess && cloudRes.data != null) {
           // Merge cloud and local (simplified: use cloud as source of truth for now)
           _tripHistory = cloudRes.data!;
           _saveHistory();
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading history: $e');
    }
  }

  Future<bool> _pollJob(String jobId) async {
    for (int attempt = 0; attempt < 180; attempt++) {
      await Future.delayed(const Duration(seconds: 2));
      final poll = await _api.getCinematicStatus(jobId);
      if (!poll.isSuccess) continue;
      final statusData = poll.data ?? {};
      final status = statusData['status']?.toString().toLowerCase() ?? '';
      if (status == 'done') {
        final rawUrl = statusData['video_url']?.toString();
        if (rawUrl != null) _generatedVideoUrl = _normalizeVideoUrl(rawUrl);
        return true;
      }
      if (status == 'error') return false;
    }
    return false;
  }
}
