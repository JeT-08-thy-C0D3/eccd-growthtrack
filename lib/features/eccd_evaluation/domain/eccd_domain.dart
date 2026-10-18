/// The canonical ECCD domains used by all future evaluation flows.
enum EccdDomain {
  grossMotor,
  fineMotor,
  selfHelp,
  receptiveLanguage,
  expressiveLanguage,
  cognitive,
  socialEmotional,
}

extension EccdDomainX on EccdDomain {
  String get code {
    switch (this) {
      case EccdDomain.grossMotor:
        return 'gross_motor';
      case EccdDomain.fineMotor:
        return 'fine_motor';
      case EccdDomain.selfHelp:
        return 'self_help';
      case EccdDomain.receptiveLanguage:
        return 'receptive_language';
      case EccdDomain.expressiveLanguage:
        return 'expressive_language';
      case EccdDomain.cognitive:
        return 'cognitive';
      case EccdDomain.socialEmotional:
        return 'social_emotional';
    }
  }

  String get label {
    switch (this) {
      case EccdDomain.grossMotor:
        return 'Gross Motor';
      case EccdDomain.fineMotor:
        return 'Fine Motor';
      case EccdDomain.selfHelp:
        return 'Self Help';
      case EccdDomain.receptiveLanguage:
        return 'Receptive Language';
      case EccdDomain.expressiveLanguage:
        return 'Expressive Language';
      case EccdDomain.cognitive:
        return 'Cognitive';
      case EccdDomain.socialEmotional:
        return 'Social Emotional';
    }
  }
}

class EccdDomainCatalog {
  const EccdDomainCatalog._();

  static const List<EccdDomain> all = EccdDomain.values;

  static EccdDomain? tryParse(String? value) {
    if (value == null || value.trim().isEmpty) return null;

    final normalized = value
        .trim()
        .toLowerCase()
        .replaceAll('-', ' ')
        .replaceAll('_', ' ')
        .replaceAll(RegExp(r'\s+'), ' ');

    switch (normalized) {
      case 'gross motor':
        return EccdDomain.grossMotor;
      case 'fine motor':
        return EccdDomain.fineMotor;
      case 'self help':
        return EccdDomain.selfHelp;
      case 'receptive language':
        return EccdDomain.receptiveLanguage;
      case 'expressive language':
        return EccdDomain.expressiveLanguage;
      case 'cognitive':
        return EccdDomain.cognitive;
      case 'social emotional':
        return EccdDomain.socialEmotional;
      default:
        return null;
    }
  }
}
