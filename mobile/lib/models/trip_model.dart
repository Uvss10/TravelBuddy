import 'dart:convert';

import 'package:equatable/equatable.dart';

// ─── Models ──────────────────────────────────────────────────────────────────

/// Represents a single travel trip.
class TripModel extends Equatable {
  final String id;
  final String destination;
  final String? country;
  final int days;
  final String budget;
  final List<String> interests;
  final String? itineraryOutput;
  final String? storyTitle;
  final String? storyNarration;
  final List<String> captions;
  final List<String> hashtags;
  final List<String> selectedImagePaths;
  final DateTime createdAt;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool isFavorite;
  final double? latitude;
  final double? longitude;

  const TripModel({
    required this.id,
    required this.destination,
    this.country,
    required this.days,
    required this.budget,
    required this.interests,
    this.itineraryOutput,
    this.storyTitle,
    this.storyNarration,
    this.captions = const [],
    this.hashtags = const [],
    this.selectedImagePaths = const [],
    required this.createdAt,
    this.startDate,
    this.endDate,
    this.isFavorite = false,
    this.latitude,
    this.longitude,
  });

  /// Create from itinerary API response JSON.
  factory TripModel.fromItineraryJson(Map<String, dynamic> json) {
    final rawItinerary = json['itinerary_ai_output'];

    String? itineraryOutput;
    if (rawItinerary is String) {
      itineraryOutput = rawItinerary;
    } else if (rawItinerary is Map || rawItinerary is List) {
      itineraryOutput = jsonEncode(rawItinerary);
    }

    return TripModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      destination: json['destination'] ?? '',
      days: json['total_days'] ?? 0,
      budget: json['budget_category'] ?? '',
      interests: List<String>.from(json['interests'] ?? const []),
      itineraryOutput: itineraryOutput,
      createdAt: DateTime.now(),
    );
  }

  /// Merge story data into this trip.
  TripModel copyWithStory(Map<String, dynamic> storyJson) {
    return TripModel(
      id: id,
      destination: destination,
      country: country,
      days: days,
      budget: budget,
      interests: interests,
      itineraryOutput: itineraryOutput,
      storyTitle: storyJson['title'],
      storyNarration: storyJson['narration'],
      captions: List<String>.from(storyJson['captions'] ?? []),
      hashtags: List<String>.from(storyJson['hashtags'] ?? []),
      selectedImagePaths: selectedImagePaths,
      createdAt: createdAt,
      startDate: startDate,
      endDate: endDate,
      isFavorite: isFavorite,
      latitude: latitude,
      longitude: longitude,
    );
  }

  TripModel copyWith({
    String? id,
    String? destination,
    String? country,
    int? days,
    String? budget,
    List<String>? interests,
    String? itineraryOutput,
    String? storyTitle,
    String? storyNarration,
    List<String>? captions,
    List<String>? hashtags,
    List<String>? selectedImagePaths,
    DateTime? createdAt,
    DateTime? startDate,
    DateTime? endDate,
    bool? isFavorite,
    double? latitude,
    double? longitude,
  }) {
    return TripModel(
      id: id ?? this.id,
      destination: destination ?? this.destination,
      country: country ?? this.country,
      days: days ?? this.days,
      budget: budget ?? this.budget,
      interests: interests ?? this.interests,
      itineraryOutput: itineraryOutput ?? this.itineraryOutput,
      storyTitle: storyTitle ?? this.storyTitle,
      storyNarration: storyNarration ?? this.storyNarration,
      captions: captions ?? this.captions,
      hashtags: hashtags ?? this.hashtags,
      selectedImagePaths: selectedImagePaths ?? this.selectedImagePaths,
      createdAt: createdAt ?? this.createdAt,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isFavorite: isFavorite ?? this.isFavorite,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'destination': destination,
    'country': country,
    'days': days,
    'budget': budget,
    'interests': interests,
    'itinerary_output': itineraryOutput,
    'story_title': storyTitle,
    'story_narration': storyNarration,
    'captions': captions,
    'hashtags': hashtags,
    'created_at': createdAt.toIso8601String(),
    'start_date': startDate?.toIso8601String(),
    'end_date': endDate?.toIso8601String(),
    'is_favorite': isFavorite,
    'latitude': latitude,
    'longitude': longitude,
  };

  @override
  List<Object?> get props => [
    id, destination, country, days, budget, interests, itineraryOutput,
    storyTitle, storyNarration, captions, hashtags, selectedImagePaths,
    createdAt, startDate, endDate, isFavorite, latitude, longitude,
  ];
}

/// Itinerary day model — holds day label and list of activities.
class ItineraryDay {
  final String label;       // e.g. "Day 1"
  final List<String> activities;

  const ItineraryDay({required this.label, required this.activities});

  /// Parse the itinerary_ai_output map.
  static List<ItineraryDay> parseFromMap(Map<String, dynamic> map) {
    // New backend format:
    // {
    //   "trip_summary": {...},
    //   "days": [
    //     {"day": 1, "activities": [{"place_name": "...", ...}]}
    //   ]
    // }
    final rawDays = map['days'];
    if (rawDays is List) {
      return rawDays
          .whereType<Map<String, dynamic>>()
          .map((dayMap) {
            final dayNumber = dayMap['day'];
            final activities = (dayMap['activities'] as List? ?? const [])
                .whereType<Map<String, dynamic>>()
                .map((activity) {
                  final place = (activity['place_name'] ?? '').toString().trim();
                  final time = (activity['recommended_time'] ?? '').toString().trim();
                  final desc = (activity['description'] ?? '').toString().trim();

                  final parts = <String>[];
                  if (time.isNotEmpty) parts.add(time);
                  if (place.isNotEmpty) parts.add(place);
                  if (desc.isNotEmpty) parts.add(desc);

                  return parts.isEmpty ? 'Activity' : parts.join(' • ');
                })
                .toList();

            final label = dayNumber == null ? 'Day' : 'Day $dayNumber';
            return ItineraryDay(label: label, activities: activities);
          })
          .toList();
    }

    // Legacy format fallback:
    // {
    //   "Day 1": ["..."]
    // }
    return map.entries.map((e) {
      final activities = (e.value as List).map((a) => a.toString()).toList();
      return ItineraryDay(label: e.key, activities: activities);
    }).toList();
  }
}

/// Image analysis result returned from backend.
class ImageAnalysisResult {
  final String imagePath;
  final double finalQualityScore;
  final String quality;
  final Map<String, double> metrics;

  const ImageAnalysisResult({
    required this.imagePath,
    required this.finalQualityScore,
    required this.quality,
    required this.metrics,
  });

  factory ImageAnalysisResult.fromJson(Map<String, dynamic> json) {
    final rawMetrics = (json['metrics'] as Map<String, dynamic>?) ?? {};
    return ImageAnalysisResult(
      imagePath: json['image_path'] ?? '',
      finalQualityScore: (json['final_quality_score'] as num?)?.toDouble() ?? 0.0,
      quality: json['quality'] ?? 'Unknown',
      metrics: rawMetrics.map((k, v) => MapEntry(k, (v as num).toDouble())),
    );
  }
}

/// User model (local auth — no backend auth yet).
class UserModel {
  final String name;
  final String email;

  const UserModel({required this.name, required this.email});

  factory UserModel.fromJson(Map<String, dynamic> json) =>
      UserModel(name: json['name'] ?? '', email: json['email'] ?? '');

  Map<String, dynamic> toJson() => {'name': name, 'email': email};
}

