import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../theme/app_theme.dart';

class TravelLoaders {
  
  /// A loading animation of a spinning globe and a plane flying around it.
  static Widget globePlaneLoader(BuildContext context, {String message = "Discovering Magic..."}) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 100,
            width: 100,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // The Globe
                Icon(
                  FontAwesomeIcons.earthAmericas,
                  size: 60,
                  color: AppTheme.primaryLight.withOpacity(0.5),
                ).animate(onPlay: (controller) => controller.repeat())
                 .rotate(duration: 4.seconds, curve: Curves.linear),
                
                // The Plane orbiting
                Transform.translate(
                  offset: const Offset(35, 0),
                  child: Icon(
                    FontAwesomeIcons.plane,
                    size: 24,
                    color: AppTheme.accentColor,
                  ),
                ).animate(onPlay: (controller) => controller.repeat())
                 .rotate(duration: 2.seconds, curve: Curves.linear),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.xl),
          Text(
            message,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppTheme.primaryColor,
            ),
          ).animate(onPlay: (controller) => controller.repeat(reverse: true))
           .fade(duration: 1.seconds, begin: 0.5, end: 1.0),
        ],
      ),
    );
  }

  /// A passport stamp animation
  static Widget passportStampLoader(BuildContext context, {String message = "Packing your bags..."}) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            FontAwesomeIcons.stamp,
            size: 60,
            color: AppTheme.accentColor,
          ).animate(onPlay: (controller) => controller.repeat())
           .scale(duration: 800.ms, begin: const Offset(1.5, 1.5), end: const Offset(1, 1), curve: Curves.bounceOut)
           .fade(duration: 800.ms),
          
          const SizedBox(height: AppTheme.xl),
          Text(
            message,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppTheme.accentColor,
              fontWeight: FontWeight.bold,
            ),
          ).animate(onPlay: (controller) => controller.repeat(reverse: true))
           .fade(duration: 1.seconds, begin: 0.2, end: 1.0),
        ],
      ),
    );
  }

  /// A film reel loader for the cinematic video background rendering.
  static Widget cinematicReelLoader(BuildContext context, {required String progressMessage}) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            FontAwesomeIcons.film,
            size: 60,
            color: AppTheme.primaryColor,
          ).animate(onPlay: (controller) => controller.repeat())
           .rotate(duration: 3.seconds, curve: Curves.linear),
          
          const SizedBox(height: AppTheme.xl),
          Text(
            progressMessage,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppTheme.primaryDark,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ).animate(key: ValueKey(progressMessage)) // Reacts when message changes
           .fadeIn(duration: 400.ms)
           .slideY(begin: 0.2, end: 0),
        ],
      ),
    );
  }
}
