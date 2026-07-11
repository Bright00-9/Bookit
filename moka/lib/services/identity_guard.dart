import 'package:flutter/material.dart';
import '../services/identity_verification_service.dart';
import '../screens/identity_verification_screen.dart';

class IdentityGuard {
  // Call before any action that requires verification
  // Returns true if user can proceed, false if blocked
  static Future<bool> check(
    BuildContext context, {
    String action = 'perform this action',
  }) async {
    try {
      final service = IdentityVerificationService();
      final canProceed = await service.canPerformActions();

      if (canProceed) return true;

      if (!context.mounted) return false;

      // Show blocking dialog
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B00)
                      .withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.shield_outlined,
                    color: Color(0xFFFF6B00), size: 32),
              ),
              const SizedBox(height: 16),
              const Text('Verification Required',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(
                'You need to verify your identity to $action. It only takes a few minutes.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Color(0xFF888888),
                    fontSize: 13),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const IdentityVerificationScreen(
                                isBlocking: true),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        const Color(0xFFFF6B00),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text('Verify Now',
                      style: TextStyle(
                          fontWeight: FontWeight.w700)),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Maybe Later',
                    style: TextStyle(
                        color: Color(0xFF888888),
                        fontSize: 13)),
              ),
            ],
          ),
        ),
      );

      return false;
    } catch (_) {
      return false;
    }
  }
}