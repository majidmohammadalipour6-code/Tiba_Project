import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:just_audio/just_audio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TibaLauncherApp());
}

class TibaLauncherApp extends StatelessWidget {
  const TibaLauncherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Tiba 2 Launcher',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF080C16),
      ),
      home: const DashboardScreen(),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedSidebarIndex = 0;
  double _currentSpeed = 0.0;
  StreamSubscription<Position>? _positionStream;

  // موزیک پلیر
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  String _currentSongTitle = "بدون آهنگ انتخابی";

  // ساعت نوار بالا
  late Timer _clockTimer;
  String _currentTime = "";

  @override
  void initState() {
    super.initState();
    _updateClock();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (timer) => _updateClock());
    _initGps();
    _initAudio();
  }

  void _updateClock() {
    final now = DateTime.now();
    if (mounted) {
      setState(() {
        _currentTime = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
      });
    }
  }

  Future<void> _initGps() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 1,
      );

      _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings).listen(
        (Position position) {
          if (mounted) {
            setState(() {
              _currentSpeed = position.speed >= 0 ? (position.speed * 3.6) : 0.0;
            });
          }
        },
      );
    } catch (e) {
      debugPrint("خطای GPS: $e");
    }
  }

  void _initAudio() {
    _audioPlayer.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing;
        });
      }
    });
  }

  Future<void> _pickAndPlayMusic() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
      );

      if (result != null && result.files.single.path != null) {
        String filePath = result.files.single.path!;
        String fileName = result.files.single.name;

        await _audioPlayer.setFilePath(filePath);
        _audioPlayer.play();

        setState(() {
          _currentSongTitle = fileName;
        });
      }
    } catch (e) {
      debugPrint("خطای پخش فایل: $e");
    }
  }

  // دستور باز کردن مسیریاب بدون کد نیتیو اندروید
  Future<void> _openMaps() async {
    final intent = AndroidIntent(
      action: 'android.intent.action.VIEW',
      data: 'geo:0,0?q=navigation',
      flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
    );
    try {
      await intent.launch();
    } catch (e) {
      debugPrint("خطا در باز کردن نقشه: $e");
    }
  }

  // دستور باز کردن بخش تنظیمات سیستم
  Future<void> _openAndroidSettings(String action) async {
    final intent = AndroidIntent(
      action: action,
      flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
    );
    try {
      await intent.launch();
    } catch (e) {
      debugPrint("خطا در باز کردن تنظیمات: $e");
    }
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    _positionStream?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // ۱. سایدبار عمودی سمت چپ
          _buildVerticalSidebar(),

          // ۲. داشبورد کامل
          Expanded(
            child: Column(
              children: [
                _buildTopStatusBar(),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Row(
                      children: [
                        // کارت چپ: ناوبری
                        Expanded(flex: 3, child: _buildNavigationCard()),
                        const SizedBox(width: 14),

                        // کارت مرکز: گیج دیجیتال سرعت‌سنج HUD
                        Expanded(flex: 4, child: _buildCenterSpeedHud()),
                        const SizedBox(width: 14),

                        // کارت‌های راست: مدیاپلیر (بالا) و عکس خودرو تیبا ۲ (پایین)
                        Expanded(
                          flex: 3,
                          child: Column(
                            children: [
                              Expanded(flex: 1, child: _buildMusicCard()),
                              const SizedBox(height: 14),
                              Expanded(flex: 1, child: _buildCarImageCard()),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // نوار بالای صفحه با ساعت و میانبرهای وای‌فای، بلوتوث و باتری
  Widget _buildTopStatusBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            _currentTime,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white70,
              letterSpacing: 1.5,
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.wifi, color: Colors.cyanAccent, size: 22),
                tooltip: "تنظیمات Wi-Fi",
                onPressed: () => _openAndroidSettings('android.settings.WIFI_SETTINGS'),
              ),
              IconButton(
                icon: const Icon(Icons.bluetooth, color: Colors.cyanAccent, size: 22),
                tooltip: "تنظیمات Bluetooth",
                onPressed: () => _openAndroidSettings('android.settings.BLUETOOTH_SETTINGS'),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.battery_charging_full, color: Colors.greenAccent, size: 22),
              const SizedBox(width: 4),
              const Text("100%", style: TextStyle(color: Colors.white70, fontSize: 13)),
            ],
          ),
        ],
      ),
    );
  }

  // سایدبار عمودی
  Widget _buildVerticalSidebar() {
    return Container(
      width: 64,
      color: const Color(0xFF0F172A),
      child: Column(
        children: [
          const SizedBox(height: 16),
          const Icon(Icons.speed, color: Colors.cyanAccent, size: 28),
          const SizedBox(height: 20),

          _buildSidebarBtn(icon: Icons.dashboard_rounded, index: 0, label: "داشبورد"),
          _buildSidebarBtn(
            icon: Icons.explore_rounded,
            index: 1,
            label: "مسیریاب",
            onTap: _openMaps,
          ),
          _buildSidebarBtn(icon: Icons.music_note_rounded, index: 2, label: "موزیک"),

          const Spacer(),

          // دکمه تنظیمات مانیتور
          _buildSidebarBtn(
            icon: Icons.settings_rounded,
            index: 3,
            label: "تنظیمات",
            onTap: () => _openAndroidSettings('android.settings.SETTINGS'),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSidebarBtn({
    required IconData icon,
    required int index,
    required String label,
    VoidCallback? onTap,
  }) {
    bool isSelected = _selectedSidebarIndex == index;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        border: isSelected
            ? const Border(left: BorderSide(color: Colors.cyanAccent, width: 3.5))
            : null,
      ),
      child: IconButton(
        icon: Icon(icon, color: isSelected ? Colors.cyanAccent : Colors.white54, size: 26),
        tooltip: label,
        onPressed: () {
          setState(() {
            _selectedSidebarIndex = index;
          });
          if (onTap != null) onTap();
        },
      ),
    );
  }

  // کارت ناوبری
  Widget _buildNavigationCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.cyanAccent.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: const [
              Icon(Icons.near_me, color: Colors.cyanAccent),
              SizedBox(width: 8),
              Text(
                "مسیریاب خودرو",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ],
          ),
          const Spacer(),
          Center(
            child: Icon(
              Icons.map_rounded,
              size: 80,
              color: Colors.cyanAccent.withOpacity(0.4),
            ),
          ),
          const Center(
            child: Text(
              "نشان / بلد / Google Maps",
              style: TextStyle(color: Colors.white60, fontSize: 13),
            ),
          ),
          const Spacer(),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.cyanAccent.withOpacity(0.15),
              foregroundColor: Colors.cyanAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Colors.cyanAccent),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: const Icon(Icons.navigation_outlined),
            label: const Text("اجرای مسیریاب", style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: _openMaps,
          ),
        ],
      ),
    );
  }

  // مرکز: سرعت‌سنج HUD کامل
  Widget _buildCenterSpeedHud() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF101726),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blueAccent.withOpacity(0.25)),
      ),
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 220,
              height: 220,
              child: CircularProgressIndicator(
                value: (_currentSpeed / 200).clamp(0.0, 1.0),
                strokeWidth: 10,
                backgroundColor: Colors.white10,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.cyanAccent),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _currentSpeed.toInt().toString(),
                  style: const TextStyle(
                    fontSize: 70,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 2,
                  ),
                ),
                const Text(
                  "KM / H",
                  style: TextStyle(
                    color: Colors.cyanAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  "TIBA 2 HUD",
                  style: TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // مدیاپلیر (بالا سمت راست)
  Widget _buildMusicCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Row(
            children: [
              const Icon(Icons.music_note, color: Colors.cyanAccent, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _currentSongTitle,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.folder_open, color: Colors.cyanAccent, size: 20),
                onPressed: _pickAndPlayMusic,
                tooltip: "انتخاب آهنگ",
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.skip_previous, color: Colors.white70),
                onPressed: () => _audioPlayer.seek(Duration.zero),
              ),
              CircleAvatar(
                backgroundColor: Colors.cyanAccent,
                radius: 18,
                child: IconButton(
                  iconSize: 20,
                  icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.black),
                  onPressed: () {
                    if (_isPlaying) {
                      _audioPlayer.pause();
                    } else {
                      _audioPlayer.play();
                    }
                  },
                ),
              ),
              IconButton(
                icon: const Icon(Icons.stop, color: Colors.white70),
                onPressed: () => _audioPlayer.stop(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // عکس خودرو تیبا ۲ (پایین سمت راست، فیت کادر جای مشخصات)
  Widget _buildCarImageCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.cyanAccent.withOpacity(0.2)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.asset(
          'tiba2.png',
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.directions_car, size: 55, color: Colors.cyanAccent),
                  SizedBox(height: 6),
                  Text("TIBA 2", style: TextStyle(color: Colors.white38, fontSize: 12)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
