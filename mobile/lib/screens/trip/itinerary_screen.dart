import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../../models/trip_model.dart';
import '../../config/routes.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../../providers/trip_provider.dart';


/// Rich itinerary view with summary metrics + day timeline cards.
/// Includes Mind Map, Budget breakdown, and Tweak field for web parity.
class ItineraryScreen extends StatefulWidget {
  final TripModel? trip;
  const ItineraryScreen({super.key, this.trip});

  @override
  State<ItineraryScreen> createState() => _ItineraryScreenState();
}

class _ItineraryScreenState extends State<ItineraryScreen> {
  final TextEditingController _tweakController = TextEditingController();
  bool _isTweaking = false;
  int _selectedDayIndex = 0;
  String? _distanceKm;

  @override
  void initState() {
    super.initState();
    _loadDistance();
  }

  Future<void> _loadDistance() async {
    try {
      final dest = widget.trip?.destination;
      if (dest == null) return;

      // 1. Get User Location (IP based)
      final userUri = Uri.parse('http://ip-api.com/json/?fields=lat,lon');
      final userResp = await _simpleGet(userUri);
      if (userResp == null) return;
      final userLat = userResp['lat'] as double;
      final userLon = userResp['lon'] as double;

      // 2. Get Destination Location (OSM Nominatim)
      final destUri = Uri.parse('https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(dest)}&format=json&limit=1');
      final destResp = await _simpleGet(destUri, useList: true);
      if (destResp == null) return;
      final destLat = double.tryParse(destResp['lat'] ?? '');
      final destLon = double.tryParse(destResp['lon'] ?? '');

      if (destLat != null && destLon != null) {
        final d = _haversine(userLat, userLon, destLat, destLon);
        if (mounted) setState(() => _distanceKm = d.toStringAsFixed(0));
      }
    } catch (_) {}
  }

  Future<dynamic> _simpleGet(Uri uri, {bool useList = false}) async {
    try {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
      final request = await client.getUrl(uri);
      request.headers.set('User-Agent', 'TravelBuddy/1.0');
      final response = await request.close();
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final data = jsonDecode(body);
        if (useList && data is List && data.isNotEmpty) return data[0];
        return data;
      }
    } catch (_) {}
    return null;
  }

  double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371; // Radius of Earth in KM
    final dLat = (lat2 - lat1) * pi / 180;
    final dLon = (lon2 - lon1) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) * cos(lat2 * pi / 180) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return r * c;
  }

  _ItineraryViewData _buildViewData() {
    final raw = widget.trip?.itineraryOutput;
    if (raw == null || raw.isEmpty) {
      return const _ItineraryViewData(days: [], payload: null);
    }

    String sanitize(String input) {
      final trimmed = input.replaceAll(RegExp(r'```json|```'), '').trim();
      final start = trimmed.indexOf('{');
      final end = trimmed.lastIndexOf('}');
      if (start >= 0 && end >= start) {
        return trimmed.substring(start, end + 1);
      }
      return trimmed;
    }

    try {
      final payload = jsonDecode(sanitize(raw)) as Map<String, dynamic>;
      final days = ItineraryDay.parseFromMap(payload);
      return _ItineraryViewData(days: days, payload: payload);
    } catch (_) {
      return const _ItineraryViewData(days: [], payload: null);
    }
  }

  Future<void> _applyTweak() async {
    if (_tweakController.text.trim().isEmpty) return;
    setState(() => _isTweaking = true);
    // In a real app, this would call the API. For now, mocking simulation.
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() {
        _isTweaking = false;
        _tweakController.clear();
      });
      Fluttertoast.showToast(
        msg: 'Tweak applied! (Simulation)',
        backgroundColor: AppTheme.success,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final view = _buildViewData();
    final summary = (view.payload?['trip_summary'] as Map<String, dynamic>?) ?? const {};
    final budgetData = (view.payload?['budget_breakdown'] as Map<String, dynamic>?) ?? const {};

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.trip?.destination ?? 'Itinerary'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () {}, // Share functionality
          ),
          IconButton(
            icon: const Icon(Icons.bookmark_border_rounded),
            tooltip: 'Save Itinerary',
            onPressed: () {
              context.read<TripProvider>().saveCurrentTrip();
              Fluttertoast.showToast(
                msg: 'Itinerary saved to My Plans! 📍',
                backgroundColor: AppTheme.success,
              );
            },
          ),
        ],
      ),
      body: view.days.isEmpty
          ? const TBEmptyState(
              icon: Icons.event_note_outlined,
              title: 'No itinerary data',
              subtitle: 'The AI could not parse the itinerary. Try generating again.',
            )
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              children: [
                _SummaryHero(trip: widget.trip, summary: summary)
                    .animate().fadeIn(duration: 400.ms).slideY(begin: 0.1),
                const SizedBox(height: 16),
                _MetricsStrip(trip: widget.trip, summary: summary)
                    .animate().fadeIn(delay: 100.ms),
                const SizedBox(height: 24),

                // ── Mind Map Section (Web Parity) ──
                const TBSectionHeader(title: '🧠 Visual Mind Map'),
                const SizedBox(height: 12),
                if (_distanceKm != null)
                  _DistanceBadge(distance: _distanceKm!)
                      .animate().fadeIn().slideX(begin: -0.1),
                const SizedBox(height: 8),
                _MindMapView(days: view.days, destination: widget.trip?.destination ?? 'Trip'),
                const SizedBox(height: 32),

                // ── Day Timeline ──
                const TBSectionHeader(title: '🗺️ Day-wise Journey'),
                const SizedBox(height: 12),
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: view.days.length,
                    itemBuilder: (context, i) {
                      final isSel = _selectedDayIndex == i;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedDayIndex = i),
                        child: Container(
                          width: 80,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            color: isSel ? AppTheme.primary : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: isSel ? AppTheme.primary : AppTheme.borderLight),
                            boxShadow: isSel ? [BoxShadow(color: AppTheme.primary.withAlpha(50), blurRadius: 10, offset: const Offset(0, 4))] : null,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('DAY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: isSel ? Colors.white70 : AppTheme.textHint)),
                              const SizedBox(height: 4),
                              Text('${i + 1}', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: isSel ? Colors.white : AppTheme.textPrimary)),
                            ],
                          ),
                        ).animate(target: isSel ? 1 : 0).scale(begin: const Offset(0.95, 0.95), end: const Offset(1.05, 1.05)),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),
                _DayCard(
                  day: view.days[_selectedDayIndex],
                  dayIndex: _selectedDayIndex,
                ).animate(key: ValueKey(_selectedDayIndex)).fadeIn().slideY(begin: 0.1),
                const SizedBox(height: 24),

                // ── Budget Section (Web Parity) ──
                const TBSectionHeader(title: '💰 Estimated Budget'),
                const SizedBox(height: 12),
                _BudgetBreakdown(budget: budgetData),
                const SizedBox(height: 32),

                // ── Tweak Plan (Web Parity) ──
                const TBSectionHeader(title: '✏️ Tweak this Plan'),
                const SizedBox(height: 12),
                _TweakPanel(
                  controller: _tweakController,
                  isTweaking: _isTweaking,
                  onApply: _applyTweak,
                ),

                const SizedBox(height: 32),
                TBPrimaryButton(
                  label: 'Generate Reel Story',
                  onPressed: () => Navigator.pushNamed(context, AppRoutes.story, arguments: widget.trip),
                  icon: Icons.movie_outlined,
                ),
                const SizedBox(height: 40),
              ],
            ),
    );
  }
}

