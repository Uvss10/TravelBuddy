import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/trip_provider.dart';
import '../../config/routes.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../../providers/language_provider.dart';

/// Professional Multi-step Trip Planning Wizard
class CreateTripScreen extends StatefulWidget {
  const CreateTripScreen({super.key});
  @override
  State<CreateTripScreen> createState() => _CreateTripScreenState();
}

class _CreateTripScreenState extends State<CreateTripScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  final _formKey        = GlobalKey<FormState>();
  final _destinCtrl     = TextEditingController();
  final _daysCtrl       = TextEditingController(text: '3');
  final _interestsCtrl  = TextEditingController();

  String _budget = 'Medium';
  final List<Map<String, dynamic>> _budgetOptions = [
    {'label': 'Low', 'icon': Icons.savings_outlined, 'desc': 'Budget friendly'},
    {'label': 'Medium', 'icon': Icons.account_balance_wallet_outlined, 'desc': 'Standard value'},
    {'label': 'High', 'icon': Icons.diamond_outlined, 'desc': 'Luxury experience'},
  ];

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
    _pageController.dispose();
    _destinCtrl.dispose();
    _daysCtrl.dispose();
    _interestsCtrl.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < 2) {
      if (_currentStep == 0 && _destinCtrl.text.isEmpty) {
        Fluttertoast.showToast(msg: 'Please enter a destination', backgroundColor: AppTheme.warning);
        return;
      }
      _pageController.nextPage(duration: 400.ms, curve: Curves.easeInOutCubic);
      setState(() => _currentStep++);
    } else {
      _generate();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(duration: 400.ms, curve: Curves.easeInOutCubic);
      setState(() => _currentStep--);
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _generate() async {
    final interests = [
      ..._selectedMoods,
      ..._interestsCtrl.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty),
    ];

    if (interests.isEmpty && _selectedMoods.isEmpty) {
      Fluttertoast.showToast(msg: 'Select at least one interest', backgroundColor: AppTheme.warning);
      return;
    }

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
      Navigator.pushReplacementNamed(context, AppRoutes.itinerary, arguments: provider.currentTrip);
    } else {
      Fluttertoast.showToast(msg: provider.errorMessage ?? 'Generation failed', backgroundColor: AppTheme.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.textPrimary, size: 20),
          onPressed: _prevStep,
        ),
        title: _StepIndicator(current: _currentStep),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildStep1(),
                    _buildStep2(),
                    _buildStep3(),
                  ],
                ),
              ),
              _buildBottomNav(),
            ],
          ),
          if (_loading) TBLoadingOverlay(message: 'Mapping your journey to ${_destinCtrl.text}...'),
        ],
      ),
    );
  }

  Widget _buildStep1() {
    final s = context.read<LanguageProvider>().strings;
    return ListView(
      padding: const EdgeInsets.all(30),
      children: [
        Text(s.whereAndWhen, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppTheme.primary, letterSpacing: 1.5)),
        const SizedBox(height: 8),
        Text(s.adventureStarts, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, height: 1.1)),
        const SizedBox(height: 40),
        TBInputField(
          label: s.destination,
          hint: 'e.g. Kyoto, Japan',
          controller: _destinCtrl,
          icon: Icons.location_on_rounded,
        ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1),
        const SizedBox(height: 24),
        TBInputField(
          label: s.durationDays,
          hint: '3',
          controller: _daysCtrl,
          keyboardType: TextInputType.number,
          icon: Icons.calendar_today_rounded,
        ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1),
      ],
    );
  }

  Widget _buildStep2() {
    final s = context.read<LanguageProvider>().strings;
    return ListView(
      padding: const EdgeInsets.all(30),
      children: [
        Text(s.budgetAndStyle, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppTheme.primary, letterSpacing: 1.5)),
        const SizedBox(height: 8),
        Text(s.howExperience, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, height: 1.1)),
        const SizedBox(height: 40),
        Column(
          children: _budgetOptions.map((opt) {
            final isSel = _budget == opt['label'];
            return GestureDetector(
              onTap: () => setState(() => _budget = opt['label']),
              child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isSel ? AppTheme.primary : AppTheme.bgLight,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: isSel ? AppTheme.primary : AppTheme.borderLight),
                  boxShadow: isSel ? [BoxShadow(color: AppTheme.primary.withAlpha(40), blurRadius: 15, offset: const Offset(0, 8))] : null,
                ),
                child: Row(
                  children: [
                    Icon(opt['icon'], color: isSel ? Colors.white : AppTheme.primary),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(opt['label'] == 'Low' ? s.low : (opt['label'] == 'Medium' ? s.medium : s.high), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: isSel ? Colors.white : AppTheme.textPrimary)),
                          Text(opt['desc'], style: TextStyle(fontSize: 12, color: isSel ? Colors.white70 : AppTheme.textHint)),
                        ],
                      ),
                    ),
                    if (isSel) const Icon(Icons.check_circle, color: Colors.white),
                  ],
                ),
              ).animate(target: isSel ? 1 : 0).scale(begin: const Offset(1, 1), end: const Offset(1.02, 1.02)),
            );
          }).toList(),
        ).animate().fadeIn().slideX(begin: 0.05),
      ],
    );
  }

  Widget _buildStep3() {
    final s = context.read<LanguageProvider>().strings;
    return ListView(
      padding: const EdgeInsets.all(30),
      children: [
        Text(s.moodAndInterests, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppTheme.primary, letterSpacing: 1.5)),
        const SizedBox(height: 8),
        Text(s.soulDance, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, height: 1.1)),
        const SizedBox(height: 32),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _moods.map((m) {
            final sel = _selectedMoods.contains(m);
            return GestureDetector(
              onTap: () => setState(() => sel ? _selectedMoods.remove(m) : _selectedMoods.add(m)),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: sel ? AppTheme.accent : AppTheme.bgLight,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: sel ? AppTheme.accent : AppTheme.borderLight),
                ),
                child: Text(m, style: TextStyle(fontWeight: FontWeight.w700, color: sel ? Colors.white : AppTheme.textPrimary, fontSize: 13)),
              ).animate(target: sel ? 1 : 0).scale(begin: const Offset(1, 1), end: const Offset(1.1, 1.1)),
            );
          }).toList(),
        ).animate().fadeIn().scale(begin: const Offset(0.9, 0.9)),
        const SizedBox(height: 32),
        TBInputField(
          label: s.otherInterests,
          hint: 'e.g. coffee tasting, local myths',
          controller: _interestsCtrl,
        ),
      ],
    );
  }

  Widget _buildBottomNav() {
    final s = context.read<LanguageProvider>().strings;
    return Container(
      padding: const EdgeInsets.fromLTRB(30, 0, 30, 40),
      child: TBPrimaryButton(
        label: _currentStep == 2 ? s.generateMasterpiece : s.nextStep,
        onPressed: _nextStep,
        icon: _currentStep == 2 ? Icons.auto_awesome_rounded : null,
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  final int current;
  const _StepIndicator({required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        final isActive = i <= current;
        return Container(
          width: 30, height: 4,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: isActive ? AppTheme.primary : AppTheme.bgLight,
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }
}
