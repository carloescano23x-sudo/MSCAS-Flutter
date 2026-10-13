import '../../services/supabase_auth_compat.dart';
import 'package:flutter/material.dart';

import '../../config/app_theme.dart';
import '../../models/user.dart';
import '../../services/attendance_service.dart';
import '../../services/offline_attendance_service.dart';

class AttendanceHistory extends StatefulWidget {
  const AttendanceHistory({super.key});

  @override
  State<AttendanceHistory> createState() => AttendanceHistoryState();
}

class AttendanceHistoryState extends State<AttendanceHistory> {
  final AttendanceService _attendanceService = AttendanceService();

  List<AttendanceRecord> _records = [];
  List<Map<String, dynamic>> _pending = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    if (mounted) setState(() => _isLoading = true);

    try {
      final studentId = FirebaseAuth.instance.currentUser?.uid ?? '';

      if (studentId.isEmpty) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      await OfflineAttendanceService.instance.syncPending();

      final results = await Future.wait<dynamic>([
        _attendanceService.getAttendanceHistory(studentId),
        OfflineAttendanceService.instance.pendingForStudent(studentId),
      ]);

      final records = results[0] as List<AttendanceRecord>;
      final pending = results[1] as List<Map<String, dynamic>>;

      if (!mounted) return;

      setState(() {
        _records = records;
        _pending = pending;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_records.isEmpty && _pending.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadHistory,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.62,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.history_rounded,
                      size: 72,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No Attendance Records',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text('Your submitted attendance will appear here.'),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadHistory,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        itemCount: _pending.length + _records.length,
        itemBuilder: (context, index) {
          if (index < _pending.length) {
            return _buildPendingCard(_pending[index]);
          }

          final record = _records[index - _pending.length];
          final status = record.status.toLowerCase();

          final icon = status == 'present'
              ? Icons.check_circle_rounded
              : status == 'late'
              ? Icons.schedule_rounded
              : Icons.cancel_rounded;

          final color = status == 'present'
              ? Colors.green
              : status == 'late'
              ? Colors.orange
              : Colors.red;

          return Card(
            margin: const EdgeInsets.only(bottom: 14),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor: color.withValues(alpha: 0.12),
                    child: Icon(icon, color: color),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          record.classCode?.isNotEmpty == true
                              ? record.classCode!
                              : record.classId,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                            fontSize: 16,
                          ),
                        ),
                        if (record.className?.isNotEmpty == true)
                          Text(record.className!),
                        if (record.section?.isNotEmpty == true)
                          Text(
                            record.section!,
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        const SizedBox(height: 8),
                        Text(
                          '${record.attendanceDate} • ${record.checkInTime}',
                        ),
                        Text(
                          'Method: ${record.verificationMethod.toUpperCase()}',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      record.status.toUpperCase(),
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPendingCard(Map<String, dynamic> item) {
    final capturedAt = DateTime.tryParse(item['captured_at']?.toString() ?? '');

    final date = capturedAt == null
        ? 'Offline capture'
        : '${capturedAt.year}-${capturedAt.month.toString().padLeft(2, '0')}-${capturedAt.day.toString().padLeft(2, '0')} • ${capturedAt.hour.toString().padLeft(2, '0')}:${capturedAt.minute.toString().padLeft(2, '0')}';

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: Colors.orange.withValues(alpha: 0.12),
              child: const Icon(
                Icons.cloud_upload_outlined,
                color: Colors.orange,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['subject_code']?.toString().isNotEmpty == true
                        ? item['subject_code'].toString()
                        : item['class_id']?.toString() ?? 'Class',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                      fontSize: 16,
                    ),
                  ),
                  if (item['subject_name']?.toString().isNotEmpty == true)
                    Text(item['subject_name'].toString()),
                  if (item['section']?.toString().isNotEmpty == true)
                    Text(
                      item['section'].toString(),
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  const SizedBox(height: 8),
                  Text(date),
                  const Text(
                    'Method: FACE • saved on this phone',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'PENDING SYNC',
                style: TextStyle(
                  color: Colors.orange,
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
