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
        toolbarHeight: 48,
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  bool isTablet = constraints.maxWidth >= 600;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Збережені пристрої:',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      _savedDevices.isEmpty
                          ? const Card(
                              child: Padding(
                                padding: EdgeInsets.all(12.0),
                                child: Text('Немає збережених пристроїв Anker.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 13)),
                              ),
                            )
                          : _buildSavedDevicesList(isTablet),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Пошук пристроїв Anker:',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                            ),
                            onPressed: _isScanning ? null : _startScan,
                            icon: _isScanning
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Icon(Icons.search, size: 18),
                            label: Text(
                                _isScanning ? 'Шукаємо...' : 'Сканувати',
                                style: const TextStyle(fontSize: 13)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Expanded(
                        child: _scanResults.isEmpty
                            ? Center(
                                child: Text(
                                  _isScanning
                                      ? 'Шукаємо Anker PowerHouse поблизу...'
                                      : 'Натисніть "Сканувати" для пошуку',
                                  style: const TextStyle(
                                      color: Colors.grey, fontSize: 13),
                                ),
                              )
                            : _buildScanResultsList(isTablet),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey.shade800,
                          disabledForegroundColor: Colors.grey.shade600,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _selectedDeviceId == null
                            ? null
                            : () => Navigator.of(context).pop(true),
                        child: const Text(
                          'Перейти до моніторингу',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSavedDevicesList(bool isTablet) {
    if (isTablet) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 3.5,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: _savedDevices.length,
        itemBuilder: (context, index) =>
            _buildSavedDeviceTile(_savedDevices[index]),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _savedDevices.length,
      itemBuilder: (context, index) =>
          _buildSavedDeviceTile(_savedDevices[index]),
    );
  }

  Widget _buildSavedDeviceTile(SavedDevice dev) {
    final isSelected = dev.id == _selectedDeviceId;
    return Card(
      color: isSelected ? Colors.blueAccent.withValues(alpha: 0.2) : null,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
        leading: Icon(
          Icons.power,
          color: isSelected ? Colors.greenAccent : Colors.grey,
          size: 22,
        ),
        title: Text(
          dev.displayName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        subtitle: Text(
          'BLE: ${dev.originalName}',
          style: const TextStyle(fontSize: 10),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_note,
                  color: Colors.blueAccent, size: 20),
              onPressed: () => _renameDevice(dev),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  color: Colors.redAccent, size: 20),
              onPressed: () => _deleteDevice(dev.id),
            ),
          ],
        ),
        onTap: () => _selectDevice(dev.id),
      ),
    );
  }

  Widget _buildScanResultsList(bool isTablet) {
    if (isTablet) {
      return GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 3.5,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: _scanResults.length,
        itemBuilder: (context, index) =>
            _buildScanResultTile(_scanResults[index]),
      );
    }

    return ListView.builder(
      itemCount: _scanResults.length,
      itemBuilder: (context, index) =>
          _buildScanResultTile(_scanResults[index]),
    );
  }

  Widget _buildScanResultTile(ScanResult result) {
    final name = result.device.platformName.isNotEmpty
        ? result.device.platformName
        : result.advertisementData.advName;
    final id = result.device.remoteId.str;

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
        leading: const Icon(Icons.battery_charging_full,
            color: Colors.blueAccent, size: 22),
        title: Text(name,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        subtitle: Text(id, style: const TextStyle(fontSize: 10)),
        trailing: const Icon(Icons.add_circle_outline,
            color: Colors.greenAccent, size: 20),
        onTap: () async {
          final newDevice = SavedDevice(id: id, originalName: name);
          await DeviceStorageService.saveDevice(newDevice);
          await DeviceStorageService.setSelectedDeviceId(id);
          await _loadSavedDevices();
        },
      ),
    );
  }
}
