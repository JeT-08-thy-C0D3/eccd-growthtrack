import 'package:flutter/material.dart';

class TermsPrivacyDialog extends StatelessWidget {
  const TermsPrivacyDialog({super.key});

  static Future<void> show(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (context) => const TermsPrivacyDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.gavel, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Terms of Service & Privacy Notice',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 600,
        height: 450,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader('Republic Act 10173 & Republic Act 12199 Compliance'),
              const Text(
                'ECCD GrowthTrack operates in strict compliance with Republic Act No. 10173 (Data Privacy Act of 2012) and Republic Act No. 12199 (Early Childhood Care and Development System Act). By accessing and using this application, you acknowledge and agree to the data privacy and child protection standards outlined below.',
                style: TextStyle(fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 16),

              _buildHeader('1. Data Privacy Act of 2012 (R.A. 10173) Compliance'),
              _buildBulletPoint('Scope of Processing', 'We collect and process personal and sensitive personal information including child names, birth dates, developmental assessment domain scores, attendance records, parent observations, and developmental referral notes.'),
              _buildBulletPoint('Lawful Basis & Consent', 'Processing of data is conducted strictly for public function and government mandated early childhood monitoring by the Municipal Social Welfare and Development (MSWD) Office and registered day care centers, supported by explicit parental/guardian consent.'),
              _buildBulletPoint('Security Safeguards', 'All transmitted data is encrypted over HTTPS/SSL. Data stored on device is protected via local SQLite cache policies and Cloud Firestore security rules.'),
              _buildBulletPoint('Data Subject Rights', 'Parents and legal guardians have the right to access, inspect, request corrections to, and request copy logs of their child’s records in accordance with Section 16 of R.A. 10173.'),

              const SizedBox(height: 16),
              _buildHeader('2. ECCD System Act (R.A. 12199) Compliance'),
              _buildBulletPoint('Confidentiality of Child Records', 'Child assessment scores, domain evaluations, and referral records are classified as confidential welfare information. Access is restricted exclusively to authorized MSWD officers, assigned ECCD teachers, and verified parents.'),
              _buildBulletPoint('Child Protection & Welfare', 'Referral notes and developmental intervention records are processed solely to support early intervention and provide necessary assistance to children requiring special monitoring.'),

              const SizedBox(height: 16),
              _buildHeader('3. Storage & Retention Policy'),
              _buildBulletPoint('Storage Infrastructure', 'Data is securely stored using Google Cloud Firestore and Supabase Storage (for media attachments). Offline records are temporarily cached locally on authorized devices and synced automatically.'),
              _buildBulletPoint('Retention Period', 'Records are retained for the duration of the child’s enrollment in municipal ECCD centers and archived securely as mandated by local government record disposal guidelines.'),

              const SizedBox(height: 16),
              _buildHeader('4. Contact Data Protection Officer'),
              const Text(
                'For inquiries, concerns, or requests regarding your data privacy rights, please contact the Municipal Social Welfare and Development Office (MSWD) Data Protection Officer.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('I Understand & Agree'),
        ),
      ],
    );
  }

  Widget _buildHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 8),
      child: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blue),
      ),
    );
  }

  Widget _buildBulletPoint(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 8.0),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 12, color: Colors.black87, height: 1.3),
          children: [
            TextSpan(text: '• $title: ', style: const TextStyle(fontWeight: FontWeight.bold)),
            TextSpan(text: description),
          ],
        ),
      ),
    );
  }
}
