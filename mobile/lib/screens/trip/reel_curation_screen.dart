import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/reel_draft_provider.dart';
import '../../theme/app_theme.dart';
import '../../config/routes.dart';
import '../../services/config_service.dart';

/// STAGE 1 — Curation Wall
/// Shows all analyzed photos grouped by type (Landscapes / Portraits / Details).
/// AI picks are highlighted with a gold star. User toggles selections.
class ReelCurationScreen extends StatefulWidget {
  const ReelCurationScreen({super.key});

  @override
  State<ReelCurationScreen> createState() => _ReelCurationScreenState();
}

class _ReelCurationScreenState extends State<ReelCurationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this); // All + 3 groups
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  void _proceed(BuildContext ctx) {
    final provider = ctx.read<ReelDraftProvider>();
    if (provider.keptCount == 0) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(content: Text('Select at least 1 photo to continue.')),
      );
      return;
    }

    // Build initial ordering and move to storyboard
    provider.advanceToCuration();
    Navigator.pushNamed(ctx, AppRoutes.reelStoryboard);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReelDraftProvider>();

    if (provider.stage == ReelStudioStage.uploading ||
        provider.stage == ReelStudioStage.analyzing ||
        provider.stage == ReelStudioStage.idle) {
      return const _AnalysisWaitScreen();
    }

    if (provider.stage == ReelStudioStage.error) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F0F1A),
        appBar: AppBar(backgroundColor: Colors.transparent),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.redAccent, size: 64),
                const SizedBox(height: 16),
                Text(
                  provider.error ?? 'An unknown error occurred.',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final allPhotos = provider.allPhotos;
    final groups = provider.groups;
    final tabs = ['All', ...groups.keys];

    // Rebuild tab controller if group count changes
    if (_tabCtrl.length != tabs.length) {
      _tabCtrl = TabController(length: tabs.length, vsync: this);
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F1A),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Step 1 · Curation',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
            Text(
              '${provider.keptCount} of ${allPhotos.length} photos selected',
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabCtrl,
          isScrollable: true,
          indicatorColor: const Color(0xFF6366F1),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white38,
          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          tabs: tabs.map((t) => Tab(text: t)).toList(),
        ),
        actions: [
          // AI Picks shortcut
          TextButton.icon(
            icon: const Icon(Icons.auto_awesome, color: Color(0xFFF59E0B), size: 16),
            label: const Text('AI Picks', style: TextStyle(color: Color(0xFFF59E0B), fontSize: 13)),
            onPressed: () {
              context.read<ReelDraftProvider>().selectAllAiPicks();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Selected ${provider.aiPickCount} AI top picks'),
                  backgroundColor: const Color(0xFF6366F1),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // AI insight banner
          _AiInsightBanner(
            total: allPhotos.length,
            aiPicks: provider.aiPickCount,
          ).animate().fadeIn(duration: 400.ms),

          // Photo grid
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                // All Photos tab
                _PhotoGrid(photos: allPhotos),
                // Group tabs
                ...groups.values.map((photos) => _PhotoGrid(photos: photos)),
              ],
            ),
          ),

          // Bottom proceed bar
          _CurationBottomBar(
            keptCount: provider.keptCount,
            total: allPhotos.length,
            onSelectAll: () => context.read<ReelDraftProvider>().selectAll(),
            onProceed: () => _proceed(context),
          ).animate().fadeIn(delay: 300.ms),
        ],
      ),
    );
  }
}

// ── Waiting screen ─────────────────────────────────────────────────────────────

class _AnalysisWaitScreen extends StatefulWidget {
  const _AnalysisWaitScreen();

  @override
  State<_AnalysisWaitScreen> createState() => _AnalysisWaitScreenState();
}

