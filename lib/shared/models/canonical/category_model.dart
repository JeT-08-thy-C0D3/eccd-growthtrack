/// Category Models for Dynamic System Configuration
/// 
/// Categories replace hard-coded lists and enable admin customization.
library;

class Category {
  final String id;
  final String name;
  final String description;
  final String categoryType; // 'referral_concern', 'referral_agency', etc.
  final int displayOrder;
  final bool isActive;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? createdBy;

  Category({
    required this.id,
    required this.name,
    required this.description,
    required this.categoryType,
    this.displayOrder = 0,
    this.isActive = true,
    this.metadata,
    required this.createdAt,
    this.updatedAt,
    this.createdBy,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'categoryType': categoryType,
    'displayOrder': displayOrder,
    'isActive': isActive,
    'metadata': metadata,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
    'createdBy': createdBy,
  };

  factory Category.fromJson(Map<String, dynamic> json) => Category(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    description: json['description'] as String? ?? '',
    categoryType: json['categoryType'] as String? ?? '',
    displayOrder: json['displayOrder'] as int? ?? 0,
    isActive: json['isActive'] as bool? ?? true,
    metadata: json['metadata'] as Map<String, dynamic>?,
    createdAt: json['createdAt'] is String
        ? DateTime.parse(json['createdAt'] as String)
        : json['createdAt'] as DateTime? ?? DateTime.now(),
    updatedAt: json['updatedAt'] is String
        ? DateTime.parse(json['updatedAt'] as String)
        : null,
    createdBy: json['createdBy'] as String?,
  );
}

// ============================================================================
// PREDEFINED CATEGORY TYPES
// ============================================================================

class CategoryType {
  /// Referral concern categories (why child is being referred)
  static const String referralConcern = 'referral_concern';

  /// Referral agency categories (where child is referred)
  static const String referralAgency = 'referral_agency';

  /// Referral outcome categories (what happened after referral)
  static const String referralOutcome = 'referral_outcome';

  /// Activity types (matching games, shape recognition, etc.)
  static const String activityType = 'activity_type';

  /// Clarification request categories
  static const String clarificationCategory = 'clarification_category';

  /// Notification types
  static const String notificationType = 'notification_type';

  /// Intervention types (support strategies)
  static const String interventionType = 'intervention_type';

  /// Accommodation/support need categories
  static const String accommodationType = 'accommodation_type';

  /// Health condition categories
  static const String healthCondition = 'health_condition';

  /// Feedback category types
  static const String feedbackCategory = 'feedback_category';

  static const List<String> allTypes = [
    referralConcern,
    referralAgency,
    referralOutcome,
    activityType,
    clarificationCategory,
    notificationType,
    interventionType,
    accommodationType,
    healthCondition,
    feedbackCategory,
  ];
}

// ============================================================================
// DEFAULT CATEGORIES (INITIALIZATION DATA)
// ============================================================================

class DefaultCategories {
  /// Referral concerns
  static final List<Map<String, dynamic>> referralConcerns = [
    {
      'name': 'Speech & Language Delay',
      'description': 'Child shows delay in speech or language development',
      'categoryType': CategoryType.referralConcern,
    },
    {
      'name': 'Motor Development Delay',
      'description': 'Gross or fine motor skills below age expectations',
      'categoryType': CategoryType.referralConcern,
    },
    {
      'name': 'Behavioral Concerns',
      'description': 'Aggressive, withdrawn, or disruptive behavior',
      'categoryType': CategoryType.referralConcern,
    },
    {
      'name': 'Social Interaction Issues',
      'description': 'Difficulty with peer relationships or social skills',
      'categoryType': CategoryType.referralConcern,
    },
    {
      'name': 'Cognitive Development Concerns',
      'description': 'Learning difficulties or cognitive delays',
      'categoryType': CategoryType.referralConcern,
    },
    {
      'name': 'Vision/Hearing Issues',
      'description': 'Suspected vision or hearing impairment',
      'categoryType': CategoryType.referralConcern,
    },
    {
      'name': 'Nutritional Concerns',
      'description': 'Malnutrition, stunting, or feeding issues',
      'categoryType': CategoryType.referralConcern,
    },
    {
      'name': 'Emotional Distress',
      'description': 'Anxiety, depression, or trauma symptoms',
      'categoryType': CategoryType.referralConcern,
    },
  ];

