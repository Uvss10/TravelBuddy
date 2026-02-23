import 'dart:io';
import 'package:flutter/material.dart';
import '../models/trip_model.dart';
import '../services/api_service.dart';

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

  // ─── Image selection ─────────────────────────────────────────────────────────
  void setImages(List<File> files) {
    _selectedImages = files;
    notifyListeners();
  }

  void removeImage(int index) {
    _selectedImages.removeAt(index);
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
  }) async {
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
      _currentTrip = _currentTrip?.copyWithStory(storyResult.data!) ?? _currentTrip;
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

    if (_currentTrip != null && _selectedImages.isNotEmpty) {
      // Build captions list from story (if available)
      final captions = _currentTrip?.captions ?? [];
      await _api.generateVideo(
        imagePaths : [], // backend will use its stored paths from the upload
        captions   : captions,
        destination: destination,
      );
      // Note: if backend returns js_canvas fallback, ReelPreviewScreen
      // uses the client-side Canvas generator — no extra action needed here.
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
    notifyListeners();
  }
}
