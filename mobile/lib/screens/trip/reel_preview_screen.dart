import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../../providers/trip_provider.dart';
import '../../config/routes.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';

/// Reel preview screen — video player with caption overlay.
/// Uses a placeholder video URL (replace with real generated reel URL).
class ReelPreviewScreen extends StatefulWidget {
  const ReelPreviewScreen({super.key});
  @override
  State<ReelPreviewScreen> createState() => _ReelPreviewScreenState();
}

class _ReelPreviewScreenState extends State<ReelPreviewScreen> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _hasError = false;
  int _captionIndex = 0;

  // Demo video URL — replace with real backend reel URL
  // static const _demoUrl = 'http://10.0.2.2:8000/video/reel.mp4';
  static const _demoUrl = 'https://www.w3schools.com/html/mov_bbb.mp4';

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    try {
      _controller = VideoPlayerController.networkUrl(Uri.parse(_demoUrl));
      await _controller!.initialize();
      _controller!.setLooping(true);
      _controller!.play();

      // Auto-rotate captions
      _controller!.addListener(_captionTick);

      if (mounted) setState(() => _initialized = true);
    } catch (_) {
      if (mounted) setState(() => _hasError = true);
    }
  }

  void _captionTick() {
    final pos = _controller?.value.position.inSeconds ?? 0;
    final captions = context.read<TripProvider>().currentTrip?.captions ?? [];
    if (captions.isEmpty) return;
    final idx = (pos ~/ 6) % captions.length; // rotate every 6 s
    if (idx != _captionIndex && mounted) setState(() => _captionIndex = idx);
  }

  void _togglePlay() {
    final c = _controller;
    if (c == null) return;
    setState(() {
      c.value.isPlaying ? c.pause() : c.play();
    });
  }

  @override
  void dispose() {
    _controller?.removeListener(_captionTick);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final captions = context.watch<TripProvider>().currentTrip?.captions ?? [];

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('Reel Preview', style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pushNamed(context, AppRoutes.downloadShare),
            child: const Text('Share →', style: TextStyle(color: AppTheme.accent)),
          ),
        ],
      ),
      body: Column(
        children: [
          // Video area
          Expanded(
            child: GestureDetector(
              onTap: _togglePlay,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (_hasError)
                    _VideoErrorPlaceholder(onRetry: () {
                      setState(() => _hasError = false);
                      _initVideo();
                    })
                  else if (!_initialized)
                    const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  else ...[
                    // Video
                    Center(
                      child: AspectRatio(
                        aspectRatio: _controller!.value.aspectRatio,
                        child: VideoPlayer(_controller!),
                      ),
                    ),

                    // Play/pause indicator
                    if (!(_controller?.value.isPlaying ?? true))
                      const Icon(Icons.play_circle_fill, size: 64, color: Colors.white),

                    // Caption overlay
                    if (captions.isNotEmpty)
                      Positioned(
                        bottom: 40,
                        left: 24,
                        right: 24,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 400),
                          child: Text(
                            captions[_captionIndex],
                            key: ValueKey(_captionIndex),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              shadows: [Shadow(blurRadius: 8, color: Colors.black)],
                            ),
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),

          // Progress bar
          if (_initialized && !_hasError)
            ValueListenableBuilder(
              valueListenable: _controller!,
              builder: (_, value, __) {
                final total = value.duration.inMilliseconds;
                final pos   = value.position.inMilliseconds;
                final progress = total > 0 ? pos / total : 0.0;
                return LinearProgressIndicator(
                  value: progress,
                  color: AppTheme.accent,
                  backgroundColor: Colors.white24,
                  minHeight: 3,
                );
              },
            ),

          // Controls
          Container(
            color: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _ControlBtn(
                  icon: (_controller?.value.isPlaying ?? false)
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  label: (_controller?.value.isPlaying ?? false) ? 'Pause' : 'Play',
                  onTap: _togglePlay,
                ),
                _ControlBtn(
                  icon: Icons.replay,
                  label: 'Replay',
                  onTap: () => _controller?.seekTo(Duration.zero),
                ),
                _ControlBtn(
                  icon: Icons.download_outlined,
                  label: 'Save',
                  onTap: () => Navigator.pushNamed(context, AppRoutes.downloadShare),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ControlBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ControlBtn({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 28),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      ),
    );
  }
}

class _VideoErrorPlaceholder extends StatelessWidget {
  final VoidCallback onRetry;
  const _VideoErrorPlaceholder({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.broken_image_outlined, color: Colors.white38, size: 64),
        const SizedBox(height: 12),
        const Text('Could not load video.', style: TextStyle(color: Colors.white60)),
        const SizedBox(height: 16),
        ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    );
  }
}
