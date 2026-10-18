import 'package:flutter/material.dart';

/// The visual language used by the ECCD GrowthTrack logo.
class BrandColors {
  static const navy = Color(0xFF0A5275);
  static const green = Color(0xFF2E9B5F);
  static const leaf = Color(0xFF63C653);
  static const sky = Color(0xFF218FD3);
  static const sunshine = Color(0xFFFBB31B);
  static const canvas = Color(0xFFF5FAFC);

  const BrandColors._();
}

class EccdLogo extends StatelessWidget {
  final double? width;
  final double? height;
  final BoxFit fit;

  const EccdLogo({super.key, this.width, this.height, this.fit = BoxFit.contain});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/eccd_growthtrack_logo.png',
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (_, _, _) => const Icon(
        Icons.auto_graph_rounded,
        color: BrandColors.green,
        size: 40,
      ),
    );
  }
}

class EccdAppBarTitle extends StatelessWidget {
  final String title;
  final String? subtitle;

  const EccdAppBarTitle({super.key, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 42,
          height: 42,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: BrandColors.green.withValues(alpha: .18)),
          ),
          child: const EccdLogo(),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: BrandColors.green.withValues(alpha: .9),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class EccdSectionIntro extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const EccdSectionIntro({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon = Icons.wb_sunny_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [BrandColors.navy, BrandColors.sky],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: BrandColors.navy.withValues(alpha: .16),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: BrandColors.sunshine.withValues(alpha: .95),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: BrandColors.navy, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .86),
                    height: 1.3,
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
