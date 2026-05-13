import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../../config/routes.dart';

import '../../services/video_cache_manager.dart';

/// Download & Share screen.
class DownloadShareScreen extends StatelessWidget {
  final String? videoUrl;
  const DownloadShareScreen({super.key, this.videoUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Download & Share')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Success illustration
          Center(
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppTheme.success.withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_outline, size: 56, color: AppTheme.success),
            ),
          ),
          const SizedBox(height: 20),
          Text('Your Reel is Ready!', textAlign: TextAlign.center, style: Theme.of(context).textTheme.displaySmall),
          const SizedBox(height: 8),
          Text(
            'Download or share your cinematic travel reel.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 40),

          _ShareOption(
            icon: Icons.download_rounded,
            label: 'Download Reel',
            sub: 'Save to your device gallery',
            onTap: () async {
              if (videoUrl == null || videoUrl!.isEmpty) return;
              Fluttertoast.showToast(msg: 'Saving to Gallery...', backgroundColor: AppTheme.success);
              final success = await VideoCacheManager.saveToGallery(videoUrl!);
              if (success) {
                Fluttertoast.showToast(msg: 'Saved automatically to Gallery! 🎉', backgroundColor: AppTheme.success);
              } else {
                Fluttertoast.showToast(msg: 'Failed to save to Gallery.', backgroundColor: AppTheme.error);
              }
            },
          ),
          const SizedBox(height: 12),
          _ShareOption(
            icon: Icons.share_outlined,
            label: 'Share to Apps',
            sub: 'Instagram, WhatsApp, more…',
            onTap: () async {
              if (videoUrl == null || videoUrl!.isEmpty) {
                Share.share('Check out my TravelBuddy reel! 🌍✈️ #TravelBuddy #TravelReel');
                return;
              }
              try {
                Fluttertoast.showToast(msg: 'Preparing video for share...', backgroundColor: AppTheme.primary);
                final file = await VideoCacheManager.fetchAndCacheVideo(videoUrl!);
                await Share.shareXFiles(
                  [XFile(file.path)],
                  text: 'Check out my TravelBuddy reel! 🌍✈️ #TravelBuddy #TravelReel',
                );
              } catch (e) {
                Share.share('Check out my TravelBuddy reel! 🌍✈️ $videoUrl\n#TravelBuddy #TravelReel');
              }
            },
          ),
          const SizedBox(height: 12),
          _ShareOption(
            icon: Icons.link,
            label: 'Copy Link',
            sub: 'Share a link to your reel',
            onTap: () {
              if (videoUrl != null && videoUrl!.isNotEmpty) {
                // To actually copy to clipboard you would use:
                // Clipboard.setData(ClipboardData(text: videoUrl!));
                Share.share('Check out my TravelBuddy reel! 🌍✈️ $videoUrl\n#TravelBuddy #TravelReel');
                Fluttertoast.showToast(msg: 'Link prepared!', backgroundColor: AppTheme.success);
              } else {
                Fluttertoast.showToast(msg: 'No link available.', backgroundColor: AppTheme.error);
              }
            },
          ),
          const SizedBox(height: 40),

          TBSecondaryButton(
            label: 'Plan Another Trip',
            icon: Icons.add,
            onPressed: () {
              Navigator.pushNamedAndRemoveUntil(
                context,
                AppRoutes.createTrip,
                (r) => r.settings.name == AppRoutes.home,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ShareOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sub;
  final VoidCallback onTap;
  const _ShareOption({required this.icon, required this.label, required this.sub, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TBCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.bgLight,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppTheme.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.titleLarge),
                Text(sub, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppTheme.textHint),
        ],
      ),
    );
  }
}
