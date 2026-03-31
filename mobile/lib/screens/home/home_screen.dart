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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
    // Keep scrollable CTAs above the floating nav + gesture/home indicator area.
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
      extendBody: true, // Needed for floating nav bar
      bottomNavigationBar: AnimatedCompassNav(
        currentIndex: _bottomNavIndex,
        onTap: (index) {
          setState(() {
            _bottomNavIndex = index;
            if (index == 0 || index == 1) {
              _tabController.animateTo(index);
            }
          });
        },
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // --- Dynamic Professional Header ---
            AnimatedContainer(
              duration: const Duration(seconds: 1),
              padding: const EdgeInsets.fromLTRB(24, 40, 24, 32),
              decoration: BoxDecoration(
                gradient: isNight ? AppTheme.darkGradient : AppTheme.primaryGradient,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(36),
                  bottomRight: Radius.circular(36),
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isNight ? AppTheme.darkBgColor : AppTheme.primaryColor).withAlpha(60),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  )
                ],
              ),
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
                        const SizedBox(height: 4),
                        const Text(
                          'Your Next Expedition',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                            color: Colors.white,
                          ),
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
            
            const SizedBox(height: 10),

            Expanded(
              child: RefreshIndicator(
                onRefresh: _onRefresh,
                color: AppTheme.accentColor,
                child: TabBarView(
                  controller: _tabController,
                  physics: const NeverScrollableScrollPhysics(), // Managed by bottom nav
                  children: [
                    _buildReelTab().animate().fade(duration: 400.ms),
                    _buildTripTab(trips).animate().fade(duration: 400.ms),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReelTab() {
    return ListView(
      padding: EdgeInsets.fromLTRB(20, 20, 20, _contentBottomInset(context)),
      children: [
        // --- Professional Studio Header ---
        const Text(
          'CINEMA STUDIO',
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2.0, color: AppTheme.primary),
        ).animate().fadeIn(),
        const SizedBox(height: 8),
        const Text(
          'Create a Masterpiece',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.5),
        ).animate().fadeIn(delay: 100.ms),
        const SizedBox(height: 24),
        const SizedBox(height: 24),

        // Input Section
        Text(
          'Where are you traveling?',
          style: Theme.of(context).textTheme.titleLarge,
        )
            .animate()
            .fadeIn(duration: 600.ms, delay: 100.ms),
        const SizedBox(height: 12),
        TextField(
          controller: _reelDestinationController,
          decoration: InputDecoration(
            hintText: 'e.g. Jaipur, Paris, Tokyo',
            prefixIcon: const Icon(Icons.location_on),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        )
            .animate()
            .fadeIn(duration: 600.ms, delay: 150.ms),
        const SizedBox(height: 24),

        // Directing Style Selection
        const Text(
          'Directing Style',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.5),
        )
            .animate()
            .fadeIn(duration: 600.ms, delay: 200.ms),
        const SizedBox(height: 12),
        SizedBox(
          height: 100,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _stylePreset(context, Icons.movie_filter_rounded, 'Cinematic', 'Wide anamorphic look', _selectedTone == 'adventurous and inspiring', () => setState(() => _selectedTone = 'adventurous and inspiring')),
              _stylePreset(context, Icons.camera_roll_rounded, 'Vintage', '35mm grain & warmth', _selectedTone == 'emotional and nostalgic', () => setState(() => _selectedTone = 'emotional and nostalgic')),
              _stylePreset(context, Icons.auto_awesome_rounded, 'Vibrant', 'Pop colors & energy', _selectedTone == 'funny and light-hearted', () => setState(() => _selectedTone = 'funny and light-hearted')),
              _stylePreset(context, Icons.eco_rounded, 'Documentary', 'Natural & authentic', _selectedTone == 'dreamy and peaceful', () => setState(() => _selectedTone = 'dreamy and peaceful')),
            ],
          ).animate().fadeIn(delay: 250.ms).slideX(begin: 0.1),
        ),
        const SizedBox(height: 24),

        // Upload Section
        Text(
          'Upload Photos',
          style: Theme.of(context).textTheme.titleLarge,
        )
            .animate()
            .fadeIn(duration: 600.ms, delay: 300.ms),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _startReelFlow,
          child: GlassCard(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withAlpha(25),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.cloud_upload,
                    size: 48,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Drag or tap to upload',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Max 100 photos · 50 MB each',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        )
            .animate()
            .fadeIn(duration: 600.ms, delay: 350.ms),
        const SizedBox(height: 24),

        // Generate Button
        PremiumButton(
          label: 'Generate Amazing Reel ✨',
          onPressed: _startReelFlow,
        )
            .animate()
            .fadeIn(duration: 600.ms, delay: 400.ms),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildTripTab(List<TripModel> trips) {
    return ListView(
      padding: EdgeInsets.fromLTRB(20, 20, 20, _contentBottomInset(context)),
      children: [
        // --- Explorer Dashboard Stats ---
        Row(
          children: [
            Expanded(child: _HubStatCard(label: 'Expeditions', value: '${trips.length}', icon: Icons.map_rounded, color: AppTheme.primary)),
            const SizedBox(width: 16),
            Expanded(child: _HubStatCard(label: 'Total Reels', value: '4', icon: Icons.auto_awesome_motion_rounded, color: AppTheme.accent)),
          ],
        ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1),
        const SizedBox(height: 32),

        // --- Quick Operations ---
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
                onTap: () {},
              ),
            ),
          ],
        ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1),
        const SizedBox(height: 32),

        // --- Recent Expeditions ---
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

  Widget _stylePreset(
    BuildContext context,
    IconData icon,
    String label,
    String sub,
    bool selected,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppTheme.primaryColor : AppTheme.borderColor),
          boxShadow: selected ? [BoxShadow(color: AppTheme.primaryColor.withAlpha(50), blurRadius: 10, offset: const Offset(0, 4))] : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: selected ? Colors.white : AppTheme.primaryColor),
            const Spacer(),
            Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: selected ? Colors.white : AppTheme.textPrimary)),
            Text(sub, style: TextStyle(fontSize: 9, color: selected ? Colors.white70 : AppTheme.textHint, fontWeight: FontWeight.w500)),
          ],
        ),
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
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.borderLight),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withAlpha(20), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -1)),
              Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textHint, fontWeight: FontWeight.w800)),
            ],
          ),
        ],
      ),
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
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppTheme.borderLight),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 15, offset: const Offset(0, 8))],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(trip.destination.toUpperCase(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.calendar_today_rounded, size: 12, color: AppTheme.textHint),
                          const SizedBox(width: 6),
                          Text('${trip.days} DAYS EXPEDITION', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.textHint)),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: AppTheme.primary.withAlpha(20), borderRadius: BorderRadius.circular(12)),
                  child: Text(trip.budget.toUpperCase(), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppTheme.primary)),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(height: 1),
            const SizedBox(height: 20),
            Row(
              children: [
                const Icon(Icons.auto_awesome_rounded, size: 16, color: AppTheme.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    trip.interests.join(' • '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.borderLight),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
