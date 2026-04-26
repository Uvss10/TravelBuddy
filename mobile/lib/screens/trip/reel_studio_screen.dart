import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../../providers/reel_draft_provider.dart';
import '../../providers/trip_provider.dart';
import '../../providers/video_generation_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../config/routes.dart';

// ── Stage indicator colours ───────────────────────────────────────────────────
const _kStageColors = [
  Color(0xFF6366F1), // Curation   - Indigo
  Color(0xFF0EA5E9), // Storyboard - Sky
  Color(0xFFF59E0B), // Atmosphere - Amber
  Color(0xFF10B981), // Annotation - Emerald
  Color(0xFFEF4444), // Production - Red
];

const _kStageLabels = [
  'Curation',
  'Storyboard',
  'Vibe',
  'Captions',
  'Produce',
];

const _kStageIcons = [
  Icons.grid_view_rounded,
  Icons.view_timeline_outlined,
  Icons.music_note_rounded,
  Icons.text_fields_rounded,
  Icons.rocket_launch_rounded,
];

/// Master entry point for the Reel Studio multi-stage pipeline.
/// Shows a cinematic dark hub with stage steps and launches the first stage.
class ReelStudioScreen extends StatefulWidget {
  const ReelStudioScreen({super.key});

  @override
  State<ReelStudioScreen> createState() => _ReelStudioScreenState();
}

class _ReelStudioScreenState extends State<ReelStudioScreen> with TickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late AnimationController _bgCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _bgCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _bgCtrl.dispose();
    super.dispose();
  }

  int _stageIndex(ReelStudioStage stage) {
    switch (stage) {
      case ReelStudioStage.curation:
        return 0;
      case ReelStudioStage.storyboard:
        return 1;
      case ReelStudioStage.atmosphere:
        return 2;
      case ReelStudioStage.annotation:
        return 3;
      case ReelStudioStage.rendering:
      case ReelStudioStage.done:
        return 4;
      default:
        return -1;
    }
  }

  Future<void> _startFlow(BuildContext context) async {
    final provider = context.read<ReelDraftProvider>();
    provider.reset();

    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(imageQuality: 90);
    if (picked.isEmpty || !context.mounted) return;

    final files = picked.map((x) => File(x.path)).toList();

    // Navigate to curation hub which handles upload + analysis internally
    Navigator.pushNamed(context, AppRoutes.reelCuration);

    // Start the upload + analyze flow in background
    await provider.uploadAndAnalyze(files);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReelDraftProvider>();
    final activeIdx = _stageIndex(provider.stage);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A18),
      body: Stack(
        children: [
          // Animated gradient background
          AnimatedBuilder(
            animation: _bgCtrl,
            builder: (_, __) => Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(_bgCtrl.value * 0.4 - 0.2, -0.5),
                  radius: 1.4,
                  colors: const [
                    Color(0xFF1E1B4B),
                    Color(0xFF0A0A18),
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // ── Header ─────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Reel Studio',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            'Create your cinematic story',
                            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 400.ms),

                const SizedBox(height: 32),

                // ── Stage Pipeline ──────────────────────────────────────────
                SizedBox(
                  height: 90,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _kStageLabels.length,
                    itemBuilder: (context, i) {
                      final isActive = i == activeIdx;
                      final isDone = i < activeIdx;
                      final color = _kStageColors[i];

                      return Row(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: isActive ? 110 : 70,
                            height: 70,
                            decoration: BoxDecoration(
                              color: isDone
                                  ? color.withOpacity(0.3)
                                  : isActive
                                      ? color.withOpacity(0.15)
                                      : Colors.white.withOpacity(0.04),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: isDone
                                    ? color.withOpacity(0.6)
                                    : isActive
                                        ? color
                                        : Colors.white12,
                                width: isActive ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                AnimatedBuilder(
                                  animation: _pulseCtrl,
                                  builder: (_, child) => Transform.scale(
                                    scale: isActive ? 1.0 + _pulseCtrl.value * 0.1 : 1.0,
                                    child: child,
                                  ),
                                  child: Icon(
                                    isDone ? Icons.check_circle_rounded : _kStageIcons[i],
                                    color: isDone ? color : isActive ? color : Colors.white24,
                                    size: isActive ? 26 : 20,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _kStageLabels[i],
                                  style: TextStyle(
                                    color: isDone
                                        ? color
                                        : isActive
                                            ? Colors.white
                                            : Colors.white30,
                                    fontSize: isActive ? 11 : 10,
                                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ).animate(delay: (i * 80).ms).fadeIn().scale(begin: const Offset(0.8, 0.8)),

                          if (i < _kStageLabels.length - 1)
                            Container(
                              width: 20,
                              height: 2,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                color: i < activeIdx ? _kStageColors[i] : Colors.white12,
                                borderRadius: BorderRadius.circular(1),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),

                const SizedBox(height: 24),

                // ── Hero Call-to-Action ─────────────────────────────────────
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        // Cinematic film reel visual
                        Expanded(
                          child: _FilmReelAnimation(pulseCtrl: _pulseCtrl),
                        ),

                        const SizedBox(height: 24),

                        // Description cards
                        _StepInfoCard(
                          icon: Icons.auto_awesome_rounded,
                          color: const Color(0xFF6366F1),
                          title: 'Smart AI Curation',
                          desc: 'AI analyzes 100 photos in seconds, scores quality, faces & story potential.',
                        ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.2),

                        const SizedBox(height: 12),

                        _StepInfoCard(
                          icon: Icons.tune_rounded,
                          color: const Color(0xFF0EA5E9),
                          title: 'You Stay in Control',
                          desc: 'Reorder, remove or add photos. Set the vibe, music & captions — your story.',
                        ).animate(delay: 350.ms).fadeIn().slideY(begin: 0.2),

                        const SizedBox(height: 28),

                        // START button
                        if (provider.stage == ReelStudioStage.idle ||
                            provider.stage == ReelStudioStage.error)
                          _StartButton(onTap: () => _startFlow(context)),

                        // Resume button (if draft exists)
                        if (provider.stage != ReelStudioStage.idle &&
                            provider.stage != ReelStudioStage.error &&
                            provider.stage != ReelStudioStage.uploading &&
                            provider.stage != ReelStudioStage.analyzing)
                          _ResumeButton(stage: provider.stage),

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Loading overlay while upload/analyze
          if (provider.stage == ReelStudioStage.uploading || provider.stage == ReelStudioStage.analyzing)
            _AnalyzingOverlay(message: provider.statusMessage),
        ],
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _FilmReelAnimation extends StatelessWidget {
  final AnimationController pulseCtrl;
  const _FilmReelAnimation({required this.pulseCtrl});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseCtrl,
      builder: (_, __) => Stack(
        alignment: Alignment.center,
        children: [
          // Outer glow ring
          Container(
            width: 180 + pulseCtrl.value * 8,
            height: 180 + pulseCtrl.value * 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.15 + pulseCtrl.value * 0.1), width: 2),
            ),
          ),
          // Middle ring
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF6366F1).withOpacity(0.2),
                  const Color(0xFF6366F1).withOpacity(0.05),
                ],
              ),
            ),
          ),
          // Icon
          Icon(
            Icons.movie_creation_outlined,
            size: 72,
            color: Colors.white.withOpacity(0.7 + pulseCtrl.value * 0.3),
          ),
        ],
      ),
    );
  }
}

