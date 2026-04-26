import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/reel_draft_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../config/routes.dart';

/// STAGE 3 — Atmosphere
/// Music library picker + custom upload + beat preview strip.
class ReelAtmosphereScreen extends StatefulWidget {
  const ReelAtmosphereScreen({super.key});

  @override
  State<ReelAtmosphereScreen> createState() => _ReelAtmosphereScreenState();
}

class _ReelAtmosphereScreenState extends State<ReelAtmosphereScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  List<Map<String, dynamic>> _libraryTracks = [];
  bool _isLoadingLibrary = true;
  bool _isUploadingAudio = false;
  late AnimationController _waveCtrl;

  @override
  void initState() {
    super.initState();
    _waveCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
    _loadLibrary();
  }

  @override
  void dispose() {
    _waveCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLibrary() async {
    final result = await _api.getMusicLibrary();
    if (mounted) {
      setState(() {
        _isLoadingLibrary = false;
        if (result.isSuccess) {
          _libraryTracks = (result.data ?? []).cast<Map<String, dynamic>>();
        }
      });
    }
  }

  Future<void> _pickCustomAudio(BuildContext ctx) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (result == null || result.files.isEmpty) return;
    final path = result.files.first.path;
    if (path == null) return;

    setState(() => _isUploadingAudio = true);
    final audioFile = File(path);
    final uploadResult = await _api.uploadAudio(audioFile);
    setState(() => _isUploadingAudio = false);

    if (!ctx.mounted) return;
    if (!uploadResult.isSuccess) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(content: Text(uploadResult.error ?? 'Upload failed')),
      );
      return;
    }
    ctx.read<ReelDraftProvider>().setAudio(uploadResult.data!, audioFile.path.split('/').last);
  }

  void _selectLibraryTrack(BuildContext ctx, Map<String, dynamic> track) {
    ctx.read<ReelDraftProvider>().setAudio(
          track['path']?.toString() ?? '',
          track['name']?.toString() ?? 'Library Track',
        );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReelDraftProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F1A),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Step 3 · Vibe & Music',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
        ),
        actions: [
          TextButton(
            onPressed: () {
              provider.clearAudio();
              provider.advanceToAnnotation();
              Navigator.pushNamed(context, AppRoutes.reelAnnotation);
            },
            child: const Text('Skip', style: TextStyle(color: Colors.white38)),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Selected track banner ─────────────────────────────────
                  if (provider.selectedAudioName != null)
                    _SelectedTrackBanner(
                      name: provider.selectedAudioName!,
                      waveCtrl: _waveCtrl,
                      onRemove: () => context.read<ReelDraftProvider>().clearAudio(),
                    ).animate().fadeIn(),

                  // ── Custom Upload ─────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: _UploadCard(
                      isLoading: _isUploadingAudio,
                      onTap: () => _pickCustomAudio(context),
                    ).animate().fadeIn(delay: 100.ms),
                  ),

                  const SizedBox(height: 24),

                  // ── Library title ─────────────────────────────────────────
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      '🎵  Copyright-Free Library',
                      style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      'All tracks are beat-analyzed and cleared for social sharing.',
                      style: TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Library tracks ────────────────────────────────────────
                  if (_isLoadingLibrary)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation(Color(0xFFF59E0B)),
                        ),
                      ),
                    )
                  else if (_libraryTracks.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                        child: Text(
                          'No library tracks found.\nAdd mp3 files to backend/static/music/',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white38, fontSize: 13),
                        ),
                      ),
                    )
                  else
                    ...List.generate(_libraryTracks.length, (i) {
                      final track = _libraryTracks[i];
                      final isSelected = provider.selectedAudioPath == track['path'];
                      return _TrackTile(
                        track: track,
                        isSelected: isSelected,
                        waveCtrl: _waveCtrl,
                        onTap: () => _selectLibraryTrack(context, track),
                      ).animate(delay: (i * 50).ms).fadeIn().slideX(begin: 0.1);
                    }),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // ── Bottom CTA ──────────────────────────────────────────────────
          _AtmosphereBottomBar(
            hasAudio: provider.selectedAudioName != null,
            onBack: () => Navigator.pop(context),
            onContinue: () {
              provider.advanceToAnnotation();
              Navigator.pushNamed(context, AppRoutes.reelAnnotation);
            },
          ).animate().fadeIn(delay: 300.ms),
        ],
      ),
    );
  }
}

