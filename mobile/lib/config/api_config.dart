/// All API endpoint configuration lives here.
/// Change [baseUrl] to your server address.
class ApiConfig {
  // ─── Base URL ───────────────────────────────────────────────────────────────
  /// Override with --dart-define=API_BASE_URL=http://<ip>:8000 when needed.
  /// Default below is configured for a physical Android device on the same LAN.
  /// IMPORTANT: Update this IP whenever the laptop's Wi-Fi IP changes.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.249.251.50:8000',
  );

  // ─── Endpoints ──────────────────────────────────────────────────────────────
  static const String health         = '/health';
  static const String versionCheck   = '/version';
  static const String itineraryGen   = '/itinerary/generate';
  static const String itineraryEdit  = '/itinerary/edit';
  static const String imageUpload    = '/images/upload';
  static const String storyGenerate  = '/story/generate';
  static const String videoGenerate  = '/video/generate';
  static const String videoStatus    = '/video/status';
  static const String videoCinematic = '/video/cinematic';
  static const String videoUploadAudio = '/video/upload-audio';
  static const String videoMusicLibrary = '/video/music/library';
  static const String llmStatus      = '/llm/status';
  static const String discoveryNearby = '/discovery/nearby';
  static const String authRegister    = '/auth/register';
  static const String authLogin       = '/auth/login';
  static const String historySave     = '/history/save';
  static const String historyList     = '/history'; // /history/{user_id}

  // ─── Reel Studio (multi-stage) ───────────────────────────────────────────────
  static const String reelAnalyze       = '/reel/analyze';
  static const String reelBuildTimeline = '/reel/build-timeline';
  static const String reelRender        = '/reel/render';
  static const String reelDraft         = '/reel/draft'; // /reel/draft/{id}
  static const String reelThemes        = '/reel/themes';

  // ─── Timeouts ───────────────────────────────────────────────────────────────
  /// 60 s connect give the phone enough time to reach the server on slow Wi-Fi.
  static const Duration connectTimeout = Duration(seconds: 60);
  static const Duration receiveTimeout = Duration(minutes: 20); // long LLM/video responses

  // ─── Image limits (100 photos · 50 MB each) ──────────────────────────────────
  static const int maxImageSizeMB = 50;
  static const int maxImageCount  = 100;

  // ─── All accepted image extensions ─────────────────────────────────────────
  /// Covers all formats image_picker / file_picker can pick.
  /// RAW formats will show as a placeholder in preview (browser/Flutter limitation).
  static const List<String> acceptedExtensions = [
    // Standard
    'jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp', 'tiff', 'tif', 'avif', 'heic', 'heif', 'svg',
    // RAW camera formats
    'nef', 'cr2', 'cr3', 'arw', 'dng', 'raw', 'raf', 'orf', 'rw2', 'pef', 'srw',
  ];
}
