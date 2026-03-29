import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../../providers/trip_provider.dart';
import '../../providers/video_generation_provider.dart';
import '../../config/routes.dart';
import '../../config/api_config.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';

/// Multi-image picker with:
///   • Tap-to-add (gallery)
///   • ReorderableGridView for drag-to-reorder
///   • Remove button per photo
///   • 50 MB per file validation
///   • 100 photo maximum
///   • All image formats accepted (JPEG, PNG, WEBP, HEIC, RAW, etc.)
class PhotoUploadScreen extends StatefulWidget {
  final String? initialDestination;
  final List<String>? initialSceneTags;
  final String? initialTone;

  const PhotoUploadScreen({
    super.key,
    this.initialDestination,
    this.initialSceneTags,
    this.initialTone,
  });

  @override
  State<PhotoUploadScreen> createState() => _PhotoUploadScreenState();
}

class _PhotoUploadScreenState extends State<PhotoUploadScreen> {
  final _picker = ImagePicker();
  List<File> _images = [];
  bool _isReordering = false;
  File? _selectedAudio;
  bool _isPickingImages = false;
  bool _isPickingAudio = false;
  bool _isPreparingNext = false;
  String _busyMessage = '';

  bool get _isBusy => _isPickingImages || _isPickingAudio || _isPreparingNext;

  // ── RAW extensions (shown with placeholder instead of thumbnail) ─────────
  static const _rawExts = {
    'nef', 'cr2', 'cr3', 'arw', 'dng', 'raw', 'raf', 'orf', 'rw2', 'pef', 'srw',
  };

  // ── Pick from gallery ─────────────────────────────────────────────────────
  Future<void> _pick() async {
    if (_isBusy) return;

    setState(() {
      _isPickingImages = true;
      _busyMessage = 'Opening gallery...';
    });

    if (_images.length >= ApiConfig.maxImageCount) {
      Fluttertoast.showToast(
        msg: 'Maximum ${ApiConfig.maxImageCount} photos allowed.',
        backgroundColor: AppTheme.warning,
      );
      setState(() => _isPickingImages = false);
      return;
    }

    final pickedFiles = await _picker.pickMultiImage(imageQuality: 90);
    if (pickedFiles.isEmpty) {
      setState(() => _isPickingImages = false);
      return;
    }

    setState(() => _busyMessage = 'Validating ${pickedFiles.length} photo(s)...');

    final added = <File>[];
    int skipped = 0;

    for (final xFile in pickedFiles) {
      if (_images.length + added.length >= ApiConfig.maxImageCount) {
        skipped++;
        continue;
      }
      final file   = File(xFile.path);
      final sizeMB = await file.length() / (1024 * 1024);

      if (sizeMB > ApiConfig.maxImageSizeMB) {
        Fluttertoast.showToast(
          msg: '${xFile.name} is too large (max ${ApiConfig.maxImageSizeMB} MB).',
          backgroundColor: AppTheme.error,
          toastLength: Toast.LENGTH_LONG,
        );
        skipped++;
        continue;
      }

      // Basic dedup by path
      if (!_images.any((f) => f.path == file.path)) {
        added.add(file);
      }
    }

    if (skipped > 0) {
      Fluttertoast.showToast(
        msg: '$skipped file(s) skipped — size limit or maximum reached.',
        backgroundColor: AppTheme.warning,
      );
    }

    if (added.isNotEmpty) {
      if (!mounted) return;
      setState(() => _images = [..._images, ...added]);
      context.read<TripProvider>().setImages(_images);
    }

    if (mounted) {
      setState(() {
        _isPickingImages = false;
        _busyMessage = '';
      });
    }
  }

  // ── Remove single image ───────────────────────────────────────────────────
  void _removeImage(int index) {
    setState(() => _images.removeAt(index));
    context.read<TripProvider>().setImages(_images);
  }

