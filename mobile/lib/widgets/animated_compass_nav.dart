import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../theme/app_theme.dart';

class AnimatedCompassNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const AnimatedCompassNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: AppTheme.xl, right: AppTheme.xl, bottom: AppTheme.xl),
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.md, vertical: AppTheme.sm),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withOpacity(0.9),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(context, 0, FontAwesomeIcons.house, 'Home'),
          _buildNavItem(context, 1, FontAwesomeIcons.mapLocationDot, 'Trip'),
          _buildNavItem(context, 2, FontAwesomeIcons.film, 'Reels'),
          _buildNavItem(context, 3, FontAwesomeIcons.user, 'Profile'),
        ],
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, int index, IconData icon, String label) {
    final isSelected = currentIndex == index;
    final color = isSelected ? AppTheme.accentColor : Theme.of(context).textTheme.bodySmall?.color;

    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.md, vertical: AppTheme.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: color,
              size: isSelected ? 24 : 20,
            ).animate(target: isSelected ? 1 : 0)
             .scaleXY(end: 1.2, duration: 200.ms, curve: Curves.easeOutBack)
             .tint(color: AppTheme.accentColor, end: 1),
            
            if (isSelected)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: const CircleAvatar(
                  radius: 3,
                  backgroundColor: AppTheme.accentColor,
                ).animate()
                 .scale(duration: 200.ms)
                 .fade(),
              )
          ],
        ),
      ),
    );
  }
}