  /// Referral agencies
  static final List<Map<String, dynamic>> referralAgencies = [
    {
      'name': 'Hospital/Pediatric Clinic',
      'description': 'Medical evaluation and treatment',
      'categoryType': CategoryType.referralAgency,
    },
    {
      'name': 'Speech-Language Pathologist',
      'description': 'Speech and language services',
      'categoryType': CategoryType.referralAgency,
    },
    {
      'name': 'Occupational Therapist',
      'description': 'Motor and daily living skills',
      'categoryType': CategoryType.referralAgency,
    },
    {
      'name': 'Physical Therapist',
      'description': 'Gross motor and movement therapy',
      'categoryType': CategoryType.referralAgency,
    },
    {
      'name': 'Psychologist/Mental Health',
      'description': 'Behavioral and emotional support',
      'categoryType': CategoryType.referralAgency,
    },
    {
      'name': 'Nutritionist',
      'description': 'Nutritional assessment and counseling',
      'categoryType': CategoryType.referralAgency,
    },
    {
      'name': 'Special Education Program',
      'description': 'Special education services',
      'categoryType': CategoryType.referralAgency,
    },
    {
      'name': 'Social Services',
      'description': 'Family support and social welfare',
      'categoryType': CategoryType.referralAgency,
    },
  ];

  /// Activity types
  static final List<Map<String, dynamic>> activityTypes = [
    {
      'name': 'Matching Game',
      'description': 'Match pictures or objects',
      'categoryType': CategoryType.activityType,
    },
    {
      'name': 'Object Recognition',
      'description': 'Identify and name objects',
      'categoryType': CategoryType.activityType,
    },
    {
      'name': 'Drag and Drop',
      'description': 'Move objects to target areas',
      'categoryType': CategoryType.activityType,
    },
    {
      'name': 'Counting',
      'description': 'Count objects or complete sequences',
      'categoryType': CategoryType.activityType,
    },
    {
      'name': 'Shape Recognition',
      'description': 'Identify and match shapes',
      'categoryType': CategoryType.activityType,
    },
    {
      'name': 'Tracing',
      'description': 'Trace lines or patterns',
      'categoryType': CategoryType.activityType,
    },
    {
      'name': 'Puzzle',
      'description': 'Complete puzzles and jigsaws',
      'categoryType': CategoryType.activityType,
    },
    {
      'name': 'Memory Game',
      'description': 'Match pairs or recall sequences',
      'categoryType': CategoryType.activityType,
    },
  ];

  /// Notification types
  static final List<Map<String, dynamic>> notificationTypes = [
    {
      'name': 'Evaluation Completed',
      'description': 'New evaluation ready for review',
      'categoryType': CategoryType.notificationType,
    },
    {
      'name': 'Referral Status Update',
      'description': 'Referral status has changed',
      'categoryType': CategoryType.notificationType,
    },
    {
      'name': 'Activity Assignment',
      'description': 'New activity assigned',
      'categoryType': CategoryType.notificationType,
    },
    {
      'name': 'Parent Feedback',
      'description': 'New feedback from parent',
      'categoryType': CategoryType.notificationType,
    },
    {
      'name': 'Clarification Request',
      'description': 'Request for clarification received',
      'categoryType': CategoryType.notificationType,
    },
    {
      'name': 'System Alert',
      'description': 'System-level notification',
      'categoryType': CategoryType.notificationType,
    },
  ];

  /// Intervention types
  static final List<Map<String, dynamic>> interventionTypes = [
    {
      'name': 'Direct Service',
      'description': 'One-on-one therapy or instruction',
      'categoryType': CategoryType.interventionType,
    },
    {
      'name': 'Group Activity',
      'description': 'Small group intervention',
      'categoryType': CategoryType.interventionType,
    },
    {
      'name': 'Parent Coaching',
      'description': 'Support and training for parents',
      'categoryType': CategoryType.interventionType,
    },
    {
      'name': 'Classroom Adaptation',
      'description': 'Modifications to classroom environment',
      'categoryType': CategoryType.interventionType,
    },
    {
      'name': 'Assistive Technology',
      'description': 'Tools or devices to support learning',
      'categoryType': CategoryType.interventionType,
    },
  ];

  /// Accommodation types
  static final List<Map<String, dynamic>> accommodationTypes = [
    {
      'name': 'Mobility Assistance',
      'description': 'Physical support for movement',
      'categoryType': CategoryType.accommodationType,
    },
    {
      'name': 'Visual Accommodation',
      'description': 'Adaptations for vision',
      'categoryType': CategoryType.accommodationType,
    },
    {
      'name': 'Hearing Accommodation',
      'description': 'Adaptations for hearing',
      'categoryType': CategoryType.accommodationType,
    },
    {
      'name': 'Communication Aid',
      'description': 'AAC devices or communication supports',
      'categoryType': CategoryType.accommodationType,
    },
    {
      'name': 'Behavioral Support',
      'description': 'Strategies for behavior management',
      'categoryType': CategoryType.accommodationType,
    },
    {
      'name': 'Learning Modification',
      'description': 'Curriculum or instruction modifications',
      'categoryType': CategoryType.accommodationType,
    },
  ];
}
