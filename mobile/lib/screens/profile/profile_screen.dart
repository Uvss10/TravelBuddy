import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/trip_provider.dart';
import '../../providers/language_provider.dart';
import '../../config/routes.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../../models/trip_model.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  int _selectedMonth = DateTime.now().month;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final trips = context.watch<TripProvider>().tripHistory;
    final user = auth.user;
    final name = user?.name.split(' ').first ?? 'Traveller';
    final totalDays = trips.fold<int>(0, (s, t) => s + t.days);
    final reelsCount = trips.where((t) => t.videoUrl != null).length;

    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            automaticallyImplyLeading: false,
            backgroundColor: AppTheme.primary,
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.pin,
              background: _PassportHeader(
                name: name,
                email: user?.email ?? '',
                trips: trips.where((t) => t.itineraryOutput != null).length,
                totalDays: totalDays,
                reels: reelsCount,
              ),
            ),
            bottom: TabBar(
              controller: _tabs,
              indicatorColor: AppTheme.accent,
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,
              labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5),
              tabs: const [
                Tab(text: 'PLANS'),
                Tab(text: 'CALENDAR'),
                Tab(text: 'REELS'),
                Tab(text: 'TRACKER'),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabs,
          children: [
            _PlansTab(trips: trips.where((t) => t.itineraryOutput != null).toList()),
            _CalendarTab(trips: trips.where((t) => t.itineraryOutput != null).toList(), selectedMonth: _selectedMonth, onMonthChanged: (m) => setState(() => _selectedMonth = m)),
            _ReelsTab(trips: trips.where((t) => t.videoUrl != null).toList()),
            _TrackerTab(trips: trips, totalDays: totalDays),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// PASSPORT HEADER
// ─────────────────────────────────────────────────────────────
class _PassportHeader extends StatelessWidget {
  final String name, email;
  final int trips, totalDays, reels;
  const _PassportHeader({required this.name, required this.email, required this.trips, required this.totalDays, required this.reels});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primary, AppTheme.primary.withAlpha(200)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  color: AppTheme.accent,
                ),
                child: Center(
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'T',
                    style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5)),
                    Text(email, style: TextStyle(fontSize: 12, color: Colors.white.withAlpha(180), fontWeight: FontWeight.w500)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: AppTheme.accent, borderRadius: BorderRadius.circular(20)),
                      child: const Text('GLOBAL EXPLORER • LVL 3', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white)),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pushNamed(context, AppRoutes.settings),
                icon: const Icon(Icons.settings_outlined, color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _HeaderStat(label: 'EXPEDITIONS', value: '$trips'),
              _vDivider(),
              _HeaderStat(label: 'TRAVEL DAYS', value: '$totalDays'),
              _vDivider(),
              _HeaderStat(label: 'REELS MADE', value: '$reels'),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _vDivider() => Container(width: 1, height: 32, color: Colors.white24);
}

class _HeaderStat extends StatelessWidget {
  final String label, value;
  const _HeaderStat({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -1)),
      Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white.withAlpha(180), letterSpacing: 1)),
    ],
  );
}

// ─────────────────────────────────────────────────────────────
// TAB 1: PLANS — Final Trip Plans with Day-Wise Breakdown
// ─────────────────────────────────────────────────────────────
class _PlansTab extends StatelessWidget {
  final List<TripModel> trips;
  const _PlansTab({required this.trips});

  @override
  Widget build(BuildContext context) {
    if (trips.isEmpty) {
      return const _EmptySection(icon: Icons.map_outlined, message: 'No trips planned yet.\nTap "Plan Expedition" to start!');
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      itemCount: trips.length,
      itemBuilder: (_, i) => _TripPlanCard(trip: trips[i])
          .animate()
          .fadeIn(delay: (i * 80).ms)
          .slideY(begin: 0.1),
    );
  }
}

