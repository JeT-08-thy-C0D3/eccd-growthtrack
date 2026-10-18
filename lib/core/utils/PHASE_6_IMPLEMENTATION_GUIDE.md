# PHASE 6: FORM VALIDATION & DYNAMIC CATEGORIES

## Implementation Guide

---

## Overview

Phase 6 adds two critical systems:

1. **Centralized Validators**: Single source of truth for all validation logic
   - Password strength, email format, date ranges
   - Age bands, score ranges, required dropdowns
   - Referral field relationships, file type/size
   - XSS prevention, alphanumeric validation

2. **Dynamic Categories**: Replace hard-coded lists with admin-managed categories
   - Referral concerns (8 defaults)
   - Referral agencies (8 defaults)
   - Activity types (8 defaults)
   - Notification types (6 defaults)
   - Intervention types (5 defaults)
   - Accommodation types (6 defaults)
   - + 4 more types (health conditions, feedback, clarifications, outcomes)

---

## Architecture

```
┌────────────────────────────────────────────────────────┐
│                 UI LAYER                               │
│  FormField validates on blur/submit                   │
│  Uses validators.dart validators                      │
│  Dropdown fetches categories from CategoryService     │
└────────────────────┬───────────────────────────────────┘
                     ↓
┌────────────────────────────────────────────────────────┐
│              VALIDATION LAYER                          │
│                                                         │
│  ValidationResult (isValid, errorMessage)             │
│  Validators (PasswordValidator, EmailValidator, etc.) │
│  FormValidator (multi-field validation)               │
│  Returns: Map<String, ValidationResult>               │
└────────────────────┬───────────────────────────────────┘
                     ↓
┌────────────────────────────────────────────────────────┐
│           CATEGORY MANAGEMENT LAYER                    │
│                                                         │
│  CategoryService (caching + CRUD)                     │
│  Category model (id, name, type, displayOrder)        │
│  CategoryType (constants for all types)               │
│  DefaultCategories (initialization data)              │
│                                                         │
│  Create/Read/Update/Delete by admin                   │
│  Reorder categories by displayOrder                   │
│  Cache with 1-hour TTL                                │
└────────────────────┬───────────────────────────────────┘
                     ↓
┌────────────────────────────────────────────────────────┐
│           FIRESTORE LAYER                              │
│                                                         │
│  /categories collection                               │
│    - categoryType (indexed)                           │
│    - isActive (indexed)                               │
│    - displayOrder                                     │
│    - name                                             │
│    - createdAt, createdBy, updatedAt                  │
└────────────────────────────────────────────────────────┘
```

---

## New Files Created

1. **lib/core/utils/validators.dart** (ENHANCED - 480 lines)
   - ValidationResult class
   - 12 validator classes (Password, Email, Date, Score, etc.)
   - 3 combined form validators
   - **Replaces** old simple validator with comprehensive system

2. **lib/shared/models/canonical/category_model.dart** (330 lines)
   - Category model (id, name, categoryType, displayOrder)
   - CategoryType (constants for 10 category types)
   - DefaultCategories (initialization data)
   - 50+ default categories across all types

3. **lib/core/services/category_service.dart** (310 lines)
   - CategoryService (singleton)
   - CRUD operations (create, read, update, delete)
   - Caching with TTL (1 hour)
   - Soft delete (isActive flag)
   - Reorder categories
   - Initialize defaults
   - Stream support (real-time)
   - Dropdown option generation

---

## Validator Types

### 1. PasswordValidator
```dart
// Validate length (6-128 chars)
PasswordValidator.validateLength(password);

// Validate strength (uppercase, lowercase, digit, special)
PasswordValidator.validateStrength(password);

// Validate confirmation
PasswordValidator.validateConfirmation(password, confirm);

// Validate change (new != old)
PasswordValidator.validateChange(oldPassword, newPassword);
```

### 2. EmailValidator
```dart
EmailValidator.validate(email);
// Returns: ValidationResult with regex check
```

### 3. DateValidator
```dart
// Date not in future
DateValidator.validateNotFuture(date);

// Date in past
DateValidator.validatePastDate(date);

// Date is future
DateValidator.validateFutureDate(date);

// Range validation (start before end)
DateValidator.validateRange(start, end);

// Age validation (from birthdate)
DateValidator.validateAge(birthDate, minAge: 0, maxAge: 120);
```

