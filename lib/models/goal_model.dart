class FocusGoal {
  final String category;
  final int targetSeconds;

  FocusGoal({required this.category, required this.targetSeconds});

  Map<String, dynamic> toJson() => {
        'category': category,
        'targetSeconds': targetSeconds,
      };

  factory FocusGoal.fromJson(Map<String, dynamic> json) => FocusGoal(
        category: json['category'] ?? '',
        targetSeconds: json['targetSeconds'] ?? 0,
      );
}
