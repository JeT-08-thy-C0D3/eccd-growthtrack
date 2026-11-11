class Validators {
  static final RegExp _emailRegex = RegExp(r'^[a-z0-9._%+-]+@gmail\.com$');

  static final RegExp _phoneRegex = RegExp(r'^(09|\+639)\d{9}$');

  static const Set<String> _blockedLanguage = {
    'asshole',
    'bastard',
    'bitch',
    'bobo',
    'bugok',
    'buang',
    'bullshit',
    'buwisit',
    'cunt',
    'dick',
    'fuck',
    'fucking',
    'gago',
    'gaga',
    'gagi',
    'hayop ka',
    'hindot',
    'inutil',
    'kupal',
    'mamatay ka',
    'patayin kita',
    'puki',
    'pakyu',
    'peste',
    'puta',
    'putang ina',
    'putangina',
    'putanginamo',
    'putanginanyo',
    'sira ulo',
    'shit',
    'slut',
    'tanga',
    'tangina',
    'tanginamo',
    'tanginanyo',
    'tarantado',
    'ulol',
    'whore',
    'yawa',
  };

  /// Validates messages intended for other users, including common Filipino
  /// and English profanity, insults, and threatening phrases.
  static String? validateAppropriateText(
    String? value,
    String fieldName, {
    bool required = false,
  }) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return required ? '$fieldName is required' : null;
    }
    if (_containsBlockedLanguage(text)) {
      return 'Please remove offensive, abusive, or inappropriate language from $fieldName.';
    }
    return null;
  }

  static bool _containsBlockedLanguage(String value) {
    final normalized = value
        .toLowerCase()
        .replaceAll('@', 'a')
        .replaceAll(r'$', 's')
        .replaceAll('0', 'o')
        .replaceAll('1', 'i')
        .replaceAll('3', 'e')
        .replaceAll('4', 'a')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim();
    final padded = ' $normalized ';
    return _blockedLanguage.any(
      (term) => RegExp('(^|\\s)${RegExp.escape(term)}(?=\\s)').hasMatch(padded),
    );
  }

  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email address is required';
    }
    final email = value.trim();
    if (email != email.toLowerCase()) {
      return 'Email address must use lowercase letters only';
    }
    if (!_emailRegex.hasMatch(email)) {
      return 'Use a valid lowercase @gmail.com address';
    }
    return null;
  }

  static String? validatePassword(
    String? value, {
    int minLength = 8,
    bool requireStrong = true,
  }) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < minLength) {
      return 'Password must be at least $minLength characters';
    }
    if (RegExp(r'\s').hasMatch(value)) {
      return 'Password must not contain spaces';
    }
    if (!requireStrong) return null;
    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return 'Password must include an uppercase letter';
    }
    if (!RegExp(r'[a-z]').hasMatch(value)) {
      return 'Password must include a lowercase letter';
    }
    if (!RegExp(r'\d').hasMatch(value)) {
      return 'Password must include a number';
    }
    if (!RegExp(r'[^A-Za-z0-9]').hasMatch(value)) {
      return 'Password must include a special character';
    }
    return null;
  }

  static String? validateRequired(
    String? value, [
    String fieldName = 'This field',
  ]) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  static String? validatePersonName(String? value, String fieldName) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) return '$fieldName is required';
    if (!RegExp(r'^[A-Za-z]+(?: [A-Za-z]+)*$').hasMatch(name)) {
      return '$fieldName may contain letters and spaces only; numbers and special characters are not allowed';
    }
    final letterCount = RegExp(r'[A-Za-z]').allMatches(name).length;
    if (letterCount < 2) {
      return '$fieldName must contain at least 2 letters';
    }
    return null;
  }

  /// Teacher names may include a period for a middle initial or title, such as
  /// "Jericho A. Taleon". Child and parent name validation remains stricter.
  static String? validateTeacherName(String? value, String fieldName) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) return '$fieldName is required';

    // Accept words separated by one space, or a period optionally followed by
    // one space. This permits initials without accepting arbitrary symbols.
    if (!RegExp(r'^[A-Za-z]+(?: [A-Za-z]+|\. ?[A-Za-z]+)*\.?$')
        .hasMatch(name)) {
      return '$fieldName may contain letters, spaces, and periods only';
    }

    final letterCount = RegExp(r'[A-Za-z]').allMatches(name).length;
    if (letterCount < 2) {
      return '$fieldName must contain at least 2 letters';
    }
    return null;
  }

  static String? validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone number is required';
    }
    if (!_phoneRegex.hasMatch(value.trim())) {
      return 'Enter a valid Philippine phone number (09XXXXXXXXX)';
    }
    return null;
  }

  static String? validateAge(String? value, {int min = 0, int max = 18}) {
    if (value == null || value.trim().isEmpty) {
      return 'Age is required';
    }
    final age = int.tryParse(value.trim());
    if (age == null) {
      return 'Please enter a valid number';
    }
    if (age < min || age > max) {
      return 'Age must be between $min and $max';
    }
    return null;
  }
}
