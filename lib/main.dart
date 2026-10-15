import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
      title: 'Tiba 2 Cyber HUD Launcher',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF030712),
      ),
      home: const CyberDashboardScreen(),
    );
  }
}

class CyberDashboardScreen extends StatefulWidget {
  const CyberDashboardScreen({super.key});

  @override
  State<CyberDashboardScreen> createState() => _CyberDashboardScreenState();
}

class _CyberDashboardScreenState extends State<CyberDashboardScreen> {
  static const platform = MethodChannel('com.tiba2.launcher/intent');

  double _currentSpeed = 0.0;
  double _calibrationFactor = 1.0;
  Timer? _timer;
  String _currentTime = "";
  String _currentDate = "";

  @override
  void initState() {
    super.initState();
    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateTime();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _updateTime() {
    final now = DateTime.now();
    setState(() {
      _currentTime =
          "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
      _currentDate = "${now.year}/${now.month}/${now.day}";
    });
  }

  Future<void> _launchSystemIntent(String action, {String? uri, String? packageName}) async {
    try {
      await platform.invokeMethod('launchIntent', {
        'action': action,
        'uri': uri,
        'package': packageName,
      });
    } on MissingPluginException {
      _fallbackAction(action);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("اجرای برنامه با خطا مواجه شد: $e"),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _fallbackAction(String action) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("دستور سیستم ارسال شد: $action"),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _openCalibrationDialog() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          title: const Text(
            "کالیبراسیون سرعت و GPS",
            style: TextStyle(color: Colors.cyanAccent),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "ضریب اصلاح: ${_calibrationFactor.toStringAsFixed(2)}x",
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
              const SizedBox(height: 10),
              Slider(
                value: _calibrationFactor,
                min: 0.5,
                max: 1.5,
                divisions: 20,
                activeColor: Colors.cyanAccent,
                onChanged: (val) {
                  setDlgState(() => _calibrationFactor = val);
                  setState(() => _calibrationFactor = val);
                },
              ),
              const Text(
                "جهت رفع تاخیر یا پرش سرعت GPS این ضریب را تنظیم نمایید.",
                style: TextStyle(color: Colors.white70, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("تایید", style: TextStyle(color: Colors.cyanAccent)),
            )
          ],
        ),
      ),
    );
  }

