import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/trip_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/trip_model.dart';
import '../../widgets/ticket_card.dart';
import '../../widgets/animated_compass_nav.dart';
import '../../config/routes.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/custom_widgets.dart';
import '../profile/profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _reelDestinationController = TextEditingController();
  String _selectedTone = 'adventurous and inspiring';
  int _bottomNavIndex = 0;
  String _currentCity = 'Locating...';
  double? _lat;
  double? _lon;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadCurrentCity();
  }

  Future<void> _loadCurrentCity() async {
    try {
      final uri = Uri.parse('http://ip-api.com/json/?fields=city,regionName');
      final httpClient = HttpClient();
      httpClient.connectionTimeout = const Duration(seconds: 4);
      final request = await httpClient.getUrl(uri);
      final response = await request.close();
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final data = jsonDecode(body) as Map<String, dynamic>;
        final city = data['city'] ?? '';
        final region = data['regionName'] ?? '';
        final lat = data['lat']?.toDouble();
        final lon = data['lon']?.toDouble();
        if (city.isNotEmpty) {
          setState(() {
            _currentCity = '$city, $region';
            _lat = lat;
            _lon = lon;
          });
          return;
        }
      }
      setState(() => _currentCity = 'Your World');
    } catch (_) {
      setState(() => _currentCity = 'Your World');
    }
  }

  Future<String?> _httpGet(Uri uri) async {
    return null; // unused, kept for compat
  }

  @override
  void dispose() {
    _reelDestinationController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    await Future.delayed(const Duration(seconds: 1));
  }

  double _contentBottomInset(BuildContext context) {
    return MediaQuery.of(context).padding.bottom + 116;
  }

  void _startReelFlow() {
    final destination = _reelDestinationController.text.trim();
    if (destination.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a destination to start reel generation.')),
      );
      return;
    }

    Navigator.pushNamed(
      context,
      AppRoutes.photoUpload,
      arguments: {
        'destination': destination,
        'scene_tags': ['travel', 'landscape'],
        'tone': _selectedTone,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final trips = context.watch<TripProvider>().tripHistory;
    final userName = auth.user?.name.split(' ').first ?? 'Traveller';
    final currentHour = DateTime.now().hour;
    final isNight = currentHour >= 18 || currentHour <= 5;

    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      extendBody: true,
      bottomNavigationBar: AnimatedCompassNav(
        currentIndex: _bottomNavIndex,
        onTap: (index) {
          setState(() {
            _bottomNavIndex = index;
            _tabController.animateTo(index);
          });
        },
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // --- Dynamic Professional Header (Dashboard Only) ---
            AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOutExpo,
              height: _bottomNavIndex == 0 ? null : 0,
              padding: _bottomNavIndex == 0 
                  ? const EdgeInsets.fromLTRB(24, 40, 24, 32)
                  : EdgeInsets.zero,
              decoration: BoxDecoration(
                gradient: isNight ? AppTheme.darkGradient : AppTheme.primaryGradient,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(36),
                  bottomRight: Radius.circular(36),
                ),
                boxShadow: _bottomNavIndex == 0 ? [
                  BoxShadow(
                    color: (isNight ? AppTheme.darkBgColor : AppTheme.primaryColor).withAlpha(60),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  )
                ] : [],
              ),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: _bottomNavIndex == 0 ? 1.0 : 0.0,
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'WELCOME BACK, ${userName.toUpperCase()}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 2.0,
                                color: Colors.white.withAlpha(180),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Icon(Icons.location_on, color: Colors.white.withAlpha(200), size: 16),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    _currentCity,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.3,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pushNamed(context, AppRoutes.settings),
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(40),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withAlpha(60)),
                          ),
                          child: const Center(
                            child: Icon(Icons.person_outline_rounded, color: Colors.white, size: 24),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 10),

            Expanded(
              child: RefreshIndicator(
                onRefresh: _onRefresh,
                color: AppTheme.accentColor,
                child: TabBarView(
                  controller: _tabController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildDashboardTab(userName, trips).animate().fade(),
                    _buildTripTab(trips).animate().fade(),
                    _buildReelTab().animate().fade(),
                    const ProfileScreen(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardTab(String name, List<TripModel> trips) {
    return ListView(
      padding: EdgeInsets.fromLTRB(20, 10, 20, _contentBottomInset(context)),
      children: [
        const Text('YOUR NEXT MOVES', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: AppTheme.textHint)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: FeatureCard(icon: Icons.explore_rounded, title: 'Discovery', description: 'Find new spots', onTap: () => Navigator.pushNamed(context, AppRoutes.discovery, arguments: {'location': _currentCity, 'lat': _lat, 'lon': _lon}))),
            const SizedBox(width: 12),
            Expanded(child: FeatureCard(icon: Icons.history_rounded, title: 'Recents', description: 'Last adventure', onTap: () => _tabController.animateTo(1))),
          ],
        ),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('MY REELS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: AppTheme.textHint)),
            TextButton(onPressed: () => _tabController.animateTo(2), child: const Text('STUDIO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.primary))),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 140,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _buildMemoryThumb('https://images.unsplash.com/photo-1548013146-72479768bada?w=800'),
              _buildMemoryThumb('https://images.unsplash.com/photo-1493246507139-91e8bef99c02?w=800'),
              _buildMemoryThumb('https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=800'),
            ],
          ),
        ),
        const SizedBox(height: 32),
        const Text('EXPEDITION TRACKER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: AppTheme.textHint)),
        const SizedBox(height: 12),
        const _TrackerCard(),
      ],
    );
  }

  Widget _buildTripTab(List<TripModel> trips) {
    return ListView(
      padding: EdgeInsets.fromLTRB(20, 20, 20, _contentBottomInset(context)),
      children: [
        Row(
          children: [
            Expanded(child: _HubStatCard(label: 'Expeditions', value: '${trips.length}', icon: Icons.map_rounded, color: AppTheme.primary)),
            const SizedBox(width: 16),
            Expanded(child: _HubStatCard(label: 'Total Reels', value: '4', icon: Icons.auto_awesome_motion_rounded, color: AppTheme.accent)),
          ],
        ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1),
        const SizedBox(height: 32),
        const Text('OPERATIONS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: AppTheme.textHint)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FeatureCard(
                icon: Icons.electric_bolt_rounded,
                title: 'Plan Expedition',
                description: 'Tailored AI Plan',
                onTap: () => Navigator.pushNamed(context, AppRoutes.createTrip),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FeatureCard(
                icon: Icons.public_rounded,
                title: 'Global Explorer',
                description: 'Discover Spots',
                onTap: () => Navigator.pushNamed(context, AppRoutes.discovery, arguments: {'location': _currentCity, 'lat': _lat, 'lon': _lon}),
              ),
            ),
          ],
        ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('RECENT EXPEDITIONS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: AppTheme.textHint)),
            TextButton(onPressed: () {}, child: const Text('VIEW ALL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.primary))),
          ],
        ).animate().fadeIn(delay: 300.ms),
        const SizedBox(height: 8),
        if (trips.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 40),
            child: Center(
              child: Text('Your world adventures begin here.', style: TextStyle(color: AppTheme.textHint, fontWeight: FontWeight.w500)),
            ),
          )
        else
          ...trips.take(5).toList().asMap().entries.map((e) {
            final trip = e.value;
            return _PassportTripCard(trip: trip)
              .animate()
              .fadeIn(delay: (400 + (e.key * 100)).ms)
              .slideX(begin: 0.05);
          }),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildReelTab() {
    return ListView(
      padding: EdgeInsets.fromLTRB(20, 10, 20, _contentBottomInset(context)),
      children: [
        Text(
          'CINEMA STUDIO',
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2.0, color: AppTheme.primary),
        ).animate().fadeIn(),
        const SizedBox(height: 8),
        Text(
          'Create a Masterpiece',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.5),
        ).animate().fadeIn(delay: 100.ms),
        const SizedBox(height: 24),
        const Text('Where are you traveling?', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        TBInputField(
          controller: _reelDestinationController,
          hint: 'e.g. Kyoto, Japan',
          icon: Icons.location_on_rounded,
          label: 'Destination',
        ),
        const SizedBox(height: 24),
        const Text('Directing Style', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
        const SizedBox(height: 12),
        SizedBox(
          height: 100,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _stylePreset(context, Icons.movie_filter_rounded, 'Cinematic', 'Anamorphic look', _selectedTone == 'adventurous and inspiring', () => setState(() => _selectedTone = 'adventurous and inspiring')),
              _stylePreset(context, Icons.camera_roll_rounded, 'Vintage', '35mm grain', _selectedTone == 'emotional and nostalgic', () => setState(() => _selectedTone = 'emotional and nostalgic')),
              _stylePreset(context, Icons.auto_awesome_rounded, 'Vibrant', 'Pop colors', _selectedTone == 'funny and light-hearted', () => setState(() => _selectedTone = 'funny and light-hearted')),
              _stylePreset(context, Icons.eco_rounded, 'Documentary', 'Natural look', _selectedTone == 'dreamy and peaceful', () => setState(() => _selectedTone = 'dreamy and peaceful')),
            ],
          ),
        ),
        const SizedBox(height: 24),
        GestureDetector(
          onTap: _startReelFlow,
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: AppTheme.borderLight)),
            child: const Column(children: [Icon(Icons.cloud_upload_rounded, size: 48, color: AppTheme.primary), SizedBox(height: 12), Text('Tap to upload traveler memories', style: TextStyle(fontWeight: FontWeight.w600))]),
          ),
        ),
        const SizedBox(height: 32),
        PremiumButton(label: 'Generate Studio Reel ✨', onPressed: _startReelFlow),
      ],
    );
  }

  Widget _buildUserTab(String name, List<TripModel> trips) {
    return ListView(
      padding: EdgeInsets.fromLTRB(20, 10, 20, _contentBottomInset(context)),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.primary,
            borderRadius: BorderRadius.circular(32),
            gradient: LinearGradient(colors: [AppTheme.primary, AppTheme.primary.withAlpha(200)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          ),
          child: Column(
            children: [
              Row(
                children: [
                   Container(width: 64, height: 64, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2), image: const DecorationImage(image: NetworkImage('https://i.pravatar.cc/150?u=traveler'), fit: BoxFit.cover))),
                   const SizedBox(width: 20),
                   Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)), const Text('GLOBAL EXPLORER • LVL 3', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white70))])),
                   const Icon(Icons.verified_rounded, color: AppTheme.accent, size: 24),
                ],
              ),
              const SizedBox(height: 24),
              const Divider(color: Colors.white24, height: 1),
              const SizedBox(height: 24),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [_ProfileStat(label: 'EXPERIENCE', val: '1.2k XP'), _ProfileStat(label: 'STAMPS', val: '${trips.length}'), _ProfileStat(label: 'JOURNAL', val: '14 DAYS')]),
            ],
          ),
        ),
        const SizedBox(height: 32),
        const Text('ACHIEVEMENTS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: AppTheme.textHint)),
        const SizedBox(height: 12),
        Row(children: [_Badge(icon: Icons.auto_awesome_rounded, label: 'First Reel', active: true), const SizedBox(width: 12), _Badge(icon: Icons.landscape_rounded, label: 'Alp Scout', active: true), const SizedBox(width: 12), _Badge(icon: Icons.forest_rounded, label: 'Rainforest', active: false)]),
        const SizedBox(height: 32),
        const Text('MY EXPEDITION RECORDS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: AppTheme.textHint)),
        const SizedBox(height: 12),
        if (trips.isEmpty) const Center(child: Text('Start an expedition to record history.')) else ...trips.map((t) => _CompactRecordCard(trip: t)),
        const SizedBox(height: 24),
        PremiumButton(label: 'Edit Explorer Profile', onPressed: () {}),
        const SizedBox(height: 48),
      ],
    );
  }

  Widget _buildMemoryThumb(String url) {
    return Container(
      width: 110,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), image: DecorationImage(image: NetworkImage(url), fit: BoxFit.cover), boxShadow: [BoxShadow(color: Colors.black.withAlpha(20), blurRadius: 10, offset: const Offset(0, 4))]),
      child: const Center(child: Icon(Icons.play_circle_outline_rounded, color: Colors.white, size: 32)),
    );
  }

  Widget _stylePreset(BuildContext context, IconData icon, String label, String sub, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: selected ? AppTheme.primaryColor : Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: selected ? AppTheme.primaryColor : AppTheme.borderColor), boxShadow: selected ? [BoxShadow(color: AppTheme.primaryColor.withAlpha(50), blurRadius: 10, offset: const Offset(0, 4))] : null),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, size: 20, color: selected ? Colors.white : AppTheme.primaryColor), const Spacer(), Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: selected ? Colors.white : AppTheme.textPrimary)), Text(sub, style: TextStyle(fontSize: 9, color: selected ? Colors.white70 : AppTheme.textHint, fontWeight: FontWeight.w500))]),
      ),
    );
  }
}