// ── Selected Track Banner ─────────────────────────────────────────────────────

class _SelectedTrackBanner extends StatelessWidget {
  final String name;
  final AnimationController waveCtrl;
  final VoidCallback onRemove;
  const _SelectedTrackBanner({required this.name, required this.waveCtrl, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.4)),
      ),
      child: Row(
        children: [
          // Mini waveform
          AnimatedBuilder(
            animation: waveCtrl,
            builder: (_, __) => SizedBox(
              width: 40,
              height: 32,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(5, (i) {
                  final h = 8.0 + (waveCtrl.value * 16.0 * ((i % 2 == 0) ? 1.0 : 0.5));
                  return Container(
                    width: 4,
                    height: h,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  );
                }),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Now Playing',
                    style: TextStyle(color: Color(0xFFF59E0B), fontSize: 10, fontWeight: FontWeight.w700)),
                Text(name,
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close_rounded, color: Colors.white54, size: 16),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Upload Card ───────────────────────────────────────────────────────────────

class _UploadCard extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onTap;
  const _UploadCard({required this.isLoading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            style: BorderStyle.solid,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: isLoading
                  ? const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Color(0xFF6366F1)),
                        ),
                      ),
                    )
                  : const Icon(Icons.upload_file_rounded, color: Color(0xFF6366F1), size: 24),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Upload Your Music',
                      style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                  SizedBox(height: 2),
                  Text('mp3, wav, m4a, flac supported',
                      style: TextStyle(color: Colors.white38, fontSize: 11)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white38),
          ],
        ),
      ),
    );
  }
}

// ── Track Tile ────────────────────────────────────────────────────────────────

class _TrackTile extends StatelessWidget {
  final Map<String, dynamic> track;
  final bool isSelected;
  final AnimationController waveCtrl;
  final VoidCallback onTap;

  const _TrackTile({
    required this.track,
    required this.isSelected,
    required this.waveCtrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = track['name']?.toString() ?? 'Unknown Track';
    final bpm = track['bpm']?.toString() ?? '—';
    final mood = track['mood']?.toString() ?? '';

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFF59E0B).withOpacity(0.1)
              : Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? const Color(0xFFF59E0B).withOpacity(0.5) : Colors.white12,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Play indicator / icon
            if (isSelected)
              AnimatedBuilder(
                animation: waveCtrl,
                builder: (_, __) => SizedBox(
                  width: 32,
                  height: 32,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(3, (i) {
                      final h = 4.0 + (waveCtrl.value * 12.0 * ((i == 1) ? 1.0 : 0.6));
                      return Container(
                        width: 4,
                        height: h,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      );
                    }),
                  ),
                ),
              )
            else
              const Icon(Icons.play_circle_outline_rounded, color: Colors.white38, size: 32),

            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      )),
                  if (mood.isNotEmpty || bpm != '—')
                    Text(
                      '${mood.isNotEmpty ? "$mood · " : ""}${bpm}BPM',
                      style: TextStyle(
                        color: isSelected
                            ? const Color(0xFFF59E0B)
                            : Colors.white.withOpacity(0.3),
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),

            if (isSelected)
              const Icon(Icons.check_circle_rounded, color: Color(0xFFF59E0B), size: 22),
          ],
        ),
      ),
    );
  }
}

// ── Bottom bar ────────────────────────────────────────────────────────────────

class _AtmosphereBottomBar extends StatelessWidget {
  final bool hasAudio;
  final VoidCallback onBack;
  final VoidCallback onContinue;

  const _AtmosphereBottomBar({
    required this.hasAudio,
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
              onTap: onContinue,
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: hasAudio
                        ? const [Color(0xFFF59E0B), Color(0xFFD97706)]
                        : [Colors.white24, Colors.white12],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: hasAudio
                      ? [BoxShadow(color: const Color(0xFFF59E0B).withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6))]
                      : [],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      hasAudio ? Icons.text_fields_rounded : Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      hasAudio ? 'Continue → Captions' : 'Skip → Captions',
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
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
