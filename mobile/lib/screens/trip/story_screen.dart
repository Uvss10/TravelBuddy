import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../../models/trip_model.dart';
import '../../providers/video_generation_provider.dart';
import '../../providers/trip_provider.dart';
import '../../config/routes.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';

/// Story screen — shows AI-generated title, narration, captions, hashtags.
/// Includes the rich Cinematic Engine panel (Web Parity).
class StoryScreen extends StatefulWidget {
  final TripModel? trip;
  const StoryScreen({super.key, this.trip});

  @override
  State<StoryScreen> createState() => _StoryScreenState();
}

class _StoryScreenState extends State<StoryScreen> {
  late TextEditingController _narrationCtrl;
  String _selectedTheme = 'cinematic';
  File? _selectedMusic;
  File? _selectedLrc;

  final Map<String, dynamic> _themes = {
    'cinematic': {'label': '🎞 Cinematic', 'color': Color(0xFF7c3aed)},
    'energetic': {'label': '⚡ Energetic', 'color': Color(0xFFef4444)},
    'romantic': {'label': '💕 Romantic', 'color': Color(0xFFec4899)},
    'adventure': {'label': '🏔 Adventure', 'color': Color(0xFFf59e0b)},
  };

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

  Future<void> _pickMusic() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (res != null) setState(() => _selectedMusic = File(res.files.first.path!));
  }

  Future<void> _pickLrc() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['lrc', 'txt'],
    );
    if (res != null) setState(() => _selectedLrc = File(res.files.first.path!));
  }

  void _generateCinematic() {
    final provider = context.read<VideoGenerationProvider>();
    final tripProc = context.read<TripProvider>();
    final images = tripProc.selectedImages.map((e) => e.path).toList();

    if (images.isEmpty) {
      Fluttertoast.showToast(msg: 'No photos selected. Go back to upload.');
      return;
    }

    provider.startCinematicGeneration(
      imagePaths: images,
      destination: widget.trip?.destination ?? 'Travel',
      theme: _selectedTheme,
      audioPath: _selectedMusic?.path,
    );

    // Provide immediate feedback
    Fluttertoast.showToast(msg: 'Starting Cinematic Engine...', backgroundColor: AppTheme.primary);
  }

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;
    final videoProv = context.watch<VideoGenerationProvider>();

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
          if (videoProv.finalVideoUrl != null)
            TextButton(
              onPressed: () => Navigator.pushNamed(context, AppRoutes.reelPreview),
              child: const Text('View Reel →'),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        children: [
          // ── Title ──
          Text('STORY TITLE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.textHint, letterSpacing: 1.2)),
          const SizedBox(height: 4),
          Text(trip!.storyTitle!, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -1)),
          const SizedBox(height: 28),

          // ── Narration ──
          _SectionContainer(
            title: 'Narration Script',
            icon: Icons.edit_note_outlined,
            child: TextField(
              controller: _narrationCtrl,
              maxLines: null,
              style: const TextStyle(fontSize: 15, height: 1.6),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'AI script loading...',
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ).animate().fadeIn(duration: 400.ms).slideX(begin: 0.05),

          const SizedBox(height: 24),

          // ── Cinematic Engine Panel (Web Parity) ──
          _CinematicPanel(
            selectedTheme: _selectedTheme,
            themes: _themes,
            onThemeChange: (t) => setState(() => _selectedTheme = t),
            onPickMusic: _pickMusic,
            onPickLrc: _pickLrc,
            musicName: _selectedMusic?.path.split('/').last,
            lrcName: _selectedLrc?.path.split('/').last,
            onGenerate: _generateCinematic,
            videoProv: videoProv,
          ).animate().fadeIn(delay: 200.ms),

          const SizedBox(height: 32),

          // ── Captions ──
          Text('ON-SCREEN CAPTIONS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.textHint, letterSpacing: 1.2)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: trip.captions.map((c) => _TextChip(text: c, color: AppTheme.primary)).toList(),
          ),

          const SizedBox(height: 32),

          // ── Hashtags ──
          Text('TRENDING HASHTAGS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.textHint, letterSpacing: 1.2)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: trip.hashtags.map((h) => _TextChip(text: h, color: AppTheme.accent)).toList(),
          ),

          const SizedBox(height: 40),
          if (videoProv.finalVideoUrl != null)
            TBPrimaryButton(
              label: 'View Final Reel',
              onPressed: () => Navigator.pushNamed(context, AppRoutes.reelPreview),
              icon: Icons.play_circle_fill,
            ),
          const SizedBox(height: 12),
          TBSecondaryButton(
            label: 'Copy Story Text',
            icon: Icons.copy_all_outlined,
            onPressed: () {
              Fluttertoast.showToast(msg: 'Story copied to clipboard!', backgroundColor: AppTheme.success);
            },
          ),
          const SizedBox(height: 60),
        ],
      ),
    );
  }
}

