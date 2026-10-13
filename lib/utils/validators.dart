class Validators {
  Validators._();

  static String? requiredText(
    String? value, {
    String fieldName = 'This field',
  }) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  static String? email(String? value) {
    final required = requiredText(value, fieldName: 'Email');
    if (required != null) return required;

    final text = value!.trim();
    final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

    if (!emailPattern.hasMatch(text)) {
      return 'Enter a valid email address';
    }

    return null;
  }

  static String? password(String? value) {
    final required = requiredText(value, fieldName: 'Password');
    if (required != null) return required;

    if (value!.length < 6) {
      return 'Password must be at least 6 characters';
    }

    return null;
  }

  static String? positiveNumber(String? value, {String fieldName = 'Value'}) {
    final required = requiredText(value, fieldName: fieldName);
    if (required != null) return required;

    final number = double.tryParse(value!.trim());
    if (number == null || number <= 0) {
      return '$fieldName must be greater than zero';
    }

    return null;
  }
}