class _ItineraryViewData {
  final List<ItineraryDay> days;
  final Map<String, dynamic>? payload;
  const _ItineraryViewData({required this.days, required this.payload});
}

class _SummaryHero extends StatelessWidget {
  final TripModel? trip;
  final Map<String, dynamic> summary;
  const _SummaryHero({required this.trip, required this.summary});

  @override
  Widget build(BuildContext context) {
    final destination = (summary['destination'] ?? trip?.destination ?? '').toString();
    final tagline = (summary['tagline'] ?? 'A journey worth telling').toString();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primary, AppTheme.primary.withAlpha(200)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withAlpha(80),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on_outlined, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                'DESTINATION',
                style: TextStyle(
                  color: Colors.white.withAlpha(180),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            destination.isEmpty ? 'Your Adventure' : destination,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            tagline,
            style: TextStyle(
              color: Colors.white.withAlpha(230),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricsStrip extends StatelessWidget {
  final TripModel? trip;
  final Map<String, dynamic> summary;
  const _MetricsStrip({required this.trip, required this.summary});

  @override
  Widget build(BuildContext context) {
    final duration = (summary['duration_days'] ?? trip?.days ?? 0).toString();
    final style = (summary['travel_style'] ?? (trip?.interests.isNotEmpty == true ? trip!.interests.first : '-')).toString().toUpperCase();
    final intensityRaw = (summary['intensity_score'] ?? '5').toString();
    final intensity = double.tryParse(intensityRaw) ?? 5;

    return TBCard(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _MetricItem(label: 'DAYS', value: duration, icon: Icons.calendar_today_outlined),
          _MetricItem(label: 'STYLE', value: style, icon: Icons.explore_outlined),
          _MetricItem(label: 'INTENSITY', value: '$intensity/10', icon: Icons.timer_outlined),
        ],
      ),
    );
  }
}

class _MetricItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _MetricItem({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 18, color: AppTheme.primary),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppTheme.textHint),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

/// A highly premium, horizontally scrollable subway-style journey map.
class _MindMapView extends StatelessWidget {
  final List<ItineraryDay> days;
  final String destination;
  const _MindMapView({required this.days, required this.destination});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.bgLight, Colors.white],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.primary.withAlpha(20), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withAlpha(10),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background decorative line
          Positioned(
            left: 0, right: 0, top: 100,
            child: Container(
              height: 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primary.withAlpha(0),
                    AppTheme.primary.withAlpha(100),
                    AppTheme.primary.withAlpha(0),
                  ],
                ),
              ),
            ),
          ),
          ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            physics: const BouncingScrollPhysics(),
            itemCount: days.length,
            itemBuilder: (context, index) {
              final isFirst = index == 0;
              final day = days[index];

              return Row(
                children: [
                  if (isFirst) ...[
                    _MindMapRootNode(label: destination).animate().scale(delay: 200.ms, curve: Curves.easeOutBack),
                    _MindMapConnector().animate().fadeIn(delay: 400.ms),
                  ],
                  _MindMapDayNode(
                    dayNumber: index + 1,
                    stops: day.activities.length,
                  ).animate().fadeIn(delay: Duration(milliseconds: 400 + (index * 150))).slideX(begin: 0.2),
                  if (index != days.length - 1) 
                    _MindMapConnector().animate().fadeIn(delay: Duration(milliseconds: 500 + (index * 150))),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MindMapRootNode extends StatelessWidget {
  final String label;
  const _MindMapRootNode({required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 70, height: 70,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [AppTheme.primary, AppTheme.accentColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(color: AppTheme.primary.withAlpha(80), blurRadius: 15, spreadRadius: 2),
            ],
          ),
          child: const Icon(Icons.flight_takeoff_rounded, color: Colors.white, size: 32),
        ).animate(onPlay: (controller) => controller.repeat(reverse: true)).shimmer(duration: 2000.ms, color: Colors.white54),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.textPrimary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label.toUpperCase(),
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.0),
          ),
        ),
      ],
    );
  }
}

