import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../../models/trip_model.dart';
import '../../config/routes.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';

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

/// A horizontally scrollable hierarchy view of the trip.
class _MindMapView extends StatelessWidget {
  final List<ItineraryDay> days;
  final String destination;
  const _MindMapView({required this.days, required this.destination});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: AppTheme.bgLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(20),
        itemCount: days.length,
        itemBuilder: (context, index) {
          final isFirst = index == 0;
          final isLast = index == days.length - 1;
          final day = days[index];

          return Row(
            children: [
              if (isFirst) ...[
                _MindMapNode(label: destination, isRoot: true),
                _MindMapConnector(),
              ],
              _MindMapNode(
                label: day.label,
                sublabel: '${day.activities.length} stops',
                isRoot: false,
              ),
              if (!isLast) _MindMapConnector(),
            ],
          );
        },
      ),
    );
  }
}

class _MindMapNode extends StatelessWidget {
  final String label;
  final String? sublabel;
  final bool isRoot;
  const _MindMapNode({required this.label, this.sublabel, this.isRoot = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      constraints: const BoxConstraints(minWidth: 100),
      decoration: BoxDecoration(
        color: isRoot ? AppTheme.primary : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isRoot ? AppTheme.primary : AppTheme.borderLight),
        boxShadow: isRoot ? [BoxShadow(color: AppTheme.primary.withAlpha(50), blurRadius: 10)] : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isRoot ? Colors.white : AppTheme.textPrimary,
            ),
          ),
          if (sublabel != null) ...[
            const SizedBox(height: 2),
            Text(
              sublabel!,
              style: const TextStyle(fontSize: 10, color: AppTheme.textHint),
            ),
          ],
        ],
      ),
    );
  }
}

class _MindMapConnector extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 2,
      color: AppTheme.borderLight,
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

class _DayCardState extends State<_DayCard> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    return TBCard(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withAlpha(20),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${widget.dayIndex + 1}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppTheme.primary),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.day.label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                      Text('${widget.day.activities.length} major stops', style: const TextStyle(fontSize: 11, color: AppTheme.textHint)),
                    ],
                  ),
                ],
              ),
              Icon(
                _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                color: AppTheme.textHint,
                size: 20,
              ),
            ],
          ),
          if (_expanded) ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            ...widget.day.activities.asMap().entries.map((entry) {
              final index = entry.key;
              final activity = entry.value;
              final isLast = index == widget.day.activities.length - 1;

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 8, height: 8,
                        margin: const EdgeInsets.only(top: 6),
                        decoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
                      ),
                      if (!isLast)
                        Container(
                          width: 1, height: 40,
                          margin: const EdgeInsets.symmetric(vertical: 2),
                          color: AppTheme.borderLight,
                        ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        activity,
                        style: const TextStyle(fontSize: 14, height: 1.5, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                ],
              );
            }),
          ],
        ],
      ),
    );
  }
}
