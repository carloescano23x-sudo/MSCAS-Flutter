import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../models/user.dart';

class AttendanceCard extends StatelessWidget {
  final AttendanceRecord record;

  const AttendanceCard({super.key, required this.record});

  @override
  Widget build(BuildContext context) {
    final status = record.status.trim().isEmpty ? 'Present' : record.status;

    final isPresent = status.toLowerCase() == 'present';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: (isPresent ? Colors.green : Colors.orange)
                  .withValues(alpha: 0.12),
              child: Icon(
                isPresent
                    ? Icons.check_circle_outline
                    : Icons.schedule_outlined,
                color: isPresent ? Colors.green : Colors.orange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.classCode ?? record.className ?? 'Class',
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (record.className != null && record.classCode != null)
                    Text(
                      record.className!,
                      style: const TextStyle(color: AppTheme.textMuted),
                    ),
                  const SizedBox(height: 6),
                  Text(
                    '${record.attendanceDate} • ${record.checkInTime}',
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    'Method: ${record.verificationMethod.toUpperCase()}',
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: (isPresent ? Colors.green : Colors.orange).withValues(
                  alpha: 0.12,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                status.toUpperCase(),
                style: TextStyle(
                  color: isPresent ? Colors.green : Colors.orange,
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
