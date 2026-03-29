import 'dart:io';
import 'package:dio/dio.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../config/api_config.dart';
import '../models/trip_model.dart';

/// Result wrapper — avoids throwing exceptions through the UI layer.
class ApiResult<T> {
  final T? data;
  final String? error;
  bool get isSuccess => error == null;

  const ApiResult.success(this.data) : error = null;
  const ApiResult.failure(this.error) : data = null;
}

/// Central API service — all backend calls go through here.
class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  late final Dio _dio;

  ApiService._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: ApiConfig.connectTimeout,
        receiveTimeout: ApiConfig.receiveTimeout,
        headers: {'Content-Type': 'application/json'},
      ),
    );

    // ── Request / Response logger (dev only) ──
    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      error: true,
    ));

    // ── Retry interceptor (1 automatic retry on connection error) ──
    _dio.interceptors.add(InterceptorsWrapper(
      onError: (DioException e, handler) async {
        if (_isRetryable(e) && e.requestOptions.extra['retried'] != true) {
          e.requestOptions.extra['retried'] = true;
          try {
            final response = await _dio.fetch(e.requestOptions);
            return handler.resolve(response);
          } catch (_) {}
        }
        handler.next(e);
      },
    ));
  }

  bool _isRetryable(DioException e) =>
      e.type == DioExceptionType.connectionTimeout ||
      e.type == DioExceptionType.receiveTimeout ||
      e.type == DioExceptionType.connectionError;

  /// Check connectivity — used only when calling cloud services.
  /// Local backend (127.0.0.1) always works on LAN without internet.
  Future<bool> hasConnection() async {
    final result = await Connectivity().checkConnectivity();
    return result != ConnectivityResult.none;
  }

  // ─── Health check ────────────────────────────────────────────────────────────
  Future<ApiResult<bool>> checkHealth() async {
    try {
      final resp = await _dio.get(ApiConfig.health);
      return ApiResult.success(resp.statusCode == 200);
    } on DioException catch (e) {
      return ApiResult.failure(_mapError(e));
    }
  }

  // ─── Generate itinerary ──────────────────────────────────────────────────────
  Future<ApiResult<TripModel>> generateItinerary({
    required String destination,
    required int days,
    required String budget,
    required List<String> interests,
  }) async {
    if (!await hasConnection()) {
      return const ApiResult.failure('No internet connection. Please check your network.');
    }
    try {
      final resp = await _dio.post(
        ApiConfig.itineraryGen,
        data: {
          'destination': destination,
          'days': days,
          'budget': budget,
          'interests': interests,
        },
        options: Options(
          connectTimeout: const Duration(minutes: 10),
          sendTimeout: const Duration(minutes: 10),
          receiveTimeout: const Duration(minutes: 20),
        ),
      );
      final trip = TripModel.fromItineraryJson(resp.data as Map<String, dynamic>);
      return ApiResult.success(trip);
    } on DioException catch (e) {
      return ApiResult.failure(_mapError(e));
    }
  }

  // ─── Upload images ───────────────────────────────────────────────────────────
  Future<ApiResult<Map<String, dynamic>>> uploadImages(List<File> images) async {
    // Local backend — no internet check needed
    try {
      final formData = FormData();
      for (final file in images) {
        formData.files.add(MapEntry(
          'files',
          await MultipartFile.fromFile(file.path, filename: file.path.split('/').last),
        ));
      }
      final resp = await _dio.post(
        ApiConfig.imageUpload,
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
        onSendProgress: (sent, total) {
          // Progress can be consumed via stream if needed
        },
      );
      return ApiResult.success(resp.data as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResult.failure(_mapError(e));
    }
  }

  // ─── Generate story ──────────────────────────────────────────────────────────
  Future<ApiResult<Map<String, dynamic>>> generateStory({
    required String destination,
    required List<String> sceneTags,
    String tone = 'adventurous and inspiring',
  }) async {
    // Local backend — no internet check needed
    try {
      final resp = await _dio.post(
        ApiConfig.storyGenerate,
        data: {
          'destination': destination,
          'scene_tags': sceneTags,
          'tone': tone,
        },
        options: Options(
          connectTimeout: const Duration(minutes: 10),
          sendTimeout: const Duration(minutes: 10),
          receiveTimeout: const Duration(minutes: 20),
        ),
      );
      return ApiResult.success(resp.data as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResult.failure(_mapError(e));
    }
  }

  // ─── Generate video ──────────────────────────────────────────────────────────
  /// Triggers server-side video generation (MoviePy → FFmpeg → JS-canvas fallback).
  /// Returns the result map; if engine == 'js_canvas' the app shows the
  /// reel preview with a client-side generation notice.
  Future<ApiResult<Map<String, dynamic>>> generateVideo({
    required List<String> imagePaths,
    required List<String> captions,
    required String destination,
  }) async {
    try {
      final resp = await _dio.post(
        ApiConfig.videoGenerate,
        data: {
          'image_paths' : imagePaths,
          'captions'    : captions,
          'destination' : destination,
        },
        options: Options(receiveTimeout: const Duration(minutes: 5)),
      );
      return ApiResult.success(resp.data as Map<String, dynamic>);
    } on DioException catch (e) {
      // Non-fatal: frontend will fall back to JS Canvas generator
      return ApiResult.failure(_mapError(e));
    }
  }

  // ─── Upload audio (optional for cinematic flow) ────────────────────────────
  Future<ApiResult<String>> uploadAudio(File audioFile) async {
    try {
      final formData = FormData();
      formData.files.add(MapEntry(
        'file',
        await MultipartFile.fromFile(
          audioFile.path,
          filename: audioFile.path.split('/').last,
        ),
      ));

      final resp = await _dio.post(
        ApiConfig.videoUploadAudio,
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );

      final body = resp.data as Map<String, dynamic>;
      final path = body['audio_path']?.toString();
      if (path == null || path.isEmpty) {
        return const ApiResult.failure('Audio uploaded but backend did not return audio_path.');
      }
      return ApiResult.success(path);
    } on DioException catch (e) {
      return ApiResult.failure(_mapError(e));
    }
  }

  // ─── Start cinematic render job ─────────────────────────────────────────────
  Future<ApiResult<Map<String, dynamic>>> startCinematicVideo({
    required List<String> imagePaths,
    required List<String> captions,
    required String destination,
    String theme = 'cinematic',
    String? audioPath,
    int durationSeconds = 60,
  }) async {
    try {
      final resp = await _dio.post(
        ApiConfig.videoCinematic,
        data: {
          'image_paths': imagePaths,
          'captions': captions,
          'destination': destination,
          'theme': theme,
          'audio_path': audioPath,
          'duration_s': durationSeconds,
        },
        options: Options(receiveTimeout: const Duration(minutes: 2)),
      );
      return ApiResult.success(resp.data as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResult.failure(_mapError(e));
    }
  }

  // ─── Poll cinematic render job status ───────────────────────────────────────
  Future<ApiResult<Map<String, dynamic>>> getCinematicStatus(String jobId) async {
    try {
      final resp = await _dio.get('${ApiConfig.videoStatus}/$jobId');
      return ApiResult.success(resp.data as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResult.failure(_mapError(e));
    }
  }

  // ─── Error mapper ────────────────────────────────────────────────────────────
  String _mapError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Request timed out while connecting to ${ApiConfig.baseUrl}. Verify backend is running and reachable from phone.';
      case DioExceptionType.connectionError:
        return 'Cannot connect to ${ApiConfig.baseUrl}. Make sure backend is running and phone/laptop are on same Wi-Fi.';
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        final message = e.response?.data?['detail'] ?? 'Server error';
        return 'Error $statusCode: $message';
      default:
        return e.message ?? 'An unexpected error occurred.';
    }
  }
}
