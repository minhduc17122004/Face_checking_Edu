import 'package:face_time_keeping/common/resources/app_colors.dart';
import 'package:face_time_keeping/entities/edu_check_in.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class EduCheckInResultWidget extends StatelessWidget {
  final EduCheckIn checkIn;

  const EduCheckInResultWidget({super.key, required this.checkIn});

  @override
  Widget build(BuildContext context) {
    final isPending = checkIn.status == 'pending';
    final color = _statusColor();
    final icon = _statusIcon();

    return Card(
      margin: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withOpacity(0.15),
                  radius: 24,
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        checkIn.studentName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        checkIn.statusLabel,
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Time row
            Row(
              children: [
                const Icon(Icons.access_time, size: 16, color: Colors.grey),
                const SizedBox(width: 6),
                Text(
                  DateFormat('HH:mm:ss dd/MM/yyyy').format(checkIn.checkinTime),
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ],
            ),

            // Offset row
            if (checkIn.minutesDiff != null && !isPending) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    checkIn.minutesDiff! > 0
                        ? Icons.arrow_upward
                        : Icons.arrow_downward,
                    size: 16,
                    color: checkIn.minutesDiff! > 0 ? AppColors.orange : AppColors.green,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    checkIn.minutesDiff! > 0
                        ? 'Trễ ${checkIn.minutesDiff} phút'
                        : 'Sớm ${-checkIn.minutesDiff!} phút',
                    style: TextStyle(
                      color: checkIn.minutesDiff! > 0
                          ? AppColors.orange
                          : AppColors.green,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],

            // Message
            const SizedBox(height: 8),
            Text(
              checkIn.message,
              style: TextStyle(
                color: isPending ? AppColors.orange : Colors.grey[700],
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor() {
    switch (checkIn.status) {
      case 'early':
        return const Color(0xFF0D9488); // teal
      case 'on_time':
        return Colors.green;
      case 'late':
        return Colors.orange;
      case 'pending':
        return Colors.amber;
      default:
        return Colors.green;
    }
  }

  IconData _statusIcon() {
    switch (checkIn.status) {
      case 'early':
        return Icons.alarm;
      case 'on_time':
        return Icons.check_circle;
      case 'late':
        return Icons.access_time;
      case 'pending':
        return Icons.cloud_upload;
      default:
        return Icons.check_circle;
    }
  }
}
