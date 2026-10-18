import 'eccd_domain.dart';

class EccdIndicator {
  final String id;
  final EccdDomain domain;
  final String text;
  final String version;
  final String? ageBand;
  final bool isActive;

  const EccdIndicator({
    required this.id,
    required this.domain,
    required this.text,
    required this.version,
    this.ageBand,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'domain': domain.code,
      'text': text,
      'version': version,
      'age_band': ageBand,
      'is_active': isActive,
    };
  }

  factory EccdIndicator.fromMap(Map<String, dynamic> map) {
    final domain = EccdDomainCatalog.tryParse(map['domain'] as String?);
    if (domain == null) {
      throw FormatException('Unknown ECCD domain: ${map['domain']}');
    }

    return EccdIndicator(
      id: map['id'] as String? ?? '',
      domain: domain,
      text: map['text'] as String? ?? '',
      version: map['version'] as String? ?? '',
      ageBand: map['age_band'] as String?,
      isActive: map['is_active'] as bool? ?? true,
    );
  }
}

/// Compatibility catalog based on the existing checklist.
///
/// This is intentionally versioned as a draft. It is a migration bridge, not
/// a claim that these indicators are the final LGU-approved ECCD checklist.
class EccdIndicatorCatalog {
  const EccdIndicatorCatalog._();

  static const String draftVersion = 'draft-2026-10';

  static const List<EccdIndicator> draft = [
    EccdIndicator(
      id: 'gross_motor.climbs_stairs_alternating',
      domain: EccdDomain.grossMotor,
      text: 'Climbs stairs with alternating feet',
      version: draftVersion,
    ),
    EccdIndicator(
      id: 'gross_motor.runs_without_falling',
      domain: EccdDomain.grossMotor,
      text: 'Runs without falling',
      version: draftVersion,
    ),
    EccdIndicator(
      id: 'gross_motor.kicks_ball',
      domain: EccdDomain.grossMotor,
      text: 'Kicks a ball',
      version: draftVersion,
    ),
    EccdIndicator(
      id: 'gross_motor.stands_on_one_foot',
      domain: EccdDomain.grossMotor,
      text: 'Stands on one foot for 5 seconds',
      version: draftVersion,
    ),
    EccdIndicator(
      id: 'fine_motor.uses_spoon_and_fork',
      domain: EccdDomain.fineMotor,
      text: 'Uses spoon and fork',
      version: draftVersion,
    ),
    EccdIndicator(
      id: 'fine_motor.copies_circle',
      domain: EccdDomain.fineMotor,
      text: 'Copies a circle',
      version: draftVersion,
    ),
    EccdIndicator(
      id: 'fine_motor.strings_large_beads',
      domain: EccdDomain.fineMotor,
      text: 'Strings large beads',
      version: draftVersion,
    ),
    EccdIndicator(
      id: 'fine_motor.turns_book_pages',
      domain: EccdDomain.fineMotor,
      text: 'Turns pages of a book one at a time',
      version: draftVersion,
    ),
    EccdIndicator(
      id: 'self_help.feeds_self',
      domain: EccdDomain.selfHelp,
      text: 'Feeds self independently',
      version: draftVersion,
    ),
    EccdIndicator(
      id: 'self_help.toileting_signal',
      domain: EccdDomain.selfHelp,
      text: 'Tells when they need to go to the toilet',
      version: draftVersion,
    ),
    EccdIndicator(
      id: 'self_help.washes_hands',
      domain: EccdDomain.selfHelp,
      text: 'Washes hands without help',
      version: draftVersion,
    ),
    EccdIndicator(
      id: 'self_help.dresses_with_minimal_help',
      domain: EccdDomain.selfHelp,
      text: 'Dresses self with minimal help',
      version: draftVersion,
    ),
    EccdIndicator(
      id: 'receptive_language.points_to_body_parts',
      domain: EccdDomain.receptiveLanguage,
      text: 'Points to body parts',
      version: draftVersion,
    ),
    EccdIndicator(
      id: 'receptive_language.follows_simple_commands',
      domain: EccdDomain.receptiveLanguage,
      text: 'Follows simple commands',
      version: draftVersion,
    ),
    EccdIndicator(
      id: 'receptive_language.identifies_objects_in_pictures',
      domain: EccdDomain.receptiveLanguage,
      text: 'Identifies common objects in pictures',
      version: draftVersion,
    ),
    EccdIndicator(
      id: 'expressive_language.uses_short_sentences',
      domain: EccdDomain.expressiveLanguage,
      text: 'Uses 2-3 word sentences',
      version: draftVersion,
    ),
    EccdIndicator(
      id: 'cognitive.identifies_colors',
      domain: EccdDomain.cognitive,
      text: 'Identifies colors',
      version: draftVersion,
    ),
    EccdIndicator(
      id: 'cognitive.matches_shapes',
      domain: EccdDomain.cognitive,
      text: 'Matches shapes',
      version: draftVersion,
    ),
    EccdIndicator(
      id: 'cognitive.counts_one_to_five',
      domain: EccdDomain.cognitive,
      text: 'Counts 1 to 5',
      version: draftVersion,
    ),
    EccdIndicator(
      id: 'cognitive.knows_name_and_age',
      domain: EccdDomain.cognitive,
      text: 'Knows their name and age',
      version: draftVersion,
    ),
    EccdIndicator(
      id: 'social_emotional.plays_with_peers',
      domain: EccdDomain.socialEmotional,
      text: 'Plays with other children',
      version: draftVersion,
    ),
    EccdIndicator(
      id: 'social_emotional.shares_toys',
      domain: EccdDomain.socialEmotional,
      text: 'Shares toys',
      version: draftVersion,
    ),
    EccdIndicator(
      id: 'social_emotional.expresses_emotions',
      domain: EccdDomain.socialEmotional,
      text: 'Expresses emotions',
      version: draftVersion,
    ),
    EccdIndicator(
      id: 'social_emotional.shows_empathy',
      domain: EccdDomain.socialEmotional,
      text: 'Shows empathy',
      version: draftVersion,
    ),
  ];

  static EccdIndicator? findById(String? id) {
    if (id == null) return null;
    for (final indicator in draft) {
      if (indicator.id == id) return indicator;
    }
    return null;
  }
}