class _TripPlanCard extends StatelessWidget {
  final TripModel trip;
  const _TripPlanCard({required this.trip});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, AppRoutes.itinerary, arguments: trip),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.borderLight),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 16, offset: const Offset(0, 6))],
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [AppTheme.primary, AppTheme.primary.withAlpha(180)]),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.flag_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 10),
                  Expanded(child: Text(trip.destination, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: AppTheme.accent, borderRadius: BorderRadius.circular(12)),
                    child: Text('${trip.days}D', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white)),
                  ),
                ],
              ),
            ),
            // Day summary chips
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _InfoChip(icon: Icons.wallet_rounded, label: trip.budget),
                      const SizedBox(width: 10),
                      if (trip.interests.isNotEmpty)
                        _InfoChip(icon: Icons.interests_rounded, label: trip.interests.first),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('INTERESTS', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: AppTheme.textHint)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: trip.interests.map((interest) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: AppTheme.primary.withAlpha(15), borderRadius: BorderRadius.circular(20)),
                      child: Text(interest, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.primary)),
                    )).toList(),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.calendar_month_rounded,
                          label: 'View Calendar',
                          onTap: () => Navigator.pushNamed(context, AppRoutes.itinerary, arguments: trip),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.auto_awesome_rounded,
                          label: 'Make Reel',
                          onTap: () => Navigator.pushNamed(context, AppRoutes.photoUpload, arguments: {'destination': trip.destination, 'tone': 'adventurous and inspiring', 'scene_tags': ['travel']}),
                          isPrimary: true,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// TAB 2: CALENDAR — Day-wise trip calendar
// ─────────────────────────────────────────────────────────────
class _CalendarTab extends StatelessWidget {
  final List<TripModel> trips;
  final int selectedMonth;
  final ValueChanged<int> onMonthChanged;
  const _CalendarTab({required this.trips, required this.selectedMonth, required this.onMonthChanged});

  static const _months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];

  @override
  Widget build(BuildContext context) {
    final year = DateTime.now().year;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      children: [
        // Month selector
        SizedBox(
          height: 44,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: 12,
            itemBuilder: (_, i) {
              final isSelected = i + 1 == selectedMonth;
              return GestureDetector(
                onTap: () => onMonthChanged(i + 1),
                child: AnimatedContainer(
                  duration: 200.ms,
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primary : Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: isSelected ? AppTheme.primary : AppTheme.borderLight),
                  ),
                  child: Text(_months[i], style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: isSelected ? Colors.white : AppTheme.textHint)),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),

        if (trips.isEmpty)
          const _EmptySection(icon: Icons.calendar_today_outlined, message: 'Plan a trip to see your\nday-wise calendar here.')
        else
          ...trips.asMap().entries.map((entry) {
            final i = entry.key;
            final trip = entry.value;
            return _DayWiseCard(trip: trip, month: selectedMonth, year: year)
                .animate()
                .fadeIn(delay: (i * 100).ms);
          }),
      ],
    );
  }
}

