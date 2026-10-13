import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../models/user.dart';

class ClassCard extends StatelessWidget {
  final Class classObj;
  final VoidCallback? onTap;
  final Widget? trailing;
  final Widget? action;

  const ClassCard({
    super.key,
    required this.classObj,
    this.onTap,
    this.trailing,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          classObj.classCode,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          classObj.className,
                          style: const TextStyle(color: AppTheme.textPrimary),
                        ),
                        if (classObj.section.trim().isNotEmpty)
                          Text(
                            classObj.section,
                            style: const TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Display trailing widget only when provided.
                  ?trailing,
                ],
              ),

              const SizedBox(height: 12),

              if (classObj.instructorName.trim().isNotEmpty)
                _DetailRow(
                  icon: Icons.person_outline,
                  text: classObj.instructorName,
                ),

              if (classObj.scheduleText.trim().isNotEmpty)
                _DetailRow(
                  icon: Icons.schedule_outlined,
                  text: classObj.scheduleText,
                ),

              if (classObj.room?.trim().isNotEmpty == true)
                _DetailRow(
                  icon: Icons.location_on_outlined,
                  text: classObj.room!,
                ),

              // Only add the spacing when an action exists.
              if (action case final actionWidget?) ...[
                const SizedBox(height: 14),
                actionWidget,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _DetailRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: AppTheme.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}