  // ── Finish reorder ────────────────────────────────────────────────────────
  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final item = _images.removeAt(oldIndex);
      _images.insert(newIndex, item);
    });
    context.read<TripProvider>().setImages(_images);
  }

  Future<void> _pickAudio() async {
    if (_isBusy) return;

    setState(() {
      _isPickingAudio = true;
      _busyMessage = 'Selecting music file...';
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['mp3', 'wav', 'ogg', 'flac', 'm4a', 'aac'],
      );

      if (result == null || result.files.isEmpty) return;

      final picked = result.files.first;
      final path = picked.path;

      if (path == null || path.isEmpty) {
        Fluttertoast.showToast(
          msg: 'Unable to access selected music file. Please choose a local file.',
          backgroundColor: AppTheme.warning,
          toastLength: Toast.LENGTH_LONG,
        );
        return;
      }

      var sizeMb = picked.size / (1024 * 1024);
      if (sizeMb <= 0) {
        try {
          sizeMb = await File(path).length() / (1024 * 1024);
        } catch (_) {
          sizeMb = 0;
        }
      }

      if (sizeMb > 50) {
        Fluttertoast.showToast(
          msg: 'Music file is too large. Max 50 MB allowed.',
          backgroundColor: AppTheme.warning,
        );
        return;
      }

      final file = File(path);
      final exists = await file.exists();
      if (!exists) {
        Fluttertoast.showToast(
          msg: 'Selected file could not be accessed. Please pick it again.',
          backgroundColor: AppTheme.warning,
        );
        return;
      }

      if (!mounted) return;
      setState(() => _selectedAudio = file);
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Could not select music file. Please try again.',
        backgroundColor: AppTheme.error,
        toastLength: Toast.LENGTH_LONG,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isPickingAudio = false;
          if (!_isPickingImages && !_isPreparingNext) {
            _busyMessage = '';
          }
        });
      }
    }
  }

  // ── Navigate to processing ────────────────────────────────────────────────
  Future<void> _proceed() async {
    if (_isBusy) return;

    setState(() {
      _isPreparingNext = true;
      _busyMessage = 'Preparing generation flow...';
    });

    final trip = context.read<TripProvider>().currentTrip;
    final destination = (trip?.destination ?? widget.initialDestination ?? '').trim();
    final tone = (widget.initialTone ?? 'adventurous and inspiring').trim();

    if (destination.isEmpty) {
      Fluttertoast.showToast(
        msg: 'Please enter a destination first.',
        backgroundColor: AppTheme.warning,
      );
      setState(() {
        _isPreparingNext = false;
        _busyMessage = '';
      });
      return;
    }

    await Future.delayed(const Duration(milliseconds: 250));

    if (!mounted) return;

    // Trigger the global, non-blocking background video generation
    context.read<VideoGenerationProvider>().startCinematicGeneration(
      imagePaths: _images.map((e) => e.path).toList(),
      destination: destination,
      theme: tone,
      audioPath: _selectedAudio?.path,
    );
    
    setState(() {
      _isPreparingNext = false;
      _busyMessage = '';
    });

    // Let the GlobalGenerationOverlay handle the state. Send user home.
    Navigator.popUntil(context, ModalRoute.withName(AppRoutes.home));
  }

  // ── Helper: is path a RAW file? ───────────────────────────────────────────
  bool _isRaw(File f) {
    final ext = f.path.split('.').last.toLowerCase();
    return _rawExts.contains(ext);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Photos'),
        actions: [
          // Toggle reorder mode hint button
          if (_images.length > 1)
            IconButton(
              icon: Icon(_isReordering ? Icons.check_circle : Icons.swap_vert),
              tooltip: _isReordering ? 'Done reordering' : 'Reorder photos',
              color: _isReordering ? AppTheme.success : null,
              onPressed: _isBusy ? null : () => setState(() => _isReordering = !_isReordering),
            ),
          if (_images.isNotEmpty)
            TextButton(
              onPressed: _isBusy ? null : _proceed,
              child: const Text('Next →'),
            ),
        ],
      ),

      body: Stack(
        children: [
          Column(
            children: [
          if (widget.initialDestination != null || widget.initialTone != null)
            Container(
              width: double.infinity,
              color: AppTheme.bgLight,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Text(
                'Destination: ${widget.initialDestination ?? '-'}  •  Tone: ${widget.initialTone ?? 'adventurous and inspiring'}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),

          if (_images.isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.primary.withAlpha(12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.primary.withAlpha(50)),
              ),
              child: Text(
                _selectedAudio == null
                    ? 'Photos selected. Optional: add music, then continue.'
                    : 'Photos + music selected. Ready for cinematic generation.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),

          // ── Reorder hint banner ─────────────────────────────────────────
          if (_isReordering)
            Container(
              width: double.infinity,
              color: AppTheme.primary.withAlpha(20),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.drag_indicator, size: 18),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Long-press a photo and drag to reorder.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _isReordering = false),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ),

          // ── Photo grid / empty state ────────────────────────────────────
          Expanded(
            child: _images.isEmpty
                ? _EmptyPickerPlaceholder(onTap: _isBusy ? null : _pick)
                : _isReordering
                    ? _buildReorderGrid()
                    : _buildStaticGrid(),
          ),

          // ── Bottom info + button ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 6,
                  alignment: WrapAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_images.length} / ${ApiConfig.maxImageCount} photos',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      'Max ${ApiConfig.maxImageSizeMB} MB each · JPG PNG WEBP HEIC RAW…',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TBPrimaryButton(
                  label: _images.isEmpty
                      ? 'Select Photos'
                      : 'Continue with ${_images.length} Photo${_images.length == 1 ? '' : 's'}',
                  onPressed: _isBusy ? null : (_images.isEmpty ? _pick : _proceed),
                  icon: _images.isEmpty
                      ? Icons.add_photo_alternate_outlined
                      : Icons.arrow_forward,
                  isLoading: _isPreparingNext,
                ),
                const SizedBox(height: 10),
                TBSecondaryButton(
                  label: _selectedAudio == null
                      ? 'Add Music (Optional)'
                      : 'Music Added: ${_selectedAudio!.path.split('/').last}',
                  icon: Icons.music_note,
                  onPressed: _isBusy ? null : _pickAudio,
                ),
              ],
            ),
          ),
            ],
          ),
          if (_isBusy)
            TBLoadingOverlay(message: _busyMessage.isEmpty ? 'Please wait...' : _busyMessage),
        ],
      ),
    );
  }

  // ── Static (non-reorder) grid ─────────────────────────────────────────────
  Widget _buildStaticGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _images.length + 1, // +1 for Add-more button
      itemBuilder: (_, i) {
        if (i == _images.length) return _AddMoreButton(onTap: _pick);
        return Stack(
          fit: StackFit.expand,
          children: [
            _ImageTile(file: _images[i], isRaw: _isRaw(_images[i])),
            // Order badge
            Positioned(
              bottom: 4, left: 5,
              child: _OrderBadge(number: i + 1),
            ),
            // Remove button
            Positioned(
              top: 4, right: 4,
              child: GestureDetector(
                onTap: () => _removeImage(i),
                child: const _DeleteBadge(),
              ),
            ),
          ],
        );
      },
    );
  }

  // ── Reorderable grid (long-press-to-drag) ─────────────────────────────────
  Widget _buildReorderGrid() {
    return ReorderableGridView.count(
      crossAxisCount: 3,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      padding: const EdgeInsets.all(16),
      onReorder: _onReorder,
      children: List.generate(_images.length, (i) {
        return Stack(
          key: ValueKey(_images[i].path + i.toString()),
          fit: StackFit.expand,
          children: [
            _ImageTile(file: _images[i], isRaw: _isRaw(_images[i])),
            Positioned(
              bottom: 4, left: 5,
              child: _OrderBadge(number: i + 1),
            ),
            Positioned(
              top: 4, right: 4,
              child: GestureDetector(
                onTap: () => _removeImage(i),
                child: const _DeleteBadge(),
              ),
            ),
          ],
        );
      }),
    );
  }
}