  void _showNavigationPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0B1329),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "انتخاب مسیریاب",
                style: TextStyle(color: Colors.cyanAccent, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 15),
              ListTile(
                leading: const Icon(Icons.navigation, color: Colors.greenAccent),
                title: const Text("نشان (Neshan)", style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _launchSystemIntent("android.intent.action.VIEW", packageName: "org.neshan.maps");
                },
              ),
              ListTile(
                leading: const Icon(Icons.map, color: Colors.blueAccent),
                title: const Text("بلد (Balad)", style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _launchSystemIntent("android.intent.action.VIEW", packageName: "ir.balad.navigation");
                },
              ),
              ListTile(
                leading: const Icon(Icons.explore, color: Colors.orangeAccent),
                title: const Text("گوگل مپ (Google Maps)", style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _launchSystemIntent("android.intent.action.VIEW", uri: "geo:0,0?q=");
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.2,
                colors: [Color(0xFF0A192F), Color(0xFF020408)],
              ),
            ),
          ),
          Positioned.fill(
            child: Opacity(
              opacity: 0.04,
              child: CustomPaint(painter: GridPainter()),
            ),
          ),
          Column(
            children: [
              _buildTopBar(),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: _buildCarDisplayPanel(),
                    ),
                    Expanded(
                      flex: 6,
                      child: _buildSpeedometerAndRearPanel(),
                    ),
                  ],
                ),
              ),
              _buildBottomNavigationBar(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.access_time_rounded, color: Colors.cyanAccent, size: 20),
              const SizedBox(width: 8),
              Text(
                _currentTime,
                style: const TextStyle(
                  color: Colors.cyanAccent,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                _currentDate,
                style: const TextStyle(color: Colors.white54, fontSize: 14),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                tooltip: "کالیبراسیون GPS",
                icon: const Icon(Icons.tune_rounded, color: Colors.cyanAccent),
                onPressed: _openCalibrationDialog,
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: "تنظیمات مانیتور",
                icon: const Icon(Icons.settings_rounded, color: Colors.cyanAccent, size: 28),
                onPressed: () {
                  _launchSystemIntent("android.settings.SETTINGS");
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // لود ایمن عکس tiba2.png از روت پروژه
  Widget _buildCarDisplayPanel() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Image.asset(
          'tiba2.png',
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return CustomPaint(
              size: const Size(180, 180),
              painter: NeonRearCarPainter(),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSpeedometerAndRearPanel() {
    double displaySpeed = _currentSpeed * _calibrationFactor;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 250,
          height: 250,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(250, 250),
                painter: AdvancedSpeedometerPainter(speed: displaySpeed),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    displaySpeed.toInt().toString(),
                    style: const TextStyle(
                      fontSize: 54,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      shadows: [
                        Shadow(color: Colors.cyanAccent, blurRadius: 20),
                        Shadow(color: Colors.blueAccent, blurRadius: 40),
                      ],
                    ),
                  ),
                  const Text(
                    "KM/H",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.cyanAccent,
                      letterSpacing: 3,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        const SaipaLogoWidget(),
        const SizedBox(height: 6),
        // لود ایمن عکس tiba2_rear.png از روت پروژه
        SizedBox(
          height: 80,
          child: Image.asset(
            'tiba2_rear.png',
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return CustomPaint(
                size: const Size(120, 55),
                painter: NeonRearCarPainter(),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withOpacity(0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.cyanAccent.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildActionButton(
            icon: Icons.navigation_rounded,
            label: "مسیریاب",
            onTap: _showNavigationPicker,
          ),
          _buildActionButton(
            icon: Icons.radio_rounded,
            label: "رادیو",
            onTap: () {
              _launchSystemIntent("android.intent.action.MAIN", packageName: "com.android.fmradio");
            },
          ),
          _buildActionButton(
            icon: Icons.phone_in_talk_rounded,
            label: "تماس",
            onTap: () {
              _launchSystemIntent("android.intent.action.DIAL");
            },
          ),
          _buildActionButton(
            icon: Icons.apps_rounded,
            label: "برنامه‌ها",
            onTap: () {
              _launchSystemIntent("android.intent.action.ALL_APPS");
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.cyanAccent, size: 28),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class AdvancedSpeedometerPainter extends CustomPainter {
  final double speed;
  AdvancedSpeedometerPainter({required this.speed});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    const startAngle = 150.0 * (pi / 180.0);
    const sweepAngle = 240.0 * (pi / 180.0);

    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.cyanAccent.withOpacity(0.18),
          Colors.blueAccent.withOpacity(0.06),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 0.75));
    canvas.drawCircle(center, radius * 0.75, glowPaint);

    final trackPaint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 20),
      startAngle,
      sweepAngle,
      false,
      trackPaint,
    );

    double progress = (speed.clamp(0, 220) / 220.0);
    double activeSweep = sweepAngle * progress;

    if (activeSweep > 0) {
      final activeGlowPaint = Paint()
        ..color = Colors.cyanAccent.withOpacity(0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10.0
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - 20),
        startAngle,
        activeSweep,
        false,
        activeGlowPaint,
      );

      final activePaint = Paint()
        ..shader = const SweepGradient(
          colors: [Colors.blueAccent, Colors.cyanAccent],
        ).createShader(Rect.fromCircle(center: center, radius: radius - 20))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.0
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - 20),
        startAngle,
        activeSweep,
        false,
        activePaint,
      );
    }

    const int totalSteps = 11;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (int i = 0; i <= totalSteps; i++) {
      double tickAngle = startAngle + (i / totalSteps) * sweepAngle;
      int speedValue = i * 20;

      double outerR = radius - 26;
      double innerR = radius - 34;

      Offset p1 = Offset(center.dx + outerR * cos(tickAngle), center.dy + outerR * sin(tickAngle));
      Offset p2 = Offset(center.dx + innerR * cos(tickAngle), center.dy + innerR * sin(tickAngle));

      bool isPassed = speedValue <= speed;
      final tickPaint = Paint()
        ..color = isPassed ? Colors.cyanAccent : Colors.white30
        ..strokeWidth = 2.0;
      canvas.drawLine(p1, p2, tickPaint);

      double numberR = radius - 48;
      Offset numPos = Offset(center.dx + numberR * cos(tickAngle), center.dy + numberR * sin(tickAngle));

      textPainter.text = TextSpan(
        text: "$speedValue",
        style: TextStyle(
          color: isPassed ? Colors.cyanAccent : Colors.white54,
          fontSize: 10,
          fontWeight: isPassed ? FontWeight.bold : FontWeight.normal,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(numPos.dx - textPainter.width / 2, numPos.dy - textPainter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant AdvancedSpeedometerPainter oldDelegate) {
    return oldDelegate.speed != speed;
  }
}

class SaipaLogoWidget extends StatelessWidget {
  const SaipaLogoWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(
          size: const Size(18, 18),
          painter: SaipaVectorPainter(),
        ),
        const SizedBox(width: 8),
        const Text(
          "SAIPA",
          style: TextStyle(
            color: Colors.cyanAccent,
            fontWeight: FontWeight.bold,
            letterSpacing: 3,
            fontSize: 12,
            shadows: [Shadow(color: Colors.cyanAccent, blurRadius: 10)],
          ),
        ),
      ],
    );
  }
}

class SaipaVectorPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.cyanAccent
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    for (int i = 0; i < 3; i++) {
      final angle = i * 2 * pi / 3 - pi / 2;
      final path = Path();
      path.moveTo(center.dx, center.dy);
      path.lineTo(
        center.dx + radius * cos(angle),
        center.dy + radius * sin(angle),
      );
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class NeonRearCarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.cyanAccent.withOpacity(0.6)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(size.width * 0.2, size.height * 0.8);
    path.lineTo(size.width * 0.8, size.height * 0.8);
    path.lineTo(size.width * 0.7, size.height * 0.3);
    path.lineTo(size.width * 0.3, size.height * 0.3);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.cyanAccent
      ..strokeWidth = 0.5;

    for (double i = 0; i < size.width; i += 40) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += 40) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
