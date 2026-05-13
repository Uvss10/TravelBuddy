import 'dart:io';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../config/api_config.dart';
import '../models/trip_model.dart';
import 'config_service.dart';

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

  late Dio _dio;
  Dio get dio => _dio;

  ApiService._internal() {
    _dio = _buildDio(ConfigService().backendUrl);
  }

  Dio _buildDio(String baseUrl) {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: ApiConfig.connectTimeout,
        receiveTimeout: ApiConfig.receiveTimeout,
        headers: {
          'Content-Type': 'application/json',
          'bypass-tunnel-reminders': 'true',
        },
      ),
    );

    // ── Request / Response logger (dev only) ──
    dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      error: true,
    ));

    // ── Retry interceptor (1 automatic retry on connection error) ──
    dio.interceptors.add(InterceptorsWrapper(
      onError: (DioException e, handler) async {
        if (_isRetryable(e) && e.requestOptions.extra['retried'] != true) {
          e.requestOptions.extra['retried'] = true;
          try {
            final response = await dio.fetch(e.requestOptions);
            return handler.resolve(response);
          } catch (_) {}
        }
        handler.next(e);
      },
    ));
    return dio;
  }

  /// Called by main() after ConfigService loads the fresh URL from Supabase.
  /// Rebuilds Dio with the new baseUrl — no APK rebuild needed.
  void reinitialize() {
    _dio = _buildDio(ConfigService().backendUrl);
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
      final data = resp.data;
      if (data == null || data is! Map<String, dynamic>) {
        return const ApiResult.failure('Server returned invalid itinerary data format.');
      }
      final trip = TripModel.fromItineraryJson(data);
      return ApiResult.success(trip);
    } on DioException catch (e) {
      return ApiResult.failure(_mapError(e));
    }
  }

  Future<ApiResult<TripModel>> editItinerary({
    required TripModel currentTrip,
    required String modification,
  }) async {
    if (!await hasConnection()) {
      return const ApiResult.failure('No internet connection. Please check your network.');
    }
    try {
      final resp = await _dio.post(
        ApiConfig.itineraryEdit,
        data: {
          'existing_plan': jsonDecode(currentTrip.itineraryOutput ?? '{}'),
          'modification': modification,
          'interests': currentTrip.interests,
        },
        options: Options(
          connectTimeout: const Duration(minutes: 10),
          sendTimeout: const Duration(minutes: 10),
          receiveTimeout: const Duration(minutes: 20),
        ),
      );
      final data = resp.data;
      if (data == null || data is! Map<String, dynamic>) {
        return const ApiResult.failure('Server returned invalid edited itinerary format.');
      }
      final trip = TripModel.fromItineraryJson(data);
      // Preserve existing ID, videoUrl, storyTitle etc.
      final updatedTrip = currentTrip.copyWith(
        itineraryOutput: trip.itineraryOutput,
      );
      return ApiResult.success(updatedTrip);
    } on DioException catch (e) {
      return ApiResult.failure(_mapError(e));
    }
  }

  Future<ApiResult<String>> exportItineraryDocx(TripModel trip) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final savePath = '${tempDir.path}/Itinerary_${trip.destination}.docx';
      
      final itineraryData = {
        'destination': trip.destination,
        'total_days': trip.days,
        'budget_category': trip.budget,
        'itinerary_ai_output': jsonDecode(trip.itineraryOutput ?? '{}'),
      };

      await _dio.download(
        ApiConfig.itineraryDocx,
        savePath,
        data: itineraryData,
        options: Options(method: 'POST'),
      );
      
      return ApiResult.success(savePath);
    } on DioException catch (e) {
      return ApiResult.failure(_mapError(e));
    } catch (e) {
      return ApiResult.failure(e.toString());
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

  // ─── Music Library: Copyright-free tracks ──────────────────────────────────
  Future<ApiResult<List<dynamic>>> getMusicLibrary() async {
    try {
      final resp = await _dio.get(ApiConfig.videoMusicLibrary);
      final data = resp.data as Map<String, dynamic>;
      return ApiResult.success(data['tracks'] as List<dynamic>);
    } on DioException catch (e) {
      return ApiResult.failure(_mapError(e));
    }
  }
  
  // ─── Reel Studio Stage 1: Analyze ────────────────────────────────────────────
  Future<ApiResult<Map<String, dynamic>>> reelAnalyze(List<String> serverPaths) async {
    try {
      final resp = await _dio.post(
        ApiConfig.reelAnalyze,
        data: {'image_paths': serverPaths},
        options: Options(receiveTimeout: const Duration(minutes: 3)),
      );
      return ApiResult.success(resp.data as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResult.failure(_mapError(e));
    }
  }

  // ─── Reel Studio Stage 2: Build Timeline ─────────────────────────────────────
  Future<ApiResult<Map<String, dynamic>>> reelBuildTimeline({
    required String draftId,
    required List<Map<String, dynamic>> selectedPhotos,
    required String theme,
    required double energyLevel,
    required int durationSeconds,
  }) async {
    try {
      final resp = await _dio.post(
        ApiConfig.reelBuildTimeline,
        data: {
          'draft_id': draftId,
          'selected_photos': selectedPhotos,
          'theme': theme,
          'energy_level': energyLevel,
          'duration_s': durationSeconds,
        },
        options: Options(receiveTimeout: const Duration(minutes: 2)),
      );
      return ApiResult.success(resp.data as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResult.failure(_mapError(e));
    }
  }

  // ─── Reel Studio Stage 3: Render ─────────────────────────────────────────────
  Future<ApiResult<Map<String, dynamic>>> reelRender({
    required String draftId,
    required List<Map<String, dynamic>> slotOverrides,
    required String destination,
    required String theme,
    required int durationSeconds,
    String? audioPath,
  }) async {
    try {
      final resp = await _dio.post(
        ApiConfig.reelRender,
        data: {
          'draft_id': draftId,
          'slot_overrides': slotOverrides,
          'destination': destination,
          'theme': theme,
          'duration_s': durationSeconds,
          if (audioPath != null) 'audio_path': audioPath,
        },
        options: Options(receiveTimeout: const Duration(minutes: 2)),
      );
      return ApiResult.success(resp.data as Map<String, dynamic>);
    } on DioException catch (e) {
      return ApiResult.failure(_mapError(e));
    }
  }

  // ─── Discovery: Nearby Spots ────────────────────────────────────────────────
  Future<ApiResult<List<dynamic>>> getNearbySpots(String location, {double? lat, double? lon}) async {
    try {
      final queryParams = {
        'location': location,
        if (lat != null) 'lat': lat,
        if (lon != null) 'lon': lon,
      };
      final resp = await _dio.get(ApiConfig.discoveryNearby, queryParameters: queryParams);
      final data = resp.data as Map<String, dynamic>;
      return ApiResult.success(data['spots'] as List<dynamic>);
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

  // ─── Auth ──────────────────────────────────────────────────────────────────
  Future<ApiResult<Map<String, dynamic>>> register(String name, String email, String password) async {
    try {
      final resp = await _dio.post(ApiConfig.authRegister, data: {'email': email, 'password': password, 'name': name});
      return ApiResult.success(resp.data);
    } on DioException catch (e) { return ApiResult.failure(_mapError(e)); }
  }

  Future<ApiResult<Map<String, dynamic>>> login(String email, String password) async {
    try {
      final resp = await _dio.post(ApiConfig.authLogin, data: {'email': email, 'password': password});
      return ApiResult.success(resp.data);
    } on DioException catch (e) { return ApiResult.failure(_mapError(e)); }
  }

  // ─── History Sync ──────────────────────────────────────────────────────────
  Future<ApiResult<void>> saveTripToCloud({
    required String userId,
    required TripModel trip,
    String? videoUrl,
  }) async {
    try {
      await _dio.post(ApiConfig.historySave, data: {
        'user_id': userId,
        'destination': trip.destination,
        'title': trip.storyTitle ?? 'Trip',
        'narration': trip.storyNarration ?? '',
        'captions': trip.captions,
        'hashtags': trip.hashtags,
        'video_url': videoUrl,
      });
      return const ApiResult.success(null);
    } on DioException catch (e) { return ApiResult.failure(_mapError(e)); }
  }

  Future<ApiResult<List<TripModel>>> getUserHistory(String userId) async {
    try {
      final resp = await _dio.get('${ApiConfig.historyList}/$userId');
      final list = (resp.data as List).map((t) => TripModel.fromJson(t)).toList();
      return ApiResult.success(list);
    } on DioException catch (e) { return ApiResult.failure(_mapError(e)); }
  }

  Future<ApiResult<void>> deleteTrip(int tripId) async {
    try {
      await _dio.delete('${ApiConfig.historyList}/$tripId');
      return const ApiResult.success(null);
    } on DioException catch (e) {
      return ApiResult.failure(_mapError(e));
    }
  }
}
