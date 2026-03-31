import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/trip_provider.dart';
import '../../providers/video_generation_provider.dart';
import '../../config/routes.dart';
import '../../config/api_config.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';

/// Professional Photo Upload Screen (Director's Suite)
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

  String _selectedStyle = 'Cinematic';
  final Map<String, dynamic> _styles = {
    'Cinematic': {'icon': Icons.movie_filter_outlined, 'desc': 'Wide, 2.35:1 look'},
    'Film': {'icon': Icons.camera_roll_outlined, 'desc': 'Vintage 35mm grain'},
    'Vibrant': {'icon': Icons.auto_awesome_outlined, 'desc': 'Rich, poppy colors'},
    'Natural': {'icon': Icons.eco_outlined, 'desc': 'Soft & authentic'},
  };

  bool get _isBusy => _isPickingImages || _isPickingAudio || _isPreparingNext;

  static const _rawExts = {'nef', 'cr2', 'cr3', 'arw', 'dng', 'raw', 'raf', 'orf', 'rw2', 'pef', 'srw'};

  Future<void> _pick() async {
    if (_isBusy) return;
    setState(() { _isPickingImages = true; _busyMessage = 'Opening gallery...'; });

    if (_images.length >= ApiConfig.maxImageCount) {
      Fluttertoast.showToast(msg: 'Maximum ${ApiConfig.maxImageCount} photos allowed.', backgroundColor: AppTheme.warning);
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
    for (final xFile in pickedFiles) {
      if (_images.length + added.length >= ApiConfig.maxImageCount) break;
      final file = File(xFile.path);
      final sizeMB = await file.length() / (1024 * 1024);
      if (sizeMB <= ApiConfig.maxImageSizeMB && !_images.any((f) => f.path == file.path)) {
        added.add(file);
      }
    }

    if (added.isNotEmpty) {
      setState(() => _images = [..._images, ...added]);
      context.read<TripProvider>().setImages(_images);
    }
    setState(() { _isPickingImages = false; _busyMessage = ''; });
  }

  void _removeImage(int index) {
    setState(() => _images.removeAt(index));
    context.read<TripProvider>().setImages(_images);
  }

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
    setState(() { _isPickingAudio = true; _busyMessage = 'Selecting score...'; });
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.audio);
      if (result != null && result.files.isNotEmpty) {
        final path = result.files.first.path;
        if (path != null) setState(() => _selectedAudio = File(path));
      }
    } finally {
      setState(() { _isPickingAudio = false; _busyMessage = ''; });
    }
  }

  Future<void> _proceed() async {
    if (_isBusy) return;
    if (_images.isEmpty) {
      Fluttertoast.showToast(msg: 'Please select at least one photo.', backgroundColor: AppTheme.warning);
      return;
    }

    setState(() { _isPreparingNext = true; _busyMessage = 'Initializing Cinematic Engine...'; });
    final trip = context.read<TripProvider>().currentTrip;
    final destination = (trip?.destination ?? widget.initialDestination ?? 'Travel').trim();

    context.read<VideoGenerationProvider>().startCinematicGeneration(
      imagePaths: _images.map((e) => e.path).toList(),
      destination: destination,
      theme: _selectedStyle,
      audioPath: _selectedAudio?.path,
    );
    
    setState(() { _isPreparingNext = false; _busyMessage = ''; });
    Navigator.popUntil(context, ModalRoute.withName(AppRoutes.home));
    Fluttertoast.showToast(msg: 'Processing in background...', backgroundColor: AppTheme.primary);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cinematic Studio'),
        actions: [
          if (_images.length > 1)
            IconButton(
              icon: Icon(_isReordering ? Icons.check_circle : Icons.auto_awesome_motion),
              color: _isReordering ? AppTheme.success : null,
              onPressed: () => setState(() => _isReordering = !_isReordering),
            ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // ── Top Styling Section ──
              _StyleSelector(
                selected: _selectedStyle,
                styles: _styles,
                onChange: (s) => setState(() => _selectedStyle = s),
              ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1),

              // ── Photo grid / empty state ──
              Expanded(
                child: _images.isEmpty
                    ? _EmptyPlaceholder(onTap: _pick)
                    : _isReordering ? _buildReorderGrid() : _buildStaticGrid(),
              ),

              // ── Bottom Panel ──
              _BottomSuite(
                imageCount: _images.length,
                audioName: _selectedAudio?.path.split('/').last,
                onPickImages: _pick,
                onPickAudio: _pickAudio,
                onProceed: _proceed,
                isBusy: _isBusy,
              ).animate().fadeIn(delay: 200.ms),
            ],
          ),
          if (_isBusy) TBLoadingOverlay(message: _busyMessage),
        ],
      ),
    );
  }

  Widget _buildStaticGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, crossAxisSpacing: 12, mainAxisSpacing: 12,
      ),
      itemCount: _images.length + 1,
      itemBuilder: (_, i) {
        if (i == _images.length) return _AddButton(onTap: _pick);
        return _ImageItem(
          file: _images[i],
          index: i,
          isRaw: _rawExts.contains(_images[i].path.split('.').last.toLowerCase()),
          onRemove: () => _removeImage(i),
        ).animate().scale(delay: (i * 30).ms);
      },
    );
  }

  Widget _buildReorderGrid() {
    return ReorderableGridView.count(
      crossAxisCount: 3, crossAxisSpacing: 12, mainAxisSpacing: 12,
      padding: const EdgeInsets.all(20),
      onReorder: _onReorder,
      children: List.generate(_images.length, (i) => _ImageItem(
        key: ValueKey(_images[i].path),
        file: _images[i],
        index: i,
        isRaw: _rawExts.contains(_images[i].path.split('.').last.toLowerCase()),
        onRemove: () => _removeImage(i),
      )),
    );
  }
}

