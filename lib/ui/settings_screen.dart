import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  final int lowThreshold;
  final int fullThreshold;
  final int snoozeMinutes;

  const SettingsScreen({
    super.key,
    required this.lowThreshold,
    required this.fullThreshold,
    required this.snoozeMinutes,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late int _low;
  late int _full;
  late int _snooze;

  final List<int> _lowThresholdOptions = [
    5,
    10,
    15,
    20,
    25,
    30,
    40,
    50,
    60,
    70,
    80
  ];
  final List<int> _fullThresholdOptions = [80, 85, 90, 95, 100];
  final List<int> _snoozeOptions = [3, 4, 5];

  @override
  void initState() {
    super.initState();
    _low = widget.lowThreshold;
    _full = widget.fullThreshold;
    _snooze = widget.snoozeMinutes;
  }

  void _saveAndPop() {
    Navigator.of(context).pop({
      'lowThreshold': _low,
      'fullThreshold': _full,
      'snoozeMinutes': _snooze,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Налаштування порогів'),
        centerTitle: true,
        toolbarHeight: 48,
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16.0, vertical: 8.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Поріг розряду (Low):',
                                      style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500)),
                                  DropdownButton<int>(
                                    value: _low,
                                    underline: const SizedBox(),
                                    items: _lowThresholdOptions
                                        .map((v) => DropdownMenuItem(
                                            value: v, child: Text('$v%')))
                                        .toList(),
                                    onChanged: (v) => v != null
                                        ? setState(() => _low = v)
                                        : null,
                                  ),
                                ],
                              ),
                              const Divider(height: 12),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Сигнал заряду (Full):',
                                      style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500)),
                                  DropdownButton<int>(
                                    value: _full,
                                    underline: const SizedBox(),
                                    items: _fullThresholdOptions
                                        .map((v) => DropdownMenuItem(
                                            value: v, child: Text('$v%')))
                                        .toList(),
                                    onChanged: (v) => v != null
                                        ? setState(() => _full = v)
                                        : null,
                                  ),
                                ],
                              ),
                              const Divider(height: 12),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Ручна призупинка:',
                                      style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500)),
                                  DropdownButton<int>(
                                    value: _snooze,
                                    underline: const SizedBox(),
                                    items: _snoozeOptions
                                        .map((v) => DropdownMenuItem(
                                            value: v, child: Text('$v хв')))
                                        .toList(),
                                    onChanged: (v) => v != null
                                        ? setState(() => _snooze = v)
                                        : null,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _saveAndPop,
                    child: const Text('Зберегти налаштування',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
