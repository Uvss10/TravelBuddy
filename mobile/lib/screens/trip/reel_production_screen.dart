import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/reel_draft_provider.dart';
import '../../providers/trip_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../config/routes.dart';

/// STAGE 5 — Production
/// Summary of all user choices, a single big "Produce" button, 
/// live progress feed, and auto-navigate to reel preview when done.
class ReelProductionScreen extends StatefulWidget {
  const ReelProductionScreen({super.key});

  @override
  State<ReelProductionScreen> createState() => _ReelProductionScreenState();
}

class _ReelProductionScreenState extends State<ReelProductionScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late AnimationController _progressCtrl;
  Timer? _pollTimer;
  final ApiService _api = ApiService();
  int _pollFailures = 0;
  bool _hasStarted = false;

  // Log lines shown during rendering
  final List<String> _renderLog = [];

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _progressCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _progressCtrl.dispose();
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _startRender() async {
    final provider = context.read<ReelDraftProvider>();
    final trip = context.read<TripProvider>().currentTrip;
    final destination = trip?.destination ?? 'trip';

    setState(() {
      _hasStarted = true;
      _renderLog.clear();
      _renderLog.add('🚀 Submitting render job…');
    });

    await provider.startRender(destination);

    if (!mounted) return;
    if (provider.error != null) {
      setState(() => _renderLog.add('❌ ${provider.error}'));
      return;
    }

    _startPolling(provider);
  }

  void _startPolling(ReelDraftProvider provider) {
    _pollTimer?.cancel();
    _pollFailures = 0;

    _pollTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final jobId = provider.jobId;
      if (jobId == null) {
        timer.cancel();
        return;
      }

      final resp = await _api.getCinematicStatus(jobId);
      if (!resp.isSuccess) {
        _pollFailures++;
        if (_pollFailures >= 5) {
          timer.cancel();
          if (mounted) {
            setState(() => _renderLog.add('⚠️ Lost connection to server.'));
          }
        }
        return;
      }

      _pollFailures = 0;
      final data = resp.data ?? {};
      final status = data['status']?.toString().toLowerCase() ?? '';
      final progress = ((data['progress'] as num?)?.toDouble() ?? 0.0) / 100.0;
      final message = data['message']?.toString() ?? '';

      if (mounted) {
        _progressCtrl.animateTo(progress.clamp(0.0, 1.0));
        setState(() {
          if (_renderLog.isEmpty || _renderLog.last != message) {
            _renderLog.add(message);
            if (_renderLog.length > 20) _renderLog.removeAt(0);
          }
        });
        provider.updateRenderProgress(progress, message, null);
      }

      if (status == 'done' || status == 'completed') {
        timer.cancel();
        final videoUrl = data['video_url']?.toString();
        if (mounted) {
          provider.updateRenderProgress(1.0, '✅ Your reel is ready!', videoUrl);
          setState(() => _renderLog.add('✅ Reel complete!'));

          // Navigate to preview
          await Future.delayed(const Duration(seconds: 1));
          if (mounted) {
            Navigator.pushNamedAndRemoveUntil(
              context,
              AppRoutes.reelPreview,
              (r) => r.settings.name == AppRoutes.home,
              arguments: videoUrl,
            );
          }
        }
        return;
      }

      if (status == 'error' || status == 'failed') {
        timer.cancel();
        final errMsg = data['message']?.toString() ?? 'Render failed on server.';
        if (mounted) {
          setState(() => _renderLog.add('❌ $errMsg'));
          provider.updateRenderProgress(0.0, errMsg, null);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReelDraftProvider>();
    final isRendering = provider.stage == ReelStudioStage.rendering;
    final isDone = provider.stage == ReelStudioStage.done;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F1A),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Step 5 · Produce',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Summary card ────────────────────────────────────────────────
            _SummaryCard(provider: provider).animate().fadeIn(delay: 100.ms),

            const SizedBox(height: 24),

            // ── Produce button ───────────────────────────────────────────────
            if (!_hasStarted && !isRendering && !isDone)
              _ProduceButton(
                onTap: _startRender,
                pulseCtrl: _pulseCtrl,
              ).animate().fadeIn(delay: 200.ms).scale(begin: const Offset(0.9, 0.9)),

            // ── Progress area ────────────────────────────────────────────────
            if (_hasStarted || isRendering)
              _RenderProgress(
                progressCtrl: _progressCtrl,
                renderLog: _renderLog,
                provider: provider,
              ).animate().fadeIn(delay: 100.ms),

            const SizedBox(height: 24),

            // ── Render specs ─────────────────────────────────────────────────
            _RenderSpecsCard(provider: provider).animate().fadeIn(delay: 350.ms),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// ── Summary Card ───────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final ReelDraftProvider provider;
  const _SummaryCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E1B4B), Color(0xFF0F172A)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your Reel Summary',
            style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5),
          ),
          const SizedBox(height: 16),
          _SummaryRow(icon: Icons.photo_library_rounded, label: 'Photos', value: '${provider.timeline.length} shots selected'),
          const SizedBox(height: 10),
          _SummaryRow(
            icon: Icons.palette_rounded,
            label: 'Theme',
            value: provider.selectedTheme[0].toUpperCase() + provider.selectedTheme.substring(1),
          ),
          const SizedBox(height: 10),
          _SummaryRow(
            icon: Icons.bolt_rounded,
            label: 'Pace',
            value: provider.energyLevel < 0.33
                ? 'Relaxed & Cinematic'
                : provider.energyLevel < 0.66
                    ? 'Balanced'
                    : 'Fast & Energetic',
          ),
          const SizedBox(height: 10),
          _SummaryRow(icon: Icons.timer_outlined, label: 'Duration', value: '${provider.durationSeconds}s'),
          const SizedBox(height: 10),
          _SummaryRow(
            icon: Icons.music_note_rounded,
            label: 'Music',
            value: provider.selectedAudioName ?? 'Synthetic Beat Grid',
          ),
          const SizedBox(height: 10),
          _SummaryRow(
            icon: Icons.text_fields_rounded,
            label: 'Captions',
            value: '${provider.timeline.where((s) => s.caption.isNotEmpty).length} of ${provider.timeline.length} shots',
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _SummaryRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white38, size: 16),
        const SizedBox(width: 10),
        Text('$label  ', style: const TextStyle(color: Colors.white38, fontSize: 13)),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ── Produce Button ─────────────────────────────────────────────────────────────