### 4. AgeBandValidator
```dart
// Valid age bands: '0-12m', '12-24m', '24-36m', '36-48m', '48-60m'
AgeBandValidator.validate(ageBand);
```

### 5. ScoreValidator
```dart
// Evaluation score (0-5)
ScoreValidator.validateEvaluationScore(5);

// Custom range
ScoreValidator.validateRange(score, min: 0, max: 10);
```

### 6. SelectionValidator
```dart
// Required selection
SelectionValidator.validateRequired(value);

// Allowed values
SelectionValidator.validateAllowed(value, ['admin', 'teacher', 'parent']);

// User type
SelectionValidator.validateUserType('teacher');

// Referral status
SelectionValidator.validateReferralStatus('active');

// Evaluation status
SelectionValidator.validateEvaluationStatus('completed');
```

### 7. TextValidator
```dart
// Required text
TextValidator.validateRequired(text);

// Length check
TextValidator.validateLength(text, minLength: 2, maxLength: 100);

// Safe content (XSS prevention)
TextValidator.validateSafeContent(text);

// Alphanumeric only
TextValidator.validateAlphanumeric(text);
```

### 8. FileValidator
```dart
// File size (max 10MB)
FileValidator.validateSize(fileSizeBytes, maxSizeMB: 10);

// File type
FileValidator.validateType(fileName, allowedExtensions: ['pdf', 'doc']);

// Image file
FileValidator.validateImage(fileName);

// PDF file
FileValidator.validatePdf(fileName);
```

### 9. ChildValidator
```dart
// Child UID format
ChildValidator.validateUID(uid);

// No duplicate
ChildValidator.validateNoDuplicate(uid, existingUIDs);
```

### 10. ReferralValidator
```dart
// All fields present
ReferralValidator.validateComplete(
  childId: childId,
  concern: concern,
  reason: reason,
  referredTo: referredTo,
  referralDate: referralDate,
);

// Date relationships
ReferralValidator.validateDates(referralDate, followUpDate);
```

---

## Category Types

### 10 Predefined Category Types

| Type | Purpose | Defaults |
|------|---------|----------|
| `referral_concern` | Why child is referred | 8 concerns |
| `referral_agency` | Where child is referred | 8 agencies |
| `referral_outcome` | What happened after | 5+ outcomes |
| `activity_type` | Automated activity type | 8 activities |
| `clarification_category` | Teacher clarification type | 5+ categories |
| `notification_type` | Notification type | 6 types |
| `intervention_type` | Support strategy | 5 types |
| `accommodation_type` | Special need accommodation | 6 types |
| `health_condition` | Child health condition | Custom |
| `feedback_category` | Parent feedback type | Custom |

### Default Referral Concerns
```
- Speech & Language Delay
- Motor Development Delay
- Behavioral Concerns
- Social Interaction Issues
- Cognitive Development Concerns
- Vision/Hearing Issues
- Nutritional Concerns
- Emotional Distress
```

### Default Referral Agencies
```
- Hospital/Pediatric Clinic
- Speech-Language Pathologist
- Occupational Therapist
- Physical Therapist
- Psychologist/Mental Health
- Nutritionist
- Special Education Program
- Social Services
```

### Default Activity Types
```
- Matching Game
- Object Recognition
- Drag and Drop
- Counting
- Shape Recognition
- Tracing
- Puzzle
- Memory Game
```

---

## Usage Examples

### Example 1: Validate Registration Form

