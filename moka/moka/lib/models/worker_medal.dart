import 'package:flutter/material.dart';

enum WorkerMedal { bronze, silver, gold }

extension WorkerMedalExtension on WorkerMedal {
  String get label {
    switch (this) {
      case WorkerMedal.bronze:
        return 'Bronze';
      case WorkerMedal.silver:
        return 'Silver';
      case WorkerMedal.gold:
        return 'Gold';
    }
  }

  String get emoji {
    return label;
  }

  // Profile card background tint
  Color get backgroundColor {
    switch (this) {
      case WorkerMedal.bronze:
        return const Color(0xFFFFF3E0); // warm orange tint
      case WorkerMedal.silver:
        return const Color(0xFFF5F5F5); // cool grey tint
      case WorkerMedal.gold:
        return const Color(0xFFFFFDE7); // warm yellow tint
    }
  }

  // Border/accent color
  Color get accentColor {
    switch (this) {
      case WorkerMedal.bronze:
        return const Color(0xFFCD7F32); // bronze
      case WorkerMedal.silver:
        return const Color(0xFF9E9E9E); // silver
      case WorkerMedal.gold:
        return const Color(0xFFFFD700); // gold
    }
  }

  // Medal icon color
  Color get medalColor {
    switch (this) {
      case WorkerMedal.bronze:
        return const Color(0xFFCD7F32);
      case WorkerMedal.silver:
        return const Color(0xFF9E9E9E);
      case WorkerMedal.gold:
        return const Color(0xFFFFD700);
    }
  }

  // Star rating color
  Color get starColor {
    switch (this) {
      case WorkerMedal.bronze:
        return const Color(0xFFCD7F32);
      case WorkerMedal.silver:
        return const Color(0xFF9E9E9E);
      case WorkerMedal.gold:
        return const Color(0xFFFFD700);
    }
  }
}

// ── Core function — call this anywhere you have a rating ──
WorkerMedal getMedal(double rating) {
  if (rating <= 2.5) return WorkerMedal.bronze;
  if (rating <= 4.3) return WorkerMedal.silver;
  return WorkerMedal.gold;
}