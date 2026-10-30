import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../shared/widgets/brand_widgets.dart';
import '../../../shared/widgets/terms_privacy_dialog.dart';

class SystemSettingsPage extends StatelessWidget {
  const SystemSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(32, 28, 32, 40),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1280),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SettingsHero(compact: constraints.maxWidth < 780),
                const SizedBox(height: 24),
                _SettingsSection(
                  icon: Icons.palette_outlined,
                  title: 'Appearance & Display',
                  subtitle: 'Customize how the admin portal looks and feels.',
                  child: ValueListenableBuilder<ThemeMode>(
                    valueListenable: themeController,
                    builder: (context, themeMode, _) {
                      final isDark = themeMode == ThemeMode.dark;
                      return _SettingsTile(
                        icon: isDark
                            ? Icons.dark_mode_rounded
                            : Icons.light_mode_rounded,
                        iconColor: BrandColors.sky,
                        iconBackground: BrandColors.sky.withValues(alpha: .12),
                        title: 'Dark Mode',
                        subtitle: 'Enable dark theme for low-light environments across the portal.',
                        trailing: Switch.adaptive(
                          value: isDark,
                          activeTrackColor: BrandColors.green,
                          onChanged: (value) async {
                            await themeController.setDarkMode(value);
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  value
                                      ? 'Dark Mode Enabled'
                                      : 'Light Mode Enabled',
                                ),
                                backgroundColor: BrandColors.green,
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 18),
                _SettingsSection(
                  icon: Icons.gavel_rounded,
                  title: 'Legal & Compliance',
                  subtitle: 'Access important legal documents and compliance information.',
                  child: _SettingsTile(
                    icon: Icons.shield_outlined,
                    iconColor: const Color(0xFF9B34D2),
                    iconBackground: const Color(0xFF9B34D2)
                        .withValues(alpha: .11),
                    title: 'Terms of Service & Privacy Notice',
                    subtitle: 'Compliant with Republic Act 10173 (Data Privacy Act) & R.A. 12199.',
                    trailing: const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 18,
                      color: BrandColors.navy,
                    ),
                    onTap: () => TermsPrivacyDialog.show(context),
                    tinted: true,
                  ),
                ),
                const SizedBox(height: 18),
                _SettingsSection(
                  icon: Icons.info_outline_rounded,
                  title: 'System Status & Information',
                  subtitle:
                      'View technical details about the system configuration.',
                  child: const _SystemInformationTable(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsHero extends StatelessWidget {
  const _SettingsHero({required this.compact});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 160,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE1F2FF), Color(0xFFF7FCFF)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -28,
            top: -56,
            child: _HeroCircle(
              size: 212,
              color: BrandColors.sky.withValues(alpha: .14),
            ),
          ),
          Positioned(
            right: 112,
            bottom: -64,
            child: _HeroCircle(
              size: 180,
              color: BrandColors.green.withValues(alpha: .12),
            ),
          ),
          if (!compact)
            Positioned(right: 76, bottom: 0, child: _SettingsIllustration()),
          Positioned(
            left: 30,
            top: 30,
            right: compact ? 24 : 420,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: const Color(0xFF9FD3FF),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.settings_rounded,
                    color: Color(0xFF1676D2),
                    size: 39,
                  ),
                ),
                const SizedBox(width: 22),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'System Settings',
                        style: TextStyle(
                          color: Color(0xFF0D1A5B),
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 7),
                      Text(
                        'Manage system preferences, legal information, and platform details.',
                        style: TextStyle(
                          color: Color(0xFF386296),
                          fontSize: 15,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroCircle extends StatelessWidget {
  const _HeroCircle({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

class _SettingsIllustration extends StatelessWidget {
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 280,
    height: 145,
    child: Stack(
      children: [
        Positioned(
          left: 12,
          bottom: 23,
          child: Icon(
            Icons.local_florist_rounded,
            size: 54,
            color: BrandColors.green.withValues(alpha: .78),
          ),
        ),
        Positioned(
          left: 72,
          top: 24,
          child: Container(
            width: 154,
            height: 96,
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFF2478C9), width: 6),
              borderRadius: BorderRadius.circular(11),
              boxShadow: const [
                BoxShadow(color: Color(0x1F28618E), blurRadius: 16),
              ],
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.settings_rounded,
                  color: Color(0xFF3B91E8),
                  size: 38,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _IllustrationLine(width: 55),
                      SizedBox(height: 8),
                      _IllustrationLine(width: 42),
                      SizedBox(height: 8),
                      _IllustrationLine(width: 50),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const Positioned(
          right: 3,
          top: 4,
          child: Icon(
            Icons.settings_rounded,
            color: Color(0xFF3B91E8),
            size: 35,
          ),
        ),
      ],
    ),
  );
}

class _IllustrationLine extends StatelessWidget {
  const _IllustrationLine({required this.width});
  final double width;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: 6,
    decoration: BoxDecoration(
      color: const Color(0xFFD5E9FB),
      borderRadius: BorderRadius.circular(4),
    ),
  );
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      boxShadow: const [BoxShadow(color: Color(0x0B173B64), blurRadius: 18)],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: BrandColors.navy, size: 31),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF0D1A5B),
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF6079A8),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        child,
      ],
    ),
  );
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.onTap,
    this.tinted = false,
  });
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback? onTap;
  final bool tinted;

  @override
  Widget build(BuildContext context) => Material(
    color: tinted ? const Color(0xFFFBF8FF) : Colors.white,
    borderRadius: BorderRadius.circular(15),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: const Color(0xFFD7E1F2)),
        ),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: iconBackground,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 31),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF121C53),
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF6079A8),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            trailing,
          ],
        ),
      ),
    ),
  );
}

class _SystemInformationTable extends StatelessWidget {
  const _SystemInformationTable();

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        Icons.code_rounded,
        BrandColors.green,
        'Application Version',
        'v1.0.0 (Build 1)',
      ),
      (
        Icons.desktop_windows_rounded,
        BrandColors.sky,
        'Active Platform',
        kIsWeb ? 'Flutter Web Admin Portal' : 'Mobile Application',
      ),
      (
        Icons.storage_rounded,
        BrandColors.sunshine,
        'Cloud Database',
        'Google Cloud Firestore',
      ),
      (
        Icons.cloud_done_rounded,
        const Color(0xFF9B34D2),
        'Storage Infrastructure',
        'Supabase Buckets (Encrypted Public URLs)',
      ),
      (
        Icons.settings_suggest_rounded,
        const Color(0xFFE65555),
        'Offline Engine',
        kIsWeb ? 'Bypassed (Direct Firestore Stream)' : 'SQLite Local Cache',
      ),
    ];
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFD7E1F2)),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          for (var index = 0; index < items.length; index++) ...[
            _SystemInfoRow(
              icon: items[index].$1,
              color: items[index].$2,
              label: items[index].$3,
              value: items[index].$4,
            ),
            if (index < items.length - 1)
              const Divider(height: 1, indent: 20, endIndent: 20),
          ],
        ],
      ),
    );
  }
}

class _SystemInfoRow extends StatelessWidget {
  const _SystemInfoRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
    child: Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: Color(0xFF405783), fontSize: 14),
          ),
        ),
        const SizedBox(width: 20),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(
              color: Color(0xFF111936),
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      ],
    ),
  );
}
