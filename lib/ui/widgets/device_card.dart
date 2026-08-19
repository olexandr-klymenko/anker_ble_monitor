import 'package:flutter/material.dart';
import '../../services/device_storage_service.dart';

class DeviceCard extends StatelessWidget {
  final SavedDevice device;
  final bool isServiceRunning;
  final VoidCallback onChange;

  const DeviceCard({
    super.key,
    required this.device,
    required this.isServiceRunning,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: ListTile(
        leading: const Icon(Icons.power, color: Colors.blueAccent),
        title: Text(
          device.displayName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'BLE: ${device.originalName} (${device.id})',
          style: const TextStyle(fontSize: 11),
        ),
        trailing: TextButton(
          onPressed: isServiceRunning ? null : onChange,
          child: Text(
            'Змінити',
            style: TextStyle(
              color: isServiceRunning ? Colors.grey : Colors.blueAccent,
            ),
          ),
        ),
      ),
    );
  }
}
