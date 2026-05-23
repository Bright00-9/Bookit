import 'package:flutter/material.dart';
import 'worker_medal.dart';
import 'worker_medal_badge.dart';

class WorkerProfileCard extends StatelessWidget {
  final String workerId;
  final String name;
  final String? avatarUrl;
  final String? jobTitle;       // e.g. "Plumber", "Electrician"
  final double? rating;
  final int? completedJobs;
  final bool isVerified;
  final VoidCallback? onTap;

  const WorkerProfileCard({
    super.key,
    required this.workerId,
    required this.name,
    this.avatarUrl,
    this.jobTitle,
    this.rating,
    this.completedJobs,
    this.isVerified = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Determine medal — null if no rating yet
    final medal = rating != null ? getMedal(rating!) : null;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: medal?.backgroundColor ?? Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: medal?.accentColor.withOpacity(0.4) ??
                Colors.grey.shade200,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: medal?.accentColor.withOpacity(0.08) ??
                  Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [

              // ── Avatar with medal overlay ──
              Stack(
                clipBehavior: Clip.none,
                children: [
                  // Avatar
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: medal?.accentColor ??
                            Colors.grey.shade300,
                        width: 2.5,
                      ),
                    ),
                    child: ClipOval(
                      child: avatarUrl != null
                          ? Image.network(
                              avatarUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _defaultAvatar(),
                            )
                          : _defaultAvatar(),
                    ),
                  ),

                  // Medal emoji on bottom-right of avatar
                  if (medal != null)
                    Positioned(
                      bottom: -4,
                      right: -4,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: medal.accentColor, width: 1),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Text(
                          medal.emoji,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 14),

              // ── Name, title, rating ──
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // Name + verified badge
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isVerified) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.verified,
                              color: Colors.blue, size: 16),
                        ],
                      ],
                    ),

                    if (jobTitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        jobTitle!,
                        style: const TextStyle(
                            color: Colors.grey, fontSize: 12),
                      ),
                    ],

                    const SizedBox(height: 6),

                    // Rating stars + medal badge
                    Row(
                      children: [
                        if (rating != null) ...[
                          // Star icon
                          Icon(
                            Icons.star_rounded,
                            size: 16,
                            color: medal?.starColor ?? Colors.amber,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            rating!.toStringAsFixed(1),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: medal?.accentColor ?? Colors.grey,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Medal badge with label
                          WorkerMedalBadge(
                            medal: medal!,
                            showLabel: true,
                          ),
                        ] else ...[
                          const Text(
                            'No ratings yet',
                            style: TextStyle(
                                color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // ── Completed jobs + chevron ──
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Icon(Icons.chevron_right, color: Colors.grey),
                  if (completedJobs != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '$completedJobs jobs',
                      style: const TextStyle(
                          fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _defaultAvatar() {
    return Container(
      color: Colors.grey.shade200,
      child: const Icon(Icons.person, color: Colors.grey, size: 30),
    );
  }
}