import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'services/background_task_handler.dart';
import 'ui/home_screen.dart';

@pragma('vm:entry-point')
void startCallback() {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterForegroundTask.setTaskHandler(AnkerBackgroundTaskHandler());
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AnkerMonitorApp());
}

class AnkerMonitorApp extends StatelessWidget {
  const AnkerMonitorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Anker 767 BLE Monitor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueAccent,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}