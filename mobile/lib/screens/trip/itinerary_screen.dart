import 'dart:convert';
import 'package:flutter/material.dart';
import '../../models/trip_model.dart';
import '../../config/routes.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';

/// Rich itinerary view with summary metrics + day timeline cards.
class ItineraryScreen extends StatelessWidget {
  final TripModel? trip;
  const ItineraryScreen({super.key, this.trip});

  _ItineraryViewData _buildViewData() {
    final raw = trip?.itineraryOutput;
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

  @override
  Widget build(BuildContext context) {
    final view = _buildViewData();
    final summary = (view.payload?['trip_summary'] as Map<String, dynamic>?) ?? const {};

    return Scaffold(
      appBar: AppBar(
        title: Text(trip?.destination ?? 'Itinerary'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pushNamed(context, AppRoutes.story, arguments: trip),
            child: const Text('Story ->'),
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
              padding: const EdgeInsets.all(20),
              children: [
                _SummaryHero(trip: trip, summary: summary),
                const SizedBox(height: 16),
                _MetricsStrip(trip: trip, summary: summary),
                const SizedBox(height: 16),
                _DayActivityGraph(days: view.days),
                const SizedBox(height: 18),
                ...view.days.asMap().entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _DayCard(
                      day: entry.value,
                      dayIndex: entry.key,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                TBPrimaryButton(
                  label: 'View Story & Reel',
                  onPressed: () => Navigator.pushNamed(context, AppRoutes.story, arguments: trip),
                  icon: Icons.play_circle_outline,
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
    final routeFocus = (summary['optimization_focus'] ?? 'Route-efficient plan').toString();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withAlpha(60),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            destination.isEmpty ? 'Your Smart Plan' : destination,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            routeFocus,
            style: TextStyle(
              color: Colors.white.withAlpha(230),
              fontSize: 13,
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
    final cost = (summary['estimated_total_trip_cost'] ?? trip?.budget ?? '-').toString();
    final travelTime = (summary['estimated_total_travel_time'] ?? '-').toString();
    final intensityRaw = (summary['intensity_score'] ?? '5').toString();
    final intensity = double.tryParse(intensityRaw) ?? 5;
    final normalizedIntensity = (intensity / 10).clamp(0.0, 1.0);

    return TBCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _MetricTile(label: 'Days', value: duration)),
              const SizedBox(width: 10),
              Expanded(child: _MetricTile(label: 'Est. Cost', value: cost)),
              const SizedBox(width: 10),
              Expanded(child: _MetricTile(label: 'Travel Time', value: travelTime)),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Intensity',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: normalizedIntensity,
              backgroundColor: AppTheme.borderLight,
              color: AppTheme.accent,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${intensity.toStringAsFixed(0)} / 10',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  const _MetricTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.bgLight,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary)),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _DayActivityGraph extends StatelessWidget {
  final List<ItineraryDay> days;
  const _DayActivityGraph({required this.days});

  @override
  Widget build(BuildContext context) {
    final maxCount = days.fold<int>(1, (prev, day) => day.activities.length > prev ? day.activities.length : prev);

    return TBCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Activity Distribution', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          ...days.map((day) {
            final ratio = (day.activities.length / maxCount).clamp(0.0, 1.0);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 58,
                    child: Text(day.label, style: Theme.of(context).textTheme.bodySmall),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        minHeight: 8,
                        value: ratio,
                        backgroundColor: AppTheme.borderLight,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('${day.activities.length}', style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            );
          }),
        ],
      ),
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
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      widget.day.label,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${widget.day.activities.length} stops',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              Icon(
                _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                color: AppTheme.textHint,
              ),
            ],
          ),
          if (_expanded) ...[
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 12),
            ...widget.day.activities.asMap().entries.map((entry) {
              final index = entry.key;
              final activity = entry.value;
              final isLast = index == widget.day.activities.length - 1;

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withAlpha(20),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.primary.withAlpha(80)),
                          ),
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                        if (!isLast)
                          Container(
                            width: 2,
                            height: 26,
                            color: AppTheme.borderLight,
                          ),
                      ],
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.bgLight,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.borderLight),
                        ),
                        child: Text(activity, style: Theme.of(context).textTheme.bodyMedium),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}