class _AnalysisWaitScreenState extends State<_AnalysisWaitScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  final List<String> _tips = [
    '🔍 Checking sharpness of every photo…',
    '👤 Finding faces and subjects…',
    '🌅 Rating exposure and brightness…',
    '✨ Computing cinematic quality scores…',
    '🗂 Grouping photos by type…',
    '⭐ Selecting AI top picks…',
  ];
  int _tipIdx = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
    // Rotate tips
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 3));
      if (!mounted) return false;
      setState(() => _tipIdx = (_tipIdx + 1) % _tips.length);
      return mounted;
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated scanner
              AnimatedBuilder(
                animation: _ctrl,
                builder: (_, __) => Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      startAngle: 0,
                      endAngle: 6.28,
                      transform: GradientRotation(_ctrl.value * 6.28),
                      colors: const [
                        Color(0xFF6366F1),
                        Color(0xFF8B5CF6),
                        Colors.transparent,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6366F1).withOpacity(0.4),
                        blurRadius: 30,
                      ),
                    ],
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: CircleAvatar(
                      backgroundColor: Color(0xFF0F0F1A),
                      child: Icon(Icons.image_search_rounded, color: Colors.white70, size: 40),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'AI is Scanning Your Photos',
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 600),
                child: Text(
                  _tips[_tipIdx],
                  key: ValueKey(_tipIdx),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Photo grid ─────────────────────────────────────────────────────────────────

class _PhotoGrid extends StatelessWidget {
  final List<CuratedPhoto> photos;
  const _PhotoGrid({required this.photos});

  @override
  Widget build(BuildContext context) {
    if (photos.isEmpty) {
      return const Center(
        child: Text('No photos in this group', style: TextStyle(color: Colors.white38)),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: photos.length,
      itemBuilder: (_, i) {
        final photo = photos[i];
        return _PhotoCell(photo: photo);
      },
    );
  }
}

class _PhotoCell extends StatelessWidget {
  final CuratedPhoto photo;
  const _PhotoCell({required this.photo});

  Widget _buildPhotoThumb(String path) {
    final String fullUrl = path.startsWith('http') 
        ? path 
        : '${ConfigService().backendUrl}${path.startsWith('/') ? '' : '/'}$path';

    // Traits visual mapping
    final Color baseColor;
    final IconData mainIcon;
    final String mainLabel;

    if (photo.goldenHour > 0.4) {
      baseColor = const Color(0xFFF59E0B);
      mainIcon = Icons.wb_sunny_rounded;
      mainLabel = '🌅 Golden';
    } else if (photo.skyPresence > 0.5) {
      baseColor = const Color(0xFF0EA5E9);
      mainIcon = Icons.landscape_rounded;
      mainLabel = '🌤 Sky';
    } else if (photo.faceCount >= 2) {
      baseColor = const Color(0xFF8B5CF6);
      mainIcon = Icons.group_rounded;
      mainLabel = '👥 Group';
    } else if (photo.faceScore > 2.0) {
      baseColor = const Color(0xFFEC4899);
      mainIcon = Icons.face_rounded;
      mainLabel = '👤 Portrait';
    } else if (photo.colorVibrancy > 0.5) {
      baseColor = const Color(0xFF10B981);
      mainIcon = Icons.palette_rounded;
      mainLabel = '🎨 Vibrant';
    } else if (photo.shotType == 'detail') {
      baseColor = const Color(0xFFF59E0B);
      mainIcon = Icons.zoom_in_rounded;
      mainLabel = '🔍 Detail';
    } else {
      baseColor = const Color(0xFF6366F1);
      mainIcon = Icons.landscape_rounded;
      mainLabel = '📸 Scene';
    }

    return Container(
      color: const Color(0xFF1A1A2E),
      width: double.infinity,
      height: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // THE REAL IMAGE
          Image.network(
            fullUrl,
            fit: BoxFit.cover,
            errorBuilder: (ctx, _, __) => Center(
              child: Icon(mainIcon, color: baseColor.withOpacity(0.5), size: 32),
            ),
            loadingBuilder: (ctx, child, progress) {
              if (progress == null) return child;
              return Center(
                child: CircularProgressIndicator(
                  value: progress.expectedTotalBytes != null
                      ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                      : null,
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(baseColor.withOpacity(0.4)),
                ),
              );
            },
          ),
          
          // Subtle overlay with trait icon for quick ID
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.3),
                  Colors.transparent,
                  Colors.black.withOpacity(0.4),
                ],
              ),
            ),
          ),
          
          // Metadata Overlay
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              Icon(mainIcon, color: Colors.white70, size: 20),
              const SizedBox(height: 2),
              Text(
                mainLabel,
                style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              // Quality score bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: photo.quality,
                    minHeight: 3,
                    backgroundColor: Colors.white12,
                    valueColor: AlwaysStoppedAnimation(baseColor),
                  ),
                ),
              ),
              const SizedBox(height: 4),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReelDraftProvider>();
    // Find the "live" version of this photo from allPhotos
    final live = provider.allPhotos.firstWhere(
      (p) => p.path == photo.path,
      orElse: () => photo,
    );
    final isKept = live.userKept;

    return GestureDetector(
      onTap: () => context.read<ReelDraftProvider>().togglePhotoKept(photo.path),
      onLongPress: () {
        if (photo.aiInsight.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.auto_awesome, color: Color(0xFFF59E0B), size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(photo.aiInsight, style: const TextStyle(fontSize: 12))),
                ],
              ),
              backgroundColor: const Color(0xFF1E1B4B),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isKept ? const Color(0xFF6366F1) : Colors.transparent,
            width: 3,
          ),
        ),
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: isKept ? 1.0 : 0.35,
                child: _buildPhotoThumb(photo.path),
              ),
            ),

            // Dark overlay when not selected
            if (!isKept)
              Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),

            // Check mark
            if (isKept)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(
                    color: Color(0xFF6366F1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 14),
                ),
              ),

            // Badges row at bottom-left
            Positioned(
              bottom: 6,
              left: 4,
              child: Wrap(
                spacing: 3,
                children: [
                  if (photo.aiPick)
                    _BadgeChip(label: '⭐', color: const Color(0xFFF59E0B)),
                  if (photo.isTravelHero)
                    _BadgeChip(label: '🦸', color: const Color(0xFF6366F1)),
                  if (photo.goldenHour > 0.4)
                    _BadgeChip(label: '🌅', color: const Color(0xFFEF4444)),
                  if (photo.faceCount >= 2)
                    _BadgeChip(label: '${photo.faceCount}👤', color: const Color(0xFFEC4899)),
                  if (photo.isDuplicate)
                    _BadgeChip(label: '👯 Similar', color: Colors.grey.shade700),
                ],
              ),
            ),

            // Quality bar at bottom
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 3,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF10B981),
                      const Color(0xFFF59E0B),
                      const Color(0xFFEF4444),
                    ],
                    stops: [photo.quality, photo.quality + 0.01, 1.0],
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(10),
                    bottomRight: Radius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── AI Insight Banner ──────────────────────────────────────────────────────────

