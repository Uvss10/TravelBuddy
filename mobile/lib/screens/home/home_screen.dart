import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/trip_provider.dart';
import '../../config/routes.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../../models/trip_model.dart';

/// Home dashboard — shows greeting, Create Trip CTA, and previous trips.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isRefreshing = false;

  Future<void> _onRefresh() async {
    setState(() => _isRefreshing = true);
    await Future.delayed(const Duration(seconds: 1));
    setState(() => _isRefreshing = false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final trips = context.watch<TripProvider>().tripHistory;
    final userName = auth.user?.name.split(' ').first ?? 'Traveller';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('TravelBuddy'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => Navigator.pushNamed(context, AppRoutes.profile),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.pushNamed(context, AppRoutes.settings),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        color: AppTheme.primary,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Greeting
            Text(
              'Hello, $userName 👋',
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: 4),
            Text(
              'Where are you heading next?',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 28),

            // Create Trip card
            _CreateTripCard(
              onTap: () => Navigator.pushNamed(context, AppRoutes.createTrip),
            ),
            const SizedBox(height: 32),

            // Previous trips
            TBSectionHeader(
              title: 'Previous Trips',
              action: trips.isNotEmpty ? 'See all' : null,
            ),
            const SizedBox(height: 16),

            if (trips.isEmpty)
              TBEmptyState(
                icon: Icons.luggage_outlined,
                title: 'No trips yet',
                subtitle: 'Create your first AI-powered trip plan above.',
                actionLabel: 'Plan a Trip',
                onAction: () => Navigator.pushNamed(context, AppRoutes.createTrip),
              )
            else
              ...trips.map((t) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _TripHistoryCard(trip: t),
                  )),
          ],
        ),
      ),
    );
  }
}

// ─── Create trip hero card ────────────────────────────────────────────────────
class _CreateTripCard extends StatelessWidget {
  final VoidCallback onTap;
  const _CreateTripCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.primary,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Plan a New Trip',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'AI itinerary, photo curation\n& reel generation — all in one.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white60,
                        ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Get Started →',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.travel_explore, size: 64, color: Colors.white24),
          ],
        ),
      ),
    );
  }
}

// ─── Trip history card ────────────────────────────────────────────────────────
class _TripHistoryCard extends StatelessWidget {
  final TripModel trip;
  const _TripHistoryCard({required this.trip});

  @override
  Widget build(BuildContext context) {
    return TBCard(
      onTap: () => Navigator.pushNamed(context, AppRoutes.itinerary, arguments: trip),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppTheme.bgLight,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.place_outlined, color: AppTheme.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trip.destination,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 2),
                Text(
                  '${trip.days} days · ${trip.budget}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppTheme.textHint),
        ],
      ),
    );
  }
}
