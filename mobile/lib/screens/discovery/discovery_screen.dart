import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/custom_widgets.dart';

class DiscoveryScreen extends StatefulWidget {
  final String location;
  final double? lat;
  final double? lon;
  const DiscoveryScreen({super.key, required this.location, this.lat, this.lon});

  @override
  State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends State<DiscoveryScreen> {
  final ApiService _api = ApiService();
  List<dynamic> _spots = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchSpots();
  }

  Future<void> _fetchSpots() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final result = await _api.getNearbySpots(widget.location, lat: widget.lat, lon: widget.lon);
    
    if (mounted) {
      if (result.isSuccess) {
        setState(() {
          _spots = result.data!;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = result.error;
          _isLoading = false;
        });
      }
    }
  }
// ... [keeping existing sliver app bar and layout] ...
// I will just replace the _DiscoverySpotCard implementation and the widget params

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            SliverFillRemaining(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 48, color: Colors.redAccent),
                      const SizedBox(height: 16),
                      Text(_error!, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 24),
                      PremiumButton(label: 'Retry', onPressed: _fetchSpots),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final spot = _spots[index];
                    return _DiscoverySpotCard(spot: spot)
                        .animate()
                        .fadeIn(delay: (index * 100).ms)
                        .slideX(begin: 0.1);
                  },
                  childCount: _spots.length,
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      backgroundColor: AppTheme.primaryColor,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
        title: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'DISCOVERY',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                color: Colors.white70,
              ),
            ),
            Text(
              widget.location,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ],
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
              ),
            ),
            Positioned(
              right: -50,
              top: -20,
              child: Icon(
                Icons.explore_rounded,
                size: 240,
                color: Colors.white.withAlpha(20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiscoverySpotCard extends StatelessWidget {
  final dynamic spot;
  const _DiscoverySpotCard({required this.spot});

  @override
  Widget build(BuildContext context) {
    final String category = spot['category'] ?? 'Photography';
    final String importance = spot['importance'] ?? 'Recommended';
    final double distance = (spot['distance_km'] ?? 0.0).toDouble();
    
    Color catColor = AppTheme.primaryColor;
    IconData catIcon = Icons.camera_alt_rounded;

    if (category.contains('Heritage')) {
      catColor = Colors.amber.shade800;
      catIcon = Icons.account_balance_rounded;
    } else if (category.contains('Nature')) {
      catColor = Colors.green.shade700;
      catIcon = Icons.landscape_rounded;
    }

    Color impColor = AppTheme.textHint;
    if (importance.contains('Must')) impColor = Colors.redAccent;
    if (importance.contains('Hidden')) impColor = AppTheme.accentColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 20, offset: const Offset(0, 10))
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- Image Header ---
          Stack(
            children: [
              Image.network(
                spot['image_url'] ?? 'https://images.unsplash.com/photo-1548013146-72479768bada?w=800',
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
              Positioned(
                top: 16,
                left: 16,
                child: _Badge(label: category.toUpperCase(), icon: catIcon, color: Colors.black.withAlpha(150)),
              ),
              Positioned(
                top: 16,
                right: 16,
                child: _Badge(label: '${distance.toStringAsFixed(1)} KM', icon: Icons.near_me_rounded, color: AppTheme.primary.withAlpha(200)),
              ),
            ],
          ),

          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        spot['name'] ?? 'Unknown Spot',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: impColor.withAlpha(20),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: impColor.withAlpha(40)),
                      ),
                      child: Text(
                        importance.toUpperCase(),
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: impColor),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(spot['description'] ?? '', style: const TextStyle(color: AppTheme.textHint, height: 1.4)),
                const SizedBox(height: 20),
                
                // --- Expert Recommendation ---
                if (spot['recommendation'] != null) ...[
                  const Text('WHY IT MATTERS', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: AppTheme.textHint)),
                  const SizedBox(height: 8),
                  Text(spot['recommendation'], style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                  const SizedBox(height: 20),
                ],

                // --- Photography Tip Box ---
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: catColor.withAlpha(15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: catColor.withAlpha(30)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.camera_rounded, color: catColor, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          spot['photography_tip'] ?? '',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: catColor, fontStyle: FontStyle.italic),
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
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  const _Badge({required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1)),
        ],
      ),
    );
  }
}
