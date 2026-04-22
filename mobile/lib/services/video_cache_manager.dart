import 'dart:io';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart';

class VideoCacheManager {
  // Custom cache instance specifically tuned for large video files
  static const key = 'travelBuddyCinematicVideoCache';
  
  static final CacheManager instance = CacheManager(
    Config(
      key,
      stalePeriod: const Duration(days: 15), // Keep generated travel videos around for 15 days
      maxNrOfCacheObjects: 50, // Keep last 50 reels
      repo: JsonCacheInfoRepository(databaseName: key),
      fileService: HttpFileService(),
    ),
  );

  /// Download and cache the video. Returns the exact local File.
  /// Pre-fetching this before playing ensures ZERO buffering drops.
  static Future<File> fetchAndCacheVideo(String url) async {
    try {
      final fileInfo = await instance.downloadFile(url);
      return fileInfo.file;
    } catch (e) {
      throw Exception('Failed to cache video: $e');
    }
  }

  /// Downloads the video to the local gallery using gal
  static Future<bool> saveToGallery(String videoUrl) async {
    try {
      // Ensure it's cached first to save bandwidth/time
      final fileInfo = await instance.getFileFromCache(videoUrl);
      String path;
      if (fileInfo != null) {
        path = fileInfo.file.path;
      } else {
        path = videoUrl; // Fallback to network download
      }

      await Gal.putVideo(path, album: 'TravelBuddy Reels');
      return true;
    } catch (e) {
      return false;
    }
  }
  
  /// Clear specific video
  static Future<void> removeVideo(String url) async {
    await instance.removeFile(url);
  }
}
