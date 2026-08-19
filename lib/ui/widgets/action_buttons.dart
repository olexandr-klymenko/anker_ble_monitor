import 'package:flutter/material.dart';

class ActionButtons extends StatelessWidget {
  final bool isServiceRunning;
  final bool isAlarmRinging;
  final int snoozeMinutes;
  final VoidCallback onSnooze;
  final VoidCallback onStartService;
  final VoidCallback onStopService;

  const ActionButtons({
    super.key,
    required this.isServiceRunning,
    required this.isAlarmRinging,
    required this.snoozeMinutes,
    required this.onSnooze,
    required this.onStartService,
    required this.onStopService,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange.shade800,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.grey.shade800,
            disabledForegroundColor: Colors.grey.shade600,
            padding: const EdgeInsets.symmetric(vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          onPressed: (isServiceRunning && isAlarmRinging) ? onSnooze : null,
          icon: const Icon(Icons.notifications_paused_rounded, size: 22),
          label: Text(
            'Призупинити сигнал на $snoozeMinutes хв',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueAccent,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.grey.shade800,
            disabledForegroundColor: Colors.grey.shade600,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          onPressed: !isServiceRunning ? onStartService : null,
          icon: const Icon(Icons.play_arrow_rounded, size: 24),
          label: const Text(
            'Запустити фоновий сервіс',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.redAccent,
            disabledForegroundColor: Colors.grey.shade600,
            side: BorderSide(
              color: isServiceRunning ? Colors.redAccent : Colors.grey.shade800,
              width: 1.5,
            ),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          onPressed: isServiceRunning ? onStopService : null,
          icon: const Icon(Icons.stop_rounded, size: 22),
          label: const Text(
            'Зупинити фоновий сервіс',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