class _DayWiseCard extends StatelessWidget {
  final TripModel trip;
  final int month, year;
  const _DayWiseCard({required this.trip, required this.month, required this.year});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderLight),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(6), blurRadius: 12)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: AppTheme.bgLight,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                const Icon(Icons.place_rounded, color: AppTheme.primary, size: 16),
                const SizedBox(width: 8),
                Text(trip.destination, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                const Spacer(),
                Text('${trip.days} DAYS', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppTheme.textHint, letterSpacing: 1)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: List.generate(trip.days, (dayIndex) {
                final date = DateTime(year, month, dayIndex + 1);
                final isToday = date.year == DateTime.now().year && date.month == DateTime.now().month && date.day == DateTime.now().day;
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isToday ? AppTheme.primary.withAlpha(15) : AppTheme.bgLight,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isToday ? AppTheme.primary.withAlpha(60) : Colors.transparent),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: isToday ? AppTheme.primary : Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: isToday ? AppTheme.primary : AppTheme.borderLight),
                        ),
                        child: Center(
                          child: Text('${dayIndex + 1}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: isToday ? Colors.white : AppTheme.textPrimary)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Day ${dayIndex + 1}${isToday ? ' — Today' : ''}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: isToday ? AppTheme.primary : AppTheme.textPrimary)),
                            Text('Explore ${trip.destination}', style: const TextStyle(fontSize: 11, color: AppTheme.textHint, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pushNamed(context, AppRoutes.itinerary, arguments: trip),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(color: AppTheme.primary.withAlpha(20), shape: BoxShape.circle),
                          child: const Icon(Icons.chevron_right_rounded, size: 16, color: AppTheme.primary),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// TAB 3: REELS & PHOTOS
// ─────────────────────────────────────────────────────────────
class _ReelsTab extends StatelessWidget {
  final List<TripModel> trips;
  const _ReelsTab({required this.trips});

  static const _sampleThumbs = [
    'https://images.unsplash.com/photo-1548013146-72479768bada?w=400',
    'https://images.unsplash.com/photo-1493246507139-91e8bef99c02?w=400',
    'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=400',
    'https://images.unsplash.com/photo-1476514525535-07fb3b4ae5f1?w=400',
    'https://images.unsplash.com/photo-1469854523086-cc02fe5d8800?w=400',
    'https://images.unsplash.com/photo-1501854140801-50d01698950b?w=400',
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      children: [
        // Achievements row
        const Text('ACHIEVEMENTS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: AppTheme.textHint)),
        const SizedBox(height: 12),
        SizedBox(
          height: 96,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _AchievementBadge(icon: Icons.movie_filter_rounded, label: 'First Reel', unlocked: trips.any((t) => t.storyTitle != null)),
              _AchievementBadge(icon: Icons.photo_library_rounded, label: '10+ Photos', unlocked: true),
              _AchievementBadge(icon: Icons.explore_rounded, label: 'World Scout', unlocked: trips.length >= 3),
              _AchievementBadge(icon: Icons.landscape_rounded, label: 'Mountain Fan', unlocked: false),
              _AchievementBadge(icon: Icons.beach_access_rounded, label: 'Beach Lover', unlocked: false),
            ],
          ),
        ),
        const SizedBox(height: 28),

        // Reels section
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('MY REELS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: AppTheme.textHint)),
            TextButton.icon(
              onPressed: () => Navigator.pushNamed(context, AppRoutes.photoUpload, arguments: {'destination': '', 'tone': 'adventurous and inspiring', 'scene_tags': ['travel']}),
              icon: const Icon(Icons.add, size: 14, color: AppTheme.primary),
              label: const Text('CREATE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.primary)),
            ),
          ],
        ),
        if (trips.isEmpty)
          const _EmptySection(icon: Icons.movie_filter_rounded, message: 'No reels yet.\nCreate one from your plans or gallery!')
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.75),
            itemCount: trips.length,
            itemBuilder: (_, i) {
              final trip = trips[i];
              // Use first image if available, else placeholder
              final thumbUrl = (trip.selectedImagePaths.isNotEmpty) 
                  ? trip.selectedImagePaths.first 
                  : 'https://images.unsplash.com/photo-1548013146-72479768bada?w=400';
              
              return GestureDetector(
                onTap: () => Navigator.pushNamed(context, AppRoutes.reelPreview, arguments: trip.videoUrl),
                onLongPress: () => _showDeleteDialog(context, trip),
                child: _ReelThumbnail(url: thumbUrl, label: trip.destination)
                    .animate().fadeIn(delay: (i * 60).ms).scale(begin: const Offset(0.95, 0.95)),
              );
            },
          ),
      ],
    );
  }

  void _showDeleteDialog(BuildContext context, TripModel trip) {
    final s = context.read<LanguageProvider>().strings;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.deleteReel),
        content: Text('${s.deleteReel} "${trip.destination}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(s.later)),
          TextButton(
            onPressed: () {
              context.read<TripProvider>().removeTrip(trip.id);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.success)));
            },
            child: Text(s.deleteReel, style: const TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
  }
}

class _AchievementBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool unlocked;
  const _AchievementBadge({required this.icon, required this.label, required this.unlocked});

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: unlocked ? 1.0 : 0.4,
    child: Container(
      width: 72,
      margin: const EdgeInsets.only(right: 12),
      child: Column(
        children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: unlocked ? AppTheme.accent.withAlpha(25) : AppTheme.bgLight,
              shape: BoxShape.circle,
              border: Border.all(color: unlocked ? AppTheme.accent : AppTheme.borderLight, width: 2),
            ),
            child: Icon(icon, color: unlocked ? AppTheme.accent : AppTheme.textHint, size: 22),
          ),
          const SizedBox(height: 6),
          Text(label, textAlign: TextAlign.center, maxLines: 2, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppTheme.textHint)),
        ],
      ),
    ),
  );
}

class _ReelThumbnail extends StatelessWidget {
  final String url, label;
  const _ReelThumbnail({required this.url, required this.label});

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(20),
    child: Stack(
      fit: StackFit.expand,
      children: [
        Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: AppTheme.bgLight, child: const Icon(Icons.image_outlined, color: AppTheme.textHint))),
        Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black.withAlpha(180), Colors.transparent]))),
        Positioned(
          bottom: 12, left: 12, right: 12,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.play_circle_filled_rounded, color: Colors.white, size: 28),
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────
// TAB 4: TRACKER
// ─────────────────────────────────────────────────────────────
class _TrackerTab extends StatelessWidget {
  final List<TripModel> trips;
  final int totalDays;
  const _TrackerTab({required this.trips, required this.totalDays});

