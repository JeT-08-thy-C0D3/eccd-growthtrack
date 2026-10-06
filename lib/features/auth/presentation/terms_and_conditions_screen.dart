import 'package:flutter/material.dart';

class TermsAndConditionsScreen extends StatelessWidget {
  const TermsAndConditionsScreen({super.key});

  static Future<bool?> show(BuildContext context) {
    return Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const TermsAndConditionsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms & Conditions'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ECCD GrowthTrack — Terms & Conditions',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Effective Date: October 2026 | Compliant with R.A. 10173 & R.A. 12199',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const Divider(height: 32),

                _buildSectionTitle('1. Acceptance of Terms'),
                const Text(
                  'By registering an account and using the ECCD GrowthTrack application, you explicitly agree to comply with and be bound by these Terms and Conditions. If you do not agree to these terms, you must not create an account or access the system.',
                  style: TextStyle(fontSize: 14, height: 1.4),
                ),

                const SizedBox(height: 20),
                _buildSectionTitle('2. Compliance with Republic Act No. 10173 (Data Privacy Act of 2012)'),
                const Text(
                  'ECCD GrowthTrack strictly adheres to R.A. 10173 regarding the processing of personal and sensitive personal information of parents, teachers, and child beneficiaries:',
                  style: TextStyle(fontSize: 14, height: 1.4),
                ),
                const SizedBox(height: 8),
                _buildBulletPoint('Scope of Data Collection', 'We collect full names, email addresses, roles, child profiles, developmental assessment scores, attendance logs, and referral records strictly for early childhood development monitoring.'),
                _buildBulletPoint('Consent & Acceptance', 'By checking "I agree to the Terms and Conditions", you grant explicit consent for processing your data and your child’s records in accordance with R.A. 10173.'),
                _buildBulletPoint('Data Protection Safeguards', 'All transmitted data is encrypted. Acceptance timestamps and user profiles are stored securely in Google Cloud Firestore.'),

                const SizedBox(height: 20),
                _buildSectionTitle('3. Compliance with Republic Act No. 12199 (ECCD System Act)'),
                const Text(
                  'In accordance with R.A. 12199, child evaluation records, domain scores, and intervention referral records are classified as confidential welfare information:',
                  style: TextStyle(fontSize: 14, height: 1.4),
                ),
                const SizedBox(height: 8),
                _buildBulletPoint('Restricted Access', 'System access is granted exclusively to authorized Municipal Social Welfare and Development (MSWD) officers, registered ECCD teachers, and verified parents.'),
                _buildBulletPoint('Data Purpose', 'All developmental records are processed solely for child progress tracking and early intervention support.'),

                const SizedBox(height: 20),
                _buildSectionTitle('4. Account Responsibilities'),
                _buildBulletPoint('Credential Confidentiality', 'Account holders are responsible for maintaining the confidentiality of their login credentials.'),
                _buildBulletPoint('Authorized Use', 'Creating unauthorized accounts or attempting to access records outside your assigned role is strictly prohibited.'),

                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('I Agree & Accept Terms', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue),
      ),
    );
  }

  Widget _buildBulletPoint(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0, left: 12.0),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.3),
          children: [
            TextSpan(text: '• $title: ', style: const TextStyle(fontWeight: FontWeight.bold)),
            TextSpan(text: description),
          ],
        ),
      ),
    );
  }
}
