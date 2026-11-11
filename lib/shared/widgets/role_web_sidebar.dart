import 'package:flutter/material.dart';

import 'brand_widgets.dart';

class RoleWebNavItem {
  const RoleWebNavItem({
    required this.label,
    required this.icon,
    required this.onTap,
    this.selected = false,
    this.isDestructive = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool selected;
  final bool isDestructive;
}

/// Shared desktop navigation for the role-based workspaces.
class RoleWebSidebar extends StatelessWidget {
  const RoleWebSidebar({
    super.key,
    required this.title,
    required this.subtitle,
    required this.items,
    this.showIdentityLogo = true,
    this.bottomItem,
  });

  final String title;
  final String subtitle;
  final List<RoleWebNavItem> items;
  final bool showIdentityLogo;
  final RoleWebNavItem? bottomItem;

  Widget _navigationItem(BuildContext context, RoleWebNavItem item) {
    final colors = Theme.of(context).colorScheme;
    final foregroundColor = item.isDestructive
        ? colors.error
        : item.selected
        ? BrandColors.navy
        : colors.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14),
        leading: Icon(item.icon, color: foregroundColor),
        title: Text(
          item.label,
          style: TextStyle(
            color: item.isDestructive ? colors.error : null,
            fontWeight: item.selected ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
        selected: item.selected,
        selectedTileColor: item.isDestructive
            ? colors.error.withValues(alpha: .08)
            : BrandColors.sky.withValues(alpha: .12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onTap: item.selected ? null : item.onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: const Color(0xFFFAFCFC),
      child: Container(
        width: 292,
        decoration: BoxDecoration(
          border: Border(right: BorderSide(color: colors.outlineVariant)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 22),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      BrandColors.navy.withValues(alpha: .96),
                      BrandColors.sky.withValues(alpha: .92),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: BrandColors.navy.withValues(alpha: .14),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    if (showIdentityLogo) ...[
                      const EccdLogo(width: 42, height: 42),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: .76),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'WORKSPACE MENU',
                  style: TextStyle(
                    color: Color(0xFF718096),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                children: items
                    .map((item) => _navigationItem(context, item))
                    .toList(),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 8, 24, 8),
              child: Row(
                children: [
                  Icon(
                    Icons.verified_user_outlined,
                    size: 16,
                    color: BrandColors.green,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Secure ECCD workspace',
                    style: TextStyle(fontSize: 11, color: Color(0xFF718096)),
                  ),
                ],
              ),
            ),
            if (bottomItem != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 20),
                child: _navigationItem(context, bottomItem!),
              ),
          ],
        ),
      ),
    );
  }
}