class _ProduceButton extends StatelessWidget {
  final VoidCallback onTap;
  final AnimationController pulseCtrl;
  const _ProduceButton({required this.onTap, required this.pulseCtrl});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseCtrl,
      builder: (_, child) => Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFEF4444).withOpacity(0.3 + pulseCtrl.value * 0.2),
              blurRadius: 30 + pulseCtrl.value * 10,
              spreadRadius: pulseCtrl.value * 4,
            ),
          ],
          borderRadius: BorderRadius.circular(20),
        ),
        child: child,
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          height: 70,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 28),
              SizedBox(width: 12),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Produce My Reel',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                  Text('720p · Beat-synced · Cinematic',
                      style: TextStyle(color: Colors.white70, fontSize: 11)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Render Progress ────────────────────────────────────────────────────────────

class _RenderProgress extends StatelessWidget {
  final AnimationController progressCtrl;
  final List<String> renderLog;
  final ReelDraftProvider provider;

  const _RenderProgress({
    required this.progressCtrl,
    required this.renderLog,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.movie_creation_outlined, color: Color(0xFFEF4444), size: 18),
              SizedBox(width: 8),
              Text('Render Progress',
                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 16),

          // Animated progress bar
          AnimatedBuilder(
            animation: progressCtrl,
            builder: (_, __) => Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${(progressCtrl.value * 100).toInt()}%',
                  style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progressCtrl.value,
                    minHeight: 8,
                    backgroundColor: Colors.white10,
                    valueColor: const AlwaysStoppedAnimation(Color(0xFFEF4444)),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Log feed
          Container(
            height: 140,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black45,
              borderRadius: BorderRadius.circular(10),
            ),
            child: ListView.builder(
              reverse: true,
              itemCount: renderLog.length,
              itemBuilder: (_, i) {
                final line = renderLog[renderLog.length - 1 - i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    line,
                    style: TextStyle(
                      color: i == 0 ? Colors.white : Colors.white38,
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Render Specs Card ──────────────────────────────────────────────────────────

class _RenderSpecsCard extends StatelessWidget {
  final ReelDraftProvider provider;
  const _RenderSpecsCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Render Specs',
              style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
          const SizedBox(height: 12),
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SpecChip(label: '720×1280', icon: Icons.stay_current_portrait_rounded),
              _SpecChip(label: '30 FPS', icon: Icons.speed_rounded),
              _SpecChip(label: '9:16 Vertical', icon: Icons.crop_portrait_rounded),
              _SpecChip(label: 'H.264 / AAC', icon: Icons.settings_rounded),
            ],
          ),
        ],
      ),
    );
  }
}

class _SpecChip extends StatelessWidget {
  final String label;
  final IconData icon;
  const _SpecChip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white38, size: 12),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
        ],
      ),
    );
  }
}
