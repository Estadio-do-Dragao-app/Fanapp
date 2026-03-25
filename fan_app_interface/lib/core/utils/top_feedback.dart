import 'package:flutter/material.dart';

/// App-wide top feedback using [MaterialBanner].
class AppTopFeedback {
  static int _warningBannerToken = 0;

  static void showWarning(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
    Color backgroundColor = const Color(0xFFE65100),
    IconData icon = Icons.warning_amber_rounded,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    final token = ++_warningBannerToken;

    messenger.hideCurrentMaterialBanner();

    messenger.showMaterialBanner(
      MaterialBanner(
        backgroundColor: backgroundColor,
        leading: Icon(icon, color: Colors.white),
        content: Text(message, style: const TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: messenger.hideCurrentMaterialBanner,
            child: const Text(
              'OK',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    Future.delayed(duration, () {
      // Only auto-hide if this is still the latest warning banner request.
      if (token != _warningBannerToken) return;
      messenger.hideCurrentMaterialBanner();
    });
  }
}
