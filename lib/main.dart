import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const TibaLauncherApp());
}

class TibaLauncherApp extends StatelessWidget {
  const TibaLauncherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tiba 2 Cyber HUD',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF030712),
        fontFamily: 'monospace',
      ),
      home: const CyberHudDashboard(),
    );
  }
}

class CyberHudDashboard extends StatefulWidget {
  const CyberHudDashboard({super.key});

  @override
  State<CyberHudDashboard> createState() => _CyberHudDashboardState();
}

class _CyberHudDashboardState extends State<CyberHudDashboard> with TickerProviderStateMixin {
  Color _themeColor = const Color(0xFF00F0FF);
  double _glowIntensity = 0.8;
  double _speedMultiplier = 1.0;

  double _currentSpeed = 0.0;
  bool _isAccelerating = false;
  Timer? _speedTimer;

  String _selectedNavApp = 'نشان (Neshan)';
  int _roadAnimTick = 0;
  late Timer _roadTimer;

  String _currentTime = '';
  String _currentDate = '';
  late Timer _clockTimer;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _startClock();
    _startSpeedSimulation();
    _startRoadAnimation();
  }

  @override
  void dispose() {
    _speedTimer?.cancel();
    _clockTimer.cancel();
    _roadTimer.cancel();
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      int colorValue = prefs.getInt('theme_color') ?? 0xFF00F0FF;
      _themeColor = Color(colorValue);
      _glowIntensity = prefs.getDouble('glow_intensity') ?? 0.8;
      _speedMultiplier = prefs.getDouble('speed_multiplier') ?? 1.0;
      _selectedNavApp = prefs.getString('nav_app') ?? 'نشان (Neshan)';
    });
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_color', _themeColor.value);
    await prefs.setDouble('glow_intensity', _glowIntensity);
    await prefs.setDouble('speed_multiplier', _speedMultiplier);
    await prefs.setString('nav_app', _selectedNavApp);
  }

  void _startClock() {
    _updateTime();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateTime();
    });
  }

  void _updateTime() {
    final now = DateTime.now();
    setState(() {
      _currentTime = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
    });
  }

  void _startSpeedSimulation() {
    _speedTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      setState(() {
        if (_isAccelerating) {
          _currentSpeed += 1.5;
          if (_currentSpeed > 180) _currentSpeed = 180;
        } else {
          _currentSpeed -= 1.0;
          if (_currentSpeed < 0) _currentSpeed = 0;
        }
      });
    });
  }

  void _startRoadAnimation() {
    _roadTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      setState(() {
        _roadAnimTick = (_roadAnimTick + 1) % 100;
      });
    });
  }

  Future<void> _sendAndroidIntent(String action, {String? packageName}) async {
    try {
      const MethodChannel channel = MethodChannel('tiba.launcher/intent');
      await channel.invokeMethod('launchIntent', {
        'action': action,
        'package': packageName,
      });
    } catch (e) {
      debugPrint('Intent error: $e');
    }
  }

  Future<void> _openAndroidSettings() async => await _sendAndroidIntent('android.settings.SETTINGS');
  Future<void> _openDialer() async => await _sendAndroidIntent('android.intent.action.DIAL');
  Future<void> _openMusicPlayer() async => await _sendAndroidIntent('android.intent.action.MUSIC_PLAYER');
  
  Future<void> _openNavigationApp() async {
    String pkg = 'com.neshan.map';
    if (_selectedNavApp.contains('بلد')) pkg = 'ir.map.balad';
    if (_selectedNavApp.contains('گوگل')) pkg = 'com.google.android.apps.maps';
    await _sendAndroidIntent('android.intent.action.VIEW', packageName: pkg);
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0B132B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: _themeColor, width: 2),
          ),
          title: Text('تنظیمات پیشرفته نئون و GPS', style: TextStyle(color: _themeColor)),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('پالت رنگ نئون:', style: TextStyle(fontSize: 14)),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _colorButton(const Color(0xFF00F0FF), setDialogState),
                        _colorButton(const Color(0xFF00FF66), setDialogState),
                        _colorButton(const Color(0xFFFF0055), setDialogState),
                        _colorButton(const Color(0xFFFFB700), setDialogState),
                        _colorButton(const Color(0xFF9D4EDD), setDialogState),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text('شدت نور (Glow): ${_glowIntensity.toStringAsFixed(1)}', style: const TextStyle(fontSize: 14)),
                    Slider(
                      value: _glowIntensity,
                      min: 0.2,
                      max: 1.0,
                      activeColor: _themeColor,
                      onChanged: (val) {
                        setDialogState(() => _glowIntensity = val);
                        setState(() => _glowIntensity = val);
                        _savePreferences();
                      },
                    ),
                    const SizedBox(height: 10),
                    Text('ضریب کالیبره سرعت GPS: ${_speedMultiplier.toStringAsFixed(2)}x', style: const TextStyle(fontSize: 14)),
                    Slider(
                      value: _speedMultiplier,
                      min: 0.7,
                      max: 1.4,
                      divisions: 14,
                      activeColor: _themeColor,
                      label: '${_speedMultiplier.toStringAsFixed(2)}x',
                      onChanged: (val) {
                        setDialogState(() => _speedMultiplier = val);
                        setState(() => _speedMultiplier = val);
                        _savePreferences();
                      },
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('بستن', style: TextStyle(color: _themeColor)),
            ),
          ],
        );
      },
    );
  }

  Widget _colorButton(Color color, StateSetter setDialogState) {
    return GestureDetector(
      onTap: () {
        setDialogState(() => _themeColor = color);
        setState(() => _themeColor = color);
        _savePreferences();
      },
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: _themeColor == color ? 2 : 0),
          boxShadow: [BoxShadow(color: color.withOpacity(0.6), blurRadius: 8)],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final calibratedSpeed = _currentSpeed * _speedMultiplier;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.2,
            colors: [Color(0xFF0A1128), Color(0xFF030712)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: Row(
              children: [
                // Left Vertical Sidebar Dock
                _buildLeftSidebar(),
                const SizedBox(width: 10),
                // Left-Center Panel: Navigation Map Preview
                Expanded(flex: 3, child: _buildNavigationPanel()),
                const SizedBox(width: 10),
                // Center Panel: Speedometer, Saipa Logo, Animated Road & tiba2_rear.png
                Expanded(flex: 4, child: _buildCenterSpeedometer(calibratedSpeed)),
                const SizedBox(width: 10),
                // Right Panel: Media Player & Car Status with tiba2.png
                Expanded(flex: 3, child: _buildRightMediaAndStatusPanel()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLeftSidebar() {
    return Container(
      width: 65,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0B132B).withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _themeColor.withOpacity(0.4), width: 1.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          IconButton(icon: Icon(Icons.flash_on, color: _themeColor, size: 24), onPressed: _showSettingsDialog),
          IconButton(icon: Icon(Icons.grid_view, color: _themeColor, size: 24), onPressed: _openAndroidSettings),
          IconButton(icon: Icon(Icons.navigation, color: _themeColor, size: 24), onPressed: _openNavigationApp),
          IconButton(icon: Icon(Icons.music_note, color: _themeColor, size: 24), onPressed: _openMusicPlayer),
          IconButton(icon: Icon(Icons.phone, color: _themeColor, size: 24), onPressed: _openDialer),
          IconButton(icon: Icon(Icons.settings, color: _themeColor, size: 24), onPressed: _openAndroidSettings),
        ],
      ),
    );
  }

  Widget _buildNavigationPanel() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0B132B).withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _themeColor.withOpacity(0.4), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.navigation, color: _themeColor, size: 16),
                  const SizedBox(width: 6),
                  Text('مسیریاب: $_selectedNavApp', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
              GestureDetector(
                onTap: () {
                  setState(() {
                    if (_selectedNavApp.contains('نشان')) {
                      _selectedNavApp = 'بلد (Balad)';
                    } else if (_selectedNavApp.contains('بلد')) {
                      _selectedNavApp = 'گوگل مپ (Google Maps)';
                    } else {
                      _selectedNavApp = 'نشان (Neshan)';
                    }
                    _savePreferences();
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    border: Border.all(color: _themeColor),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('تغییر', style: TextStyle(fontSize: 9)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: GestureDetector(
              onTap: _openNavigationApp,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _themeColor.withOpacity(0.3)),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(double.infinity, double.infinity),
                      painter: NavigationRoadPainter(themeColor: _themeColor, roadProgress: _roadAnimTick / 100.0),
                    ),
                    Positioned(
                      bottom: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: _themeColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _themeColor),
                        ),
                        child: Text('Start Navigation', style: TextStyle(color: _themeColor, fontWeight: FontWeight.bold, fontSize: 11)),
                      ),
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

  Widget _buildCenterSpeedometer(double speed) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF0B132B).withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _themeColor.withOpacity(0.4), width: 1.5),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(double.infinity, double.infinity),
            painter: CyberSpeedometerPainter(speed: speed, themeColor: _themeColor),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 8),
              // Saipa Neon Logo
              CustomPaint(
                size: const Size(36, 36),
                painter: SaipaNeonLogoPainter(color: _themeColor),
              ),
              const SizedBox(height: 2),
              Text(
                speed.toStringAsFixed(0),
                style: TextStyle(
                  fontSize: 52,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [Shadow(color: _themeColor, blurRadius: 15)],
                ),
              ),
              const Text('KM / H', style: TextStyle(fontSize: 10, letterSpacing: 2, color: Colors.grey)),
              const Spacer(),
              // Animated Road & tiba2_rear.png EXACTLY under speedometer
              SizedBox(
                height: 100,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(140, 100),
                      painter: AnimatedRoadPainter(tick: _roadAnimTick, themeColor: _themeColor),
                    ),
                    Container(
                      width: 85,
                      height: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        image: const DecorationImage(
                          image: AssetImage('tiba2_rear.png'),
                          fit: BoxFit.contain,
                        ),
                        boxShadow: [BoxShadow(color: _themeColor.withOpacity(0.5), blurRadius: 10)],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              // Gear Selector Bar (D P R N)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: ['D', 'P', 'R', 'N'].map((gear) {
                  bool active = gear == 'D';
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: active ? _themeColor : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _themeColor),
                    ),
                    child: Text(gear, style: TextStyle(fontSize: 12, color: active ? Colors.black : Colors.white, fontWeight: FontWeight.bold)),
                  );
                }).toList(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRightMediaAndStatusPanel() {
    return Column(
      children: [
        // Media Player Card
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF0B132B).withOpacity(0.6),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _themeColor.withOpacity(0.4), width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Now Playing', style: TextStyle(fontSize: 11, color: Colors.grey)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 45,
                      height: 45,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: _themeColor.withOpacity(0.2),
                        border: Border.all(color: _themeColor),
                      ),
                      child: Icon(Icons.music_note, color: _themeColor, size: 24),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('آهنگ‌های دستگاه', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text('Unknown Artist', style: TextStyle(fontSize: 9, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    IconButton(icon: const Icon(Icons.shuffle, size: 16), onPressed: () {}),
                    IconButton(icon: const Icon(Icons.skip_previous, size: 18), onPressed: () {}),
                    IconButton(icon: Icon(Icons.play_arrow, color: _themeColor, size: 22), onPressed: _openMusicPlayer),
                    IconButton(icon: const Icon(Icons.skip_next, size: 18), onPressed: () {}),
                    IconButton(icon: const Icon(Icons.repeat, size: 16), onPressed: () {}),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Car Status Card with tiba2.png
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF0B132B).withOpacity(0.6),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _themeColor.withOpacity(0.4), width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Car Status', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    Text('Tiba 2 Sport', style: TextStyle(fontSize: 10, color: _themeColor)),
                  ],
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _themeColor.withOpacity(0.3)),
                      image: const DecorationImage(
                        image: AssetImage('tiba2.png'),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// Custom Painters

class CyberSpeedometerPainter extends CustomPainter {
  final double speed;
  final Color themeColor;
  CyberSpeedometerPainter({required this.speed, required this.themeColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 - 10);
    const radius = 120.0;

    final paintGlow = Paint()
      ..color = themeColor.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    final paintArc = Paint()
      ..color = themeColor.withOpacity(0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    const startAngle = math.pi * 0.75;
    const sweepAngle = math.pi * 1.5;

    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, sweepAngle, false, paintGlow);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, sweepAngle, false, paintArc);

    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    for (int i = 0; i <= 240; i += 20) {
      double angle = startAngle + (i / 240.0) * sweepAngle;
      double innerR = radius - (i % 40 == 0 ? 10 : 6);
      double outerR = radius;

      Offset p1 = Offset(center.dx + innerR * math.cos(angle), center.dy + innerR * math.sin(angle));
      Offset p2 = Offset(center.dx + outerR * math.cos(angle), center.dy + outerR * math.sin(angle));

      final tickPaint = Paint()
        ..color = i <= speed ? themeColor : Colors.grey.withOpacity(0.5)
        ..strokeWidth = i % 40 == 0 ? 2.5 : 1.2;

      canvas.drawLine(p1, p2, tickPaint);

      if (i % 40 == 0) {
        double textR = radius - 22;
        Offset tp = Offset(center.dx + textR * math.cos(angle), center.dy + textR * math.sin(angle));

        textPainter.text = TextSpan(
          text: '$i',
          style: TextStyle(color: Colors.grey[300], fontSize: 9, fontWeight: FontWeight.bold),
        );
        textPainter.layout();
        textPainter.paint(canvas, Offset(tp.dx - textPainter.width / 2, tp.dy - textPainter.height / 2));
      }
    }
  }

  @override
  bool shouldRepaint(covariant CyberSpeedometerPainter oldDelegate) =>
      oldDelegate.speed != speed || oldDelegate.themeColor != themeColor;
}

class SaipaNeonLogoPainter extends CustomPainter {
  final Color color;
  SaipaNeonLogoPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    final fillPaint = Paint()
      ..color = color.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(center.dx, center.dy - 12)
      ..lineTo(center.dx + 12, center.dy)
      ..lineTo(center.dx, center.dy + 12)
      ..lineTo(center.dx - 12, center.dy)
      ..close();

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant SaipaNeonLogoPainter oldDelegate) => oldDelegate.color != color;
}

class AnimatedRoadPainter extends CustomPainter {
  final int tick;
  final Color themeColor;
  AnimatedRoadPainter({required this.tick, required this.themeColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = themeColor.withOpacity(0.6)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    double w = size.width;
    double h = size.height;

    Path roadPath = Path()
      ..moveTo(w * 0.25, h)
      ..lineTo(w * 0.42, h * 0.15)
      ..moveTo(w * 0.75, h)
      ..lineTo(w * 0.58, h * 0.15);

    canvas.drawPath(roadPath, paint);

    final dashPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.5;

    double offset = (tick * 1.5) % 15;
    for (double y = offset; y < h; y += 15) {
      double x = w * 0.5;
      canvas.drawLine(Offset(x, y), Offset(x, y + 6), dashPaint);
    }
  }

  @override
  bool shouldRepaint(covariant AnimatedRoadPainter oldDelegate) =>
      oldDelegate.tick != tick || oldDelegate.themeColor != themeColor;
}

class NavigationRoadPainter extends CustomPainter {
  final Color themeColor;
  final double roadProgress;
  NavigationRoadPainter({required this.themeColor, required this.roadProgress});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    path.moveTo(size.width * 0.2, size.height * 0.8);
    path.quadraticBezierTo(
      size.width * 0.5,
      size.height * 0.3,
      size.width * 0.8,
      size.height * 0.1,
    );

    final routeGlowPaint = Paint()
      ..color = themeColor.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    final routePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    canvas.drawPath(path, routeGlowPaint);
    canvas.drawPath(path, routePaint);
  }

  @override
  bool shouldRepaint(covariant NavigationRoadPainter oldDelegate) =>
      oldDelegate.roadProgress != roadProgress || oldDelegate.themeColor != themeColor;
}
