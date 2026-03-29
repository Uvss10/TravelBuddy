import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import '../models/trip_model.dart';
import '../services/api_service.dart';
import '../config/api_config.dart';

/// Loading state enum for UI feedback.
enum LoadState { idle, loading, success, error }

/// Central state for trip creation workflow.
class TripProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  // ─── State ───────────────────────────────────────────────────────────────────
  LoadState _itineraryState = LoadState.idle;
  LoadState _imageState     = LoadState.idle;
  LoadState _storyState     = LoadState.idle;

  TripModel? _currentTrip;
  List<TripModel> _tripHistory = [];
  List<File> _selectedImages   = [];
  String? _errorMessage;
  int _processingStep = 0; // 0=analyzing, 1=story, 2=reel
  String? _generatedVideoUrl;
  String? _videoEngine;
  String? _videoMessage;

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

    if (!rawUrl.startsWith('http')) {
      return '${ApiConfig.baseUrl}$rawUrl';
    }

    final raw = Uri.tryParse(rawUrl);
    final base = Uri.tryParse(ApiConfig.baseUrl);
    if (raw == null || base == null) return rawUrl;

    // Backend may return localhost/127.0.0.1 URLs that are unreachable from phone.
    if (raw.host == '127.0.0.1' || raw.host == 'localhost' || raw.host == '0.0.0.0') {
      return base
          .replace(
            path: raw.path,
            query: raw.query.isEmpty ? null : raw.query,
            fragment: raw.fragment.isEmpty ? null : raw.fragment,
          )
          .toString();
    }

    return rawUrl;
  }

  void _ensureCurrentTripForReel({
    required String destination,
    required List<String> sceneTags,
  }) {
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
  Future<bool> generateItinerary({
    required String destination,
    required int days,
    required String budget,
    required List<String> interests,
  }) async {
    _itineraryState = LoadState.loading;
    _errorMessage = null;
    notifyListeners();

    final result = await _api.generateItinerary(
      destination: destination,
      days: days,
      budget: budget,
      interests: interests,
    );

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

  // ─── Full AI processing pipeline ─────────────────────────────────────────────
  Future<bool> processAll({
    required String destination,
    required List<String> sceneTags,
    String tone = 'adventurous and inspiring',
    String? localAudioPath,
  }) async {
    _errorMessage = null;
    _generatedVideoUrl = null;
    _videoEngine = null;
    _videoMessage = null;

    List<String> serverImagePaths = [];

    _ensureCurrentTripForReel(destination: destination, sceneTags: sceneTags);

    // Step 0: Analysing Images
    if (_selectedImages.isNotEmpty) {
      _processingStep = 0;
      _imageState = LoadState.loading;
      notifyListeners();

      final imgResult = await _api.uploadImages(_selectedImages);
      _imageState = imgResult.isSuccess ? LoadState.success : LoadState.error;
      if (!imgResult.isSuccess) {
        _errorMessage = imgResult.error;
        notifyListeners();
        return false;
      }

      final analysis = imgResult.data?['analysis_results'];
      if (analysis is Map<String, dynamic>) {
        serverImagePaths = List<String>.from(analysis['selected_images'] ?? const []);
      }
    }

    // Step 1: Generating Story
    _processingStep = 1;
    _storyState = LoadState.loading;
    notifyListeners();

    final storyResult = await _api.generateStory(
      destination: destination,
      sceneTags: sceneTags,
      tone: tone,
    );

    if (storyResult.isSuccess) {
      if (_currentTrip == null) {
        _ensureCurrentTripForReel(destination: destination, sceneTags: sceneTags);
      }
      _currentTrip = _currentTrip?.copyWithStory(storyResult.data!);
      _storyState = LoadState.success;
    } else {
      _errorMessage = storyResult.error;
      _storyState = LoadState.error;
      notifyListeners();
      return false;
    }

    // Step 2: Generate reel video via backend (MoviePy / FFmpeg)
    _processingStep = 2;
    notifyListeners();

    if (_selectedImages.isNotEmpty) {
      if (serverImagePaths.isEmpty) {
        _errorMessage = 'No server-side selected images were returned for reel generation.';
        _storyState = LoadState.error;
        notifyListeners();
        return false;
      }

      // Build captions list from story (if available)
      final captions = _currentTrip?.captions ?? [];
      if (localAudioPath != null && localAudioPath.isNotEmpty) {
        final audioUpload = await _api.uploadAudio(File(localAudioPath));
        if (!audioUpload.isSuccess || (audioUpload.data ?? '').isEmpty) {
          _errorMessage = audioUpload.error ?? 'Failed to upload music file.';
          notifyListeners();
          return false;
        }

        final startJob = await _api.startCinematicVideo(
          imagePaths: serverImagePaths,
          captions: captions,
          destination: destination,
          audioPath: audioUpload.data,
          theme: 'cinematic',
          durationSeconds: 60,
        );

        if (!startJob.isSuccess) {
          _errorMessage = startJob.error ?? 'Failed to start cinematic video generation.';
          notifyListeners();
          return false;
        }

        final jobId = startJob.data?['job_id']?.toString();
        if (jobId == null || jobId.isEmpty) {
          _errorMessage = 'Cinematic video job did not return a valid job id.';
          notifyListeners();
          return false;
        }

        for (int attempt = 0; attempt < 180; attempt++) {
          await Future.delayed(const Duration(seconds: 2));

          final poll = await _api.getCinematicStatus(jobId);
          if (!poll.isSuccess) {
            continue;
          }

          final statusData = poll.data ?? {};
          final status = statusData['status']?.toString().toLowerCase() ?? '';
          _videoMessage = statusData['message']?.toString();

          if (status == 'done') {
            final rawUrl = statusData['video_url']?.toString();
            if (rawUrl != null && rawUrl.isNotEmpty) {
              _generatedVideoUrl = _normalizeVideoUrl(rawUrl);
              _videoEngine = 'cinematic';
              break;
            }
            _errorMessage = 'Cinematic render completed but video URL is missing.';
            notifyListeners();
            return false;
          }

          if (status == 'error' || status == 'not_found') {
            _errorMessage = _videoMessage ?? 'Cinematic render failed.';
            notifyListeners();
            return false;
          }
        }

        if (_generatedVideoUrl == null || _generatedVideoUrl!.isEmpty) {
          _errorMessage = 'Cinematic video generation timed out.';
          notifyListeners();
          return false;
        }
      } else {
        final videoResult = await _api.generateVideo(
          imagePaths : serverImagePaths,
          captions   : captions,
          destination: destination,
        );

        if (videoResult.isSuccess) {
          final data = videoResult.data ?? {};
          _videoEngine = data['engine']?.toString();
          _videoMessage = data['message']?.toString();

          final status = data['status']?.toString().toLowerCase();

          final rawUrl = data['video_url']?.toString();
          if (rawUrl != null && rawUrl.isNotEmpty) {
            _generatedVideoUrl = _normalizeVideoUrl(rawUrl);
          }

          // Mobile app cannot run the web js_canvas fallback engine.
          if (_generatedVideoUrl == null || _generatedVideoUrl!.isEmpty) {
            _errorMessage = _videoMessage ?? 'Video generation did not return a playable URL.';
            if ((_videoEngine ?? '').toLowerCase() == 'js_canvas' || status == 'fallback') {
              _errorMessage =
                  'Server returned web-only fallback (js_canvas). Install ffmpeg/moviepy on backend to enable mobile playback.';
            }
            notifyListeners();
            return false;
          }
        } else {
          _videoMessage = videoResult.error;
          _errorMessage = videoResult.error;
          notifyListeners();
          return false;
        }
      }
    }

    // Save to history
    if (_currentTrip != null) {
      _tripHistory.insert(0, _currentTrip!);
    }

    notifyListeners();
    return true;
  }

  void reset() {
    _itineraryState = LoadState.idle;
    _imageState     = LoadState.idle;
    _storyState     = LoadState.idle;
    _currentTrip    = null;
    _selectedImages = [];
    _errorMessage   = null;
    _processingStep = 0;
    _generatedVideoUrl = null;
    _videoEngine = null;
    _videoMessage = null;
    notifyListeners();
  }
}
