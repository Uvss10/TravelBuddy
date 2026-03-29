/// All API endpoint configuration lives here.
/// Change [baseUrl] to your server address.
class ApiConfig {
  // ─── Base URL ───────────────────────────────────────────────────────────────
  /// Override with --dart-define=API_BASE_URL=http://<ip>:8000 when needed.
  /// Default below is configured for a physical Android device on the same LAN.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.0.114:8000',
  );

  // ─── Endpoints ──────────────────────────────────────────────────────────────
  static const String health         = '/health';
  static const String itineraryGen   = '/itinerary/generate';
  static const String imageUpload    = '/images/upload';
  static const String storyGenerate  = '/story/generate';
  static const String videoGenerate  = '/video/generate';
  static const String videoStatus    = '/video/status';

  // ─── Timeouts ───────────────────────────────────────────────────────────────
  static const Duration connectTimeout = Duration(minutes: 10);
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