class _MindMapDayNode extends StatelessWidget {
  final int dayNumber;
  final int stops;
  const _MindMapDayNode({required this.dayNumber, required this.stops});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 50, height: 50,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.primary, width: 3),
            boxShadow: [
              BoxShadow(color: AppTheme.borderLight, blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: Center(
            child: Text(
              'D$dayNumber',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppTheme.primary),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.primary.withAlpha(20),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.place, size: 12, color: AppTheme.primary),
              const SizedBox(width: 4),
              Text(
                '$stops stops',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.primary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MindMapConnector extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 3,
      margin: const EdgeInsets.only(bottom: 30), // Align with circles
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(
          5, 
          (index) => Container(
            width: 4, height: 3,
            decoration: BoxDecoration(
              color: AppTheme.primary.withAlpha(100),
              borderRadius: BorderRadius.circular(2),
            ),
          )
        ),
      ),
    );
  }
}

class _BudgetBreakdown extends StatelessWidget {
  final Map<String, dynamic> budget;
  const _BudgetBreakdown({required this.budget});

  @override
  Widget build(BuildContext context) {
    final accommodation = budget['accommodation'] ?? '-';
    final food = budget['food'] ?? '-';
    final transport = budget['transport'] ?? '-';
    final misc = budget['misc'] ?? '-';
    final source = budget['source'] ?? 'Verified via Booking.com & Global Cost of Living Data';

    return TBCard(
      child: Column(
        children: [
          _BudgetItem(label: 'Accommodation', value: accommodation, icon: Icons.hotel_outlined),
          const Divider(height: 20),
          _BudgetItem(label: 'Food & Dining', value: food, icon: Icons.restaurant_outlined),
          const Divider(height: 20),
          _BudgetItem(label: 'Local Transport', value: transport, icon: Icons.directions_bus_outlined),
          const Divider(height: 20),
          _BudgetItem(label: 'Miscellaneous', value: misc, icon: Icons.shopping_bag_outlined),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.success.withAlpha(20),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.success.withAlpha(50)),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_user_rounded, color: AppTheme.success, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(fontSize: 10, color: AppTheme.textPrimary),
                      children: [
                        const TextSpan(text: 'Pricing Authentication: '),
                        TextSpan(
                          text: source.toString(),
                          style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.success),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 500.ms),
        ],
      ),
    );
  }
}

class _BudgetItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _BudgetItem({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppTheme.textHint),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        const Spacer(),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.primary)),
      ],
    );
  }
}

class _TweakPanel extends StatelessWidget {
  final TextEditingController controller;
  final bool isTweaking;
  final VoidCallback onApply;

