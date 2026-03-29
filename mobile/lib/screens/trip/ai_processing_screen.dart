import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/trip_provider.dart';
import '../../config/routes.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';

/// AI Processing screen — shows animated progress through 3 pipeline stages.
class AiProcessingScreen extends StatefulWidget {
  final Map<String, dynamic> tripData;
  const AiProcessingScreen({super.key, required this.tripData});

  @override
  State<AiProcessingScreen> createState() => _AiProcessingScreenState();
}

class _AiProcessingScreenState extends State<AiProcessingScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;

  static const _stages = [
    _Stage(icon: Icons.photo_library_outlined, label: 'Analysing Images', sub: 'Scoring quality, removing duplicates…'),
    _Stage(icon: Icons.auto_stories_outlined,  label: 'Generating Story',  sub: 'Crafting your cinematic narration…'),
    _Stage(icon: Icons.movie_creation_outlined,label: 'Creating Reel',    sub: 'Assembling your travel reel…'),
  ];

  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _startProcessing();
  }

  Future<void> _startProcessing() async {
    final provider = context.read<TripProvider>();
    final destination = widget.tripData['destination'] as String? ?? '';
    final sceneTags  = (widget.tripData['scene_tags'] as List?)?.cast<String>() ?? ['travel'];
    final tone = widget.tripData['tone'] as String? ?? 'adventurous and inspiring';
    final sourceFlow = widget.tripData['source_flow'] as String? ?? 'itinerary';

    final ok = await provider.processAll(
      destination: destination,
      sceneTags: sceneTags,
      tone: tone,
    );
    if (!mounted) return;

    if (ok) {
      _pulseCtrl.stop();
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      if (sourceFlow == 'reel') {
        Navigator.pushReplacementNamed(context, AppRoutes.reelPreview);
      } else {
        Navigator.pushReplacementNamed(context, AppRoutes.itinerary, arguments: provider.currentTrip);
      }
    } else {
      setState(() => _failed = true);
      _pulseCtrl.stop();
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final step = context.watch<TripProvider>().processingStep;
    final destination = widget.tripData['destination'] as String? ?? '-';
    final tone = widget.tripData['tone'] as String? ?? 'adventurous and inspiring';

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated icon
              ScaleTransition(
                scale: _pulse,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: const Icon(Icons.auto_awesome, size: 50, color: Colors.white),
                ),
              ),
              const SizedBox(height: 40),
              Text(
                'Working on it…',
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: 8),
              Text(
                'This may take a few seconds.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.bgLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.borderLight),
                ),
                child: Text(
                  'Destination: $destination  •  Tone: $tone',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 48),

              // Stage list
              ..._stages.asMap().entries.map((e) {
                final i     = e.key;
                final stage = e.value;
                final done  = i < step;
                final active= i == step && !_failed;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: done
                          ? AppTheme.success.withAlpha(20)
                          : active
                              ? AppTheme.primary.withAlpha(12)
                              : Theme.of(context).cardTheme.color,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: done
                            ? AppTheme.success.withAlpha(60)
                            : active
                                ? AppTheme.primary.withAlpha(60)
                                : AppTheme.borderLight,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: done
                                ? AppTheme.success
                                : active
                                    ? AppTheme.primary
                                    : AppTheme.bgLight,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: done
                              ? const Icon(Icons.check, color: Colors.white, size: 18)
                              : active
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Icon(stage.icon, color: AppTheme.textHint, size: 18),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(stage.label, style: Theme.of(context).textTheme.titleMedium),
                            Text(stage.sub, style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),

              // Error state
              if (_failed) ...[
                const SizedBox(height: 16),
                TBErrorBanner(
                  message: context.read<TripProvider>().errorMessage ?? 'Processing failed.',
                  onRetry: () {
                    setState(() => _failed = false);
                    _pulseCtrl.repeat(reverse: true);
                    _startProcessing();
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Stage {
  final IconData icon;
  final String label;
  final String sub;
  const _Stage({required this.icon, required this.label, required this.sub});
}
