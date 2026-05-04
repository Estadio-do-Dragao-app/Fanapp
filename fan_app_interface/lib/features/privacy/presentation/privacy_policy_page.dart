import 'package:flutter/material.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Privacy Policy for Public Area Navigator',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Text(
              'Effective Date: May 2026',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
            SizedBox(height: 16),
            Text(
              '1. Introduction',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Welcome to our application. This policy describes how we collect, use, and process your data while you are using the app within the public area. We are committed to protecting your privacy and complying with data protection regulations.',
            ),
            SizedBox(height: 16),
            Text(
              '2. Legal Basis for Processing',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Our legal basis for processing your data is your consent under Art. 6(1)(a) GDPR, subject to the conditions set out in Art. 7 GDPR. You are asked to provide this consent upon starting the application for the first time.',
            ),
            SizedBox(height: 16),
            Text(
              '3. Data Collection and Usage',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'We collect anonymous location data to provide navigation and routing services. '
              'Our local camera-based analytics do not capture personally identifiable information (PII). '
              'The data is strictly used for estimating wait times and crowd congestion to improve your experience.',
            ),
            SizedBox(height: 16),
            Text(
              '4. Data Retention (Storage Limitation)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'In accordance with Art. 5.1.e, any operational data collected (such as camera events or congestion metrics) is retained only as long as necessary to provide the service, and is automatically deleted within 24 hours.',
            ),
            SizedBox(height: 16),
            Text(
              '5. Your Rights',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'You have the right to withdraw your consent at any time by uninstalling the application or clearing its local storage. Since we do not collect PII or maintain user accounts, we cannot identify individual records to fulfill specific data deletion requests beyond our automatic 24-hour retention policy.',
            ),
            SizedBox(height: 32),
            Text(
              'If you have any questions, please contact the public area administration.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
