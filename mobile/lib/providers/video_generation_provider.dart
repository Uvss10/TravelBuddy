import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:async';
import '../services/api_service.dart';
import '../config/api_config.dart';

enum GenerationStatus { initial, uploading, generating, completed, error }

class VideoGenerationProvider extends ChangeNotifier {
  GenerationStatus _status = GenerationStatus.initial;
  double _progress = 0.0;
  String _message = '';
  String? _jobId;
  String? _finalVideoUrl;
  Timer? _pollingTimer;
  int _pollFailureCount = 0;
  int _pollTickCount = 0;

  final ApiService _api = ApiService();

  GenerationStatus get status => _status;
  double get progress => _progress;
  String get message => _message;
  String? get finalVideoUrl => _finalVideoUrl;
  bool get isActive => _status == GenerationStatus.uploading || _status == GenerationStatus.generating;

  void reset() {
    _status = GenerationStatus.initial;
    _progress = 0.0;
    _message = '';
    _jobId = null;
    _finalVideoUrl = null;
    _pollingTimer?.cancel();
    notifyListeners();
  }

  void _setError(String message) {
    _status = GenerationStatus.error;
    _message = message;
    notifyListeners();
  }

  String _normalizeVideoUrl(String rawUrl) {
    if (rawUrl.isEmpty) return rawUrl;

    String encodeAbsolute(String url) {
      final parsed = Uri.tryParse(url);
      if (parsed == null) return url.replaceAll(' ', '%20');
      return parsed.replace(pathSegments: parsed.pathSegments).toString();
    }

    if (!rawUrl.startsWith('http')) {
      final base = Uri.tryParse(ApiConfig.baseUrl);
      if (base == null) return '${ApiConfig.baseUrl}${rawUrl.replaceAll(' ', '%20')}';

      final path = rawUrl.startsWith('/') ? rawUrl : '/$rawUrl';
      return base.replace(path: path).toString();
    }

    final raw = Uri.tryParse(rawUrl);
    final base = Uri.tryParse(ApiConfig.baseUrl);
    if (raw == null || base == null) return encodeAbsolute(rawUrl);

    if (raw.host == '127.0.0.1' || raw.host == 'localhost' || raw.host == '0.0.0.0') {
      return base
          .replace(
            path: raw.path,
            query: raw.query.isEmpty ? null : raw.query,
            fragment: raw.fragment.isEmpty ? null : raw.fragment,
          )
          .toString();
    }
    return encodeAbsolute(rawUrl);
  }

  Future<void> startCinematicGeneration({
    required List<String> imagePaths,
    required String destination,
    required String theme,
    String? audioPath,
  }) async {
    _pollingTimer?.cancel();
    _pollFailureCount = 0;
    _pollTickCount = 0;

    try {
      if (imagePaths.isEmpty) {
        _setError('Please select at least one photo to generate the reel.');
        return;
      }

      _status = GenerationStatus.uploading;
      _message = 'Uploading selected photos...';
      _progress = 0.1;
      notifyListeners();

      final localFiles = imagePaths
          .where((path) => path.trim().isNotEmpty)
          .map((path) => File(path))
          .where((file) => file.existsSync())
          .toList();

      if (localFiles.isEmpty) {
        _setError('Selected photos are not accessible. Please reselect photos and try again.');
        return;
      }

      final uploadResult = await _api.uploadImages(localFiles);
      if (!uploadResult.isSuccess) {
        _setError(uploadResult.error ?? 'Failed to upload photos for reel generation.');
        return;
      }

      final analysis = uploadResult.data?['analysis_results'];
      final serverImagePaths = (analysis is Map<String, dynamic>)
          ? List<String>.from(analysis['selected_images'] ?? const [])
          : <String>[];

      if (serverImagePaths.isEmpty) {
        _setError('No valid server-side images were returned. Please try different photos.');
        return;
      }

      String? uploadedAudioPath;
      if (audioPath != null && audioPath.trim().isNotEmpty) {
        if (audioPath.startsWith('static/') || audioPath.startsWith('backend/static/')) {
          // It's a server-side asset, skip upload
          uploadedAudioPath = audioPath;
        } else {
          _message = 'Uploading music track...';
          _progress = 0.35;
          notifyListeners();

          final audioFile = File(audioPath);
          if (!audioFile.existsSync()) {
            _setError('Selected music file is not accessible. Please pick it again.');
            return;
          }

          final audioUpload = await _api.uploadAudio(audioFile);
          if (!audioUpload.isSuccess || (audioUpload.data ?? '').isEmpty) {
            _setError(audioUpload.error ?? 'Failed to upload music track.');
            return;
          }
          uploadedAudioPath = audioUpload.data;
        }
      }

      _status = GenerationStatus.generating;
      _message = 'Initializing cinematic engine...';
      _progress = 0.45;
      notifyListeners();

      final startResult = await _api.startCinematicVideo(
        imagePaths: serverImagePaths,
        captions: const [],
        destination: destination,
        theme: theme,
        audioPath: uploadedAudioPath,
        durationSeconds: 60,
      );

      if (!startResult.isSuccess) {
        _setError(startResult.error ?? 'Failed to start cinematic render job.');
        return;
      }

      _jobId = startResult.data?['job_id']?.toString();
      if (_jobId == null || _jobId!.isEmpty) {
        _setError('Video generation job started without a valid job ID.');
        return;
      }

      _startPolling();
    } catch (_) {
      _setError('Could not start video generation. Please try again.');
    }
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (_jobId == null || _jobId!.isEmpty) {
        timer.cancel();
        return;
      }

      _pollTickCount++;
      if (_pollTickCount > 180) {
        timer.cancel();
        _setError('Video generation timed out. Please try again.');
        return;
      }

      final response = await _api.getCinematicStatus(_jobId!);
      if (!response.isSuccess) {
        _pollFailureCount++;
        if (_pollFailureCount >= 5) {
          timer.cancel();
          _setError(response.error ?? 'Connection lost while tracking video generation.');
        }
        return;
      }

      _pollFailureCount = 0;
      final data = response.data ?? const <String, dynamic>{};
      final statusStr = data['status']?.toString().toLowerCase() ?? '';

      if (statusStr == 'done' || statusStr == 'completed') {
        timer.cancel();
        final rawUrl = data['video_url']?.toString();
        if (rawUrl == null || rawUrl.isEmpty) {
          _setError('Generation finished but no playable video URL was returned.');
          return;
        }

        _status = GenerationStatus.completed;
        _progress = 1.0;
        _message = 'Your cinematic reel is ready!';
        _finalVideoUrl = _normalizeVideoUrl(rawUrl);
        notifyListeners();
        return;
      }

      if (statusStr == 'error' || statusStr == 'failed' || statusStr == 'not_found') {
        timer.cancel();
        _setError(
          data['error']?.toString() ??
              data['message']?.toString() ??
              'Generation failed on the server.',
        );
        return;
      }

      final rawProgress = data['progress'];
      final progressNumber = rawProgress is num ? rawProgress.toDouble() : 0.0;
      final normalized = progressNumber > 1.0 ? progressNumber / 100.0 : progressNumber;
      _progress = (0.45 + (normalized.clamp(0.0, 1.0) * 0.5)).clamp(0.45, 0.98);
      _message = data['message']?.toString() ?? 'Adding magic...';
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }
}
