import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/trip_provider.dart';
import '../../config/routes.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_widgets.dart';
import '../../models/trip_model.dart';
import '../../widgets/animated_compass_nav.dart';
import '../../widgets/ticket_card.dart';

/// Modern home dashboard with beautiful UI
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
            // Dynamic Time-of-Day Hero Header
            AnimatedContainer(
              duration: const Duration(seconds: 1),
              decoration: BoxDecoration(
                gradient: isNight ? AppTheme.darkGradient : AppTheme.primaryGradient,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isNight ? AppTheme.darkBgColor : AppTheme.primaryColor).withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  )
                ]
              ),
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                    ),
                    child: const Icon(Icons.public, color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Where to next, $userName?',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isNight ? 'The stars are waiting.' : 'Adventure calls.',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(context, AppRoutes.settings),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.settings, color: Colors.white, size: 22),
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
        // Hero Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: AppTheme.accentGradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppTheme.accentColor.withAlpha(76),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              const Icon(
                Icons.bolt,
                size: 40,
                color: Colors.white,
              ),
              const SizedBox(height: 12),
              const Text(
                'Turn Photos Into\nCinematic Reels',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'AI picks the best shots & generates narration, captions & hashtags',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: Colors.white.withAlpha(229),
                ),
              ),
            ],
          ),
        )
            .animate()
            .fadeIn(duration: 600.ms)
            .slide(begin: const Offset(0, 0.3)),
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

        // Tone Selection
        Text(
          'Select a Tone',
          style: Theme.of(context).textTheme.titleLarge,
        )
            .animate()
            .fadeIn(duration: 600.ms, delay: 200.ms),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.3,
          children: [
            _toneCard(
              context,
              '🔥 Adventurous',
              'adventurous and inspiring',
              selected: _selectedTone == 'adventurous and inspiring',
              onTap: () => setState(() => _selectedTone = 'adventurous and inspiring'),
            ),
            _toneCard(
              context,
              '🌙 Dreamy',
              'dreamy and peaceful',
              selected: _selectedTone == 'dreamy and peaceful',
              onTap: () => setState(() => _selectedTone = 'dreamy and peaceful'),
            ),
            _toneCard(
              context,
              '😄 Funny',
              'funny and light-hearted',
              selected: _selectedTone == 'funny and light-hearted',
              onTap: () => setState(() => _selectedTone = 'funny and light-hearted'),
            ),
            _toneCard(
              context,
              '💛 Nostalgic',
              'emotional and nostalgic',
              selected: _selectedTone == 'emotional and nostalgic',
              onTap: () => setState(() => _selectedTone = 'emotional and nostalgic'),
            ),
          ]
              .animate(interval: 50.ms)
              .fadeIn(duration: 600.ms, delay: 250.ms)
              .slide(begin: const Offset(0, 0.2)),
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
        // Hero section
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withAlpha(76),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              const Icon(
                Icons.map,
                size: 40,
                color: Colors.white,
              ),
              const SizedBox(height: 12),
              const Text(
                'Your Trips',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Get AI-powered itineraries tailored to your interests',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: Colors.white.withAlpha(229),
                ),
              ),
            ],
          ),
        )
            .animate()
            .fadeIn(duration: 600.ms)
            .slide(begin: const Offset(0, 0.3)),
        const SizedBox(height: 24),

        // Quick sections
        Row(
          children: [
            Expanded(
              child: FeatureCard(
                icon: Icons.electric_bolt,
                title: 'New Itinerary',
                description: 'Personalized plan',
                onTap: () => Navigator.pushNamed(context, AppRoutes.createTrip),
              )
                  .animate()
                  .fadeIn(duration: 600.ms, delay: 100.ms),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FeatureCard(
                icon: Icons.map,
                title: 'Explore Map',
                description: 'See attractions',
                onTap: () {
                  // TODO: Navigate to map
                },
              )
                  .animate()
                  .fadeIn(duration: 600.ms, delay: 150.ms),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Previous trips
        if (trips.isEmpty)
          EmptyState(
            icon: Icons.navigation,
            title: 'No trips yet',
            description: 'Create your first AI-powered trip plan',
            actionLabel: 'Plan a Trip',
            onAction: () => Navigator.pushNamed(context, AppRoutes.createTrip),
          )
        else ...[
          Text(
            'Recent Trips',
            style: Theme.of(context).textTheme.titleLarge,
          )
              .animate()
              .fadeIn(duration: 600.ms, delay: 200.ms),
          const SizedBox(height: 12),
          ...trips.take(5).toList().asMap().entries.map((e) {
            final i = e.key;
            final trip = e.value;
            // Generate a random sample image URL based on destination for demo
            final sampleImg = 'https://source.unsplash.com/800x600/?${Uri.encodeComponent(trip.destination)},travel';
            
            return TicketCard(
              destination: trip.destination,
              title: '${trip.days} Day Adventure',
              date: 'Upcoming', // Would bind to real date
              duration: '${trip.days}d',
              imageUrl: sampleImg,
              onTap: () {
                // TODO: View trip details
              },
            ).animate()
             .fadeIn(duration: 600.ms, delay: Duration(milliseconds: 200 + (i * 100)))
             .slideX(begin: 0.1, end: 0, curve: Curves.easeOutQuad);
          }),
        ],
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _toneCard(
    BuildContext context,
    String label,
    String value, {
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: selected ? AppTheme.primaryColor : AppTheme.borderColor,
            width: selected ? 2.4 : 2,
          ),
          borderRadius: BorderRadius.circular(12),
          color: selected ? AppTheme.primaryColor.withAlpha(18) : AppTheme.surfaceColor,
        ),
        child: Center(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: selected ? AppTheme.primaryColor : null,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
          ),
        ),
      ),
    );
  }
}