class _AiInsightBanner extends StatelessWidget {
  final int total;
  final int aiPicks;
  const _AiInsightBanner({required this.total, required this.aiPicks});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, color: Color(0xFFF59E0B), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 12, color: Colors.white70),
                children: [
                  const TextSpan(text: 'AI found '),
                  TextSpan(
                    text: '$aiPicks top picks ',
                    style: const TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.w700),
                  ),
                  TextSpan(text: 'from $total photos. Tap '),
                  const TextSpan(
                    text: '"AI Picks" ',
                    style: TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.w700),
                  ),
                  const TextSpan(text: 'to auto-select them, or manually choose your favorites.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Badge Chip ─────────────────────────────────────────────────────────────────

class _BadgeChip extends StatelessWidget {
  final String label;
  final Color color;
  const _BadgeChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.9),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.w800),
      ),
    );
  }
}


class _CurationBottomBar extends StatelessWidget {
  final int keptCount;
  final int total;
  final VoidCallback onSelectAll;
  final VoidCallback onProceed;

  const _CurationBottomBar({
    required this.keptCount,
    required this.total,
    required this.onSelectAll,
    required this.onProceed,
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
          // Select all button
          GestureDetector(
            onTap: onSelectAll,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white12),
              ),
              child: const Text(
                'All',
                style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Proceed
          Expanded(
            child: GestureDetector(
              onTap: onProceed,
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withOpacity(0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$keptCount photos',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      '→ Storyboard',
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