class _StyleSelector extends StatelessWidget {
  final String selected;
  final Map<String, dynamic> styles;
  final Function(String) onChange;
  const _StyleSelector({required this.selected, required this.styles, required this.onChange});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      color: Colors.white,
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: styles.entries.map((e) {
                final isSel = e.key == selected;
                return GestureDetector(
                  onTap: () => onChange(e.key),
                  child: Container(
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSel ? AppTheme.primary : AppTheme.bgLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isSel ? AppTheme.primary : AppTheme.borderLight),
                    ),
                    child: Row(
                      children: [
                        Icon(e.value['icon'], size: 16, color: isSel ? Colors.white : AppTheme.primary),
                        const SizedBox(width: 8),
                        Text(e.key, style: TextStyle(fontWeight: FontWeight.w700, color: isSel ? Colors.white : AppTheme.textPrimary)),
                      ],
                    ),
                  ),
                );
              }).toList().animate().fadeIn(delay: 250.ms).slideX(begin: 0.1),
            ),
          ),
          const SizedBox(height: 8),
          Text(styles[selected]['desc'], style: const TextStyle(fontSize: 11, color: AppTheme.textHint, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _EmptyPlaceholder extends StatelessWidget {
  final VoidCallback onTap;
  const _EmptyPlaceholder({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add_photo_alternate_rounded, size: 80, color: AppTheme.borderLight),
            const SizedBox(height: 16),
            const Text('No content yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const Text('Upload photos to start your cinematic trip', style: TextStyle(color: AppTheme.textHint)),
          ],
        ),
      ),
    );
  }
}

class _ImageItem extends StatelessWidget {
  final File file;
  final int index;
  final bool isRaw;
  final VoidCallback onRemove;
  const _ImageItem({super.key, required this.file, required this.index, required this.isRaw, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: isRaw 
            ? Container(color: AppTheme.primaryDark, child: const Icon(Icons.camera_rounded, color: Colors.white54))
            : Image.file(file, fit: BoxFit.cover, width: double.infinity, height: double.infinity),
        ),
        Positioned(top: -5, right: -5, child: GestureDetector(onTap: onRemove, child: const _BadgeIcon(icon: Icons.close))),
        Positioned(bottom: 6, left: 6, child: _OrderTag(n: index + 1)),
      ],
    );
  }
}

class _BadgeIcon extends StatelessWidget {
  final IconData icon;
  const _BadgeIcon({required this.icon});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
      child: Icon(icon, size: 10, color: Colors.white),
    );
  }
}

class _OrderTag extends StatelessWidget {
  final int n;
  const _OrderTag({required this.n});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: Colors.white70, borderRadius: BorderRadius.circular(4)),
      child: Text('$n', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900)),
    );
  }
}

class _AddButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AddButton({required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(color: AppTheme.bgLight, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.borderLight, style: BorderStyle.none)),
        child: const Icon(Icons.add, color: AppTheme.textHint),
      ),
    );
  }
}

class _BottomSuite extends StatelessWidget {
  final int imageCount;
  final String? audioName;
  final VoidCallback onPickImages;
  final VoidCallback onPickAudio;
  final VoidCallback onProceed;
  final bool isBusy;

  const _BottomSuite({required this.imageCount, this.audioName, required this.onPickImages, required this.onPickAudio, required this.onProceed, required this.isBusy});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(20), blurRadius: 20, offset: const Offset(0, -5))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _ActionTile(
                  label: 'PHOTOS', subtitle: '$imageCount added', 
                  icon: Icons.image_rounded, onTap: onPickImages,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionTile(
                  label: 'SOUNDTRACK', subtitle: audioName ?? 'Standard', 
                  icon: Icons.audiotrack_rounded, onTap: onPickAudio,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          TBPrimaryButton(
            label: 'Process Masterpiece',
            onPressed: isBusy ? null : onProceed,
            icon: Icons.auto_awesome_rounded,
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final String label, subtitle;
  final IconData icon;
  final VoidCallback onTap;
  const _ActionTile({required this.label, required this.subtitle, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppTheme.bgLight, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppTheme.borderLight)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: AppTheme.primary),
            const SizedBox(height: 10),
            Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.textHint, letterSpacing: 0.5)),
            Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class ReorderableGridView extends StatelessWidget {
  final int crossAxisCount;
  final double crossAxisSpacing, mainAxisSpacing;
  final EdgeInsetsGeometry padding;
  final List<Widget> children;
  final void Function(int oldIndex, int newIndex) onReorder;

  const ReorderableGridView.count({super.key, required this.crossAxisCount, required this.crossAxisSpacing, required this.mainAxisSpacing, required this.padding, required this.children, required this.onReorder});

  @override
  Widget build(BuildContext context) {
    return ReorderableListView(
      padding: padding as EdgeInsets? ?? EdgeInsets.zero,
      onReorder: onReorder,
      children: children,
    );
  }
}
