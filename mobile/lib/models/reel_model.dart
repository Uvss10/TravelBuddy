import 'package:equatable/equatable.dart';

/// Represents a generated reel/video
class ReelModel extends Equatable {
  final String id;
  final String title;
  final String destination;
  final String tone;
  final String story;
  final String narration;
  final List<String> captions;
  final List<String> hashtags;
  final String videoUrl;
  final String thumbnailUrl;
  final DateTime createdAt;
  final Duration duration;
  final int imageCount;
  final bool isFavorite;
  final String? shareUrl;

  const ReelModel({
    required this.id,
    required this.title,
    required this.destination,
    required this.tone,
    required this.story,
    required this.narration,
    required this.captions,
    required this.hashtags,
    required this.videoUrl,
    required this.thumbnailUrl,
    required this.createdAt,
    required this.duration,
    required this.imageCount,
    this.isFavorite = false,
    this.shareUrl,
  });

  ReelModel copyWith({
    String? id,
    String? title,
    String? destination,
    String? tone,
    String? story,
    String? narration,
    List<String>? captions,
    List<String>? hashtags,
    String? videoUrl,
    String? thumbnailUrl,
    DateTime? createdAt,
    Duration? duration,
    int? imageCount,
    bool? isFavorite,
    String? shareUrl,
  }) {
    return ReelModel(
      id: id ?? this.id,
      title: title ?? this.title,
      destination: destination ?? this.destination,
      tone: tone ?? this.tone,
      story: story ?? this.story,
      narration: narration ?? this.narration,
      captions: captions ?? this.captions,
      hashtags: hashtags ?? this.hashtags,
      videoUrl: videoUrl ?? this.videoUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      createdAt: createdAt ?? this.createdAt,
      duration: duration ?? this.duration,
      imageCount: imageCount ?? this.imageCount,
      isFavorite: isFavorite ?? this.isFavorite,
      shareUrl: shareUrl ?? this.shareUrl,
    );
  }

  @override
  List<Object?> get props => [
    id, title, destination, tone, story, narration, captions, hashtags,
    videoUrl, thumbnailUrl, createdAt, duration, imageCount, isFavorite, shareUrl,
  ];
}