  const _TweakPanel({
    required this.controller,
    required this.isTweaking,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.borderLight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Is something not quite right? Tell the AI what to change.',
                style: TextStyle(fontSize: 12, color: AppTheme.textHint),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 2,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'e.g. Add more food stalls or make it slower...',
                  fillColor: AppTheme.bgLight,
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TBPrimaryButton(
                label: 'Apply Modification',
                onPressed: isTweaking ? null : onApply,
                isLoading: isTweaking,
                icon: Icons.auto_awesome_outlined,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DayCard extends StatefulWidget {
  final ItineraryDay day;
  final int dayIndex;
  const _DayCard({required this.day, required this.dayIndex});

  @override
  State<_DayCard> createState() => _DayCardState();
}

class _DayCardState extends State<_DayCard> with SingleTickerProviderStateMixin {
  bool _expanded = true;
  late List<bool> _checkedItems;

  @override
  void initState() {
    super.initState();
    // Initialize checkboxes as unchecked
    _checkedItems = List.filled(widget.day.activities.length, false);
  }

  void _toggleCheck(int index) {
    setState(() {
      _checkedItems[index] = !_checkedItems[index];
    });
  }

  @override
  Widget build(BuildContext context) {
    // Calculate progress
    final checkedCount = _checkedItems.where((c) => c).length;
    final progress = widget.day.activities.isEmpty ? 0.0 : checkedCount / widget.day.activities.length;

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: EdgeInsets.only(bottom: _expanded ? 16 : 8),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _expanded ? AppTheme.primary.withAlpha(50) : AppTheme.borderLight),
          boxShadow: [
            BoxShadow(
              color: AppTheme.textPrimary.withAlpha(5),
              blurRadius: _expanded ? 20 : 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: progress == 1.0 ? AppTheme.success.withAlpha(20) : AppTheme.primary.withAlpha(20),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${widget.dayIndex + 1}',
                          style: TextStyle(
                            fontSize: 16, 
                            fontWeight: FontWeight.w900, 
                            color: progress == 1.0 ? AppTheme.success : AppTheme.primary
                          ),
                        ),
                      ).animate(target: progress == 1.0 ? 1 : 0).shimmer(color: AppTheme.success),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.day.label, 
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: progress,
                                      backgroundColor: AppTheme.borderLight,
                                      color: progress == 1.0 ? AppTheme.success : AppTheme.primary,
                                      minHeight: 6,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '$checkedCount/${widget.day.activities.length}',
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.textHint),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutBack,
                  child: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.textHint, size: 28),
                ),
              ],
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutQuart,
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: double.infinity,
                child: !_expanded ? const SizedBox.shrink() : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    ...widget.day.activities.asMap().entries.map((entry) {
                      final index = entry.key;
                      final activity = entry.value;
                      final isLast = index == widget.day.activities.length - 1;
                      final isChecked = _checkedItems[index];

                      return GestureDetector(
                        onTap: () => _toggleCheck(index),
                        behavior: HitTestBehavior.opaque,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Column(
                              children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 24, height: 24,
                                  decoration: BoxDecoration(
                                    color: isChecked ? AppTheme.success : Colors.white,
                                    border: Border.all(color: isChecked ? AppTheme.success : AppTheme.borderLight, width: 2),
                                    shape: BoxShape.circle,
                                    boxShadow: isChecked ? [BoxShadow(color: AppTheme.success.withAlpha(50), blurRadius: 8)] : null,
                                  ),
                                  child: isChecked 
                                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                                    : null,
                                ),
                                if (!isLast)
                                  Container(
                                    width: 2, height: 40,
                                    margin: const EdgeInsets.symmetric(vertical: 4),
                                    color: isChecked ? AppTheme.success.withAlpha(100) : AppTheme.borderLight,
                                  ),
                              ],
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 2, bottom: 20),
                                child: AnimatedDefaultTextStyle(
                                  duration: const Duration(milliseconds: 200),
                                  style: TextStyle(
                                    fontSize: 15,
                                    height: 1.4,
                                    fontWeight: isChecked ? FontWeight.w500 : FontWeight.w600,
                                    color: isChecked ? AppTheme.textHint : AppTheme.textPrimary,
                                    decoration: isChecked ? TextDecoration.lineThrough : TextDecoration.none,
                                  ),
                                  child: Text(activity),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ).animate(target: isChecked ? 1 : 0).moveX(end: 4, duration: 200.ms);
                    }),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DistanceBadge extends StatelessWidget {
  final String distance;
  const _DistanceBadge({required this.distance});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.primary.withAlpha(20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary.withAlpha(40)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.near_me_rounded, color: AppTheme.primary, size: 16),
          const SizedBox(width: 10),
          RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
              children: [
                const TextSpan(text: 'Journey Scope: '),
                TextSpan(
                  text: '$distance KM',
                  style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w900),
                ),
                const TextSpan(text: ' from your location'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
