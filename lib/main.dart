import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:just_audio/just_audio.dart';
import 'package:file_picker/file_picker.dart';

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
      title: 'Tiba 2 HUD Launcher',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF070B14),
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

  // پلتفرم چنل برای فراخوانی ناوبری بومی اندروید
  static const platform = MethodChannel('com.tiba.launcher/channel');

  @override
  void initState() {
    super.initState();
    _initGps();
    _initAudio();
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
          setState(() {
            // تبدیل متر بر ثانیه به کیلومتر بر ساعت
            _currentSpeed = position.speed >= 0 ? (position.speed * 3.6) : 0.0;
          });
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
      debugPrint("خطای پخش فایل صوتی: $e");
    }
  }

  Future<void> _openNavigationApp() async {
    try {
      await platform.invokeMethod('openMap');
    } catch (e) {
      debugPrint("خطای باز کردن مسیریاب: $e");
    }
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // سایدبار عمودی سمت چپ
          _buildVerticalSidebar(),

          // محتوای اصلی داشبورد
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  // کارت سمت چپ: ناوبری و نقشه
                  Expanded(
                    flex: 3,
                    child: _buildNavigationCard(),
                  ),
                  const SizedBox(width: 16),

                  // بخش مرکزی: سرعت‌سنج HUD و عکس ماشین تیبا ۲
                  Expanded(
                    flex: 4,
                    child: _buildCenterVehicleHud(),
                  ),
                  const SizedBox(width: 16),

                  // کارت سمت راست: مدیا پلیر و وضعیت خودرو
                  Expanded(
                    flex: 3,
                    child: Column(
                      children: [
                        Expanded(child: _buildMusicCard()),
                        const SizedBox(height: 16),
                        Expanded(child: _buildVehicleStatusCard()),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ۱. نوار عمودی سمت چپ با کارکرد مشخص برای هر دکمه
  Widget _buildVerticalSidebar() {
    return Container(
      width: 65,
      color: const Color(0xFF0F172A),
      child: Column(
        children: [
          const SizedBox(height: 16),
          const Icon(Icons.flash_on, color: Colors.cyanAccent, size: 28),
          const SizedBox(height: 24),

          // دکمه خانه / داشبورد اصلی
          _buildSidebarItem(icon: Icons.dashboard_rounded, index: 0, label: "خانه"),

          // دکمه مسیریاب (با لمس مستقیم مپ را باز می‌کند)
          _buildSidebarItem(
            icon: Icons.navigation_rounded,
            index: 1,
            label: "مسیریاب",
            onCustomTap: () => _openNavigationApp(),
          ),

          // دکمه موزیک
          _buildSidebarItem(icon: Icons.music_note_rounded, index: 2, label: "موزیک"),

          // دکمه برنامه‌های خودرو
          _buildSidebarItem(icon: Icons.apps_rounded, index: 3, label: "برنامه‌ها"),

          const Spacer(),

          // دکمه تنظیمات در پایین سایدبار
          _buildSidebarItem(icon: Icons.settings_rounded, index: 4, label: "تنظیمات"),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSidebarItem({
    required IconData icon,
    required int index,
    required String label,
    VoidCallback? onCustomTap,
  }) {
    bool isSelected = _selectedSidebarIndex == index;
    return Tooltip(
      message: label,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          border: isSelected
              ? const Border(left: BorderSide(color: Colors.cyanAccent, width: 3))
              : null,
        ),
        child: IconButton(
          icon: Icon(
            icon,
            color: isSelected ? Colors.cyanAccent : Colors.white54,
            size: 26,
          ),
          onPressed: () {
            setState(() {
              _selectedSidebarIndex = index;
            });
            if (onCustomTap != null) {
              onCustomTap();
            }
          },
        ),
      ),
    );
  }

  // ۲. کارت نقشه و مسیریابی
  Widget _buildNavigationCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF131B2E),
        borderRadius: BorderRadius.circular(16),
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
                "مسیریابی",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const Spacer(),
          Center(
            child: Icon(
              Icons.map_outlined,
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
            icon: const Icon(Icons.explore),
            label: const Text("اجرای مسیریاب مانیتور", style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: _openNavigationApp,
          ),
        ],
      ),
    );
  }

  // ۳. سرعت‌سنج HUD و تصویر خودروی تیبا ۲
  Widget _buildCenterVehicleHud() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF101726),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blueAccent.withOpacity(0.25)),
      ),
      child: Column(
        children: [
          // گیج سرعت دیجیتال نئونی
          Expanded(
            flex: 3,
            child: Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 170,
                    height: 170,
                    child: CircularProgressIndicator(
                      value: (_currentSpeed / 200).clamp(0.0, 1.0),
                      strokeWidth: 8,
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
                          fontSize: 52,
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
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // نمایش عکس خودرو (تیبا ۲) مستقیماً از روت
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Image.asset(
                'tiba2.png',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.directions_car, size: 70, color: Colors.cyanAccent),
                      SizedBox(height: 8),
                      Text("TIBA 2 HUD", style: TextStyle(color: Colors.white38)),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ۴. کارت پخش موسیقی
  Widget _buildMusicCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF131B2E),
        borderRadius: BorderRadius.circular(16),
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
                tooltip: "انتخاب آهنگ از فلش / حافظه",
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
                radius: 20,
                child: IconButton(
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

  // ۵. کارت وضعیت باد چرخ‌ها و سیستم خودرو
  Widget _buildVehicleStatusCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF131B2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          const Text(
            "وضعیت چرخ‌ها (TPMS)",
            style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildTyreInfo("جلو چپ", "32 PSI"),
              _buildTyreInfo("جلو راست", "32 PSI"),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildTyreInfo("عقب چپ", "30 PSI"),
              _buildTyreInfo("عقب راست", "30 PSI"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTyreInfo(String title, String psi) {
    return Column(
      children: [
        Text(title, style: const TextStyle(color: Colors.white38, fontSize: 10)),
        Text(psi, style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 12)),
      ],
    );
  }
}