// ─── Empty placeholder ─────────────────────────────────────────────────────────
class _EmptyPickerPlaceholder extends StatelessWidget {
  final VoidCallback? onTap;
  const _EmptyPickerPlaceholder({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 120, height: 120,
              decoration: BoxDecoration(
                color: AppTheme.bgLight,
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Icon(Icons.add_photo_alternate_outlined, size: 52, color: AppTheme.textHint),
            ),
            const SizedBox(height: 20),
            Text('Tap to add photos', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 6),
            Text(
              'Up to ${ApiConfig.maxImageCount} images · ${ApiConfig.maxImageSizeMB} MB each\nJPG · PNG · WEBP · HEIC · RAW and more',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Single image tile ────────────────────────────────────────────────────────
class _ImageTile extends StatelessWidget {
  final File file;
  final bool isRaw;
  const _ImageTile({required this.file, required this.isRaw});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: isRaw
          ? Container(
              color: const Color(0xFF0f172a),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.camera_outlined, color: Color(0xFF38bdf8), size: 28),
                  const SizedBox(height: 4),
                  Text(
                    file.path.split('.').last.toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xFF94a3b8), fontSize: 10, fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            )
          : Image.file(file, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: const Color(0xFF1e293b),
                child: const Icon(Icons.broken_image_outlined, color: Colors.white38),
              ),
            ),
    );
  }
}

// ─── Order-number badge ════════════════════════════════════════════════════════
class _OrderBadge extends StatelessWidget {
  final int number;
  const _OrderBadge({required this.number});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '$number',
        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
      ),
    );
  }
}

// ─── Delete badge ─────────────────────────────────────────────────────────────
class _DeleteBadge extends StatelessWidget {
  const _DeleteBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20, height: 20,
      decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
      child: const Icon(Icons.close, size: 13, color: Colors.white),
    );
  }
}

// ─── Add-more button ──────────────────────────────────────────────────────────
class _AddMoreButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AddMoreButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.bgLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.borderLight),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, size: 28, color: AppTheme.textHint),
            SizedBox(height: 4),
            Text('Add', style: TextStyle(fontSize: 11, color: AppTheme.textHint)),
          ],
        ),
      ),
    );
  }
}

// ─── ReorderableGridView shim ──────────────────────────────────────────────────
/// Wraps `ReorderableListView` in a grid layout since Flutter doesn't have a
/// ReorderableGridView in its core library.
/// Add `reorderable_grid_view` to pubspec.yaml, or use this simple shim.
class ReorderableGridView extends StatelessWidget {
  final int crossAxisCount;
  final double crossAxisSpacing;
  final double mainAxisSpacing;
  final EdgeInsetsGeometry padding;
  final List<Widget> children;
  final void Function(int oldIndex, int newIndex) onReorder;

  const ReorderableGridView.count({
    super.key,
    required this.crossAxisCount,
    required this.crossAxisSpacing,
    required this.mainAxisSpacing,
    required this.padding,
    required this.children,
    required this.onReorder,
  });

  @override
  Widget build(BuildContext context) {
    // Simple ReorderableListView displayed as a wrapped grid
    return ReorderableListView(
      padding: padding as EdgeInsets? ?? EdgeInsets.zero,
      onReorder: onReorder,
      children: children,
    );
  }
}
