import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const TibaLauncherApp());
}

class TibaLauncherApp extends StatelessWidget {
  const TibaLauncherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tiba 2 Launcher',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF030712),
      ),
      home: const LauncherHome(),
    );
  }
}

class LauncherHome extends StatefulWidget {
  const LauncherHome({super.key});

  @override
  State<LauncherHome> createState() => _LauncherHomeState();
}

class _LauncherHomeState extends State<LauncherHome>
    with SingleTickerProviderStateMixin {
  static const platform = MethodChannel('com.tiba2.launcher/actions');

  double _rawSpeed = 0.0;
  double _gpsMultiplier = 1.0;
  double _neonIntensity = 1.0;
  Color _neonColor = const Color(0xFF00E5FF);

  String _timeString = '';
  String _dateString = '';
  Timer? _clockTimer;

  // Music Player
  final AudioPlayer _player = AudioPlayer();
  List<PlatformFile> _tracks = [];
  int _currentTrackIndex = -1;
  bool _isPlaying = false;
  String _currentTrackTitle = 'آهنگی انتخاب نشده';

  // Navigation App
  String _selectedNav = 'ir.neshan.sp';

  late AnimationController _roadAnimCtrl;

  @override
  void initState() {
    super.initState();
    _roadAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _setupPlatformChannel();
    _loadPreferences();
    _initClock();
    _initAudioPlayer();
    _requestAllPermissions();
  }

  void _setupPlatformChannel() {
    platform.setMethodCallHandler((call) async {
      if (call.method == 'onSpeed') {
        final speed = (call.arguments as num).toDouble();
        if (mounted) {
          setState(() {
            _rawSpeed = speed < 1.0 ? 0.0 : speed;
          });
        }
      }
    });
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _gpsMultiplier = prefs.getDouble('gps_multiplier') ?? 1.0;
      _neonIntensity = prefs.getDouble('neon_intensity') ?? 1.0;
      _selectedNav = prefs.getString('selected_nav') ?? 'ir.neshan.sp';
      int? colorVal = prefs.getInt('neon_color');
      if (colorVal != null) {
        _neonColor = Color(colorVal);
      }
    });
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('gps_multiplier', _gpsMultiplier);
    await prefs.setDouble('neon_intensity', _neonIntensity);
    await prefs.setString('selected_nav', _selectedNav);
    await prefs.setInt('neon_color', _neonColor.value);
  }

  void _initClock() {
    _updateClock();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) => _updateClock());
  }

  void _updateClock() {
    final now = DateTime.now();
    if (mounted) {
      setState(() {
        _timeString =
            "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
        _dateString = "${now.year}/${now.month}/${now.day}";
      });
    }
  }

  void _initAudioPlayer() {
    _player.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });
    _player.onPlayerComplete.listen((_) {
      _nextTrack();
    });
  }

  Future<void> _requestAllPermissions() async {
    await [
      Permission.location,
      Permission.storage,
      Permission.audio,
    ].request();

    try {
      await platform.invokeMethod('open', {'action': 'request_location'});
    } catch (_) {}
  }

  Future<void> _pickMusicFiles() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['mp3', 'wav', 'aac', 'm4a', 'flac', 'ogg'],
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _tracks = result.files.where((f) => f.path != null).toList();
        if (_tracks.isNotEmpty) {
          _currentTrackIndex = 0;
          _playTrack(0);
        }
      });
    }
  }

  Future<void> _playTrack(int index) async {
    if (index >= 0 && index < _tracks.length) {
      final file = _tracks[index];
      await _player.play(DeviceFileSource(file.path!));
      setState(() {
        _currentTrackIndex = index;
        _currentTrackTitle = file.name;
        _isPlaying = true;
      });
    }
  }

  Future<void> _togglePlayPause() async {
    if (_tracks.isEmpty) {
      try {
        await platform.invokeMethod('open', {'action': 'media_play_pause'});
      } catch (_) {}
      return;
    }
    if (_isPlaying) {
      await _player.pause();
    } else {
      if (_currentTrackIndex == -1 && _tracks.isNotEmpty) {
        _playTrack(0);
      } else {
        await _player.resume();
      }
    }
  }

  Future<void> _nextTrack() async {
    if (_tracks.isNotEmpty) {
      int next = (_currentTrackIndex + 1) % _tracks.length;
      _playTrack(next);
    } else {
      try {
        await platform.invokeMethod('open', {'action': 'media_next'});
      } catch (_) {}
    }
  }

  Future<void> _prevTrack() async {
    if (_tracks.isNotEmpty) {
      int prev = (_currentTrackIndex - 1 + _tracks.length) % _tracks.length;
      _playTrack(prev);
    } else {
      try {
        await platform.invokeMethod('open', {'action': 'media_prev'});
      } catch (_) {}
    }
  }

  Future<void> _launchIntent(String action, {String pkg = ''}) async {
    try {
      await platform.invokeMethod('open', {'action': action, 'pkg': pkg});
    } catch (_) {}
  }

  void _openSettingsDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF0F172A),
              shape: RoundedRectangleBorder(
                side: BorderSide(color: _neonColor, width: 1.5),
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                'تنظیمات لانچر تیبا ۲',
                textAlign: TextAlign.center,
                style: TextStyle(color: _neonColor, fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: Icon(Icons.settings_suggest, color: _neonColor),
                      title: const Text('تنظیمات اصلی تبلت / اندروید', style: TextStyle(color: Colors.white)),
                      onTap: () {
                        Navigator.pop(ctx);
                        _launchIntent('settings');
                      },
                    ),
                    ListTile(
                      leading: Icon(Icons.gps_fixed, color: _neonColor),
                      title: const Text('تنظیمات موقعیت مکانی (GPS)', style: TextStyle(color: Colors.white)),
                      onTap: () {
                        Navigator.pop(ctx);
                        _launchIntent('location_settings');
                      },
                    ),
                    const Divider(color: Colors.white24),
                    Text(
                      'کالیبراسیون و ضریب سرعت: ${_gpsMultiplier.toStringAsFixed(2)}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    Slider(
                      value: _gpsMultiplier,
                      min: 0.7,
                      max: 1.3,
                      divisions: 12,
                      activeColor: _neonColor,
                      onChanged: (val) {
                        setDlgState(() => _gpsMultiplier = val);
                        setState(() => _gpsMultiplier = val);
                        _savePreferences();
                      },
                    ),
                    const Divider(color: Colors.white24),
                    Text(
                      'شدت نور نئون: ${(_neonIntensity * 100).toInt()}%',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    Slider(
                      value: _neonIntensity,
                      min: 0.3,
                      max: 1.5,
                      activeColor: _neonColor,
                      onChanged: (val) {
                        setDlgState(() => _neonIntensity = val);
                        setState(() => _neonIntensity = val);
                        _savePreferences();
                      },
                    ),
                    const Divider(color: Colors.white24),
                    const Text('مسیریاب پیش‌فرض', style: TextStyle(color: Colors.white70)),
                    DropdownButton<String>(
                      value: _selectedNav,
                      dropdownColor: const Color(0xFF1E293B),
                      style: const TextStyle(color: Colors.white),
                      items: const [
                        DropdownMenuItem(value: 'ir.neshan.sp', child: Text('نشان')),
                        DropdownMenuItem(value: 'ir.balad.navigation', child: Text('بلد')),
                        DropdownMenuItem(value: 'com.google.android.apps.maps', child: Text('گوگل مپ')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDlgState(() => _selectedNav = val);
                          setState(() => _selectedNav = val);
                          _savePreferences();
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('بستن', style: TextStyle(color: _neonColor)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _roadAnimCtrl.dispose();
    _clockTimer?.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final speed = (_rawSpeed * _gpsMultiplier).round();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.0, -0.2),
            radius: 1.2,
            colors: [Color(0xFF0D1B2A), Color(0xFF030712)],
          ),
        ),
        child: SafeArea(
          child: Row(
            children: [
              // 1. سایدبار ناوبری و دکمه‌ها (سمت چپ)
              _buildSidebar(),

              // 2. ستون سمت چپ: کارت مسیریاب
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
                  child: _buildNavCard(),
                ),
              ),

              // 3. ستون وسط: هدر تیبا ۲ + سرعت‌سنج + جاده متحرک + آرم سایپا + نمای پشت تیبا + پلیر
              Expanded(
                flex: 6,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
                  child: _buildCenterDashboard(speed),
                ),
              ),

              // 4. ستون سمت راست: تصویر اصلی ماشین و دکمه‌های کنترلی
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
                  child: _buildRightCarPanel(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 72,
      margin: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0F1D).withOpacity(0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _neonColor.withOpacity(0.35 * _neonIntensity)),
        boxShadow: [
          BoxShadow(
            color: _neonColor.withOpacity(0.15 * _neonIntensity),
            blurRadius: 10,
          )
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: Icon(Icons.settings, color: _neonColor, size: 28),
            onPressed: _openSettingsDialog,
          ),
          IconButton(
            icon: const Icon(Icons.navigation_outlined, color: Colors.white70, size: 28),
            onPressed: () => _launchIntent('nav', pkg: _selectedNav),
          ),
          IconButton(
            icon: const Icon(Icons.radio, color: Colors.white70, size: 28),
            onPressed: () => _launchIntent('radio'),
          ),
          IconButton(
            icon: const Icon(Icons.phone, color: Colors.white70, size: 28),
            onPressed: () => _launchIntent('phone'),
          ),
          IconButton(
            icon: const Icon(Icons.apps, color: Colors.white70, size: 28),
            onPressed: () => _launchIntent('apps'),
          ),
        ],
      ),
    );
  }

  Widget _buildNavCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0A0F1D).withOpacity(0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _neonColor.withOpacity(0.3 * _neonIntensity)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _timeString,
                style: TextStyle(
                  color: _neonColor,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(color: _neonColor, blurRadius: 10 * _neonIntensity)
                  ],
                ),
              ),
              Text(
                _dateString,
                style: const TextStyle(color: Colors.white54, fontSize: 14),
              ),
            ],
          ),
          const Spacer(),
          Center(
            child: Icon(
              Icons.explore_outlined,
              size: 70,
              color: _neonColor.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 12),
          const Center(
            child: Text(
              'سیستم مسیریابی هوشمند',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          const Spacer(),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _neonColor.withOpacity(0.2),
              side: BorderSide(color: _neonColor),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: () => _launchIntent('nav', pkg: _selectedNav),
            icon: const Icon(Icons.near_me, color: Colors.white),
            label: const Text('شروع مسیریابی', style: TextStyle(color: Colors.white, fontSize: 15)),
          ),
        ],
      ),
    );
  }

  Widget _buildCenterDashboard(int speed) {
    return Column(
      children: [
        // عنوان تیبا ۲
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'TIBA 2',
              style: TextStyle(
                color: _neonColor,
                fontSize: 22,
                letterSpacing: 4,
                fontWeight: FontWeight.w900,
                shadows: [
                  Shadow(color: _neonColor, blurRadius: 15 * _neonIntensity),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'تیبا ۲',
              style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 4),

        // کیلومترشمار نئونی، سرعت زنده، آرم سایپا و نمای پشت تیبا
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              // جاده سه‌بعدی نئونی
              AnimatedBuilder(
                animation: _roadAnimCtrl,
                builder: (context, child) {
                  return CustomPaint(
                    size: const Size(double.infinity, double.infinity),
                    painter: RoadPainter(
                      progress: _roadAnimCtrl.value,
                      color: _neonColor.withOpacity(0.4 * _neonIntensity),
                    ),
                  );
                },
              ),

              // سرعت‌سنج مرکزی
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$speed',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 68,
                      fontWeight: FontWeight.w900,
                      shadows: [
                        Shadow(color: _neonColor, blurRadius: 20 * _neonIntensity),
                      ],
                    ),
                  ),
                  Text(
                    'KM / H',
                    style: TextStyle(
                      color: _neonColor,
                      fontSize: 14,
                      letterSpacing: 2,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // آرم سایپا
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                    decoration: BoxDecoration(
                      border: Border.all(color: _neonColor.withOpacity(0.5)),
                      borderRadius: BorderRadius.circular(10),
                      color: Colors.black.withOpacity(0.4),
                    ),
                    child: Text(
                      'SAIPA • سایپا',
                      style: TextStyle(
                        color: _neonColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),

                  // نمای پشت ماشین تیبا ۲
                  Image.asset(
                    'tiba2_rear.png',
                    height: 52,
                    errorBuilder: (_, __, ___) => const SizedBox(height: 52),
                  ),
                ],
              ),
            ],
          ),
        ),

        // پلیر صوتی پایین ستون وسط
        _buildBottomPlayerBar(),
      ],
    );
  }

  Widget _buildBottomPlayerBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0F1D).withOpacity(0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _neonColor.withOpacity(0.3 * _neonIntensity)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _currentTrackTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                ),
                Text(
                  _tracks.isEmpty ? 'پلیر چندرسانه‌ای' : 'تعداد ترک‌ها: ${_tracks.length}',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.skip_previous, color: Colors.white),
            onPressed: _prevTrack,
          ),
          IconButton(
            icon: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                color: _neonColor, size: 36),
            onPressed: _togglePlayPause,
          ),
          IconButton(
            icon: const Icon(Icons.skip_next, color: Colors.white),
            onPressed: _nextTrack,
          ),
        ],
      ),
    );
  }

  Widget _buildRightCarPanel() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0A0F1D).withOpacity(0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _neonColor.withOpacity(0.3 * _neonIntensity)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _neonColor.withOpacity(0.15),
              side: BorderSide(color: _neonColor),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              minimumSize: const Size(double.infinity, 44),
            ),
            onPressed: _pickMusicFiles,
            icon: const Icon(Icons.folder_open, color: Colors.white),
            label: const Text('پوشه موزیک / فلش', style: TextStyle(color: Colors.white, fontSize: 13)),
          ),
          const Spacer(),
          // تصویر اصلی تیبا ۲
          Image.asset(
            'tiba2.png',
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Center(
              child: Icon(Icons.directions_car, size: 90, color: _neonColor.withOpacity(0.5)),
            ),
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: const Icon(Icons.music_note, color: Colors.white70),
                onPressed: () => _launchIntent('music'),
              ),
              IconButton(
                icon: const Icon(Icons.tune, color: Colors.white70),
                onPressed: _openSettingsDialog,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class RoadPainter extends CustomPainter {
  final double progress;
  final Color color;

  RoadPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final pTop = Offset(size.width * 0.5, size.height * 0.2);
    final pBottomLeft = Offset(size.width * 0.1, size.height);
    final pBottomRight = Offset(size.width * 0.9, size.height);

    // خطوط کناری جاده
    canvas.drawLine(pTop, pBottomLeft, paint);
    canvas.drawLine(pTop, pBottomRight, paint);

    // خطوط افقی متحرک
    for (int i = 0; i < 5; i++) {
      double t = (progress + (i / 5.0)) % 1.0;
      double y = pTop.dy + (size.height - pTop.dy) * (t * t);
      double x1 = pTop.dx - (pTop.dx - pBottomLeft.dx) * t;
      double x2 = pTop.dx + (pBottomRight.dx - pTop.dx) * t;
      canvas.drawLine(Offset(x1, y), Offset(x2, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant RoadPainter oldDelegate) => true;
}