```dart
class RegistrationForm extends StatefulWidget {
  @override
  State<RegistrationForm> createState() => _RegistrationFormState();
}

class _RegistrationFormState extends State<RegistrationForm> {
  final _formKey = GlobalKey<FormState>();
  
  String _email = '';
  String _password = '';
  String _passwordConfirm = '';
  String _name = '';
  String _userType = '';

  void _validateAndSubmit() {
    // Validate all fields
    final results = FormValidator.validateUserRegistration(
      email: _email,
      password: _password,
      passwordConfirm: _passwordConfirm,
      name: _name,
      userType: _userType,
    );

    if (!FormValidator.allValid(results)) {
      // Show errors
      final errors = FormValidator.getErrors(results);
      _showErrorDialog(errors);
      return;
    }

    // Proceed with registration
    _submitForm();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            decoration: InputDecoration(labelText: 'Email'),
            onChanged: (value) => _email = value,
            validator: (value) {
              final result = EmailValidator.validate(value ?? '');
              return result.isValid ? null : result.errorMessage;
            },
          ),
          TextFormField(
            decoration: InputDecoration(labelText: 'Password'),
            obscureText: true,
            onChanged: (value) => _password = value,
            validator: (value) {
              final result = PasswordValidator.validate(
                value ?? '',
                checkStrength: true,
              );
              return result.isValid ? null : result.errorMessage;
            },
          ),
          TextFormField(
            decoration: InputDecoration(labelText: 'Confirm Password'),
            obscureText: true,
            onChanged: (value) => _passwordConfirm = value,
            validator: (value) {
              final result = PasswordValidator.validateConfirmation(
                _password,
                value ?? '',
              );
              return result.isValid ? null : result.errorMessage;
            },
          ),
          TextFormField(
            decoration: InputDecoration(labelText: 'Name'),
            onChanged: (value) => _name = value,
            validator: (value) {
              final result = TextValidator.validateLength(
                value ?? '',
                minLength: 2,
                maxLength: 100,
              );
              return result.isValid ? null : result.errorMessage;
            },
          ),
          ElevatedButton(
            onPressed: _validateAndSubmit,
            child: const Text('Register'),
          ),
        ],
      ),
    );
  }
}
```

### Example 2: Dropdown with Dynamic Categories

```dart
class ReferralForm extends StatefulWidget {
  @override
  State<ReferralForm> createState() => _ReferralFormState();
}

class _ReferralFormState extends State<ReferralForm> {
  final _categoryService = CategoryService();
  
  String? _selectedConcern;
  List<Category> _concerns = [];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final concerns = await _categoryService
        .getCategoriesByType(CategoryType.referralConcern);

    setState(() {
      _concerns = concerns;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: _selectedConcern,
      items: _concerns
          .map((concern) => DropdownMenuItem(
                value: concern.id,
                child: Text(concern.name),
              ))
          .toList(),
      onChanged: (value) => setState(() => _selectedConcern = value),
      validator: (value) {
        final result = SelectionValidator.validateRequired(value);
        return result.isValid ? null : result.errorMessage;
      },
      decoration: InputDecoration(labelText: 'Concern'),
    );
  }
}
```

### Example 3: Real-time Category Stream

```dart
class CategoryDropdown extends StatelessWidget {
  final String categoryType;
  final Function(String) onSelected;

  const CategoryDropdown({
    required this.categoryType,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final categoryService = CategoryService();

    return StreamBuilder<List<Category>>(
      stream: categoryService.streamCategoriesByType(categoryType),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const CircularProgressIndicator();
        }

        return DropdownButton<String>(
          items: snapshot.data!
              .map((cat) => DropdownMenuItem(
                    value: cat.id,
                    child: Text(cat.name),
                  ))
              .toList(),
          onChanged: onSelected,
          hint: const Text('Select...'),
        );
      },
    );
  }
}
```

### Example 4: Admin Category Management

```dart
class AdminCategoryPage extends StatefulWidget {
  @override
  State<AdminCategoryPage> createState() => _AdminCategoryPageState();
}

class _AdminCategoryPageState extends State<AdminCategoryPage> {
  final _categoryService = CategoryService();
  final _selectedType = 'referral_concern';

  @override
  void initState() {
    super.initState();
    _categoryService.initializeDefaultCategories();
  }

  void _createCategory(String name, String description) async {
    await _categoryService.createCategory(
      name: name,
      description: description,
      categoryType: _selectedType,
      createdBy: 'admin-user-id', // From auth
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Category created')),
    );
  }

  void _deleteCategory(String id) async {
    await _categoryService.deleteCategory(id);
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Category deleted')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      body: FutureBuilder<List<Category>>(
        future: _categoryService.getCategoriesByType(_selectedType),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          return ListView.builder(
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final category = snapshot.data![index];
              return ListTile(
                title: Text(category.name),
                subtitle: Text(category.description),
                trailing: IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => _deleteCategory(category.id),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
```

### Example 5: Validation on Form Field Change