class _HubStatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _HubStatCard({required this.label, required this.value, required this.icon, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: AppTheme.borderLight), boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 20, offset: const Offset(0, 10))]),
      child: Row(children: [Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withAlpha(20), shape: BoxShape.circle), child: Icon(icon, color: color, size: 22)), const SizedBox(width: 12), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -1)), Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textHint, fontWeight: FontWeight.w800))])]),
    );
  }
}

class _PassportTripCard extends StatelessWidget {
  final TripModel trip;
  const _PassportTripCard({required this.trip});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, AppRoutes.itinerary, arguments: trip),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), border: Border.all(color: AppTheme.borderLight), boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 15, offset: const Offset(0, 8))]),
        child: Column(children: [Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(trip.destination.toUpperCase(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.5)), const SizedBox(height: 4), Row(children: [Icon(Icons.calendar_today_rounded, size: 12, color: AppTheme.textHint), const SizedBox(width: 6), Text('${trip.days} DAYS EXPEDITION', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.textHint))])])), Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: AppTheme.primary.withAlpha(20), borderRadius: BorderRadius.circular(12)), child: Text(trip.budget.toUpperCase(), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppTheme.primary)))]), const SizedBox(height: 20), const Divider(height: 1), const SizedBox(height: 20), Row(children: [const Icon(Icons.auto_awesome_rounded, size: 16, color: AppTheme.accent), const SizedBox(width: 8), Expanded(child: Text(trip.interests.join(' • '), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary))), const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.borderLight)])]),
      ),
    );
  }
}

