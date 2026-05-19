import 'dart:math';
import 'package:flutter/material.dart';
import 'app_tips.dart';
import 'Services/role_service.dart';
import 'Services/tips_service.dart';

class AppTipDialog extends StatelessWidget {
  final AppTip tip;

  const AppTipDialog({super.key, required this.tip});

  // ── Main entry point ──────────────────────────────────────────
  // Call this from initState of your home/main screen.
  // Pass forceShow: true from the "Show a Tip Now" button in Settings.
  static Future<void> showIfEnabled(
    BuildContext context, {
    bool forceShow = false,
  }) async {
    try {
      final tipsService = TipsService();
      final roleService = RoleService();

      // Check if tips are enabled unless forced
      if (!forceShow) {
        final enabled = await tipsService.getTipsEnabled();
        if (!enabled) return;
      }

      // Fetch role from users table
      final role = await roleService.fetchRole();

      // Filter tips by role
      final filtered = appTips.where((tip) {
        switch (tip.audience) {
          case TipAudience.all:
            return true;
          case TipAudience.customer:
            return role == UserRole.customer;
          case TipAudience.worker:
            return role == UserRole.worker;
        }
      }).toList();

      // Fallback to general tips if role is unknown or filtered list is empty
      final pool = filtered.isNotEmpty
          ? filtered
          : appTips.where((t) => t.audience == TipAudience.all).toList();

      if (pool.isEmpty) return;

      // Pick random tip
      final tip = pool[Random().nextInt(pool.length)];

      if (context.mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AppTipDialog(tip: tip),
        );
      }
    } catch (_) {
      // Fail silently — tips are non-critical
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [

            // ── Header ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.lightbulb_outline,
                        size: 14,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Tip of the Day',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Emoji ──
            Text(tip.emoji, style: const TextStyle(fontSize: 52)),
            const SizedBox(height: 12),

            // ── Title ──
            Text(
              tip.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),

            // ── Body ──
            Text(
              tip.body,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),

            // ── Got it button ──
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Got it!'),
              ),
            ),

            // ── Disable tips ──
            TextButton(
              onPressed: () async {
                await TipsService().disableTips();
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text(
                "Don't show tips anymore",
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}