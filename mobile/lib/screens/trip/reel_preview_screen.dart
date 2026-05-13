import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import '../../providers/trip_provider.dart';
import '../../config/routes.dart';
import '../../theme/app_theme.dart';

import '../../services/video_cache_manager.dart';
import '../../services/config_service.dart';

/// Reel preview screen — video player with zero-buffering cache.
class ReelPreviewScreen extends StatefulWidget {
  final String? videoUrl;
  const ReelPreviewScreen({super.key, this.videoUrl});
  @override
  State<ReelPreviewScreen> createState() => _ReelPreviewScreenState();
}

class _ReelPreviewScreenState extends State<ReelPreviewScreen> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _hasError = false;
  int _captionIndex = 0;
  String? _activeVideoUrl;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    final provider = context.read<TripProvider>();
    // Priority: Argument URL > Provider URL
    _activeVideoUrl = widget.videoUrl ?? provider.generatedVideoUrl;

    if (_activeVideoUrl == null || _activeVideoUrl!.isEmpty) {
      if (mounted) {
        setState(() {
          _initialized = false;
          _hasError = true;
        });
      }
      return;
    }

    // Fix: If URL is relative (e.g. /data/...), prepend the backend URL
    if (_activeVideoUrl!.startsWith('/')) {
      _activeVideoUrl = '${ConfigService().backendUrl}$_activeVideoUrl';
    }

    try {
      _controller?.removeListener(_captionTick);
      await _controller?.dispose();

      // Pre-fetch and cache the video before initializing player
      final cachedFile = await VideoCacheManager.fetchAndCacheVideo(_activeVideoUrl!);

      _controller = VideoPlayerController.file(cachedFile);
      await _controller!.initialize();
      _controller!.setLooping(true);
      _controller!.play();

      // Auto-rotate captions
      _controller!.addListener(_captionTick);
      _controller!.addListener(() {
        if (!mounted) return;
        if (_controller?.value.hasError == true) {
          setState(() => _hasError = true);
        }
      });

      if (mounted) {
        setState(() {
          _initialized = true;
          _hasError = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _hasError = true);
    }
  }

  Future<void> _openInExternalPlayer() async {
    final url = _activeVideoUrl;
    if (url == null || url.isEmpty) return;
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
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

  Future<void> _saveVideo() async {
    if (_activeVideoUrl == null) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saving to Gallery...')));
    final success = await VideoCacheManager.saveToGallery(_activeVideoUrl!);
    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved automatically to Gallery! 🎉')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to save to Gallery.')));
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_captionTick);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TripProvider>();
    final captions = context.watch<TripProvider>().currentTrip?.captions ?? [];

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('Reel Preview', style: TextStyle(color: Colors.white)),
        actions: [
          if (_activeVideoUrl != null && _activeVideoUrl!.isNotEmpty)
            TextButton(
              onPressed: _openInExternalPlayer,
              child: const Text('Open External', style: TextStyle(color: Colors.white)),
            ),
          TextButton(
            onPressed: () => Navigator.pushNamed(context, AppRoutes.downloadShare, arguments: _activeVideoUrl),
            child: const Text('Share →', style: TextStyle(color: AppTheme.accent)),
          ),
        ],
      ),
      body: Column(
        children: [
          if (provider.videoEngine != null || provider.videoMessage != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 6, 16, 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (provider.videoEngine != null)
                    Text(
                      'Engine: ${provider.videoEngine}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  if ((provider.videoMessage ?? '').isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      provider.videoMessage!,
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),

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
                    }, message: provider.videoMessage, videoUrl: _activeVideoUrl, onOpenExternal: _openInExternalPlayer)
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
                  onTap: _saveVideo,
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
  final String? message;
  final String? videoUrl;
  final VoidCallback? onOpenExternal;

  const _VideoErrorPlaceholder({required this.onRetry, this.message, this.videoUrl, this.onOpenExternal});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.broken_image_outlined, color: Colors.white38, size: 64),
        const SizedBox(height: 12),
        const Text('Could not load generated video.', style: TextStyle(color: Colors.white60)),
        if (message != null && message!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              message!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
        ],
        const SizedBox(height: 16),
        ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
        if (videoUrl != null && videoUrl!.isNotEmpty && onOpenExternal != null) ...[
          const SizedBox(height: 8),
          OutlinedButton(onPressed: onOpenExternal, child: const Text('Open In External Player')),
        ],
      ],
    );
  }
}
