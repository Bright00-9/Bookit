class AppSettings {
  final double jobRadiusKm;
  final bool notifyNewJobs;
  final bool notifyApplicationUpdates;
  final bool notifyMessages;
  final bool notifyPromotions;
  final bool showTips;

  AppSettings({
    this.jobRadiusKm = 10,
    this.notifyNewJobs = true,
    this.notifyApplicationUpdates = true,
    this.notifyMessages = true,
    this.notifyPromotions = false,
    this.showTips = true,
  });

  Map<String, dynamic> toJson() => {
    'job_radius_km': jobRadiusKm,
    'notify_new_jobs': notifyNewJobs,
    'notify_application_updates': notifyApplicationUpdates,
    'notify_messages': notifyMessages,
    'notify_promotions': notifyPromotions,
    'show_tips': showTips,
  };

  AppSettings copyWith({
    double? jobRadiusKm,
    bool? notifyNewJobs,
    bool? notifyApplicationUpdates,
    bool? notifyMessages,
    bool? notifyPromotions,
    bool? showTips, 
  }) =>
      AppSettings(
        jobRadiusKm: jobRadiusKm ?? this.jobRadiusKm,
        notifyNewJobs: notifyNewJobs ?? this.notifyNewJobs,
        notifyApplicationUpdates:
            notifyApplicationUpdates ?? this.notifyApplicationUpdates,
        notifyMessages: notifyMessages ?? this.notifyMessages,
        notifyPromotions: notifyPromotions ?? this.notifyPromotions,
        showTips: showTips ?? this.showTips,
      );

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        jobRadiusKm: (json['job_radius_km'] ?? 10).toDouble(),
        notifyNewJobs: json['notify_new_jobs'] ?? true,
        notifyApplicationUpdates: json['notify_application_updates'] ?? true,
        notifyMessages: json['notify_messages'] ?? true,
        notifyPromotions: json['notify_promotions'] ?? false,
        showTips: json['show_tips'] ?? true,
      );
}