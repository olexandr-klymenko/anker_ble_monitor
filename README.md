# AnkerAlert (Anker BLE Monitor) 🔋⚡

Оптимізований Flutter-додаток для фонового моніторингу стану заряду та живлення зарядних станцій Anker PowerHouse (767 / F2000) через Bluetooth Low Energy (BLE).

Додаток призначений для автоматичного сповіщення про необхідність увімкнення або вимкнення генератора/мережевого живлення.

---

## 🚀 Основні можливості

* **Фоновий моніторинг (Android Foreground Service):** Додаток працює у фоновому режимі та не закривається системою при згортанні.
* **Гнучкі сповіщення:**
  * **Поріг розряду (Low Battery):** Звуковий сигнал при падінні заряду нижче встановленого порогу.
  * **Повний заряд (Full Battery):** Окремий сигнал про досягнення макс. заряду під час живлення від мережі/генератора.
  * **Автоматичне скасування:** Сигнал розряду миттєво вимикається при появі вхідної напруги (AC Input > 0 Вт).
* **Динамічне керування у шторці Android:** Кнопка «Заглушити сигнал» з'являється у системному сповіщенні тільки під час звучання тривоги.
* **Керування декількома пристроями:**
  * Пошук та фільтрація лише станцій Anker поблизу.
  * Збереження пристроїв у локальній пам'яті (SharedPreferences).
  * Власні (кастомні) назви для кожної станції із збереженням оригінальної BLE-назви.
* **Тимчасова призупинка (Snooze):** Можливість вимкнути звук на заданий час (3, 4, 5 хв). Зміна налаштувань, що скасовують умову тривоги, автоматично анулює паузу.

---

## 🛠 Архітектура проєкту

Код розділений на шари так, щоб уся бізнес-логіка (коли саме дзвонить тривога, що написати в нотифікації) перевірялась юніт-тестами без реального BLE-стека чи платформних плагінів. UI-ізолят і фоновий `TaskHandler`-ізолят спілкуються через типізований IPC (`ipc/`), а не через довільні `Map`.

```
lib/
├── domain/                       — чиста бізнес-логіка, без Flutter/BLE-залежностей
│   ├── alarm_controller.dart         — стейт-машина тривоги (коли дзвонити/глушити)
│   ├── monitor_notification_builder.dart — текст нотифікації зі знімка AlarmEvaluation
│   └── models/
│       └── monitor_settings.dart     — value-object порогів і паузи
│
├── data/ble/                     — доступ до станції за інтерфейсом
│   ├── anker_connection.dart         — абстракція (connect/telemetry/keepAlive)
│   └── flutter_blue_anker_connection.dart — реалізація на flutter_blue_plus
│
├── services/
│   ├── background_task_handler.dart  — тонкий TaskHandler, делегує до MonitorService
│   ├── monitor_service.dart          — оркестрація: телеметрія → тривога → звук → нотифікація
│   ├── alarm_audio.dart              — абстракція над AudioPlayer
│   ├── monitor_notifier.dart         — абстракція над нотифікацією Android-сервісу
│   ├── device_storage_service.dart   — збереження пристроїв і налаштувань (SharedPreferences)
│   ├── permission_service.dart       — запит дозволів Bluetooth/Location/Notifications
│   └── telemetry_parser.dart         — парсинг сирих BLE-пакетів телеметрії
│
├── ipc/                          — типізований зв'язок між UI- та фоновим ізолятом
│   ├── monitor_command.dart          — команди UI → фон (SyncStateCommand, SnoozeCommand)
│   └── telemetry_channel.dart        — потік телеметрії фон → UI
│
├── models/
│   └── anker_telemetry.dart          — знімок телеметрії, що публікується в UI
│
├── ui/
│   ├── home_screen.dart              — головний екран (Mobile/Tablet), без бізнес-логіки
│   ├── monitor_view_model.dart       — стан екрана (ChangeNotifier), без BuildContext
│   ├── device_scanner_dialog.dart    — керування збереженими пристроями та сканування BLE
│   ├── settings_screen.dart          — екран налаштування порогів і паузи
│   └── widgets/
│       ├── action_buttons.dart       — панель кнопок керування сервісом
│       ├── charging_progress_bar.dart— прогресбар з анімованою хвилею світла
│       ├── device_card.dart          — картка вибраного пристрою
│       └── telemetry_card.dart       — картка стану заряду та мережевого живлення
│
└── main.dart                     — точка входу UI-ізолята й фонового callback
```

