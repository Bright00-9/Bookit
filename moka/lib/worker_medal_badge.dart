import 'package:flutter/material.dart';
import 'worker_medal.dart';

class WorkerMedalBadge extends StatelessWidget {
  final WorkerMedal medal;
  final bool showLabel;

  const WorkerMedalBadge({
    super.key,
    required this.medal,
    this.showLabel = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: medal.backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: medal.accentColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(medal.emoji, style: const TextStyle(fontSize: 13)),
          if (showLabel) ...[
            const SizedBox(width: 4),
            Text(
              medal.label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: medal.accentColor,
              ),
            ),
          ],
        ],
      ),
    );
  }
}