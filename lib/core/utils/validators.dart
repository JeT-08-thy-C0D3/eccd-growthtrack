class Validators {
  static final RegExp _emailRegex = RegExp(r'^[a-z0-9._%+-]+@gmail\.com$');

  static final RegExp _phoneRegex = RegExp(r'^(09|\+639)\d{9}$');

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
    if (name.length < 2) {
      return '$fieldName must contain at least 2 letters';
    }
    if (!RegExp(r'^[A-Za-z]+(?: [A-Za-z]+)*$').hasMatch(name)) {
      return '$fieldName may contain letters and spaces only (no special characters)';
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
