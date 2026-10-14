import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:just_audio/just_audio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
        scaffoldBackgroundColor: const Color(0xFF050811),
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

  // موزیک پلیر پیشرفته با پشتیبانی از پلی‌لیست و ذخیره پوزیشن
  final AudioPlayer _audioPlayer = AudioPlayer();
  ConcatenatingAudioSource? _playlist;
  bool _isPlaying = false;
  String _currentSongTitle = "بدون آهنگ انتخابی";
  int _currentSongIndex = 0;

  // ساعت نوار بالا
  late Timer _clockTimer;
  String _currentTime = "";

  // تنظیمات رنگ و نور سفارشی
  Color _accentColor = Colors.cyanAccent;
  Color _secondaryAccent = Colors.orangeAccent;
  double _screenBrightness = 1.0;

  @override
  void initState() {
    super.initState();
    _updateClock();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (timer) => _updateClock());
    _initGps();
    _initAudioPlayer();
    _loadSettings();
  }

  // بارگذاری تنظیمات ذخیره شده
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      int colorVal = prefs.getInt('accentColor') ?? Colors.cyanAccent.value;
      _accentColor = Color(colorVal);
      _screenBrightness = prefs.getDouble('brightness') ?? 1.0;
    });
  }

  Future<void> _saveColorSetting(Color color) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('accentColor', color.value);
  }

  Future<void> _saveBrightnessSetting(double val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('brightness', val);
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

  void _initAudioPlayer() {
    _audioPlayer.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing;
        });
      }
    });

    _audioPlayer.currentIndexStream.listen((index) {
      if (index != null && _playlist != null && mounted) {
        setState(() {
          _currentSongIndex = index;
          // نام آهنگ فعلی را بر اساس فایل‌ها تنظیم می‌کنیم
        });
      }
    });
  }

  // انتخاب چند آهنگ برای تشکیل پلی‌لیست و پخش پشت سر هم
  Future<void> _pickAndPlayMultipleMusic() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        List<AudioSource> sources = [];
        for (var file in result.files) {
          if (file.path != null) {
            sources.add(AudioSource.file(file.path!));
          }
        }

        _playlist = ConcatenatingAudioSource(children: sources);
        await _audioPlayer.setAudioSource(_playlist!);
        await _audioPlayer.play();

        setState(() {
          _currentSongTitle = result.files.first.name;
        });
      }
    } catch (e) {
      debugPrint("خطای پخش فایل‌ها: $e");
    }
  }

  Future<void> _openMaps() async {
    final intent = AndroidIntent(
      action: 'android.intent.action.VIEW',
      data: 'geo:0,0?q=navigation',
      flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
    );
    try {
      await intent.launch();
    } catch (e) {
      debugPrint("خطا در نقشه: $e");
    }
  }

  Future<void> _openAndroidSettings(String action) async {
    final intent = AndroidIntent(
      action: action,
      flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
    );
    try {
      await intent.launch();
    } catch (e) {
      debugPrint("خطا در تنظیمات: $e");
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
    return Opacity(
      opacity: _screenBrightness.clamp(0.2, 1.0),
      child: Scaffold(
        body: Row(
          children: [
            // ۱. سایدبار عمودی سمت چپ (دقیقاً مشابه عکس)
            _buildVerticalSidebar(),

            // ۲. صفحه اصلی داشبورد
            Expanded(
              child: Column(
                children: [
                  _buildTopStatusBar(),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                      child: Row(
                        children: [
                          // الف) کارت سمت چپ: ناوبری و مینی‌مپ
                          Expanded(flex: 3, child: _buildNavigationCard()),
                          const SizedBox(width: 14),

                          // ب) کارت مرکز: سرعت‌سنج HUD مدرن و دایره‌ای
                          Expanded(flex: 4, child: _buildCenterSpeedHud()),
                          const SizedBox(width: 14),

                          // ج) کارت‌های سمت راست: مدیاپلیر (بالا) و عکس خودرو تیبا ۲ (پایین)
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
      ),
    );
  }

  // نوار وضعیت بالای صفحه
  Widget _buildTopStatusBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(
                _currentTime,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white70),
              ),
              const SizedBox(width: 16),
              const Icon(Icons.signal_cellular_alt, color: Colors.white54, size: 16),
              const SizedBox(width: 4),
              const Text("LTE", style: TextStyle(color: Colors.white54, fontSize: 12)),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.wifi, color: _accentColor, size: 20),
                onPressed: () => _openAndroidSettings('android.settings.WIFI_SETTINGS'),
              ),
              IconButton(
                icon: Icon(Icons.bluetooth, color: _accentColor, size: 20),
                onPressed: () => _openAndroidSettings('android.settings.BLUETOOTH_SETTINGS'),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.battery_charging_full, color: Colors.greenAccent, size: 20),
              const SizedBox(width: 4),
              const Text("100%", style: TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  // سایدبار عمودی سمت چپ
  Widget _buildVerticalSidebar() {
    return Container(
      width: 65,
      color: const Color(0xFF0A0F1D),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Icon(Icons.flash_on, color: _accentColor, size: 28),
          const SizedBox(height: 24),

          _buildSidebarBtn(icon: Icons.dashboard_rounded, index: 0, label: "خانه", onTap: () => setState(() => _selectedSidebarIndex = 0)),
          _buildSidebarBtn(icon: Icons.explore_rounded, index: 1, label: "مسیریاب", onTap: _openMaps),
          _buildSidebarBtn(icon: Icons.music_note_rounded, index: 2, label: "موزیک", onTap: () => setState(() => _selectedSidebarIndex = 2)),
          _buildSidebarBtn(icon: Icons.apps_rounded, index: 3, label: "برنامه‌ها", onTap: () => _openAndroidSettings('android.settings.SETTINGS')),

          const Spacer(),

          // دکمه تنظیمات رنگ و روشنایی اختصاصی لانچر
          IconButton(
            icon: const Icon(Icons.settings_suggest_rounded, color: Colors.white54, size: 26),
            tooltip: "تنظیمات گرافیکی لانچر",
            onPressed: _showSettingsDialog,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSidebarBtn({required IconData icon, required int index, required String label, VoidCallback? onTap}) {
    bool isSelected = _selectedSidebarIndex == index;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: isSelected ? Border(left: BorderSide(color: _accentColor, width: 3.5)) : null,
      ),
      child: IconButton(
        icon: Icon(icon, color: isSelected ? _accentColor : Colors.white54, size: 26),
        onPressed: onTap,
      ),
    );
  }

  // دیالوگ تنظیمات رنگ‌بندی و روشنایی
  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF101728),
          title: const Text("تنظیمات ظاهری لانچر تیبا ۲", style: TextStyle(color: Colors.white)),
          content: StatefulBuilder(
            builder: (context, setStateModal) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("رنگ تم نئونی:", style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _colorOption(Colors.cyanAccent, setStateModal),
                      _colorOption(Colors.orangeAccent, setStateModal),
                      _colorOption(Colors.greenAccent, setStateModal),
                      _colorOption(Colors.purpleAccent, setStateModal),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text("میزان روشنایی صفحه:", style: TextStyle(color: Colors.white70)),
                  Slider(
                    value: _screenBrightness,
                    min: 0.3,
                    max: 1.0,
                    activeColor: _accentColor,
                    onChanged: (val) {
                      setStateModal(() => _screenBrightness = val);
                      setState(() => _screenBrightness = val);
                      _saveBrightnessSetting(val);
                    },
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              child: Text("تایید", style: TextStyle(color: _accentColor)),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        );
      },
    );
  }

  Widget _colorOption(Color color, StateSetter setStateModal) {
    return GestureDetector(
      onTap: () {
        setStateModal(() => _accentColor = color);
        setState(() => _accentColor = color);
        _saveColorSetting(color);
      },
      child: CircleAvatar(
        backgroundColor: color,
        radius: 18,
        child: _accentColor == color ? const Icon(Icons.check, color: Colors.black, size: 18) : null,
      ),
    );
  }

  // کارت ناوبری (شبیه عکس)
  Widget _buildNavigationCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _accentColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.navigation, color: _accentColor, size: 18),
              const SizedBox(width: 8),
              const Text("0.5 mi - Route 101", style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF070B14),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: Center(
                child: Icon(Icons.map_rounded, size: 70, color: _accentColor.withOpacity(0.5)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentColor.withOpacity(0.15),
              foregroundColor: _accentColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: _accentColor),
              ),
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
            onPressed: _openMaps,
            child: const Text("اجرای کامل مسیریاب", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  // سرعت‌سنج مرکز (دقیقاً مشابه عکس مرجع با دو حلقه رنگی نئونی)
  Widget _buildCenterSpeedHud() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _secondaryAccent.withOpacity(0.3)),
      ),
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // حلقه بیرونی نارنجی
            SizedBox(
              width: 210,
              height: 210,
              child: CircularProgressIndicator(
                value: (_currentSpeed / 200).clamp(0.0, 1.0),
                strokeWidth: 6,
                backgroundColor: Colors.white10,
                valueColor: AlwaysStoppedAnimation<Color>(_secondaryAccent),
              ),
            ),
            // حلقه داخلی آبی نئونی
            SizedBox(
              width: 175,
              height: 175,
              child: CircularProgressIndicator(
                value: (_currentSpeed / 200).clamp(0.0, 1.0),
                strokeWidth: 8,
                backgroundColor: Colors.white10,
                valueColor: AlwaysStoppedAnimation<Color>(_accentColor),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _currentSpeed.toInt().toString(),
                  style: const TextStyle(
                    fontSize: 64,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 2,
                  ),
                ),
                Text(
                  "KM / H",
                  style: TextStyle(
                    color: _accentColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  "TIBA 2 HUD",
                  style: TextStyle(color: Colors.white38, fontSize: 10),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // مدیا پلیر (بالا سمت راست با قابلیت پخش پشت سر هم و پوزیشن ذخیره‌شده)
  Widget _buildMusicCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Now Playing", style: TextStyle(color: Colors.white54, fontSize: 11)),
              IconButton(
                icon: Icon(Icons.folder_open, color: _accentColor, size: 20),
                tooltip: "انتخاب پوشه / آهنگ‌ها",
                onPressed: _pickAndPlayMultipleMusic,
              ),
            ],
          ),
          Text(
            _currentSongTitle,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.skip_previous, color: Colors.white70, size: 20),
                onPressed: () {
                  if (_audioPlayer.hasPrevious) _audioPlayer.seekToPrevious();
                },
              ),
              CircleAvatar(
                backgroundColor: _secondaryAccent,
                radius: 18,
                child: IconButton(
                  iconSize: 18,
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
                icon: const Icon(Icons.skip_next, color: Colors.white70, size: 20),
                onPressed: () {
                  if (_audioPlayer.hasNext) _audioPlayer.seekToNext();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // عکس خودرو تیبا ۲ (پایین سمت راست دقیقاً جای مشخصات خودرو در عکس مرجع)
  Widget _buildCarImageCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _accentColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Car Status", style: TextStyle(color: Colors.white54, fontSize: 11)),
          Expanded(
            child: Center(
              child: Image.asset(
                'tiba2.png',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(Icons.directions_car, size: 50, color: _accentColor);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