class _StepInfoCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String desc;
  const _StepInfoCard({required this.icon, required this.color, required this.title, required this.desc});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(desc, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StartButton extends StatelessWidget {
  final VoidCallback onTap;
  const _StartButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 60,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(color: const Color(0xFF6366F1).withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 8)),
          ],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate_rounded, color: Colors.white, size: 22),
            SizedBox(width: 10),
            Text(
              'Start Creating Reel',
              style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: 0.2),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 500.ms).scale(begin: const Offset(0.9, 0.9));
  }
}

class _ResumeButton extends StatelessWidget {
  final ReelStudioStage stage;
  const _ResumeButton({required this.stage});

  String get _label {
    switch (stage) {
      case ReelStudioStage.curation:
        return 'Resume → Curation';
      case ReelStudioStage.storyboard:
        return 'Resume → Storyboard';
      case ReelStudioStage.atmosphere:
        return 'Resume → Vibe & Music';
      case ReelStudioStage.annotation:
        return 'Resume → Captions';
      case ReelStudioStage.rendering:
        return 'Resume → Production';
      case ReelStudioStage.done:
        return 'View Your Reel ✨';
      default:
        return 'Resume';
    }
  }

  String get _route {
    switch (stage) {
      case ReelStudioStage.curation:
        return AppRoutes.reelCuration;
      case ReelStudioStage.storyboard:
        return AppRoutes.reelStoryboard;
      case ReelStudioStage.atmosphere:
        return AppRoutes.reelAtmosphere;
      case ReelStudioStage.annotation:
        return AppRoutes.reelAnnotation;
      default:
        return AppRoutes.reelProduction;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, _route),
      child: Container(
        width: double.infinity,
        height: 60,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.play_circle_outline_rounded, color: Colors.white70, size: 22),
            const SizedBox(width: 10),
            Text(_label,
                style: const TextStyle(color: Colors.white70, fontSize: 15, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _AnalyzingOverlay extends StatelessWidget {
  final String message;
  const _AnalyzingOverlay({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black87,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 64,
              height: 64,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation(Color(0xFF6366F1)),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              '🎬 AI is working…',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
