import 'dart:io';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

// ── Enums ─────────────────────────────────────────────────────────────────────

enum ReelStudioStage { idle, uploading, analyzing, curation, storyboard, atmosphere, annotation, rendering, done, error }

// ── Model: Curated photo (editable by user) ───────────────────────────────────

class CuratedPhoto {
  final String path;
  final double quality;
  final String shotType;
  final String orientation;
  final double faceScore;
  final int faceCount;
  final bool aiPick;
  final bool isTravelHero;
  final String aiInsight;
  final bool isDuplicate;
  // v2 scores
  final double colorVibrancy;
  final double goldenHour;
  final double skyPresence;
  final double compositionScore;
  final double noiseScore;
  final double blurScore;
  final double exposureScore;

  bool userKept;
  String caption;

  CuratedPhoto({
    required this.path,
    required this.quality,
    required this.shotType,
    required this.orientation,
    required this.faceScore,
    this.faceCount = 0,
    required this.aiPick,
    this.isTravelHero = false,
    this.aiInsight = '',
    this.isDuplicate = false,
    this.colorVibrancy = 0.0,
    this.goldenHour = 0.0,
    this.skyPresence = 0.0,
    this.compositionScore = 0.0,
    this.noiseScore = 1.0,
    this.blurScore = 0.0,
    this.exposureScore = 0.0,
    this.userKept = true,
    this.caption = '',
  });

  factory CuratedPhoto.fromJson(Map<String, dynamic> json) => CuratedPhoto(
        path:             json['path'] as String? ?? '',
        quality:          (json['overall_quality'] as num?)?.toDouble() ?? 0.0,
        shotType:         json['shot_type'] as String? ?? 'wide',
        orientation:      json['orientation'] as String? ?? 'landscape',
        faceScore:        (json['face_score'] as num?)?.toDouble() ?? 0.0,
        faceCount:        (json['face_count'] as num?)?.toInt() ?? 0,
        aiPick:           json['ai_pick'] as bool? ?? false,
        isTravelHero:     json['is_travel_hero'] as bool? ?? false,
        aiInsight:        json['ai_insight'] as String? ?? '',
        isDuplicate:      json['is_duplicate'] as bool? ?? false,
        colorVibrancy:    (json['color_vibrancy'] as num?)?.toDouble() ?? 0.0,
        goldenHour:       (json['golden_hour'] as num?)?.toDouble() ?? 0.0,
        skyPresence:      (json['sky_presence'] as num?)?.toDouble() ?? 0.0,
        compositionScore: (json['composition_score'] as num?)?.toDouble() ?? 0.0,
        noiseScore:       (json['noise_score'] as num?)?.toDouble() ?? 1.0,
        blurScore:        (json['blur_score'] as num?)?.toDouble() ?? 0.0,
        exposureScore:    (json['exposure_score'] as num?)?.toDouble() ?? 0.0,
        userKept: true,
        caption: '',
      );

  Map<String, dynamic> toSelectionJson() => {
        'path': path,
        'caption': caption,
        'user_kept': userKept,
      };
}

// ── Model: Timeline Slot (from backend, editable caption) ─────────────────────

class TimelineSlotModel {
  final int index;
  final String photoPath;
  final String section;
  final double startS;
  final double endS;
  final double durationS;
  final String shotType;
  final String orientation;
  String caption;

  TimelineSlotModel({
    required this.index,
    required this.photoPath,
    required this.section,
    required this.startS,
    required this.endS,
    required this.durationS,
    required this.shotType,
    required this.orientation,
    this.caption = '',
  });

  factory TimelineSlotModel.fromJson(Map<String, dynamic> json) => TimelineSlotModel(
        index: (json['index'] as num?)?.toInt() ?? 0,
        photoPath: json['photo_path'] as String? ?? '',
        section: json['section'] as String? ?? 'middle',
        startS: (json['start_s'] as num?)?.toDouble() ?? 0.0,
        endS: (json['end_s'] as num?)?.toDouble() ?? 0.0,
        durationS: (json['duration_s'] as num?)?.toDouble() ?? 2.0,
        shotType: json['shot_type'] as String? ?? 'wide',
        orientation: json['orientation'] as String? ?? 'landscape',
        caption: json['caption'] as String? ?? '',
      );

  Map<String, dynamic> toOverrideJson() => {
        'index': index,
        'photo_path': photoPath,
        'caption': caption,
      };
}

// ── Provider ──────────────────────────────────────────────────────────────────

class ReelDraftProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  // ── State ─────────────────────────────────────────────────────────────────
  ReelStudioStage _stage = ReelStudioStage.idle;
  String _statusMessage = '';
  String? _error;

  // Stage 1 – Analysis results
  String? _draftId;
  List<CuratedPhoto> _allPhotos = [];
  int _aiPickCount = 0;
  Map<String, List<CuratedPhoto>> _groups = {};

  // Stage 2 – Storyboard
  List<CuratedPhoto> _curatedOrder = [];
  String _selectedTheme = 'cinematic';
  double _energyLevel = 0.5;
  int _durationSeconds = 60;
  List<TimelineSlotModel> _timeline = [];

  // Stage 3 – Atmosphere
  String? _selectedAudioPath;
  String? _selectedAudioName;

  // Stage 4 – Annotation (captions are stored on TimelineSlotModel.caption)

  // Stage 5 – Production
  String? _jobId;
  double _renderProgress = 0.0;
  String? _finalVideoUrl;

  // ── Getters ───────────────────────────────────────────────────────────────
  ReelStudioStage get stage => _stage;
  String get statusMessage => _statusMessage;
  String? get error => _error;

  String? get draftId => _draftId;
  List<CuratedPhoto> get allPhotos => _allPhotos;
  int get aiPickCount => _aiPickCount;
  Map<String, List<CuratedPhoto>> get groups => _groups;

  List<CuratedPhoto> get curatedOrder => _curatedOrder;
  String get selectedTheme => _selectedTheme;
  double get energyLevel => _energyLevel;
  int get durationSeconds => _durationSeconds;
  List<TimelineSlotModel> get timeline => _timeline;
  int get keptCount => _allPhotos.where((p) => p.userKept).length;

  String? get selectedAudioPath => _selectedAudioPath;
  String? get selectedAudioName => _selectedAudioName;

  String? get jobId => _jobId;
  double get renderProgress => _renderProgress;
  String? get finalVideoUrl => _finalVideoUrl;

  bool get isLoading => _stage == ReelStudioStage.uploading ||
      _stage == ReelStudioStage.analyzing ||
      _stage == ReelStudioStage.rendering;

  // ── Reset ──────────────────────────────────────────────────────────────────
  void reset() {
    _stage = ReelStudioStage.idle;
    _statusMessage = '';
    _error = null;
    _draftId = null;
    _allPhotos = [];
    _aiPickCount = 0;
    _groups = {};
    _curatedOrder = [];
    _selectedTheme = 'cinematic';
    _energyLevel = 0.5;
    _durationSeconds = 60;
    _timeline = [];
    _selectedAudioPath = null;
    _selectedAudioName = null;
    _jobId = null;
    _renderProgress = 0.0;
    _finalVideoUrl = null;
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // STAGE 1: Upload + Analyze
  // ─────────────────────────────────────────────────────────────────────────────
  Future<void> uploadAndAnalyze(List<File> localFiles) async {
    _stage = ReelStudioStage.uploading;
    _statusMessage = 'Uploading ${localFiles.length} photos…';
    _error = null;
    notifyListeners();

    // 1. Upload to server
    final uploadResult = await _api.uploadImages(localFiles);
    if (!uploadResult.isSuccess) {
      _setError(uploadResult.error ?? 'Upload failed.');
      return;
    }

    final serverPaths = List<String>.from(uploadResult.data?['image_paths'] ?? []);

    if (serverPaths.isEmpty) {
      _setError('No valid images returned from server.');
      return;
    }

    // 2. Analyze
    _stage = ReelStudioStage.analyzing;
    _statusMessage = '🔍 AI is scanning ${serverPaths.length} photos…';
    notifyListeners();

    final analyzeResult = await _api.reelAnalyze(serverPaths);
    if (!analyzeResult.isSuccess) {
      _setError(analyzeResult.error ?? 'Analysis failed.');
      return;
    }

    final data = analyzeResult.data!;
    _draftId = data['draft_id'] as String?;
    _aiPickCount = (data['ai_pick_count'] as num?)?.toInt() ?? 0;

    final rawPhotos = data['all_photos'] as List<dynamic>? ?? [];
    _allPhotos = rawPhotos.map((e) => CuratedPhoto.fromJson(e as Map<String, dynamic>)).toList();

    // Build groups
    final rawGroups = data['groups'] as Map<String, dynamic>? ?? {};
    _groups = {};
    rawGroups.forEach((key, val) {
      final list = (val as List<dynamic>).map((e) => CuratedPhoto.fromJson(e as Map<String, dynamic>)).toList();
      _groups[key] = list;
    });

    // Default curation order = all AI picks first, rest after
    _curatedOrder = List<CuratedPhoto>.from(_allPhotos);

    _stage = ReelStudioStage.curation;
    _statusMessage = 'Analysis complete! ${_allPhotos.length} photos found.';
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // STAGE 1 interactions: Curation wall
  // ─────────────────────────────────────────────────────────────────────────────
  void togglePhotoKept(String path) {
    final photo = _allPhotos.firstWhere((p) => p.path == path, orElse: () => _allPhotos.first);
    photo.userKept = !photo.userKept;

    // Keep curatedOrder in sync (remove if unchecked)
    if (!photo.userKept) {
      _curatedOrder.removeWhere((p) => p.path == path);
    } else {
      if (!_curatedOrder.any((p) => p.path == path)) {
        _curatedOrder.add(photo);
      }
    }
    notifyListeners();
  }

  void selectAllAiPicks() {
    for (final p in _allPhotos) {
      p.userKept = p.aiPick;
    }
    _curatedOrder = _allPhotos.where((p) => p.userKept).toList();
    notifyListeners();
  }

  void selectAll() {
    for (final p in _allPhotos) {
      p.userKept = true;
    }
    _curatedOrder = List<CuratedPhoto>.from(_allPhotos);
    notifyListeners();
  }

  void advanceToCuration() {
    _stage = ReelStudioStage.curation;
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // STAGE 2: Storyboard
  // ─────────────────────────────────────────────────────────────────────────────
  void reorderPhoto(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    final item = _curatedOrder.removeAt(oldIndex);
    _curatedOrder.insert(newIndex, item);
    notifyListeners();
  }

  void setTheme(String theme) {
    _selectedTheme = theme;
    notifyListeners();
  }

  void setEnergyLevel(double level) {
    _energyLevel = level;
    notifyListeners();
  }

  void setDuration(int seconds) {
    _durationSeconds = seconds;
    notifyListeners();
  }

  Future<void> buildTimeline() async {
    if (_draftId == null) {
      _setError('No draft ID. Please restart the process.');
      return;
    }
    final kept = _curatedOrder.where((p) => p.userKept).toList();
    if (kept.isEmpty) {
      _setError('Please select at least 1 photo.');
      return;
    }

    _statusMessage = '🎬 Building your storyboard…';
    notifyListeners();

    final result = await _api.reelBuildTimeline(
      draftId: _draftId!,
      selectedPhotos: kept.map((p) => p.toSelectionJson()).toList(),
      theme: _selectedTheme,
      energyLevel: _energyLevel,
      durationSeconds: _durationSeconds,
    );

    if (!result.isSuccess) {
      _setError(result.error ?? 'Timeline build failed.');
      return;
    }

    final rawSlots = result.data?['slots'] as List<dynamic>? ?? [];
    _timeline = rawSlots.map((s) => TimelineSlotModel.fromJson(s as Map<String, dynamic>)).toList();

    _stage = ReelStudioStage.storyboard;
    _statusMessage = 'Storyboard ready — ${_timeline.length} slots';
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // STAGE 3: Atmosphere (Music / Theme)
  // ─────────────────────────────────────────────────────────────────────────────
  void setAudio(String path, String name) {
    _selectedAudioPath = path;
    _selectedAudioName = name;
    notifyListeners();
  }

  void clearAudio() {
    _selectedAudioPath = null;
    _selectedAudioName = null;
    notifyListeners();
  }

  void advanceToAtmosphere() {
    _stage = ReelStudioStage.atmosphere;
    notifyListeners();
  }

  void advanceToAnnotation() {
    _stage = ReelStudioStage.annotation;
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // STAGE 4: Annotation (captions per slot)
  // ─────────────────────────────────────────────────────────────────────────────
  void updateCaption(int slotIndex, String caption) {
    if (slotIndex >= 0 && slotIndex < _timeline.length) {
      _timeline[slotIndex].caption = caption;
      notifyListeners();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // STAGE 5: Render
  // ─────────────────────────────────────────────────────────────────────────────
  Future<void> startRender(String destination) async {
    if (_draftId == null) {
      _setError('No draft found. Please restart.');
      return;
    }

    _stage = ReelStudioStage.rendering;
    _renderProgress = 0.0;
    _statusMessage = '🚀 Starting the cinematic engine…';
    notifyListeners();

    final result = await _api.reelRender(
      draftId: _draftId!,
      slotOverrides: _timeline.map((s) => s.toOverrideJson()).toList(),
      destination: destination,
      theme: _selectedTheme,
      durationSeconds: _durationSeconds,
      audioPath: _selectedAudioPath,
    );

    if (!result.isSuccess) {
      _setError(result.error ?? 'Failed to start render.');
      return;
    }

    _jobId = result.data?['job_id']?.toString();
    _statusMessage = 'Render queued — this takes 1-3 minutes…';
    notifyListeners();
  }

  void updateRenderProgress(double progress, String message, String? videoUrl) {
    _renderProgress = progress;
    _statusMessage = message;
    if (videoUrl != null && videoUrl.isNotEmpty) {
      _finalVideoUrl = videoUrl;
      _stage = ReelStudioStage.done;
    }
    notifyListeners();
  }

  // ── Internal ──────────────────────────────────────────────────────────────
  void _setError(String message) {
    _stage = ReelStudioStage.error;
    _error = message;
    _statusMessage = message;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
