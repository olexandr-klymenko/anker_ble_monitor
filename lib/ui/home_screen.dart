import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../domain/models/monitor_settings.dart';
import 'monitor_view_model.dart';
import '../main.dart' show startCallback;
import 'device_scanner_dialog.dart';
import 'settings_screen.dart';
import 'widgets/action_buttons.dart';
import 'widgets/device_card.dart';
import 'widgets/telemetry_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MonitorViewModel _viewModel = MonitorViewModel();
  bool _isLoading = true;
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _viewModel.addListener(_onViewModelChanged);
    _init();
    _loadAppVersion();
  }

  Future<void> _init() async {
    await _viewModel.init();
    setState(() => _isLoading = false);

    if (_viewModel.selectedDevice == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openDeviceManager());
    }
  }

  Future<void> _loadAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) setState(() => _appVersion = info.version);
  }

  void _onViewModelChanged() => setState(() {});

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChanged);
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _openDeviceManager() async {
    if (_viewModel.isServiceRunning) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const DeviceManagerScreen()),
    );
    await _viewModel.refreshSelectedDevice();
  }

  Future<void> _openSettings() async {
    final result = await Navigator.of(context).push<MonitorSettings>(
      MaterialPageRoute(
        builder: (context) => SettingsScreen(settings: _viewModel.settings),
      ),
    );

    if (result != null) {
      await _viewModel.updateSettings(result);
    }
  }

  Future<void> _startService() async {
    if (_viewModel.selectedDevice == null) {
      _openDeviceManager();
      return;
    }

    if (!await _viewModel.requestPermissions()) return;
    await _viewModel.startService(startCallback);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _viewModel.selectedDevice == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return WithForegroundTask(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Anker 767 BLE Monitor'),
          centerTitle: true,
          toolbarHeight: 48,
        ),
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  bool isTablet = constraints.maxWidth >= 600;
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 8.0),
                    child:
                        isTablet ? _buildTabletLayout() : _buildMobileLayout(),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileLayout() {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DeviceCard(
            device: _viewModel.selectedDevice!,
            isServiceRunning: _viewModel.isServiceRunning,
            onChange: _openDeviceManager,
          ),
          const SizedBox(height: 8),
          TelemetryCard(
            isServiceRunning: _viewModel.isServiceRunning,
            telemetry: _viewModel.latestTelemetry,
            lowThreshold: _viewModel.settings.lowThreshold,
            fullThreshold: _viewModel.settings.fullThreshold,
          ),
          const SizedBox(height: 8),
          _buildSettingsCard(),
          const SizedBox(height: 10),
          ActionButtons(
            isServiceRunning: _viewModel.isServiceRunning,
            isAlarmRinging: _viewModel.isAlarmRinging,
            snoozeMinutes: _viewModel.settings.snoozeMinutes,
            onSnooze: _viewModel.snooze,
            onStartService: _startService,
            onStopService: _viewModel.stopService,
          ),
          _buildVersionFooter(),
        ],
      ),
    );
  }

  Widget _buildTabletLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DeviceCard(
                device: _viewModel.selectedDevice!,
                isServiceRunning: _viewModel.isServiceRunning,
                onChange: _openDeviceManager,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: TelemetryCard(
                  isServiceRunning: _viewModel.isServiceRunning,
                  telemetry: _viewModel.latestTelemetry,
                  lowThreshold: _viewModel.settings.lowThreshold,
                  fullThreshold: _viewModel.settings.fullThreshold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 4,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSettingsCard(),
                const SizedBox(height: 8),
                ActionButtons(
                  isServiceRunning: _viewModel.isServiceRunning,
                  isAlarmRinging: _viewModel.isAlarmRinging,
                  snoozeMinutes: _viewModel.settings.snoozeMinutes,
                  onSnooze: _viewModel.snooze,
                  onStartService: _startService,
                  onStopService: _viewModel.stopService,
                ),
                _buildVersionFooter(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVersionFooter() {
    if (_appVersion.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Center(
        child: Text(
          'Anker BLE Monitor v$_appVersion',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
        ),
      ),
    );
  }

  Widget _buildSettingsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Низький: ${_viewModel.settings.lowThreshold}% | '
                  'Повний: ${_viewModel.settings.fullThreshold}%',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text('Пауза: ${_viewModel.settings.snoozeMinutes} хв',
                    style: const TextStyle(color: Colors.grey, fontSize: 11)),
              ],
            ),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: const Icon(Icons.tune, color: Colors.blueAccent, size: 20),
              onPressed: _openSettings,
            ),
          ],
        ),
      ),
    );
  }
}