  @override
  Widget build(BuildContext context) {
    final xp = trips.length * 150 + totalDays * 20;
    final nextLevelXp = 1000;
    final progress = (xp / nextLevelXp).clamp(0.0, 1.0);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      children: [
        // XP / Level card
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [AppTheme.primary, AppTheme.accent], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [BoxShadow(color: AppTheme.primary.withAlpha(60), blurRadius: 20, offset: const Offset(0, 8))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('EXPLORER LEVEL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2, color: Colors.white70)),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Level ${(xp / 300).floor() + 1}', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -1)),
                  const SizedBox(width: 12),
                  Padding(padding: const EdgeInsets.only(bottom: 6), child: Text('$xp XP', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white70))),
                ],
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 10,
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation(Colors.white),
                ),
              ),
              const SizedBox(height: 8),
              Text('${((1 - progress) * nextLevelXp).round()} XP to next level', style: const TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w600)),
            ],
          ),
        ).animate().fadeIn().slideY(begin: 0.1),
        const SizedBox(height: 28),

        // Stats grid
        const Text('EXPEDITION STATS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: AppTheme.textHint)),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.4,
          children: [
            _StatTile(icon: Icons.map_rounded, label: 'Plans Saved', value: '${trips.where((t) => t.itineraryOutput != null).length}', color: AppTheme.primary),
            _StatTile(icon: Icons.today_rounded, label: 'Travel Days', value: '$totalDays', color: AppTheme.accent),
            _StatTile(icon: Icons.movie_rounded, label: 'Reels Created', value: '${trips.where((t) => t.videoUrl != null).length}', color: const Color(0xFF7C3AED)),
            _StatTile(icon: Icons.photo_rounded, label: 'Memories', value: '${trips.length * 12}', color: const Color(0xFF059669)),
          ],
        ).animate().fadeIn(delay: 100.ms),
        const SizedBox(height: 28),

        // Streak
        const Text('ACTIVITY STREAK', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: AppTheme.textHint)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppTheme.borderLight)),
          child: Row(
            children: List.generate(7, (i) {
              final active = i < 4;
              return Expanded(
                child: Column(
                  children: [
                    Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: active ? AppTheme.accent : AppTheme.bgLight,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(active ? Icons.local_fire_department_rounded : Icons.circle_outlined, size: 16, color: active ? Colors.white : AppTheme.borderLight),
                    ),
                    const SizedBox(height: 4),
                    Text(['M','T','W','T','F','S','S'][i], style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: active ? AppTheme.accent : AppTheme.textHint)),
                  ],
                ),
              );
            }),
          ),
        ).animate().fadeIn(delay: 200.ms),
        const SizedBox(height: 28),

        // Sign out
        OutlinedButton.icon(
          onPressed: () async {
            await context.read<AuthProvider>().logout();
            if (context.mounted) Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (_) => false);
          },
          icon: const Icon(Icons.logout_rounded, color: AppTheme.error),
          label: const Text('Sign Out', style: TextStyle(color: AppTheme.error, fontWeight: FontWeight.w700)),
          style: OutlinedButton.styleFrom(side: const BorderSide(color: AppTheme.error), padding: const EdgeInsets.all(16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  const _StatTile({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppTheme.borderLight)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withAlpha(20), shape: BoxShape.circle), child: Icon(icon, color: color, size: 18)),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: color, letterSpacing: -1)),
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.textHint)),
        ]),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────
// SHARED HELPERS
// ─────────────────────────────────────────────────────────────
class _EmptySection extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptySection({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 60),
    child: Column(children: [
      Icon(icon, size: 56, color: AppTheme.borderLight),
      const SizedBox(height: 16),
      Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textHint, fontWeight: FontWeight.w500, height: 1.6)),
    ]),
  );
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(color: AppTheme.bgLight, borderRadius: BorderRadius.circular(20)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: AppTheme.textHint),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textHint)),
    ]),
  );
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;
  const _ActionButton({required this.icon, required this.label, required this.onTap, this.isPrimary = false});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: isPrimary ? AppTheme.primary : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isPrimary ? AppTheme.primary : AppTheme.borderLight),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 14, color: isPrimary ? Colors.white : AppTheme.primary),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: isPrimary ? Colors.white : AppTheme.primary)),
      ]),
    ),
  );
}