class _TrackerCard extends StatelessWidget {
  const _TrackerCard();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), border: Border.all(color: AppTheme.borderLight), boxShadow: [BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 20)]),
      child: Column(children: [Row(children: [const Icon(Icons.track_changes_rounded, color: AppTheme.primary, size: 20), const SizedBox(width: 12), const Text('Active Discovery', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)), const Spacer(), Text('Step 3 of 5', style: TextStyle(color: AppTheme.textHint, fontSize: 11, fontWeight: FontWeight.w700))]), const SizedBox(height: 20), ClipRRect(borderRadius: BorderRadius.circular(10), child: const LinearProgressIndicator(value: 0.6, minHeight: 8, backgroundColor: AppTheme.bgLight, valueColor: AlwaysStoppedAnimation(AppTheme.primary))), const SizedBox(height: 12), const Text('You have captured 14 memories this month. 6 more to level up!', style: TextStyle(fontSize: 11, color: AppTheme.textHint, fontWeight: FontWeight.w500))]),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  final String label, val;
  const _ProfileStat({required this.label, required this.val});
  @override
  Widget build(BuildContext context) {
    return Column(children: [Text(val, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white)), Text(label, style: TextStyle(fontSize: 8, color: Colors.white.withAlpha(180), fontWeight: FontWeight.w800))]);
  }
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  const _Badge({required this.icon, required this.label, required this.active});
  @override
  Widget build(BuildContext context) {
    return Column(children: [Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: active ? AppTheme.accent.withAlpha(30) : AppTheme.bgLight, shape: BoxShape.circle, border: Border.all(color: active ? AppTheme.accent : AppTheme.borderLight)), child: Icon(icon, color: active ? AppTheme.accent : AppTheme.textHint, size: 24)), const SizedBox(height: 8), Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: active ? AppTheme.textPrimary : AppTheme.textHint))]);
  }
}

class _CompactRecordCard extends StatelessWidget {
  final TripModel trip;
  const _CompactRecordCard({required this.trip});
  @override
  Widget build(BuildContext context) {
    return Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppTheme.borderLight)), child: Row(children: [Container(width: 48, height: 48, decoration: BoxDecoration(color: AppTheme.bgLight, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.landscape_rounded, color: AppTheme.primary)), const SizedBox(width: 16), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(trip.destination, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)), Text('${trip.days} Day Expedition', style: const TextStyle(fontSize: 10, color: AppTheme.textHint, fontWeight: FontWeight.w600))])), const Icon(Icons.chevron_right_rounded, color: AppTheme.borderLight)]));
  }
}
