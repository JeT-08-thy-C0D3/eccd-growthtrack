import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../core/theme/theme_controller.dart';
import '../../../shared/widgets/terms_privacy_dialog.dart';

class SystemSettingsPage extends StatefulWidget {
  const SystemSettingsPage({super.key});

  @override
  State<SystemSettingsPage> createState() => _SystemSettingsPageState();
}

class _SystemSettingsPageState extends State<SystemSettingsPage> {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('System Settings'),
        scrolledUnderElevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader('Appearance & Display', Icons.palette_outlined),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: colorScheme.outlineVariant),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ValueListenableBuilder<ThemeMode>(
                    valueListenable: themeController,
                    builder: (context, themeMode, child) {
                      final isDark = themeMode == ThemeMode.dark;
                      return SwitchListTile(
                        value: isDark,
                        onChanged: (val) async {
                          await themeController.setDarkMode(val);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(val ? 'Dark Mode Enabled' : 'Light Mode Enabled'),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                        secondary: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.amber.withValues(alpha: 0.2)
                                : Colors.blue.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isDark ? Icons.dark_mode : Icons.light_mode,
                            color: isDark ? Colors.amber : Colors.blue,
                          ),
                        ),
                        title: const Text('Dark Mode', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        subtitle: const Text('Enable dark theme for low-light environments across the portal.'),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 32),

                _buildSectionHeader('Legal & Compliance', Icons.gavel_outlined),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: colorScheme.outlineVariant),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.purple.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.shield_outlined, color: Colors.purple),
                    ),
                    title: const Text('Terms of Service & Privacy Notice', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    subtitle: const Text('Compliant with Republic Act 10173 (Data Privacy Act) & R.A. 12199.'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => TermsPrivacyDialog.show(context),
                  ),
                ),
                const SizedBox(height: 32),

                _buildSectionHeader('System Status & Information', Icons.info_outline),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: colorScheme.outlineVariant),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        _buildInfoRow('Application Version', 'v1.0.0 (Build 1)'),
                        const Divider(),
                        _buildInfoRow('Active Platform', kIsWeb ? 'Flutter Web Admin Portal' : 'Mobile Application'),
                        const Divider(),
                        _buildInfoRow('Cloud Database', 'Google Cloud Firestore'),
                        const Divider(),
                        _buildInfoRow('Storage Infrastructure', 'Supabase Buckets (Encrypted Public URLs)'),
                        const Divider(),
                        _buildInfoRow('Offline Engine', kIsWeb ? 'Bypassed (Direct Firestore Stream)' : 'SQLite Local Cache'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }
}
