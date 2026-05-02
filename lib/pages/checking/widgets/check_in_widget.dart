import 'package:face_time_keeping/entities/check_in.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../common/resources/index.dart';

class CheckInWidget extends StatelessWidget {
  final CheckIn? checkInData;

  const CheckInWidget({Key? key, this.checkInData}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    String formattedTime = DateFormat('yyyy-MM-dd HH:mm:ss')
        .format(checkInData?.time ?? DateTime.now());
    bool isLate =
        checkInData?.minutesLate != null && checkInData!.minutesLate! > 0;
    bool isEarly =
        checkInData?.minutesLate != null && checkInData!.minutesLate! < 0;
    final statusColor = isLate
        ? Colors.red
        : isEarly
            ? AppColors.teal600
            : Colors.green;
    final statusIcon =
        isLate ? Icons.warning : (isEarly ? Icons.alarm : Icons.check_circle);
    final statusText = isLate
        ? 'Đến muộn ${checkInData!.minutesLate!} phút'
        : isEarly
            ? 'Sớm (${checkInData!.minutesLate!.abs()} p)'
            : 'Đúng giờ';
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      elevation: 4,
      margin: const EdgeInsets.all(12.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(width: 12),
            // Check-in details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formattedTime,
                    style: TextStyles.blackSmallRegular,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Học sinh:',
                    style: TextStyles.blackSmallRegular.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    checkInData?.studentName ?? 'Unknown',
                    style: TextStyles.blackSmallRegular,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        statusIcon,
                        color: statusColor,
                        size: 20,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          statusText,
                          style: TextStyles.blackSmallRegular.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
