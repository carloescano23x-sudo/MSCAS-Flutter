class Helpers {
  Helpers._();

  static String twoDigits(int value) => value.toString().padLeft(2, '0');

  static String formatDate(DateTime date) =>
      '${date.year}-${twoDigits(date.month)}-${twoDigits(date.day)}';

  static String formatTime(DateTime date) =>
      '${twoDigits(date.hour)}:${twoDigits(date.minute)}';

  static String fullName({
    required String firstName,
    required String lastName,
  }) => '$firstName $lastName'.trim();

  static String normalizeRole(Object? role) =>
      role?.toString().trim().toLowerCase() ?? '';
}
