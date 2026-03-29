import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../../providers/trip_provider.dart';
import '../../config/routes.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';

/// Create Trip screen with destination, days, budget and mood inputs.
class CreateTripScreen extends StatefulWidget {
  const CreateTripScreen({super.key});
  @override
  State<CreateTripScreen> createState() => _CreateTripScreenState();
}

class _CreateTripScreenState extends State<CreateTripScreen> {
  final _formKey        = GlobalKey<FormState>();
  final _destinCtrl     = TextEditingController();
  final _daysCtrl       = TextEditingController(text: '3');
  final _interestsCtrl  = TextEditingController();

  String _budget = 'Medium';
  final _budgets = ['Low', 'Medium', 'High'];

  final _moods = [
    'Food & Street Food', 'History & Heritage', 'Nature & Parks', 
    'Adventure & Trekking', 'Photography', 'Nightlife & Bars', 
    'Shopping & Markets', 'Culture & Festivals', 'Wellness & Yoga', 
    'Beaches & Water Sports', 'Hidden Gems', 'Architecture', 
    'Luxury & Relaxation', 'Art & Museums', 'Local Life', 'Offbeat Trails'
  ];
  final Set<String> _selectedMoods = {};

  bool _loading = false;

  @override
  void dispose() {
    _destinCtrl.dispose();
    _daysCtrl.dispose();
    _interestsCtrl.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    if (!_formKey.currentState!.validate()) return;

    final interests = [
      ..._selectedMoods,
      // Also include free-text interests
      ..._interestsCtrl.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty),
    ];

    setState(() => _loading = true);
    final provider = context.read<TripProvider>();
    final ok = await provider.generateItinerary(
      destination: _destinCtrl.text.trim(),
      days: int.parse(_daysCtrl.text.trim()),
      budget: _budget,
      interests: interests,
    );
    if (!mounted) return;
    setState(() => _loading = false);

    if (ok) {
      Fluttertoast.showToast(msg: 'Itinerary generated!', backgroundColor: AppTheme.success);
      Navigator.pushReplacementNamed(
        context,
        AppRoutes.itinerary,
        arguments: provider.currentTrip,
      );
    } else {
      Fluttertoast.showToast(
        msg: provider.errorMessage ?? 'Failed to generate itinerary.',
        backgroundColor: AppTheme.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Plan Your Trip')),
      body: Stack(
        children: [
          Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                // Destination
                TBInputField(
                  label: 'Destination',
                  hint: 'e.g. Jaisalmer, Paris, Tokyo',
                  controller: _destinCtrl,
                  validator: (v) => (v == null || v.isEmpty) ? 'Please enter a destination' : null,
                ),
                const SizedBox(height: 20),

                // Days
                TBInputField(
                  label: 'Number of Days',
                  hint: '3',
                  controller: _daysCtrl,
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    final n = int.tryParse(v);
                    if (n == null || n < 1 || n > 30) return 'Enter between 1–30 days';
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Budget selector
                Text('Budget', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 10),
                Row(
                  children: _budgets.map((b) {
                    final selected = _budget == b;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: GestureDetector(
                          onTap: () => setState(() => _budget = b),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: selected ? AppTheme.primary : AppTheme.surfaceLight,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: selected ? AppTheme.primary : AppTheme.borderLight),
                            ),
                            child: Text(
                              b,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                    color: selected ? Colors.white : AppTheme.textPrimary,
                                  ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),

                // Mood / interests chips
                Text('Mood & Interests', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _moods.map((m) {
                    final sel = _selectedMoods.contains(m);
                    return TBChip(
                      label: m,
                      selected: sel,
                      onTap: () => setState(() {
                        sel ? _selectedMoods.remove(m) : _selectedMoods.add(m);
                      }),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                // Free-text interests
                TBInputField(
                  label: 'Other Interests (comma separated)',
                  hint: 'e.g. folk music, camel safari',
                  controller: _interestsCtrl,
                ),
                const SizedBox(height: 32),

                TBPrimaryButton(
                  label: 'Generate Itinerary',
                  isLoading: _loading,
                  onPressed: _generate,
                  icon: Icons.auto_awesome,
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
          if (_loading) const TBLoadingOverlay(message: 'Generating your itinerary…'),
        ],
      ),
    );
  }
}
