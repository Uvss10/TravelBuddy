import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/custom_widgets.dart';

/// Global Explorer — user types a destination and gets best spots to visit.
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
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _spots = [];
  bool _isLoading = false;
  bool _hasSearched = false;
  String? _error;
  String _currentSearch = '';

  @override
  void initState() {
    super.initState();
    // Pre-fill with location if it's a real place (not placeholder)
    if (widget.location.isNotEmpty &&
        widget.location != 'Your World' &&
        widget.location != 'Locating...') {
      _searchController.text = widget.location;
      _currentSearch = widget.location;
      _fetchSpots(widget.location);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchSpots(String location) async {
    if (location.trim().isEmpty) return;
    setState(() {
      _isLoading = true;
      _error = null;
      _hasSearched = true;
      _currentSearch = location.trim();
    });

    final result = await _api.getNearbySpots(location.trim());

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          // ── Search Bar ────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withAlpha(20),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    )
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: _fetchSpots,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText: 'e.g. Jaipur, Paris, Bali...',
                    hintStyle: const TextStyle(color: AppTheme.textHint),
                    prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.primary),
                    suffixIcon: SizedBox(
                      width: 90,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (_searchController.text.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.close_rounded, color: AppTheme.textHint, size: 20),
                              onPressed: () {
                                setState(() {
                                  _searchController.clear();
                                  _hasSearched = false;
                                  _spots = [];
                                });
                              },
                            ),
                          GestureDetector(
                            onTap: () => _fetchSpots(_searchController.text),
                            child: Container(
                              margin: const EdgeInsets.all(8),
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppTheme.primary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.explore_rounded, color: Colors.white, size: 20),
                            ),
                          ),
                          const SizedBox(width: 4),
                        ],
                      ),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1),
          ),

          // ── Content ───────────────────────────────────────────────────────
          if (!_hasSearched)
            SliverFillRemaining(
              child: _buildEmptyState(),
            )
          else if (_isLoading)
            const SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Discovering best spots...', style: TextStyle(color: AppTheme.textHint)),
                  ],
                ),
              ),
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
                      Text(_error!, textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 24),
                      PremiumButton(
                        label: 'Retry',
                        onPressed: () => _fetchSpots(_currentSearch),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (_spots.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.location_off_rounded, size: 48, color: AppTheme.textHint),
                    const SizedBox(height: 12),
                    Text('No spots found for "$_currentSearch"',
                        style: const TextStyle(color: AppTheme.textHint)),
                    const SizedBox(height: 8),
                    const Text('Try a different location name',
                        style: TextStyle(fontSize: 12, color: AppTheme.textHint)),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (index == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          'Best spots in $_currentSearch',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                            color: AppTheme.textHint,
                          ),
                        ).animate().fadeIn(),
                      );
                    }
                    final spot = _spots[index - 1];
                    return _DiscoverySpotCard(spot: spot)
                        .animate()
                        .fadeIn(delay: (index * 100).ms)
                        .slideX(begin: 0.1);
                  },
                  childCount: _spots.length + 1,
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.primary.withAlpha(15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.travel_explore_rounded, size: 56, color: AppTheme.primary),
          ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack),
          const SizedBox(height: 20),
          const Text(
            'Explore Any Destination',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ).animate().fadeIn(delay: 200.ms),
          const SizedBox(height: 8),
          const Text(
            'Type a city or country above\nto discover the best spots',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textHint, height: 1.5),
          ).animate().fadeIn(delay: 300.ms),
          const SizedBox(height: 32),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: ['Jaipur', 'Paris', 'Bali', 'Tokyo', 'Rome', 'Goa']
                .asMap()
                .entries
                .map((e) => GestureDetector(
                      onTap: () {
                        _searchController.text = e.value;
                        _fetchSpots(e.value);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppTheme.borderLight),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 8, offset: const Offset(0, 4))
                          ],
                        ),
                        child: Text(
                          '📍 ${e.value}',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                      ),
                    ).animate().fadeIn(delay: Duration(milliseconds: 400 + e.key * 80)))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 160,
      pinned: true,
      backgroundColor: AppTheme.primaryColor,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
        title: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('GLOBAL EXPLORER',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900,
                    letterSpacing: 2, color: Colors.white70)),
            Text(
              _hasSearched ? _currentSearch : 'Discover the World',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white),
            ),
          ],
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            Container(decoration: BoxDecoration(gradient: AppTheme.primaryGradient)),
            Positioned(
              right: -50, top: -20,
              child: Icon(Icons.public_rounded, size: 220, color: Colors.white.withAlpha(20)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Spot Card ─────────────────────────────────────────────────────────────────

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
    if (category.contains('Heritage')) { catColor = Colors.amber.shade800; catIcon = Icons.account_balance_rounded; }
    else if (category.contains('Nature')) { catColor = Colors.green.shade700; catIcon = Icons.landscape_rounded; }

    Color impColor = AppTheme.textHint;
    if (importance.contains('Must')) impColor = Colors.redAccent;
    if (importance.contains('Hidden')) impColor = AppTheme.accentColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              Image.network(
                spot['image_url'] ?? 'https://images.unsplash.com/photo-1548013146-72479768bada?w=800',
                height: 220, width: double.infinity, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 220,
                  color: catColor.withAlpha(30),
                  child: Center(child: Icon(catIcon, size: 56, color: catColor)),
                ),
              ),
              Positioned(top: 16, left: 16,
                  child: _Badge(label: category.toUpperCase(), icon: catIcon, color: Colors.black.withAlpha(150))),
              if (distance > 0)
                Positioned(top: 16, right: 16,
                    child: _Badge(label: '${distance.toStringAsFixed(1)} KM',
                        icon: Icons.near_me_rounded, color: AppTheme.primary.withAlpha(200))),
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
                      child: Text(spot['name'] ?? 'Unknown Spot',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: impColor.withAlpha(20),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: impColor.withAlpha(40)),
                      ),
                      child: Text(importance.toUpperCase(),
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: impColor)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(spot['description'] ?? '', style: const TextStyle(color: AppTheme.textHint, height: 1.4)),
                if (spot['recommendation'] != null) ...[
                  const SizedBox(height: 20),
                  const Text('WHY IT MATTERS',
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: AppTheme.textHint)),
                  const SizedBox(height: 8),
                  Text(spot['recommendation'],
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                ],
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: catColor.withAlpha(15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: catColor.withAlpha(30)),
                  ),
                  child: Row(children: [
                    Icon(Icons.camera_rounded, color: catColor, size: 20),
                    const SizedBox(width: 12),
                    Expanded(child: Text(spot['photography_tip'] ?? '',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                            color: catColor, fontStyle: FontStyle.italic))),
                  ]),
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
  final String label; final IconData icon; final Color color;
  const _Badge({required this.label, required this.icon, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: Colors.white, size: 14),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1)),
      ]),
    );
  }
}
