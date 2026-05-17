import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'privacy_policy_page.dart';

class ConsentModal extends StatelessWidget {
  final VoidCallback onAccepted;

  const ConsentModal({super.key, required this.onAccepted});

  static Future<bool> hasConsented() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('privacy_consent_accepted') ?? false;
  }

  static Future<void> setConsented(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('privacy_consent_accepted', value);
    
    // Generate or get an anonymous User ID for audit logs
    String? userId = prefs.getString('anonymous_user_id');
    if (userId == null) {
      userId = const Uuid().v4();
      await prefs.setString('anonymous_user_id', userId);
    }
    
    // Send audit log to backend for both granted and denied
    try {
      // Use the IP address of your machine or service
      // In local dev with adb reverse, localhost:8001 points to WaitTime-Service
      final url = Uri.parse('http://localhost:8001/api/v1/privacy/consent');
      await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': 'dragao_secret_key_2026'
        },
        body: jsonEncode({
          'user_id': userId,
          'action': value ? 'granted' : 'denied',
          'timestamp': DateTime.now().toUtc().toIso8601String(),
        }),
      ).timeout(const Duration(seconds: 3));
    } catch (e) {
      debugPrint('Failed to send consent audit: $e');
    }
  }

  static void show(BuildContext context, {required VoidCallback onAccepted}) {
    showDialog(
      context: context,
      barrierDismissible: false, // User must interact
      builder: (context) => ConsentModal(
        onAccepted: () {
          Navigator.of(context).pop();
          onAccepted();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Privacy & Data Processing Consent'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Welcome to the Public Area Navigator.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'To provide you with navigation and real-time updates within the area, '
              'this app needs to process your approximate location data. '
              'Wait times and crowd density are calculated anonymously using our cameras, which use AI strictly to count the number of people.',
            ),
            const SizedBox(height: 12),
            const Text(
              'We do not collect any personally identifiable information (PII). '
              'All processing is based on your consent.',
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const PrivacyPolicyPage(),
                  ),
                );
              },
              child: const Text(
                'Read our full Privacy Policy',
                style: TextStyle(
                  color: Colors.blue,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () async {
            await setConsented(false);
            Navigator.of(context).pop();
            // Deny tracking by disabling LocationService
            // In production, navigate to a blocked screen or exit the app
          },
          child: const Text(
            'Decline',
            style: TextStyle(color: Colors.red),
          ),
        ),
        ElevatedButton(
          onPressed: () async {
            await setConsented(true);
            onAccepted();
          },
          child: const Text('I Accept'),
        ),
      ],
    );
  }
}
