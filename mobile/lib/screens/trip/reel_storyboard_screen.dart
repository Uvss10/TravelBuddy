import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/reel_draft_provider.dart';
import '../../theme/app_theme.dart';
import '../../config/routes.dart';
import '../../services/config_service.dart';

/// STAGE 2 — Storyboard
/// Drag-and-drop reordering, theme picker, energy/duration sliders.
class ReelStoryboardScreen extends StatefulWidget {
  const ReelStoryboardScreen({super.key});

  @override
  State<ReelStoryboardScreen> createState() => _ReelStoryboardScreenState();
}

class _ReelStoryboardScreenState extends State<ReelStoryboardScreen> {
  bool _isBuilding = false;

  // Theme data
  static const _themes = {
    'cinematic': {
      'label': 'Cinematic',
      'emoji': '🎬',
      'desc': 'Wide shots, dramatic cuts',
      'color': Color(0xFF6366F1),
    },
    'energetic': {
      'label': 'Energetic',
      'emoji': '⚡',
      'desc': 'Fast-paced, beat-synced',
      'color': Color(0xFFEF4444),
    },
    'romantic': {
      'label': 'Romantic',
      'emoji': '🌸',
      'desc': 'Soft fades, warm tones',
      'color': Color(0xFFEC4899),
    },
    'documentary': {
      'label': 'Documentary',
      'emoji': '📽',
      'desc': 'Real & raw storytelling',
      'color': Color(0xFFF59E0B),
    },
    'adventure': {
      'label': 'Adventure',
      'emoji': '🏔',
      'desc': 'Bold & intense motion',
      'color': Color(0xFF10B981),
    },
  };

  static const _durations = [30, 45, 60, 90, 120];

