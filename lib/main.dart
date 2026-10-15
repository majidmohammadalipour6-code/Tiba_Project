import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
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

class _DashboardScreenState extends State<DashboardScreen> with SingleTickerProviderStateMixin {
  static const platform = MethodChannel('com.tiba2.launcher/actions');

  double currentSpeed = 0.0;
  String selectedGear = 'D';
  bool isPlaying = false;
  String currentTrack = 'در حال پخش نیست';

  late AnimationController _roadAnimController;
  Timer? _clockTimer;
  String _currentTime = "";

  @override
  void initState() {
    super.initState();
    _roadAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();

    _updateClock();
    _requestGps();
  }

  void _updateClock() {
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final now = DateTime.now();
      if (mounted) {
        setState(() {
          _currentTime = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
        });
      }
    });
  }

  Future<void> _requestGps() async {
    try {
      await platform.invokeMethod('call', {'action': 'location_settings'});
    } catch (_) {}
  }

  Future<void> _callNative(String action, {String pkg = ""}) async {
    try {
      await platform.invokeMethod('call', {'action': action, 'pkg': pkg});
    } catch (_) {}
  }

  @override
  void dispose() {
    _roadAnimController.dispose();
    _clockTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // ستون ۱: سایدبار داک سمت چپ
          _buildDock(),

          // ستون ۲: کارت ناوبری و مسیریاب
          Expanded(flex: 3, child: _buildNavCard()),

          // ستون ۳: سرعت‌سنج HUD، آرم سایپا، جاده متحرک و نمای پشت تیبا
          Expanded(flex: 4, child: _buildCenterSpeedoHUD()),

          // ستون ۴: عکس خودرو تیبا ۲ و موزیک پلیر
          Expanded(flex: 3, child: _buildRightMediaPanel()),
        ],
      ),
    );
  }

  Widget _buildDock() {
    return Container(
      width: 75,
      decoration: BoxDecoration(
        color: const Color(0xFF0C1322),
        border: Border(right: BorderSide(color: Colors.cyan.withOpacity(0.2))),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Text(_currentTime, style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 13)),
          _dockIcon(Icons.settings, "تنظیمات", () => _callNative("settings")),
          _dockIcon(Icons.navigation_outlined, "مسیریاب", () => _callNative("nav", pkg: "ir.balad.app")),
          _dockIcon(Icons.music_note, "موزیک", () => _callNative("music")),
          _dockIcon(Icons.radio, "رادیو", () => _callNative("radio")),
          _dockIcon(Icons.phone, "تماس", () => _callNative("phone")),
          _dockIcon(Icons.apps, "برنامه‌ها", () => _callNative("apps")),
        ],
      ),
    );
  }

  Widget _dockIcon(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: Column(
          children: [
            Icon(icon, color: Colors.cyanAccent, size: 22),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: Colors.white60, fontSize: 9)),
          ],
        ),
      ),
    );
  }

  Widget _buildNavCard() {
    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1726),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.cyan.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.near_me, color: Colors.cyanAccent, size: 16),
              SizedBox(width: 6),
              Text("ناوبری ماهواره‌ای", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
          const Spacer(),
          Center(
            child: InkWell(
              onTap: () => _callNative("nav", pkg: "ir.balad.app"),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(colors: [Colors.cyan.withOpacity(0.3), Colors.blue.withOpacity(0.1)]),
                  border: Border.all(color: Colors.cyanAccent),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.map_outlined, color: Colors.cyanAccent, size: 36),
                    SizedBox(height: 6),
                    Text("ورود به مسیریاب", style: TextStyle(color: Colors.white, fontSize: 11)),
                  ],
                ),
              ),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildCenterSpeedoHUD() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0A101D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.cyan.withOpacity(0.2)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // جاده نئونی متحرک
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 120,
            child: AnimatedBuilder(
              animation: _roadAnimController,
              builder: (context, child) {
                return CustomPaint(
                  painter: CyberRoadPainter(progress: _roadAnimController.value),
                );
              },
            ),
          ),

          // کیلومترشمار، نشان سایپا، خودرو و دنده‌ها
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                currentSpeed.toInt().toString(),
                style: const TextStyle(
                  fontSize: 54,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -2,
                ),
              ),
              const Text(
                "KM/H",
                style: TextStyle(color: Colors.cyanAccent, fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 6),

              // آرم سایپا
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.cyanAccent.withOpacity(0.5)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  "S A I P A",
                  style: TextStyle(color: Colors.cyanAccent, fontSize: 9, letterSpacing: 3, fontWeight: FontWeight.bold),
                ),
              ),

              const SizedBox(height: 8),

              // تصویر پشت تیبا ۲
              SizedBox(
                height: 85,
                child: Image.asset(
                  "tiba2_rear.png",
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(Icons.directions_car, color: Colors.cyanAccent, size: 60),
                ),
              ),

              // دنده‌ها
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: ['P', 'R', 'N', 'D'].map((gear) {
                  bool isSelected = gear == selectedGear;
                  return GestureDetector(
                    onTap: () => setState(() => selectedGear = gear),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.cyanAccent : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.cyanAccent.withOpacity(0.5)),
                      ),
                      child: Text(
                        gear,
                        style: TextStyle(
                          color: isSelected ? Colors.black : Colors.white70,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRightMediaPanel() {
    return Container(
      margin: const EdgeInsets.all(8),
      child: Column(
        children: [
          // تصویر اصلی تیبا ۲
          Expanded(
            flex: 5,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF0E1726),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.cyan.withOpacity(0.3)),
              ),
              child: Center(
                child: Image.asset(
                  "tiba2.png",
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(Icons.car_rental, color: Colors.cyanAccent, size: 70),
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // کارت موزیک پلیر
          Expanded(
            flex: 5,
            child: InkWell(
              onTap: () => _callNative("music"),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0E1726),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.cyan.withOpacity(0.3)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.music_note, color: Colors.cyanAccent, size: 16),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            currentTrack,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white, fontSize: 11),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.skip_previous, color: Colors.cyanAccent),
                          onPressed: () => _callNative("media_prev"),
                        ),
                        IconButton(
                          icon: Icon(isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill, color: Colors.cyanAccent, size: 36),
                          onPressed: () {
                            setState(() => isPlaying = !isPlaying);
                            _callNative("media_play_pause");
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.skip_next, color: Colors.cyanAccent),
                          onPressed: () => _callNative("media_next"),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// نقاش جاده پرسپکتیو نئونی
class CyberRoadPainter extends CustomPainter {
  final double progress;
  CyberRoadPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paintLine = Paint()
      ..color = Colors.cyanAccent.withOpacity(0.4)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final paintGlow = Paint()
      ..color = Colors.cyanAccent.withOpacity(0.15)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(size.width * 0.40, 0)
      ..lineTo(size.width * 0.1, size.height)
      ..lineTo(size.width * 0.9, size.height)
      ..lineTo(size.width * 0.60, 0)
      ..close();
    canvas.drawPath(path, paintGlow);

    canvas.drawLine(Offset(size.width * 0.40, 0), Offset(size.width * 0.1, size.height), paintLine);
    canvas.drawLine(Offset(size.width * 0.60, 0), Offset(size.width * 0.9, size.height), paintLine);

    for (int i = 0; i < 5; i++) {
      double t = (i / 5.0 + progress) % 1.0;
      double y = math.pow(t, 2) * size.height;
      double leftX = (size.width * 0.40) - (size.width * 0.30 * t);
      double rightX = (size.width * 0.60) + (size.width * 0.30 * t);

      paintLine.color = Colors.cyanAccent.withOpacity(0.1 + (0.5 * t));
      canvas.drawLine(Offset(leftX, y), Offset(rightX, y), paintLine);
    }
  }

  @override
  bool shouldRepaint(covariant CyberRoadPainter oldDelegate) => true;
}
