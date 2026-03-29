import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/video_generation_provider.dart';
import '../../config/routes.dart';
import '../../theme/app_theme.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class GlobalGenerationOverlay extends StatelessWidget {
  final Widget child;

  const GlobalGenerationOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child, // The main app content
        
        // The overlay pill
        Positioned(
          top: MediaQuery.of(context).padding.top + 16,
          left: 16,
          right: 16,
          child: Consumer<VideoGenerationProvider>(
            builder: (context, provider, _) {
              if (provider.status == GenerationStatus.initial) {
                return const SizedBox.shrink();
              }

              final isCompleted = provider.status == GenerationStatus.completed;
              final isError = provider.status == GenerationStatus.error;

              return Dismissible(
                key: const Key('generation_overlay'),
                direction: DismissDirection.up,
                onDismissed: (_) {
                  if (isCompleted || isError) {
                    provider.reset();
                  }
                },
                child: GestureDetector(
                  onTap: () {
                    final videoUrl = provider.finalVideoUrl;
                    if (isCompleted && videoUrl != null && videoUrl.isNotEmpty) {
                      provider.reset();
                      Navigator.pushNamed(context, AppRoutes.reelPreview, arguments: videoUrl);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppTheme.lg, vertical: AppTheme.md),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                      border: Border.all(
                        color: isCompleted ? AppTheme.successColor.withValues(alpha: 0.5) :
                               isError ? AppTheme.errorColor.withValues(alpha: 0.5) :
                               AppTheme.borderColor,
                      ),
                    ),
                    child: Row(
                      children: [
                        if (provider.isActive) ...[
                          const Icon(
                            FontAwesomeIcons.circleNotch,
                            color: AppTheme.primaryColor,
                            size: 20,
                          ).animate(onPlay: (controller) => controller.repeat())
                           .rotate(duration: 1.seconds),
                        ] else if (isCompleted) ...[
                          const Icon(
                            FontAwesomeIcons.circleCheck,
                            color: AppTheme.successColor,
                            size: 20,
                          ).animate().scale().fadeIn(),
                        ] else if (isError) ...[
                          const Icon(
                            FontAwesomeIcons.circleXmark,
                            color: AppTheme.errorColor,
                            size: 20,
                          ).animate().shake(),
                        ],
                        
                        const SizedBox(width: AppTheme.md),
                        
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                provider.message,
                                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (provider.isActive) ...[
                                const SizedBox(height: 6),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: provider.progress,
                                    backgroundColor: AppTheme.borderColor,
                                    color: AppTheme.primaryColor,
                                    minHeight: 4,
                                  ),
                                ),
                              ] else if (isCompleted) ...[
                                Text(
                                  "Tap to view",
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppTheme.primaryColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              ],
                            ],
                          ),
                        ),
                        
                        if (isCompleted || isError)
                          IconButton(
                            icon: const Icon(FontAwesomeIcons.xmark, size: 16),
                            onPressed: () => provider.reset(),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            color: AppTheme.mutedColor,
                          ),
                      ],
                    ),
                  ).animate()
                   .slideY(begin: -1.0, end: 0.0, curve: Curves.easeOutBack, duration: 400.ms)
                   .fadeIn(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
