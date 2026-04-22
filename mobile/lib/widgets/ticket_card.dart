import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class TicketCard extends StatelessWidget {
  final String destination;
  final String date;
  final String title;
  final String duration;
  final String imageUrl;
  final VoidCallback onTap;

  const TicketCard({
    super.key,
    required this.destination,
    required this.date,
    required this.title,
    required this.duration,
    required this.imageUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: AppTheme.lg, vertical: AppTheme.sm),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipPath(
          clipper: TicketClipper(),
          child: Column(
            children: [
              // Top Image Section
              Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: NetworkImage(imageUrl),
                    fit: BoxFit.cover,
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.1),
                        Colors.black.withOpacity(0.7),
                      ],
                    ),
                  ),
                  padding: const EdgeInsets.all(AppTheme.lg),
                  alignment: Alignment.bottomLeft,
                  child: Text(
                    destination.toUpperCase(),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      letterSpacing: 2.0,
                    ),
                  ),
                ),
              ),
              
              // Bottom Details Section
              Padding(
                padding: const EdgeInsets.all(AppTheme.lg),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: Theme.of(context).textTheme.headlineSmall,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: AppTheme.sm),
                          Row(
                            children: [
                              Icon(
                                FontAwesomeIcons.calendarDay,
                                size: 14,
                                color: Theme.of(context).textTheme.bodySmall?.color,
                              ),
                              const SizedBox(width: AppTheme.xs),
                              Text(
                                date,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    // The "Tear" Separator happens outside here via Clipper, but let's draw a dashed line
                    Container(
                      width: 1,
                      height: 50,
                      margin: const EdgeInsets.symmetric(horizontal: AppTheme.lg),
                      child: LayoutBuilder(
                        builder: (BuildContext context, BoxConstraints constraints) {
                          final boxHeight = constraints.constrainHeight();
                          const dashWidth = 3.0;
                          final dashHeight = 4.0;
                          final dashCount = (boxHeight / (2 * dashHeight)).floor();
                          return Flex(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            direction: Axis.vertical,
                            children: List.generate(dashCount, (_) {
                              return SizedBox(
                                width: dashWidth,
                                height: dashHeight,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(color: AppTheme.borderColor),
                                ),
                              );
                            }),
                          );
                        },
                      ),
                    ),

                    Expanded(
                      flex: 1,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(
                            FontAwesomeIcons.planeDeparture,
                            color: AppTheme.primaryColor,
                            size: 24,
                          ),
                          const SizedBox(height: AppTheme.sm),
                          Text(
                            duration,
                            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TicketClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    
    path.lineTo(0.0, size.height);
    path.lineTo(size.width, size.height);
    path.lineTo(size.width, 0.0);

    // Add semi-circle cutouts on the left and right at the image separator line (height 120)
    final double cutoutRadius = 10.0;
    final double cutoutY = 120.0;
    
    path.addOval(Rect.fromCircle(center: Offset(0, cutoutY), radius: cutoutRadius));
    path.addOval(Rect.fromCircle(center: Offset(size.width, cutoutY), radius: cutoutRadius));
    
    return Path.combine(PathOperation.difference, path, Path()..addOval(Rect.fromCircle(center: Offset(0, cutoutY), radius: cutoutRadius))..addOval(Rect.fromCircle(center: Offset(size.width, cutoutY), radius: cutoutRadius)));
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