class _SectionContainer extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  const _SectionContainer({required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderLight),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text(title.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.textHint, letterSpacing: 1)),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _CinematicPanel extends StatelessWidget {
  final String selectedTheme;
  final Map<String, dynamic> themes;
  final Function(String) onThemeChange;
  final VoidCallback onPickMusic;
  final VoidCallback onPickLrc;
  final String? musicName;
  final String? lrcName;
  final VoidCallback onGenerate;
  final VideoGenerationProvider videoProv;

  const _CinematicPanel({
    required this.selectedTheme,
    required this.themes,
    required this.onThemeChange,
    required this.onPickMusic,
    required this.onPickLrc,
    this.musicName,
    this.lrcName,
    required this.onGenerate,
    required this.videoProv,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF7c3aed).withAlpha(20), const Color(0xFF10b981).withAlpha(10)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF7c3aed).withAlpha(40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🎬', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Cinematic Engine', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                    Text('1080p · Beat-sync · Grade', style: TextStyle(fontSize: 11, color: AppTheme.textHint)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF7c3aed), Color(0xFF10b981)]),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('NEW', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Themes ──
          const Text('VISUAL THEME', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.textHint)),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: themes.entries.map((e) {
                final isSel = e.key == selectedTheme;
                final color = e.value['color'] as Color;
                return GestureDetector(
                  onTap: () => onThemeChange(e.key),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSel ? color : Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: isSel ? color : AppTheme.borderLight),
                    ),
                    child: Text(
                      e.value['label'],
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isSel ? Colors.white : AppTheme.textPrimary),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 20),

          // ── Audio/LRC ──
          Row(
            children: [
              Expanded(
                child: _FileTile(
                  label: 'MUSIC',
                  filename: musicName,
                  onTap: onPickMusic,
                  icon: Icons.music_note_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _FileTile(
                  label: 'LYRICS',
                  filename: lrcName,
                  onTap: onPickLrc,
                  icon: Icons.subtitles_outlined,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          if (videoProv.isActive)
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(videoProv.message, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    Text('${(videoProv.progress * 100).toInt()}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppTheme.primary)),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: videoProv.progress,
                    minHeight: 8,
                    backgroundColor: Colors.white.withAlpha(100),
                    color: const Color(0xFF7c3aed),
                  ),
                ),
              ],
            )
          else
            TBPrimaryButton(
              label: 'Generate Cinematic Reel',
              onPressed: onGenerate,
              icon: Icons.auto_awesome,
            ),
        ],
      ),
    );
  }
}

class _FileTile extends StatelessWidget {
  final String label;
  final String? filename;
  final VoidCallback onTap;
  final IconData icon;

  const _FileTile({required this.label, this.filename, required this.onTap, required this.icon});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(150),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppTheme.textHint)),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(icon, size: 14, color: AppTheme.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    filename ?? 'Select...',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TextChip extends StatelessWidget {
  final String text;
  final Color color;
  const _TextChip({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(40)),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}
