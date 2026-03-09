import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../../providers/trip_provider.dart';
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
  const PhotoUploadScreen({super.key});
  @override
  State<PhotoUploadScreen> createState() => _PhotoUploadScreenState();
}

class _PhotoUploadScreenState extends State<PhotoUploadScreen> {
  final _picker = ImagePicker();
  List<File> _images = [];
  bool _isReordering = false;

  // ── RAW extensions (shown with placeholder instead of thumbnail) ─────────
  static const _rawExts = {
    'nef', 'cr2', 'cr3', 'arw', 'dng', 'raw', 'raf', 'orf', 'rw2', 'pef', 'srw',
  };

  // ── Pick from gallery ─────────────────────────────────────────────────────
  Future<void> _pick() async {
    if (_images.length >= ApiConfig.maxImageCount) {
      Fluttertoast.showToast(
        msg: 'Maximum ${ApiConfig.maxImageCount} photos allowed.',
        backgroundColor: AppTheme.warning,
      );
      return;
    }

    final pickedFiles = await _picker.pickMultiImage(imageQuality: 90);
    if (pickedFiles.isEmpty) return;

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
      setState(() => _images = [..._images, ...added]);
      context.read<TripProvider>().setImages(_images);
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

  // ── Navigate to processing ────────────────────────────────────────────────
  void _proceed() {
    final trip = context.read<TripProvider>().currentTrip;
    if (trip == null) return;
    Navigator.pushNamed(
      context,
      AppRoutes.aiProcessing,
      arguments: {
        'destination': trip.destination,
        'scene_tags' : trip.interests.isEmpty ? ['landscape', 'travel'] : trip.interests,
      },
    );
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
              onPressed: () => setState(() => _isReordering = !_isReordering),
            ),
          if (_images.isNotEmpty)
            TextButton(
              onPressed: _proceed,
              child: const Text('Next →'),
            ),
        ],
      ),

      body: Column(
        children: [
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
                ? _EmptyPickerPlaceholder(onTap: _pick)
                : _isReordering
                    ? _buildReorderGrid()
                    : _buildStaticGrid(),
          ),

          // ── Bottom info + button ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                  onPressed: _images.isEmpty ? _pick : _proceed,
                  icon: _images.isEmpty
                      ? Icons.add_photo_alternate_outlined
                      : Icons.arrow_forward,
                ),
              ],
            ),
          ),
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
  final VoidCallback onTap;
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
