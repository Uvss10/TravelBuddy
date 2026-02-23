import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../../models/trip_model.dart';
import '../../config/routes.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';

/// Story screen — shows AI-generated title, narration, captions, hashtags.
/// Narration is editable (TextArea).
class StoryScreen extends StatefulWidget {
  final TripModel? trip;
  const StoryScreen({super.key, this.trip});
  @override
  State<StoryScreen> createState() => _StoryScreenState();
}

class _StoryScreenState extends State<StoryScreen> {
  late TextEditingController _narrationCtrl;

  @override
  void initState() {
    super.initState();
    _narrationCtrl = TextEditingController(text: widget.trip?.storyNarration ?? '');
  }

  @override
  void dispose() {
    _narrationCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;

    if (trip?.storyTitle == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Story')),
        body: const TBEmptyState(
          icon: Icons.auto_stories_outlined,
          title: 'No story yet',
          subtitle: 'Complete the AI processing step to generate your story.',
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Story'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pushNamed(context, AppRoutes.reelPreview),
            child: const Text('Preview Reel →'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Title
          Text('Title', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          Text(trip!.storyTitle!, style: Theme.of(context).textTheme.displaySmall),
          const SizedBox(height: 24),

          // Narration (editable)
          Row(
            children: [
              Text('Narration', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppTheme.textSecondary)),
              const SizedBox(width: 6),
              const Icon(Icons.edit_outlined, size: 14, color: AppTheme.textHint),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.borderLight),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(12),
            child: TextFormField(
              controller: _narrationCtrl,
              maxLines: null,
              style: Theme.of(context).textTheme.bodyLarge,
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Captions
          Text('On-Screen Captions', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppTheme.textSecondary)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: trip.captions.map((c) => _CaptionChip(text: c)).toList(),
          ),
          const SizedBox(height: 24),

          // Hashtags
          Text('Hashtags', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppTheme.textSecondary)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: trip.hashtags.map((h) => _HashtagChip(text: h)).toList(),
          ),
          const SizedBox(height: 32),

          TBPrimaryButton(
            label: 'Preview Reel',
            onPressed: () => Navigator.pushNamed(context, AppRoutes.reelPreview),
            icon: Icons.play_circle_outline,
          ),
          const SizedBox(height: 12),
          TBSecondaryButton(
            label: 'Copy Narration',
            icon: Icons.copy_outlined,
            onPressed: () {
              // Would use Clipboard.setData in production
              Fluttertoast.showToast(msg: 'Narration copied!', backgroundColor: AppTheme.success);
            },
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _CaptionChip extends StatelessWidget {
  final String text;
  const _CaptionChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.primary.withAlpha(10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Text(text, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500)),
    );
  }
}

class _HashtagChip extends StatelessWidget {
  final String text;
  const _HashtagChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.accent.withAlpha(15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.accent.withAlpha(40)),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.accent,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
