import '../../../shared/models/assessment_model.dart';
import '../domain/eccd_domain.dart';
import '../domain/evaluation_model.dart';

class LegacyDomainMapping {
  final String sourceValue;
  final EccdDomain? canonicalDomain;
  final bool requiresReview;
  final String reason;

  const LegacyDomainMapping({
    required this.sourceValue,
    required this.canonicalDomain,
    required this.requiresReview,
    required this.reason,
  });
}

class LegacyEvaluationMapper {
  const LegacyEvaluationMapper._();

  static LegacyDomainMapping mapDomain(String? sourceValue) {
    final raw = sourceValue?.trim() ?? '';
    final normalized = raw
        .toLowerCase()
        .replaceAll('-', ' ')
        .replaceAll('_', ' ')
        .replaceAll(RegExp(r'\s+'), ' ');

    final directMapping = EccdDomainCatalog.tryParse(normalized);
    if (directMapping != null) {
      return LegacyDomainMapping(
        sourceValue: raw,
        canonicalDomain: directMapping,
        requiresReview: false,
        reason: 'Direct canonical-domain match.',
      );
    }

    switch (normalized) {
      case 'selfhelp':
        return _mapped(raw, EccdDomain.selfHelp);
      case 'social emotional':
      case 'socialemotional':
        return _mapped(raw, EccdDomain.socialEmotional);
      case 'physical':
        return _review(raw, 'Physical does not distinguish Gross Motor from Fine Motor.');
      case 'language':
        return _review(raw, 'Language does not distinguish Receptive Language from Expressive Language.');
      default:
        return _review(raw, 'No canonical ECCD domain mapping exists.');
    }
  }

  static LegacyDomainMapping fromEvaluationModel(EvaluationModel model) {
    return mapDomain(model.domain);
  }

  static LegacyDomainMapping fromAssessmentModel(AssessmentModel model) {
    return mapDomain(model.domain);
  }

  static LegacyDomainMapping _mapped(String raw, EccdDomain domain) {
    return LegacyDomainMapping(
      sourceValue: raw,
      canonicalDomain: domain,
      requiresReview: false,
      reason: 'Legacy spelling normalized.',
    );
  }

  static LegacyDomainMapping _review(String raw, String reason) {
    return LegacyDomainMapping(
      sourceValue: raw,
      canonicalDomain: null,
      requiresReview: true,
      reason: reason,
    );
  }
}
