import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../services/device_storage_service.dart';

class DeviceManagerScreen extends StatefulWidget {
  const DeviceManagerScreen({super.key});

  @override
  State<DeviceManagerScreen> createState() => _DeviceManagerScreenState();
}

class _DeviceManagerScreenState extends State<DeviceManagerScreen> {
  List<SavedDevice> _savedDevices = [];
  String? _selectedDeviceId;

  final List<ScanResult> _scanResults = [];
  StreamSubscription<List<ScanResult>>? _scanSub;
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _loadSavedDevices();
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  Future<void> _loadSavedDevices() async {
    final devices = await DeviceStorageService.getSavedDevices();
    final selectedId = await DeviceStorageService.getSelectedDeviceId();
    setState(() {
      _savedDevices = devices;
      _selectedDeviceId =
          selectedId ?? (devices.isNotEmpty ? devices.first.id : null);
      // Прибираємо зі списку сканування пристрої, які вже збережені
      _scanResults.removeWhere(
          (r) => _savedDevices.any((sd) => sd.id == r.device.remoteId.str));
    });
  }

  void _startScan() async {
    setState(() {
      _scanResults.clear();
      _isScanning = true;
    });

    _scanSub?.cancel();
    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      if (!mounted) return;
      setState(() {
        for (var r in results) {
          final name = (r.device.platformName.isNotEmpty
                  ? r.device.platformName
                  : r.advertisementData.advName)
              .toLowerCase();

          bool isAnker = name.contains('anker') || name.contains('powerhouse');
          bool isAlreadySaved =
              _savedDevices.any((sd) => sd.id == r.device.remoteId.str);

          if (isAnker &&
              !isAlreadySaved &&
              !_scanResults
                  .any((e) => e.device.remoteId == r.device.remoteId)) {
            _scanResults.add(r);
          }
        }
      });
    });

    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 8));
    } catch (_) {}

    if (mounted) {
      setState(() {
        _isScanning = false;
      });
    }
  }

  Future<void> _selectDevice(String id) async {
    await DeviceStorageService.setSelectedDeviceId(id);
    setState(() {
      _selectedDeviceId = id;
    });
  }

  Future<void> _deleteDevice(String id) async {
    await DeviceStorageService.deleteDevice(id);
    await _loadSavedDevices();
  }

  Future<void> _renameDevice(SavedDevice device) async {
    final controller = TextEditingController(text: device.customName);

    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Змінити назву'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Оригінальна назва: ${device.originalName}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Власна назва',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Скасувати'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Зберегти'),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty) {
      device.customName = newName;
      await DeviceStorageService.saveDevice(device);
      await _loadSavedDevices();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Керування Anker пристроями'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Збережені пристрої:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _savedDevices.isEmpty
                  ? const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text('Немає збережених пристроїв Anker.',
                            textAlign: TextAlign.center),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _savedDevices.length,
                      itemBuilder: (context, index) {
                        final dev = _savedDevices[index];
                        final isSelected = dev.id == _selectedDeviceId;
                        return Card(
                          color: isSelected
                              ? Colors.blueAccent.withValues(alpha: 0.2)
                              : null,
                          child: ListTile(
                            leading: Icon(
                              Icons.power,
                              color:
                                  isSelected ? Colors.greenAccent : Colors.grey,
                            ),
                            title: Text(
                              dev.displayName,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              'BLE: ${dev.originalName}\nID: ${dev.id}',
                              style: const TextStyle(fontSize: 11),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_note,
                                      color: Colors.blueAccent),
                                  onPressed: () => _renameDevice(dev),
                                  tooltip: 'Змінити назву',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      color: Colors.redAccent),
                                  onPressed: () => _deleteDevice(dev.id),
                                  tooltip: 'Видалити',
                                ),
                              ],
                            ),
                            onTap: () => _selectDevice(dev.id),
                          ),
                        );
                      },
                    ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Пошук пристроїв Anker:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  ElevatedButton.icon(
                    onPressed: _isScanning ? null : _startScan,
                    icon: _isScanning
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.search),
                    label: Text(_isScanning ? 'Шукаємо...' : 'Сканувати'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _scanResults.isEmpty
                    ? Center(
                        child: Text(
                          _isScanning
                              ? 'Шукаємо Anker PowerHouse поблизу...'
                              : 'Натисніть "Сканувати" для пошуку',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _scanResults.length,
                        itemBuilder: (context, index) {
                          final result = _scanResults[index];
                          final name = result.device.platformName.isNotEmpty
                              ? result.device.platformName
                              : result.advertisementData.advName;
                          final id = result.device.remoteId.str;

                          return Card(
                            child: ListTile(
                              leading: const Icon(Icons.battery_charging_full,
                                  color: Colors.blueAccent),
                              title: Text(name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              subtitle: Text(id),
                              trailing: const Icon(Icons.add_circle_outline,
                                  color: Colors.greenAccent),
                              onTap: () async {
                                final newDevice =
                                    SavedDevice(id: id, originalName: name);
                                await DeviceStorageService.saveDevice(
                                    newDevice);
                                await DeviceStorageService.setSelectedDeviceId(
                                    id);
                                await _loadSavedDevices();
                              },
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
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
                onPressed: _selectedDeviceId == null
                    ? null
                    : () => Navigator.of(context).pop(true),
                child: const Text(
                  'Перейти до моніторингу',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
