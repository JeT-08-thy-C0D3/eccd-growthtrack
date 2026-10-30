/// ECCD (Early Childhood Care and Development) standard domains and indicators.
/// 
/// This model defines the 7 standard ECCD domains recognized across
/// the system and their associated indicators.
library;

enum EccdDomainType {
  grossMotor,
  fineMotor,
  selfHelp,
  receptiveLanguage,
  expressiveLanguage,
  cognitive,
  socialEmotional,
}

class EccdDomain {
  final String id; // Unique identifier (e.g., 'gross_motor')
  final EccdDomainType type;
  final String name; // Display name
  final String description;
  final List<EccdIndicator> indicators; // Domain-specific indicators
  final int sequenceOrder; // For display ordering

  EccdDomain({
    required this.id,
    required this.type,
    required this.name,
    required this.description,
    required this.indicators,
    required this.sequenceOrder,
  });

  factory EccdDomain.fromMap(Map<String, dynamic> map) {
    return EccdDomain(
      id: map['id'] ?? '',
      type: EccdDomainType.values.firstWhere(
        (e) => e.toString().split('.').last == map['type'],
        orElse: () => EccdDomainType.grossMotor,
      ),
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      indicators: (map['indicators'] as List<dynamic>? ?? [])
          .map((i) => EccdIndicator.fromMap(i as Map<String, dynamic>))
          .toList(),
      sequenceOrder: map['sequence_order'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.toString().split('.').last,
      'name': name,
      'description': description,
      'indicators': indicators.map((i) => i.toMap()).toList(),
      'sequence_order': sequenceOrder,
    };
  }

  EccdDomain copyWith({
    String? id,
    EccdDomainType? type,
    String? name,
    String? description,
    List<EccdIndicator>? indicators,
    int? sequenceOrder,
  }) {
    return EccdDomain(
      id: id ?? this.id,
      type: type ?? this.type,
      name: name ?? this.name,
      description: description ?? this.description,
      indicators: indicators ?? this.indicators,
      sequenceOrder: sequenceOrder ?? this.sequenceOrder,
    );
  }

  @override
  String toString() => 'EccdDomain($name, ${indicators.length} indicators)';
}

/// An indicator represents a measurable skill or developmental milestone
/// within an ECCD domain. Each indicator has age-band specific criteria.
class EccdIndicator {
  final String id; // Unique identifier within domain
  final String code; // Short code (e.g., 'GM-001')
  final String name; // Display name
  final String description; // What this indicator measures
  final List<AgeBandCriteria> ageBandCriteria; // Age-specific scoring rules
  final int sequenceOrder;

  EccdIndicator({
    required this.id,
    required this.code,
    required this.name,
    required this.description,
    required this.ageBandCriteria,
    required this.sequenceOrder,
  });

