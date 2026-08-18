import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SavedDevice {
  final String id;
  final String originalName;
  String customName;

  SavedDevice({
    required this.id,
    required this.originalName,
    String? customName,
  }) : customName = customName ?? originalName;

  /// Назва для відображення в UI
  String get displayName => customName.isNotEmpty ? customName : originalName;

  Map<String, dynamic> toJson() => {
        'id': id,
        'originalName': originalName,
        'customName': customName,
      };

  factory SavedDevice.fromJson(Map<String, dynamic> json) {
    return SavedDevice(
      id: json['id'] as String,
      originalName: json['originalName'] as String? ??
          json['name'] as String? ??
          'Anker PowerHouse',
      customName: json['customName'] as String?,
    );
  }
}

class DeviceStorageService {
  static const String _keyDevicesList = 'saved_anker_devices';
  static const String _keySelectedDeviceId = 'selected_anker_device_id';

  static Future<List<SavedDevice>> getSavedDevices() async {
    final prefs = await SharedPreferences.getInstance();
    final String? rawData = prefs.getString(_keyDevicesList);
    if (rawData == null || rawData.isEmpty) return [];

    try {
      final List<dynamic> jsonList = jsonDecode(rawData);
      return jsonList.map((e) => SavedDevice.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveDevice(SavedDevice device) async {
    final prefs = await SharedPreferences.getInstance();
    List<SavedDevice> list = await getSavedDevices();

    int index = list.indexWhere((d) => d.id == device.id);
    if (index >= 0) {
      list[index] = device;
    } else {
      list.add(device);
    }

    final String rawData = jsonEncode(list.map((d) => d.toJson()).toList());
    await prefs.setString(_keyDevicesList, rawData);

    if (await getSelectedDeviceId() == null) {
      await setSelectedDeviceId(device.id);
    }
  }

  static Future<void> deleteDevice(String id) async {
    final prefs = await SharedPreferences.getInstance();
    List<SavedDevice> list = await getSavedDevices();
    list.removeWhere((d) => d.id == id);

    final String rawData = jsonEncode(list.map((d) => d.toJson()).toList());
    await prefs.setString(_keyDevicesList, rawData);

    String? currentSelected = await getSelectedDeviceId();
    if (currentSelected == id) {
      if (list.isNotEmpty) {
        await setSelectedDeviceId(list.first.id);
      } else {
        await prefs.remove(_keySelectedDeviceId);
      }
    }
  }

  static Future<String?> getSelectedDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keySelectedDeviceId);
  }

  static Future<void> setSelectedDeviceId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySelectedDeviceId, id);
  }
}
