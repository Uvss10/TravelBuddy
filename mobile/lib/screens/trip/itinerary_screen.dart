import 'dart:convert';
import 'package:flutter/material.dart';
import '../../models/trip_model.dart';
import '../../config/routes.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';

/// Displays the AI-generated day-wise itinerary as expandable cards.
class ItineraryScreen extends StatelessWidget {
  final TripModel? trip;
  const ItineraryScreen({super.key, this.trip});

  List<ItineraryDay> _parseDays() {
    final raw = trip?.itineraryOutput;
    if (raw == null || raw.isEmpty) return [];
    try {
      // Strip markdown fences if present
      final cleaned = raw.replaceAll(RegExp(r'```json|```'), '').trim();
      final start = cleaned.indexOf('{');
      final end   = cleaned.lastIndexOf('}') + 1;
      if (start < 0 || end <= 0) return [];
      final map = jsonDecode(cleaned.substring(start, end)) as Map<String, dynamic>;
      return ItineraryDay.parseFromMap(map);
    } catch (_) {
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final days = _parseDays();

    return Scaffold(
      appBar: AppBar(
        title: Text(trip?.destination ?? 'Itinerary'),
        actions: [
          // Jump to story
          TextButton(
            onPressed: () => Navigator.pushNamed(context, AppRoutes.story, arguments: trip),
            child: const Text('Story →'),
          ),
        ],
      ),
      body: days.isEmpty
          ? const TBEmptyState(
              icon: Icons.event_note_outlined,
              title: 'No itinerary data',
              subtitle: 'The AI could not parse the itinerary. Try generating again.',
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Trip summary chip row
                Row(
                  children: [
                    _InfoChip(label: '${trip?.days ?? 0} Days'),
                    const SizedBox(width: 8),
                    _InfoChip(label: trip?.budget ?? ''),
                  ],
                ),
                const SizedBox(height: 24),

                ...days.map((day) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _DayCard(day: day),
                    )),

                const SizedBox(height: 32),
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

// ─── Day card (expandable) ────────────────────────────────────────────────────
class _DayCard extends StatefulWidget {
  final ItineraryDay day;
  const _DayCard({required this.day});
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
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${widget.day.activities.length} activities',
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
            ...widget.day.activities.asMap().entries.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: AppTheme.bgLight,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Center(
                          child: Text(
                            '${e.key + 1}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(e.value, style: Theme.of(context).textTheme.bodyMedium),
                      ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  const _InfoChip({required this.label});

  @override
  Widget build(BuildContext context) {
    if (label.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.bgLight,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
    );
  }
}
