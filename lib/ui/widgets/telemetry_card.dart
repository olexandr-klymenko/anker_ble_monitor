import 'package:flutter/material.dart';
import '../../models/anker_telemetry.dart';
import 'charging_progress_bar.dart';

class TelemetryCard extends StatelessWidget {
  final bool isServiceRunning;
  final AnkerTelemetry? telemetry;
  final int lowThreshold;
  final int fullThreshold;

  const TelemetryCard({
    super.key,
    required this.isServiceRunning,
    required this.telemetry,
    required this.lowThreshold,
    required this.fullThreshold,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isServiceRunning ? Colors.greenAccent : Colors.grey.shade700,
          width: 2,
        ),
        color: isServiceRunning
            ? Colors.greenAccent.withValues(alpha: 0.08)
            : Colors.grey.shade900,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isServiceRunning
                        ? Icons.bluetooth_connected
                        : Icons.bluetooth_disabled,
                    size: 24,
                    color: isServiceRunning ? Colors.greenAccent : Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isServiceRunning
                        ? 'МОНІТОРИНГ АКТИВНИЙ'
                        : 'СЕРВІС ЗУПИНЕНО',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isServiceRunning
                          ? Colors.greenAccent
                          : Colors.redAccent,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (isServiceRunning &&
                  telemetry != null &&
                  telemetry!.soc >= 0) ...[
                Text(
                  '${telemetry!.soc}%',
                  style: const TextStyle(
                    fontSize: 52,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: 260,
                  child: ChargingProgressBar(
                    soc: telemetry!.soc,
                    isCharging: telemetry!.isCharging,
                    lowThreshold: lowThreshold,
                    fullThreshold: fullThreshold,
                  ),
                ),
                const SizedBox(height: 10),
                if (telemetry!.isCharging)
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.bolt, color: Colors.amber, size: 20),
                      SizedBox(width: 4),
                      Text(
                        'Живлення підключено',
                        style: TextStyle(
                          color: Colors.amber,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  )
                else
                  const Text(
                    'Живлення від мережі відсутнє',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
              ] else ...[
                const Icon(Icons.battery_unknown, size: 52, color: Colors.grey),
                const SizedBox(height: 8),
                Text(
                  isServiceRunning
                      ? 'Очікування даних з Anker...'
                      : 'Запустіть сервіс для отримання даних',
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