  factory EccdIndicator.fromMap(Map<String, dynamic> map) {
    return EccdIndicator(
      id: map['id'] ?? '',
      code: map['code'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      ageBandCriteria: (map['age_band_criteria'] as List<dynamic>? ?? [])
          .map((c) => AgeBandCriteria.fromMap(c as Map<String, dynamic>))
          .toList(),
      sequenceOrder: map['sequence_order'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'code': code,
      'name': name,
      'description': description,
      'age_band_criteria':
          ageBandCriteria.map((c) => c.toMap()).toList(),
      'sequence_order': sequenceOrder,
    };
  }

  EccdIndicator copyWith({
    String? id,
    String? code,
    String? name,
    String? description,
    List<AgeBandCriteria>? ageBandCriteria,
    int? sequenceOrder,
  }) {
    return EccdIndicator(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      description: description ?? this.description,
      ageBandCriteria: ageBandCriteria ?? this.ageBandCriteria,
      sequenceOrder: sequenceOrder ?? this.sequenceOrder,
    );
  }

  @override
  String toString() =>
      'EccdIndicator($code: $name, ${ageBandCriteria.length} age bands)';
}

/// Age band represents a developmental age range and the scoring
/// criteria specific to that age band for an indicator.
class AgeBandCriteria {
  final String ageBand; // e.g., '0-6m', '6-12m', '1-2y', '2-3y', '3-4y', '4-5y', '5-6y'
  final String minMonths; // Minimum age in months (for storage)
  final String maxMonths; // Maximum age in months (for storage)
  final List<ScoringLevel> scoringLevels; // Scoring options for this age band
  final String guidance; // Additional guidance/examples for this age band

  AgeBandCriteria({
    required this.ageBand,
    required this.minMonths,
    required this.maxMonths,
    required this.scoringLevels,
    required this.guidance,
  });

  factory AgeBandCriteria.fromMap(Map<String, dynamic> map) {
    return AgeBandCriteria(
      ageBand: map['age_band'] ?? '',
      minMonths: map['min_months'] ?? '',
      maxMonths: map['max_months'] ?? '',
      scoringLevels: (map['scoring_levels'] as List<dynamic>? ?? [])
          .map((s) => ScoringLevel.fromMap(s as Map<String, dynamic>))
          .toList(),
      guidance: map['guidance'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'age_band': ageBand,
      'min_months': minMonths,
      'max_months': maxMonths,
      'scoring_levels': scoringLevels.map((s) => s.toMap()).toList(),
      'guidance': guidance,
    };
  }

  AgeBandCriteria copyWith({
    String? ageBand,
    String? minMonths,
    String? maxMonths,
    List<ScoringLevel>? scoringLevels,
    String? guidance,
  }) {
    return AgeBandCriteria(
      ageBand: ageBand ?? this.ageBand,
      minMonths: minMonths ?? this.minMonths,
      maxMonths: maxMonths ?? this.maxMonths,
      scoringLevels: scoringLevels ?? this.scoringLevels,
      guidance: guidance ?? this.guidance,
    );
  }

  @override
  String toString() => 'AgeBandCriteria($ageBand)';
}

/// Scoring level represents one possible score for an indicator
/// at a specific age band (e.g., "Not Yet", "Emerging", "Proficient", "Advanced").
class ScoringLevel {
  final int score; // Numeric score (0-3 typical)
  final String label; // Display label
  final String description; // What this score means
  final String criteria; // Observable criteria for this score

  ScoringLevel({
    required this.score,
    required this.label,
    required this.description,
    required this.criteria,
  });

  factory ScoringLevel.fromMap(Map<String, dynamic> map) {
    return ScoringLevel(
      score: map['score'] ?? 0,
      label: map['label'] ?? '',
      description: map['description'] ?? '',
      criteria: map['criteria'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'score': score,
      'label': label,
      'description': description,
      'criteria': criteria,
    };
  }

  ScoringLevel copyWith({
    int? score,
    String? label,
    String? description,
    String? criteria,
  }) {
    return ScoringLevel(
      score: score ?? this.score,
      label: label ?? this.label,
      description: description ?? this.description,
      criteria: criteria ?? this.criteria,
    );
  }

  @override
  String toString() => 'ScoringLevel($score: $label)';
}

/// Static reference implementation of the 7 ECCD domains.
/// These are the canonical, standard domains used throughout the system.
class EccdDomainRegistry {
  static final Map<String, EccdDomain> _domains = {};

  /// Initialize with standard domains. Typically called from Firestore at startup.
  static void initialize(List<EccdDomain> domains) {
    _domains.clear();
    for (final domain in domains) {
      _domains[domain.id] = domain;
    }
  }

  /// Get a domain by ID
  static EccdDomain? getDomain(String domainId) => _domains[domainId];

  /// Get indicator by domain ID and indicator ID
  static EccdIndicator? getIndicator(
      String domainId, String indicatorId) {
    final domain = _domains[domainId];
    if (domain == null) return null;
    try {
      return domain.indicators
          .firstWhere((i) => i.id == indicatorId);
    } catch (_) {
      return null;
    }
  }

  /// Get all domains
  static List<EccdDomain> getAllDomains() =>
      _domains.values.toList()
        ..sort((a, b) => a.sequenceOrder.compareTo(b.sequenceOrder));

  /// Get domain IDs in standard order
  static List<String> getDomainIds() =>
      getAllDomains().map((d) => d.id).toList();
}