**Потік даних:** `FlutterBlueAnkerConnection` отримує сирі байти → `TelemetryParser` розбирає їх → `MonitorService` прогонить результат крізь `AlarmController` (вирішує, чи дзвонити тривогу) → `AlarmAudio`/`MonitorNotifier` застосовують ефект → `TelemetryChannel` публікує знімок в UI-ізолят → `MonitorViewModel` оновлює `HomeScreen`. Зміни з UI (пороги, вибір пристрою, snooze) йдуть у зворотному напрямку через `MonitorCommand`.

Кожен шар (`domain/`, `services/`, `ipc/`, `ui/`) покритий юніт-тестами з фейками замість реальних BLE/аудіо/нотифікаційних плагінів — структура `test/` дзеркалить `lib/` (`test/domain/`, `test/services/`, `test/ipc/`, `test/ui/`), плюс окрема `test/fakes/` зі спільними тестовими двійниками.

---

## ⚙️ Встановлення та збірка

### Вимоги:
* Flutter SDK: >=3.3.0
* Android: API level 21+ (Android 5.0+)

### Збірка APK / AAB:

1. Завантажити залежності:
   flutter pub get

2. Зібрати APK для GitHub Release:
   flutter build apk --release

3. Зібрати App Bundle для Google Play Console:
   flutter build appbundle --release

---

## 📋 Changelog

### v1.3.1

* 🏗 Рефакторинг архітектури: бізнес-логіка тривоги (`AlarmController`) і побудова тексту нотифікацій (`MonitorNotificationBuilder`) винесені в незалежний від Flutter `domain/`-шар — усунуто дублювання, коли умова тривоги перевірялась і в фоновому сервісі, і в нотифікації окремо.
* 🔌 BLE винесено за інтерфейс `AnkerConnection`: фоновий оркестратор `MonitorService` більше не залежить напряму від `flutter_blue_plus`, `AudioPlayer` чи `flutter_foreground_task` — усі підмінюються фейками в тестах.
* 📡 Типізований IPC (`ipc/monitor_command.dart`, `ipc/telemetry_channel.dart`) замінив довільні `Map` між UI- та фоновим ізолятом; виправлено витік `ReceivePort`, що лишався зареєстрованим після закриття екрана.
* 🖥 `HomeScreen` розвантажено в `MonitorViewModel` (`ChangeNotifier` без `BuildContext`) — стан екрана тепер тестується без побудови віджетів.
* 🧹 Прибрано дублюючу кнопку `settings_bluetooth` в AppBar (та сама дія, що й «Змінити» на картці пристрою) і мертвий код: поле `acInWatts` з `AnkerTelemetry`, `PermissionService.isBluetoothEnabled()`, `MonitorSettings.copyWith()`, `AlarmController.isLowAlarmActive`/`isFullAlarmActive`-геттери; злито `service/` і `services/` в один каталог.
* 🔢 Показ поточної версії застосунку у футері головного екрана (`package_info_plus`).
* ✅ Юніт-тести на всі нові шари (`domain/`, `services/`, `ipc/`, `ui/monitor_view_model.dart`), включно з фейками для BLE/аудіо/нотифікацій і мокнутим `MethodChannel` для `flutter_foreground_task`; структура `test/` приведена у відповідність до `lib/`.

### v1.2.0

* 🔐 CI: налаштовано підпис релізних збірок (keystore, `key.properties`) та явний шлях до нього в GitHub Actions.
* ✅ Тести: юніт-тести для `DeviceStorageService`, розширені edge-case тести для `TelemetryParser`; тестовий ранер інтегровано в реліз-workflow.

### v1.1.0

* 🏗 Рефакторинг: Повний перехід на модульну структуру та Pub/Sub взаємодію між ізолятами (IsolatePubSub, замінено на TelemetryChannel у v1.3.1).
* 📱 Керування пристроями: Додано окремий екран сканування станцій Anker та можливість задавати власні імена.
* ⚙️ Налаштування: Налаштування порогів та паузи винесено в окремий екран SettingsScreen.
* 🔔 Smart Notifications: Кнопка глушіння у шторці Android з'являється лише у момент активності звукового сигналу.
* ⚡ Автоматизація: Зміна налаштувань під час паузи автоматично оновлює стан шторки та анулює паузу, якщо тривога більше не актуальна.