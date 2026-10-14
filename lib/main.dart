import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audio_session/audio_session.dart';
import 'package:file_picker/file_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  try {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.tiba.launcher.channel.audio',
      androidNotificationChannelName: 'پخش موسیقی تیبا',
      androidNotificationOngoing: true,
    );
  } catch (_) {}

  try {
    await WakelockPlus.enable();
  } catch (_) {}

  runApp(const TibaModernLauncherApp());
}

class TibaModernLauncherApp extends StatelessWidget {
  const TibaModernLauncherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tiba Dashboard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF070B11),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E5FF),
          secondary: Color(0xFFFF6D00),
          surface: Color(0xFF101726),
        ),
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
  static const MethodChannel _appChannel = MethodChannel('com.tiba.launcher/app');

  // Music Player
  late AudioPlayer _player;
  List<String> _playlist = [];
  int _currentIndex = 0;
  String _currentTitle = "آهنگی انتخاب نشده";
  bool _isPlaying = false;

  // GPS & Speed
  double _speed = 0.0;
  StreamSubscription<Position>? _positionStream;

  // Time & Status
  late Timer _timer;
  String _currentTime = "";

  @override
  void initState() {
    super.initState();
    _initAudio();
    _initLocation();
    _updateClock();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) => _updateClock());
  }

  void _updateClock() {
    final now = DateTime.now();
    setState(() {
      _currentTime =
          "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
    });
  }

  Future<void> _initAudio() async {
    _player = AudioPlayer();
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    _player.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing;
        });
      }
    });

    _player.currentIndexStream.listen((index) {
      if (index != null && index < _playlist.length && mounted) {
        setState(() {
          _currentIndex = index;
          _currentTitle = _playlist[index].split('/').last;
        });
      }
    });
  }

  Future<void> _pickAudioFiles() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: true,
      );

      if (result != null && result.paths.isNotEmpty) {
        _playlist = result.paths.whereType<String>().toList();
        final audioSources = _playlist.map((path) {
          final title = path.split('/').last;
          return AudioSource.file(
            path,
            tag: MediaItem(
              id: path,
              album: "آهنگ‌های خودرو",
              title: title,
              artUri: Uri.parse("asset:///tiba2.png"),
            ),
          );
        }).toList();

        await _player.setAudioSource(
          ConcatenatingAudioSource(children: audioSources),
        );
        await _player.play();
        setState(() {
          _currentIndex = 0;
          _currentTitle = _playlist[0].split('/').last;
        });
      }
    } catch (_) {}
  }

  Future<void> _initLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse) {
        _positionStream = Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            distanceFilter: 1,
          ),
        ).listen((Position position) {
          if (mounted) {
            double speedKmh = (position.speed * 3.6);
            if (speedKmh < 0) speedKmh = 0;
            setState(() {
              _speed = speedKmh;
            });
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _launchApp(String packageName, String fallbackUrl) async {
    try {
      final bool success = await _appChannel.invokeMethod('launchApp', {'package': packageName});
      if (!success) {
        final uri = Uri.parse(fallbackUrl);
        if (await canLaunchUrl(uri)) await launchUrl(uri);
      }
    } catch (_) {
      final uri = Uri.parse(fallbackUrl);
      if (await canLaunchUrl(uri)) await launchUrl(uri);
    }
  }

  void _openAllApps() async {
    try {
      final List<dynamic>? apps = await _appChannel.invokeMethod('getInstalledApps');
      if (!mounted || apps == null) return;

      showModalBottomSheet(
        context: context,
        backgroundColor: const Color(0xEB0A0E17),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (ctx) {
          return Container(
            padding: const EdgeInsets.all(16),
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 6,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: apps.length,
              itemBuilder: (context, index) {
                final app = apps[index];
                return InkWell(
                  onTap: () {
                    Navigator.pop(ctx);
                    _launchApp(app['package'], '');
                  },
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF131D2E),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.3)),
                        ),
                        child: const Icon(Icons.apps, color: Color(0xFF00E5FF), size: 28),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        app['name'] ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: Colors.white70),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      );
    } catch (_) {}
  }

  @override
  void dispose() {
    _timer.cancel();
    _positionStream?.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.0, -0.2),
            radius: 1.2,
            colors: [
              Color(0xFF111E33),
              Color(0xFF06090F),
              Color(0xFF020408),
            ],
          ),
        ),
        child: SafeArea(
          child: Row(
            children: [
              // 1. سمت چپ: نوار عمودی باریک (مانند ستون آیکون‌های اپل کارپلی تصویر)
              _buildLeftVerticalBar(),

              // محتوای اصلی داشبورد: ۳ بخش (نقشه، سرعت‌سنج مرکزی، موزیک و وضعیت ماشین)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
                  child: Row(
                    children: [
                      // بخش ناوبری / نقشه (سمت چپ)
                      Expanded(flex: 30, child: _buildNavigationCard()),

                      const SizedBox(width: 12),

                      // سرعت‌سنج عقربه‌ای/دیجیتال مرکزی (مرکز)
                      Expanded(flex: 38, child: _buildCentralSpeedometer()),

                      const SizedBox(width: 12),

                      // پلیر موزیک و کارت وضعیت خودرو (سمت راست)
                      Expanded(
                        flex: 32,
                        child: Column(
                          children: [
                            Expanded(flex: 55, child: _buildMusicPlayerCard()),
                            const SizedBox(height: 10),
                            Expanded(flex: 45, child: _buildCarStatusCard()),
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
      ),
    );
  }

  // --- نوار میانبر عمودی سمت چپ ---
  Widget _buildLeftVerticalBar() {
    return Container(
      width: 60,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0B111C).withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Text(
            _currentTime,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 4),
          const Icon(Icons.wifi, size: 14, color: Color(0xFF00E5FF)),
          const Spacer(),
          _buildSidebarIconButton(Icons.map_outlined, const Color(0xFF00E5FF), () {
            _launchApp("ir.neshan.sp", "https://neshan.org");
          }),
          const SizedBox(height: 12),
          _buildSidebarIconButton(Icons.music_note_rounded, const Color(0xFFFF6D00), _pickAudioFiles),
          const SizedBox(height: 12),
          _buildSidebarIconButton(Icons.navigation_rounded, Colors.greenAccent, () {
            _launchApp("ir.balad.app", "https://balad.ir");
          }),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.grid_view_rounded, color: Colors.white70, size: 26),
            onPressed: _openAllApps,
            tooltip: "برنامه‌ها",
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildSidebarIconButton(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
    );
  }

  // --- پنل نقشه و ناوبری سمت چپ ---
  Widget _buildNavigationCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D1422).withOpacity(0.85),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.25)),
      ),
      child: Stack(
        children: [
          // پس‌زمینه راداری نقشه با خطوط شبیه‌ساز
          Positioned.fill(
            child: Opacity(
              opacity: 0.15,
              child: CustomPaint(painter: MapGridPainter()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00E5FF).withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.turn_right_rounded, color: Color(0xFF00E5FF), size: 22),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("مسیر یاب تیبا", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                          Text("موقعیت آنلاین فعال", style: TextStyle(fontSize: 10, color: Colors.white54)),
                        ],
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildNavBtn("نشان", () => _launchApp("ir.neshan.sp", "https://neshan.org")),
                    _buildNavBtn("بلد", () => _launchApp("ir.balad.app", "https://balad.ir")),
                    _buildNavBtn("گوگل", () => _launchApp("com.google.android.apps.maps", "geo:0,0?q=")),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavBtn(String title, VoidCallback onTap) {
    return ElevatedButton(
      onTap: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF142138),
        foregroundColor: const Color(0xFF00E5FF),
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.4)),
        ),
      ),
      child: Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  // --- سرعت‌سنج مدرن نئونی وسط داشبورد (مشابه عکس ارسالی) ---
  Widget _buildCentralSpeedometer() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0B111C).withOpacity(0.9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00E5FF).withOpacity(0.06),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Center(
        child: AspectRatio(
          aspectRatio: 1.0,
          child: CustomPaint(
            painter: ModernDialPainter(speed: _speed),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 10),
                  Text(
                    _speed.toStringAsFixed(0),
                    style: const TextStyle(
                      fontSize: 54,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -1,
                    ),
                  ),
                  const Text(
                    "KM/H",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00E5FF),
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6D00).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "RPM ${(_speed * 35).clamp(800, 6500).toStringAsFixed(0)}",
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFFF9E40),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- کارت موزیک پلیر سمت راست بالا (نارنجی نئونی شبیه تصویر) ---
  Widget _buildMusicPlayerCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1624).withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFF6D00).withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.equalizer_rounded, color: Color(0xFFFF6D00), size: 18),
              const SizedBox(width: 6),
              const Text(
                "Now Playing",
                style: TextStyle(fontSize: 11, color: Color(0xFFFF9E40), fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              InkWell(
                onTap: _pickAudioFiles,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6D00).withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.folder_open_rounded, size: 16, color: Color(0xFFFF9E40)),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            _currentTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 4),
          const Text("سیستم صوتی تیبا", style: TextStyle(fontSize: 10, color: Colors.white54)),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 24),
                onPressed: () {
                  if (_player.hasPrevious) _player.seekToPrevious();
                },
              ),
              GestureDetector(
                onTap: () {
                  if (_isPlaying) {
                    _player.pause();
                  } else {
                    _player.play();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF6D00),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 24),
                onPressed: () {
                  if (_player.hasNext) _player.seekToNext();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- کارت وضعیت خودرو Car Status سمت راست پایین ---
  Widget _buildCarStatusCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1624).withOpacity(0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "Car Status",
                  style: TextStyle(fontSize: 11, color: Color(0xFF00E5FF), fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text(
                  "TIBA 2 EX",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    const Text("سیستم آماده", style: TextStyle(fontSize: 10, color: Colors.white70)),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            flex: 5,
            child: Center(
              child: CustomPaint(
                size: const Size(100, 50),
                painter: NeonCarSilhouettePainter(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== رسم دیال و گیج‌های نئونی سرعت‌سنج مرکزی ====================

class ModernDialPainter extends CustomPainter {
  final double speed;
  ModernDialPainter({required this.speed});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 12;

    // 1. حلقه بیرونی تیره
    final baseArcPaint = Paint()
      ..color = const Color(0xFF142138)
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius, baseArcPaint);

    // 2. حلقه فیروزه‌ای پیشرفت سرعت (Cyan Arc)
    final progressPaint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    double maxSpeed = 180.0;
    double sweepAngle = (speed.clamp(0.0, maxSpeed) / maxSpeed) * (math.pi * 1.5);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi * 0.75,
      sweepAngle,
      false,
      progressPaint,
    );

    // 3. حلقه داخلی نارنجی دور موتور (Orange RPM Indicator)
    final innerOrangePaint = Paint()
      ..color = const Color(0xFFFF6D00)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    double rpmSweep = ((speed * 35).clamp(800, 6500) / 6500) * (math.pi * 1.2);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 16),
      math.pi * 0.9,
      rpmSweep,
      false,
      innerOrangePaint,
    );

    // 4. خطوط تیک سرعت (Tick marks)
    final tickPaint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1.5;

    for (int i = 0; i <= 36; i++) {
      double angle = (math.pi * 0.75) + (i * (math.pi * 1.5) / 36);
      Offset p1 = Offset(center.dx + (radius - 8) * math.cos(angle), center.dy + (radius - 8) * math.sin(angle));
      Offset p2 = Offset(center.dx + (radius - 2) * math.cos(angle), center.dy + (radius - 2) * math.sin(angle));
      canvas.drawLine(p1, p2, tickPaint);
    }
  }

  @override
  bool shouldRepaint(covariant ModernDialPainter oldDelegate) => oldDelegate.speed != speed;
}

// نقاشی نئونی شماتیک خودرو برای پنل Car Status
class NeonCarSilhouettePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = const Color(0xFF00E5FF).withOpacity(0.08)
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, size.height * 0.7);
    path.lineTo(size.width * 0.15, size.height * 0.65);
    path.lineTo(size.width * 0.35, size.height * 0.3);
    path.lineTo(size.width * 0.65, size.height * 0.3);
    path.lineTo(size.width * 0.85, size.height * 0.55);
    path.lineTo(size.width, size.height * 0.7);
    path.lineTo(size.width * 0.85, size.height * 0.85);
    path.lineTo(size.width * 0.15, size.height * 0.85);
    path.close();

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, paint);

    // چرخ‌ها
    final wheelPaint = Paint()..color = const Color(0xFFFF6D00);
    canvas.drawCircle(Offset(size.width * 0.22, size.height * 0.85), 6, wheelPaint);
    canvas.drawCircle(Offset(size.width * 0.78, size.height * 0.85), 6, wheelPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// نقاشی گرید پس‌زمینه کارت نقشه
class MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..strokeWidth = 1.0;

    for (double i = 0; i < size.width; i += 24) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double j = 0; j < size.height; j += 24) {
      canvas.drawLine(Offset(0, j), Offset(size.width, j), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
