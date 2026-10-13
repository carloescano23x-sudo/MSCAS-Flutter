import 'supabase_firestore_compat.dart';

class SessionTimeService {
  const SessionTimeService._();

  static DateTime? asDate(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value);
    }

    return null;
  }

  static DateTime? effectiveEnd(Map<String, dynamic> data) =>
      asDate(data['effective_end_at']) ?? asDate(data['scheduled_end_at']);

  static bool isOpen(Map<String, dynamic> data, {DateTime? now}) {
    if (data['active'] != true) {
      return false;
    }

    final end = effectiveEnd(data);

    return end == null || (now ?? DateTime.now()).isBefore(end);
  }

  static bool isExpired(Map<String, dynamic> data, {DateTime? now}) {
    if (data['active'] != true) {
      return false;
    }

    final end = effectiveEnd(data);

    return end != null && !(now ?? DateTime.now()).isBefore(end);
  }

  static String? validateStart(
    Map<String, dynamic> classData, {
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();

    final day =
        classData['schedule_day']?.toString().trim().toLowerCase() ?? '';

    if (day.isNotEmpty && !_matchesDay(day, current.weekday)) {
      return 'This class is scheduled for '
          '${classData['schedule_day']}, not today.';
    }

    final start = _today(classData['start_time']?.toString() ?? '', current);

    final end = _today(classData['end_time']?.toString() ?? '', current);

    if (start == null || end == null || !end.isAfter(start)) {
      return 'Set a valid class start and end time first.';
    }

    if (current.isBefore(start)) {
      return 'Attendance opens at the scheduled start time '
          '(${formatClock(start)}).';
    }

    if (!current.isBefore(end)) {
      return 'The scheduled class ended at ${formatClock(end)}.';
    }

    return null;
  }

  static Map<String, dynamic> fieldsForNewSession(
    Map<String, dynamic> classData, {
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();

    final start = _today(classData['start_time']?.toString() ?? '', current)!;

    final end = _today(classData['end_time']?.toString() ?? '', current)!;

    return {
      'scheduled_start_at': Timestamp.fromDate(start),
      'scheduled_end_at': Timestamp.fromDate(end),
      'effective_end_at': Timestamp.fromDate(end),
      'extended': false,
      'extension_minutes': 0,
    };
  }

  static DateTime extend(
    Map<String, dynamic> data,
    int minutes, {
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    final oldEnd = effectiveEnd(data) ?? current;
    final base = oldEnd.isAfter(current) ? oldEnd : current;

    return base.add(Duration(minutes: minutes));
  }

  static String formatClock(DateTime value) {
    final h = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final m = value.minute.toString().padLeft(2, '0');

    return '$h:$m ${value.hour >= 12 ? 'PM' : 'AM'}';
  }

  static bool _matchesDay(String raw, int weekday) {
    const aliases = <int, List<String>>{
      1: ['monday', 'mon'],
      2: ['tuesday', 'tue', 'tues'],
      3: ['wednesday', 'wed'],
      4: ['thursday', 'thu', 'thur', 'thurs'],
      5: ['friday', 'fri'],
      6: ['saturday', 'sat'],
      7: ['sunday', 'sun'],
    };

    return aliases[weekday]!.any(
      (x) => RegExp('(^|[^a-z])$x([^a-z]|\$)').hasMatch(raw),
    );
  }

  static DateTime? _today(String raw, DateTime day) {
    final match = RegExp(
      r'^(\d{1,2})(?::(\d{1,2}))?\s*(AM|PM)?$',
      caseSensitive: false,
    ).firstMatch(raw.trim());

    if (match == null) {
      return null;
    }

    var hour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2) ?? '0');
    final suffix = match.group(3)?.toUpperCase();

    if (hour == null || minute == null || minute > 59) {
      return null;
    }

    if (suffix != null) {
      if (hour < 1 || hour > 12) {
        return null;
      }

      if (suffix == 'AM' && hour == 12) {
        hour = 0;
      }

      if (suffix == 'PM' && hour != 12) {
        hour += 12;
      }
    } else if (hour > 23) {
      return null;
    }

    return DateTime(day.year, day.month, day.day, hour, minute);
  }
}
