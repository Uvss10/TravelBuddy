import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../providers/auth_provider.dart';
import '../config/routes.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class _OnboardPage {
  final IconData icon;
  final String title;
  final String subtitle;
  const _OnboardPage({required this.icon, required this.title, required this.subtitle});
}

/// 3-slide onboarding screen explaining core features.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _currentPage = 0;

  static const _pages = [
    _OnboardPage(
      icon: Icons.auto_awesome,
      title: 'AI-Powered Itineraries',
      subtitle: 'Tell us your destination and interests.\nGet a personalized day-wise travel plan in seconds.',
    ),
    _OnboardPage(
      icon: Icons.photo_library_outlined,
      title: 'Smart Photo Selection',
      subtitle: 'Upload your trip photos.\nOur AI ranks and picks the most stunning shots automatically.',
    ),
    _OnboardPage(
      icon: Icons.movie_creation_outlined,
      title: 'Cinematic Reel Generation',
      subtitle: 'Transform your memories into Instagram-ready reels with AI narration and captions.',
    ),
  ];

  void _next() {
    if (_currentPage < _pages.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    } else {
      _finish();
    }
  }

  void _finish() {
    context.read<AuthProvider>().completeOnboarding();
    Navigator.pushReplacementNamed(context, AppRoutes.login);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _currentPage == _pages.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _finish,
                child: Text(
                  'Skip',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            // Page content
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemCount: _pages.length,
                itemBuilder: (_, i) => _OnboardSlide(page: _pages[i]),
              ),
            ),

            // Indicator & CTA
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
              child: Column(
                children: [
                  SmoothPageIndicator(
                    controller: _controller,
                    count: _pages.length,
                    effect: const ExpandingDotsEffect(
                      activeDotColor: AppTheme.primary,
                      dotColor: AppTheme.borderLight,
                      dotHeight: 8,
                      dotWidth: 8,
                      expansionFactor: 3,
                    ),
                  ),
                  const SizedBox(height: 32),
                  TBPrimaryButton(
                    label: isLast ? 'Get Started' : 'Continue',
                    onPressed: _next,
                    icon: isLast ? Icons.arrow_forward : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardSlide extends StatelessWidget {
  final _OnboardPage page;
  const _OnboardSlide({required this.page});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon illustration
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              color: AppTheme.bgLight,
              borderRadius: BorderRadius.circular(36),
            ),
            child: Icon(page.icon, size: 64, color: AppTheme.primary),
          ),
          const SizedBox(height: 40),
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.displaySmall,
          ),
          const SizedBox(height: 16),
          Text(
            page.subtitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.textSecondary,
                ),
          ),
        ],
      ),
    );
  }
}