```dart
class EvaluationScoreField extends StatefulWidget {
  @override
  State<EvaluationScoreField> createState() => _EvaluationScoreFieldState();
}

class _EvaluationScoreFieldState extends State<EvaluationScoreField> {
  String? _errorMessage;
  int? _score;

  void _onScoreChanged(String value) {
    setState(() {
      try {
        _score = int.parse(value);
        
        // Validate score
        final result = ScoreValidator.validateEvaluationScore(_score!);
        _errorMessage = result.isValid ? null : result.errorMessage;
      } catch (e) {
        _errorMessage = 'Must be a number';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      keyboardType: TextInputType.number,
      onChanged: _onScoreChanged,
      decoration: InputDecoration(
        labelText: 'Score (0-5)',
        errorText: _errorMessage,
        helperText: 'Enter score between 0 and 5',
      ),
    );
  }
}
```

---

## Database Schema

### Firestore: /categories

```
{
  id: "cat-123"           // Auto-generated
  name: "Speech & Language Delay"
  description: "Child shows delay in speech..."
  categoryType: "referral_concern"
  displayOrder: 0
  isActive: true
  metadata: {             // Custom fields
    color: "#FF5733",
    icon: "speech",
    riskLevel: "high"
  }
  createdAt: 2024-10-06T12:00:00Z
  updatedAt: 2024-10-06T14:00:00Z
  createdBy: "admin-user-id"
}
```

### Firestore Indexes

```
/categories:
  - (categoryType, isActive, displayOrder)
  - (categoryType, createdAt DESC)
```

---

## Firestore Rules (Categories)

```javascript
match /categories/{document=**} {
  // Read: anyone can read active categories
  allow read: if resource.data.isActive == true;
  
  // Create/Update/Delete: admin only
  allow create, update, delete: if isAdmin();
}
```

---

## Migration Guide

### Old Pattern (Hard-coded):
```dart
const referralConcerns = [
  'Speech & Language Delay',
  'Motor Development Delay',
  'Behavioral Concerns',
];

DropdownButton(
  items: referralConcerns.map((concern) => 
    DropdownMenuItem(child: Text(concern))
  ).toList(),
)
```

### New Pattern (Dynamic):
```dart
final categoryService = CategoryService();

StreamBuilder<List<Category>>(
  stream: categoryService.streamCategoriesByType('referral_concern'),
  builder: (context, snapshot) {
    return DropdownButton(
      items: snapshot.data?.map((cat) =>
        DropdownMenuItem(value: cat.id, child: Text(cat.name))
      ).toList(),
    );
  },
)
```

---

## Caching Strategy

### TTL: 1 Hour
```dart
_cache[categoryType] = categories;
_cacheTimestamps[categoryType] = DateTime.now();

// On next request, check:
if (DateTime.now().difference(timestamp) < Duration(hours: 1)) {
  return _cache[categoryType];  // Return cached
}
```

### Manual Invalidation
```dart
// After create/update/delete, invalidate cache
_cache.remove(categoryType);

// Clear all
categoryService.clearCache();
```

### Stream Updates
```dart
// Real-time updates bypass cache
categoryService.streamCategoriesByType(type)
  // Automatically reflects admin changes
```

---

## Initialization on App Start

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp();
  
  // Initialize default categories
  final categoryService = CategoryService();
  await categoryService.initializeDefaultCategories();
  
  runApp(const MyApp());
}
```

---

## Phase 6 Approval Gate

**Before proceeding to Phase 7**, please verify:

- [ ] **Validators**: All 12 validator types work correctly
- [ ] **ValidationResult**: Consistent error message format
- [ ] **Categories**: All 10 category types initialized
- [ ] **CategoryService**: CRUD operations working
- [ ] **Caching**: TTL-based cache invalidation
- [ ] **Admin UI**: Create/update/delete categories
- [ ] **Dropdowns**: Categories load and display correctly
- [ ] **Form Integration**: Validators used in registration/evaluation forms
- [ ] **Performance**: Category loads < 100ms (cached)
- [ ] **Firestore Rules**: Category read/write permissions enforced

**Open Questions**:
1. Should categories support hierarchy (parent/child)?
2. Should categories support multiple languages?
3. Should we add category "tags" for advanced filtering?
4. Should soft-deleted categories be excluded from counts?

---

## Next Phase: Phase 7

Once Phase 6 approval is granted:

**Phase 7: Admin Web Completion**

- Strict admin route guards
- Real CSV/PDF export
- Date-range filters
- Report sorting
- Category management UI
- Privacy/data-request administration
- User status filtering
- Audit log filters
- Center & teacher assignment management
- Device/RFID management
- Responsive design for smaller screens
- Estimated effort: 12-15 hours