  Future<void> _buildAndContinue(BuildContext ctx) async {
    final provider = ctx.read<ReelDraftProvider>();
    setState(() => _isBuilding = true);
    await provider.buildTimeline();
    setState(() => _isBuilding = false);
    if (!ctx.mounted) return;
    if (provider.error != null) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(content: Text(provider.error!), backgroundColor: Colors.red),
      );
      return;
    }
    Navigator.pushNamed(ctx, AppRoutes.reelAtmosphere);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReelDraftProvider>();
    final kept = provider.curatedOrder.where((p) => p.userKept).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F1A),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Step 2 · Storyboard',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '${kept.length} photos',
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // ── Story sequence strip (reorderable) ───────────────────────
              Container(
                height: 130,
                color: const Color(0xFF0F0F1A),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Row(
                        children: [
                          const Icon(Icons.drag_indicator, color: Colors.white38, size: 16),
                          const SizedBox(width: 6),
                          const Text(
                            'Drag to reorder your story',
                            style: TextStyle(color: Colors.white38, fontSize: 12),
                          ),
                          const Spacer(),
                          Text(
                            'Hold & drag photos',
                            style: TextStyle(
                              color: const Color(0xFF6366F1).withOpacity(0.7),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ReorderableListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: kept.length,
                        onReorder: (oldIdx, newIdx) {
                          context.read<ReelDraftProvider>().reorderPhoto(oldIdx, newIdx);
                        },
                        itemBuilder: (_, i) {
                          final photo = kept[i];
                          return _StripPhotoCard(
                            key: ValueKey(photo.path),
                            photo: photo,
                            index: i,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Theme Selector ────────────────────────────────────
                      const _SectionHeader(
                        icon: Icons.palette_rounded,
                        title: 'Choose Your Vibe',
                        subtitle: 'Sets transitions, color grade & motion',
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 90,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: _themes.entries.map((e) {
                            final key = e.key;
                            final val = e.value;
                            final isSelected = provider.selectedTheme == key;
                            final color = val['color'] as Color;
                            return GestureDetector(
                              onTap: () => context.read<ReelDraftProvider>().setTheme(key),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 100,
                                margin: const EdgeInsets.only(right: 10),
                                decoration: BoxDecoration(
                                  color: isSelected ? color.withOpacity(0.15) : Colors.white.withOpacity(0.04),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isSelected ? color : Colors.white12,
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(val['emoji'] as String, style: const TextStyle(fontSize: 24)),
                                    const SizedBox(height: 4),
                                    Text(
                                      val['label'] as String,
                                      style: TextStyle(
                                        color: isSelected ? color : Colors.white54,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      val['desc'] as String,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 9),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ).animate().fadeIn(delay: 100.ms),

                      const SizedBox(height: 24),

                      // ── Energy Slider ─────────────────────────────────────
                      const _SectionHeader(
                        icon: Icons.bolt_rounded,
                        title: 'Edit Pace',
                        subtitle: 'Controls how fast photos change',
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Text('😌', style: TextStyle(fontSize: 18)),
                                    const SizedBox(width: 6),
                                    Text('Relaxed',
                                        style: TextStyle(
                                          color: provider.energyLevel < 0.33
                                              ? const Color(0xFF10B981)
                                              : Colors.white38,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        )),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Text('Intense',
                                        style: TextStyle(
                                          color: provider.energyLevel > 0.66
                                              ? const Color(0xFFEF4444)
                                              : Colors.white38,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        )),
                                    const SizedBox(width: 6),
                                    const Text('🔥', style: TextStyle(fontSize: 18)),
                                  ],
                                ),
                              ],
                            ),
                            SliderTheme(
                              data: SliderThemeData(
                                trackHeight: 6,
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
                                overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
                                activeTrackColor: const Color(0xFF6366F1),
                                inactiveTrackColor: Colors.white12,
                                thumbColor: Colors.white,
                                overlayColor: const Color(0xFF6366F1).withOpacity(0.2),
                              ),
                              child: Slider(
                                value: provider.energyLevel,
                                onChanged: (v) => context.read<ReelDraftProvider>().setEnergyLevel(v),
                              ),
                            ),
                            Text(
                              _energyLabel(provider.energyLevel),
                              style: const TextStyle(color: Colors.white54, fontSize: 11),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(delay: 200.ms),

                      const SizedBox(height: 24),

                      // ── Duration Selector ─────────────────────────────────
                      const _SectionHeader(
                        icon: Icons.timer_outlined,
                        title: 'Reel Length',
                        subtitle: 'How long should your reel be?',
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: _durations.map((sec) {
                          final isSelected = provider.durationSeconds == sec;
                          return GestureDetector(
                            onTap: () => context.read<ReelDraftProvider>().setDuration(sec),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.only(right: 10),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFF0EA5E9).withOpacity(0.15) : Colors.white.withOpacity(0.04),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected ? const Color(0xFF0EA5E9) : Colors.white12,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Text(
                                '${sec}s',
                                style: TextStyle(
                                  color: isSelected ? const Color(0xFF0EA5E9) : Colors.white38,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ).animate().fadeIn(delay: 300.ms),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),

              // ── Bottom CTA ────────────────────────────────────────────────
              _StoryboardBottomBar(
                isLoading: _isBuilding,
                onBack: () => Navigator.pop(context),
                onContinue: () => _buildAndContinue(context),
              ).animate().fadeIn(delay: 400.ms),
            ],
          ),

          // Building overlay
          if (_isBuilding)
            Container(
              color: Colors.black.withOpacity(0.8),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(Color(0xFF0EA5E9))),
                    SizedBox(height: 20),
                    Text('Building your storyboard…',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _energyLabel(double v) {
    if (v < 0.33) return '~3s per photo · Slow cinematic feel';
    if (v < 0.66) return '~2s per photo · Balanced pacing';
    return '~0.8s per photo · Fast, beat-locked cuts';
  }
}

// ── Strip photo card (for reorderable strip) ──────────────────────────────────

class _StripPhotoCard extends StatelessWidget {
  final CuratedPhoto photo;
  final int index;
  const _StripPhotoCard({super.key, required this.photo, required this.index});

  Color _sectionColor(int i, int total) {
    final ratio = i / (total <= 1 ? 1 : total - 1);
    if (ratio < 0.08) return const Color(0xFF6366F1);
    if (ratio < 0.33) return const Color(0xFF0EA5E9);
    if (ratio < 0.67) return const Color(0xFFF59E0B);
    if (ratio < 0.92) return const Color(0xFF10B981);
    return const Color(0xFFEF4444);
  }

  @override
  Widget build(BuildContext context) {
    final total = context.watch<ReelDraftProvider>().curatedOrder.where((p) => p.userKept).length;
    final col = _sectionColor(index, total);

    return Container(
      width: 72,
      margin: const EdgeInsets.only(right: 8, bottom: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: col.withOpacity(0.5), width: 2),
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              color: Colors.white10,
              width: double.infinity,
              height: double.infinity,
              child: Image.network(
                '${ConfigService().backendUrl}${photo.path.startsWith('/') ? '' : '/'}${photo.path}',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_rounded, color: Colors.white10, size: 24),
                loadingBuilder: (_, child, progress) {
                  if (progress == null) return child;
                  return Center(
                    child: SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        value: progress.expectedTotalBytes != null
                            ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                            : null,
                        strokeWidth: 2,
                        valueColor: const AlwaysStoppedAnimation(Colors.white10),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: col.withOpacity(0.85),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
              ),
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text(
                '${index + 1}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
              ),
            ),
          ),
          // Drag handle
          const Positioned(
            top: 4,
            right: 4,
            child: Icon(Icons.drag_handle_rounded, color: Colors.white54, size: 14),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _SectionHeader({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white54, size: 16),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
            Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)),
          ],
        ),
      ],
    );
  }
}

class _StoryboardBottomBar extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onBack;
  final VoidCallback onContinue;

  const _StoryboardBottomBar({
    required this.isLoading,
    required this.onBack,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F1A),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08))),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white12),
              ),
              child: const Icon(Icons.arrow_back_rounded, color: Colors.white70),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: isLoading ? null : onContinue,
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF0EA5E9), Color(0xFF6366F1)]),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFF0EA5E9).withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6)),
                  ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.music_note_rounded, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text('Continue → Add Vibe',
                        style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
