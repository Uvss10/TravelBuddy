import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lottie/lottie.dart';
import '../../providers/trip_provider.dart';
import '../../providers/video_generation_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';

/// Premium AiProcessingScreen with Lottie Mascot and Engagement Carousel
class AiProcessingScreen extends StatefulWidget {
  final String destination;
  final List<String> sceneTags;
  final String tone;
  final String? audioPath;

  const AiProcessingScreen({
    super.key,
    required this.destination,
    required this.sceneTags,
    required this.tone,
    this.audioPath,
  });

  @override
  State<AiProcessingScreen> createState() => _AiProcessingScreenState();
}

class _AiProcessingScreenState extends State<AiProcessingScreen> {
  int _currentTipIdx = 0;
  Timer? _tipTimer;
  bool _failed = false;

  final List<String> _travelTips = [
    "The best light for photos is during the 'Golden Hour' — the first hour after sunrise and the last hour before sunset.",
    "Try to include someone in your landscape shots to give a sense of scale to the mountains and architecture.",
    "Rule of Thirds: Place your main subject off-center for a more balanced and cinematic composition.",
    "Did you know? Rajasthan is known as the 'Land of Kings' and has more forts than any other state in India.",
    "When shooting architecture, look for leading lines like hallways or paths to guide the viewer's eye into the frame.",
    "A clean lens is the best lens! Wipe your phone camera before every adventure session for crystal clear reels.",
    "Capturing food? Use natural side-lighting from a window to make those textures pop without harsh shadows."
  ];

  final List<_Stage> _stages = [
    const _Stage(icon: Icons.auto_awesome_rounded, label: 'Media Intelligence', sub: 'Ranking & analyzing image quality'),
    const _Stage(icon: Icons.history_edu_rounded, label: 'Story Drafting', sub: 'Crafting the narrative arc'),
    const _Stage(icon: Icons.audiotrack_rounded, label: 'Sonic Alignment', sub: 'Syncing beats with your visuals'),
    const _Stage(icon: Icons.movie_creation_rounded, label: 'Cinematic Render', sub: 'Compositing slots & transitions'),
  ];

  @override
  void initState() {
    super.initState();
    _tipTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) {
        setState(() => _currentTipIdx = (_currentTipIdx + 1) % _travelTips.length);
      }
    });
  }

  @override
  void dispose() {
    _tipTimer?.cancel();
    super.dispose();
  }

  // Note: This screen is usually pushed by PhotoUploadScreen which passes correct params.
  // The VideoGenerationProvider is already managing the state.

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<VideoGenerationProvider>();
    final progressValue = provider.progress;
    final videoMsg = provider.message;
    final status = provider.status;

    if (status == GenerationStatus.error) {
      _failed = true;
      _tipTimer?.cancel();
    }

    int step = 0;
    if (progressValue > 0.15) step = 1;
    if (progressValue > 0.40) step = 2;
    if (progressValue > 0.60) step = 3;

    String activeStageLabel = _stages[step].label;

    return PopScope(
      canPop: status == GenerationStatus.completed || status == GenerationStatus.error,
      onPopInvoked: (didPop) {
        if (!didPop) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Wait! We are polishing your masterpiece...')),
          );
        }
      },
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.primary.withOpacity(0.05),
                Colors.white,
                AppTheme.accent.withOpacity(0.05),
              ],
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                children: [
                   // ── Taddy Mascot (Engagement) ──
                  _buildMascotAnimated(),
                  
                  const SizedBox(height: 32),
                  Text(
                    'Crafting Your Memories',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.destination.isEmpty ? 'Adventure Awaits' : 'Exploring ${widget.destination}...',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppTheme.textHint,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const SizedBox(height: 40),
                  // Progress Section
                  _buildProgressSection(progressValue, activeStageLabel, videoMsg),

                  const SizedBox(height: 48),
                  // Tips Carousel
                  _buildTipsCarousel(),

                  const SizedBox(height: 48),
                  // Stages List
                  _buildStageList(step),

                  if (_failed) ...[
                    const SizedBox(height: 32),
                    TBErrorBanner(
                      message: provider.message,
                      onRetry: () {
                         // Provider reset and retry should happen here
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMascotAnimated() {
    return SizedBox(
      height: 180,
      child: Lottie.network(
        'https://assets10.lottiefiles.com/packages/lf20_m6cuL6.json', // Taddy / Bear
        fit: BoxFit.contain,
        errorBuilder: (c, e, s) => const Icon(Icons.auto_awesome_rounded, size: 80, color: AppTheme.accent),
      ),
    ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack);
  }

  Widget _buildProgressSection(double value, String label, String? detail) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text('${(value * 100).toInt()}%', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary)),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 12,
            backgroundColor: AppTheme.primary.withOpacity(0.1),
            valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
          ),
        ),
        if (detail != null && detail.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(color: Colors.black.withOpacity(0.05), borderRadius: BorderRadius.circular(20)),
            child: Text(detail, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black54), textAlign: TextAlign.center),
          ),
        ],
      ],
    );
  }

  Widget _buildTipsCarousel() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      child: Container(
        key: ValueKey(_currentTipIdx),
        padding: const EdgeInsets.all(24),
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.primary.withOpacity(0.1)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 10))],
        ),
        child: Column(
          children: [
            const Icon(Icons.lightbulb_outline, color: Colors.orange, size: 28),
            const SizedBox(height: 16),
            Text(
              _travelTips[_currentTipIdx],
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, height: 1.5, fontWeight: FontWeight.w500, fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStageList(int currentStep) {
    return Column(
      children: _stages.asMap().entries.map((e) {
        final i = e.key;
        final stage = e.value;
        final isDone = i < currentStep;
        final isActive = i == currentStep && !_failed;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isActive ? Colors.white : Colors.white.withOpacity(0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isActive ? AppTheme.primary : AppTheme.borderLight,
                width: isActive ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                _buildStatusIcon(isDone, isActive, stage.icon),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(stage.label, style: TextStyle(fontWeight: FontWeight.bold, color: isActive ? Colors.black : Colors.black45)),
                      Text(stage.sub, style: TextStyle(fontSize: 12, color: isActive ? Colors.black54 : Colors.black38)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStatusIcon(bool isDone, bool isActive, IconData defaultIcon) {
    if (isDone) {
      return Container(width: 32, height: 32, decoration: const BoxDecoration(color: AppTheme.success, shape: BoxShape.circle), child: const Icon(Icons.check, color: Colors.white, size: 18));
    }
    if (isActive) {
      return const SizedBox(width: 32, height: 32, child: CircularProgressIndicator(strokeWidth: 3, valueColor: AlwaysStoppedAnimation(AppTheme.primary)));
    }
    return Icon(defaultIcon, color: Colors.black26, size: 24);
  }
}

class _Stage {
  final IconData icon;
  final String label;
  final String sub;
  const _Stage({required this.icon, required this.label, required this.sub});
}
