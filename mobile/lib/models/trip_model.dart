// ─── Models ──────────────────────────────────────────────────────────────────

/// Represents a single travel trip.
class TripModel {
  final String id;
  final String destination;
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

  const TripModel({
    required this.id,
    required this.destination,
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
  });

  /// Create from itinerary API response JSON.
  factory TripModel.fromItineraryJson(Map<String, dynamic> json) {
    return TripModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      destination: json['destination'] ?? '',
      days: json['total_days'] ?? 0,
      budget: json['budget_category'] ?? '',
      interests: const [],
      itineraryOutput: json['itinerary_ai_output']?.toString(),
      createdAt: DateTime.now(),
    );
  }

  /// Merge story data into this trip.
  TripModel copyWithStory(Map<String, dynamic> storyJson) {
    return TripModel(
      id: id,
      destination: destination,
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
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'destination': destination,
    'days': days,
    'budget': budget,
    'interests': interests,
    'itinerary_output': itineraryOutput,
    'story_title': storyTitle,
    'story_narration': storyNarration,
    'captions': captions,
    'hashtags': hashtags,
    'created_at': createdAt.toIso8601String(),
  };
}

/// Itinerary day model — holds day label and list of activities.
class ItineraryDay {
  final String label;       // e.g. "Day 1"
  final List<String> activities;

  const ItineraryDay({required this.label, required this.activities});

  /// Parse the itinerary_ai_output map.
  static List<ItineraryDay> parseFromMap(Map<String, dynamic> map) {
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
