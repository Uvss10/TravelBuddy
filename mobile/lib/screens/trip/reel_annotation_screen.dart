import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/reel_draft_provider.dart';
import '../../theme/app_theme.dart';
import '../../config/routes.dart';
import '../../services/config_service.dart';

/// STAGE 4 — Annotation
/// User edits captions per slot on a scrollable timeline.
class ReelAnnotationScreen extends StatefulWidget {
  const ReelAnnotationScreen({super.key});

  @override
  State<ReelAnnotationScreen> createState() => _ReelAnnotationScreenState();
}

class _ReelAnnotationScreenState extends State<ReelAnnotationScreen> {
  final Map<int, TextEditingController> _controllers = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Build controllers for each slot
    final timeline = context.read<ReelDraftProvider>().timeline;
    for (final slot in timeline) {
      _controllers.putIfAbsent(slot.index, () => TextEditingController(text: slot.caption));
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReelDraftProvider>();
    final timeline = provider.timeline;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F1A),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Step 4 · Captions',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
        ),
        actions: [
          // Clear all
          TextButton(
            onPressed: () {
              for (final slot in timeline) {
                _controllers[slot.index]?.clear();
                context.read<ReelDraftProvider>().updateCaption(slot.index, '');
              }
            },
            child: const Text('Clear All', style: TextStyle(color: Colors.white38, fontSize: 12)),
          ),
        ],
      ),
      body: Column(
        children: [
          // Instruction banner
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF10B981).withOpacity(0.2)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded, color: Color(0xFF10B981), size: 16),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Add captions to any photo — they\'ll appear as text overlays in your reel. Leave blank to skip.',
                    style: TextStyle(color: Colors.white60, fontSize: 11),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(),

          const SizedBox(height: 8),

          // Timeline list
          Expanded(
            child: timeline.isEmpty
                ? const Center(
                    child: Text(
                      'No timeline slots found.\nGo back and build your storyboard.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white38),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: timeline.length,
                    itemBuilder: (context, i) {
                      final slot = timeline[i];
                      final ctrl = _controllers[slot.index] ??= TextEditingController(text: slot.caption);
                      return _SlotAnnotationCard(
                        slot: slot,
                        controller: ctrl,
                        onChanged: (text) =>
                            context.read<ReelDraftProvider>().updateCaption(slot.index, text),
                      ).animate(delay: (i * 40).ms).fadeIn().slideX(begin: 0.05);
                    },
                  ),
          ),

          // Bottom CTA
          _AnnotationBottomBar(
            onBack: () => Navigator.pop(context),
            onContinue: () => Navigator.pushNamed(context, AppRoutes.reelProduction),
          ).animate().fadeIn(delay: 300.ms),
        ],
      ),
    );
  }
}

// ── Slot annotation card ──────────────────────────────────────────────────────

class _SlotAnnotationCard extends StatefulWidget {
  final TimelineSlotModel slot;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _SlotAnnotationCard({
    required this.slot,
    required this.controller,
    required this.onChanged,
  });

  @override
  State<_SlotAnnotationCard> createState() => _SlotAnnotationCardState();
}

class _SlotAnnotationCardState extends State<_SlotAnnotationCard> {
  bool _isFocused = false;

  Color get _sectionColor {
    switch (widget.slot.section) {
      case 'intro':
        return const Color(0xFF6366F1);
      case 'exploration':
        return const Color(0xFF0EA5E9);
      case 'peak':
        return const Color(0xFFF59E0B);
      case 'scenic':
        return const Color(0xFF10B981);
      case 'outro':
        return const Color(0xFFEF4444);
      default:
        return Colors.white38;
    }
  }

  String get _sectionEmoji {
    switch (widget.slot.section) {
      case 'intro':
        return '🎬';
      case 'exploration':
        return '🌍';
      case 'peak':
        return '⚡';
      case 'scenic':
        return '🌅';
      case 'outro':
        return '✨';
      default:
        return '📸';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (f) => setState(() => _isFocused = f),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: _isFocused ? _sectionColor.withOpacity(0.08) : Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isFocused ? _sectionColor.withOpacity(0.5) : Colors.white12,
            width: _isFocused ? 2 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Photo thumbnail placeholder + section tag
              Column(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _sectionColor.withOpacity(0.3)),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          '${ConfigService().backendUrl}${widget.slot.photoPath.startsWith('/') ? '' : '/'}${widget.slot.photoPath}',
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Center(
                            child: Text(_sectionEmoji, style: const TextStyle(fontSize: 22)),
                          ),
                        ),
                        // Small emoji overlay
                        Positioned(
                          top: 4,
                          left: 4,
                          child: Text(_sectionEmoji, style: const TextStyle(fontSize: 14)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _sectionColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${widget.slot.durationS.toStringAsFixed(1)}s',
                      style: TextStyle(color: _sectionColor, fontSize: 9, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),

              const SizedBox(width: 14),

              // Caption input
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _sectionColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${widget.slot.section.toUpperCase()} · #${widget.slot.index + 1}',
                            style: TextStyle(
                              color: _sectionColor,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${widget.slot.startS.toStringAsFixed(1)}s – ${widget.slot.endS.toStringAsFixed(1)}s',
                          style: const TextStyle(color: Colors.white24, fontSize: 10),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: widget.controller,
                      onChanged: widget.onChanged,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      maxLines: 2,
                      maxLength: 60,
                      decoration: InputDecoration(
                        hintText: 'Add a caption (optional)…',
                        hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        counterStyle: const TextStyle(color: Colors.white24, fontSize: 9),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Bottom bar ────────────────────────────────────────────────────────────────

class _AnnotationBottomBar extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onContinue;

  const _AnnotationBottomBar({required this.onBack, required this.onContinue});

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
              onTap: onContinue,
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10B981).withOpacity(0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Continue → Produce',
                      style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                    ),
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
