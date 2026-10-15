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
  static const platform = MethodChannel('samples.flutter.dev/battery'); // Standard channel fallback

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
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      _currentDate = "${days[now.weekday - 1]}, ${now.day} ${months[now.month - 1]}";
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

  // Native Android Intent Launcher via Platform Channel
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

  Future<void> _openAndroidSettings() async {
    await _sendAndroidIntent('android.settings.SETTINGS');
  }

  Future<void> _openDialer() async {
    await _sendAndroidIntent('android.intent.action.DIAL');
  }

  Future<void> _openMusicPlayer() async {
    await _sendAndroidIntent('android.intent.action.MUSIC_PLAYER');
  }

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
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                _buildTopBar(),
                const SizedBox(height: 10),
                Expanded(
                  child: Row(
                    children: [
                      // Left Panel (Other controls/widgets)
                      _buildLeftControlPanel(),
                      const SizedBox(width: 10),
                      // Center Panel (Speedometer, Saipa logo, rear car, road)
                      Expanded(flex: 3, child: _buildCenterSpeedometer(calibratedSpeed)),
                      const SizedBox(width: 10),
                      // Right Panel: Large Tiba 2 Sport Image + Nav/Media
                      _buildRightCarAndMediaPanel(),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                _buildBottomDock(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0B132B).withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _themeColor.withOpacity(0.4), width: 1.5),
        boxShadow: [BoxShadow(color: _themeColor.withOpacity(_glowIntensity * 0.2), blurRadius: 10)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.access_time, color: _themeColor, size: 20),
              const SizedBox(width: 8),
              Text(_currentTime, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(width: 12),
              Text(_currentDate, style: TextStyle(fontSize: 13, color: Colors.grey[400])),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(color: _themeColor, width: 1),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: _themeColor.withOpacity(0.3), blurRadius: 6)],
            ),
            child: Text('TIBA 2 • CYBER HUD', style: TextStyle(color: _themeColor, fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          Row(
            children: [
              Icon(Icons.wifi, color: _themeColor, size: 20),
              const SizedBox(width: 12),
              Icon(Icons.bluetooth, color: _themeColor, size: 20),
              const SizedBox(width: 12),
              IconButton(
                icon: Icon(Icons.settings_suggest, color: _themeColor, size: 24),
                onPressed: _showSettingsDialog,
                tooltip: 'تنظیمات نئون',
              ),
              IconButton(
                icon: Icon(Icons.settings, color: _themeColor, size: 24),
                onPressed: _openAndroidSettings,
                tooltip: 'تنظیمات مانیتور اندروید',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLeftControlPanel() {
    return Expanded(
      flex: 2,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF0B132B).withOpacity(0.6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _themeColor.withOpacity(0.4), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('وضعیت سیستم', style: TextStyle(color: _themeColor, fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _themeColor.withOpacity(0.3)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.speed, color: _themeColor, size: 36),
                    const SizedBox(height: 10),
                    const Text('کالیبراسیون هوشمند GPS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                    const SizedBox(height: 6),
                    Text('برای تنظیم دقیق ضریب سرعت و رفع پرش، از دکمه تنظیمات نئون استفاده کنید.', style: TextStyle(fontSize: 10, color: Colors.grey[400]), textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _themeColor.withOpacity(0.5)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('طراحی اختصاصی مانیتور', style: TextStyle(fontSize: 11, color: Colors.grey[300])),
                  const SizedBox(width: 6),
                  Icon(Icons.verified, color: _themeColor, size: 14),
                ],
              ),
            ),
          ],
        ),
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
              const SizedBox(height: 10),
              CustomPaint(
                size: const Size(40, 40),
                painter: SaipaNeonLogoPainter(color: _themeColor),
              ),
              const SizedBox(height: 4),
              Text(
                speed.toStringAsFixed(0),
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [Shadow(color: _themeColor, blurRadius: 15)],
                ),
              ),
              const Text('KM / H', style: TextStyle(fontSize: 10, letterSpacing: 2, color: Colors.grey)),
              const Spacer(),
              SizedBox(
                height: 90,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(120, 90),
                      painter: AnimatedRoadPainter(tick: _roadAnimTick, themeColor: _themeColor),
                    ),
                    Container(
                      width: 75,
                      height: 55,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        image: const DecorationImage(
                          image: AssetImage('tiba2_rear.png'),
                          fit: BoxFit.contain,
                        ),
                        boxShadow: [BoxShadow(color: _themeColor.withOpacity(0.4), blurRadius: 8)],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            bottom: 10,
            right: 10,
            child: GestureDetector(
              onTapDown: (_) => setState(() => _isAccelerating = true),
              onTapUp: (_) => setState(() => _isAccelerating = false),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _isAccelerating ? _themeColor : _themeColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _themeColor),
                ),
                child: Text('گاز', style: TextStyle(fontSize: 11, color: _isAccelerating ? Colors.black : Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRightCarAndMediaPanel() {
    return Expanded(
      flex: 2,
      child: Column(
        children: [
          // Tiba 2 Sport Large Image Card (Right Side)
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
                      Text('سايپا تيابا ۲', style: TextStyle(color: _themeColor, fontWeight: FontWeight.bold, fontSize: 13)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _themeColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: _themeColor, width: 0.8),
                        ),
                        child: const Text('TIBA 2 SPORT', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
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
          const SizedBox(height: 8),
          // Navigation Card
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
                      Row(
                        children: [
                          Icon(Icons.navigation, color: _themeColor, size: 16),
                          const SizedBox(width: 4),
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
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            border: Border.all(color: _themeColor),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('تغییر', style: TextStyle(fontSize: 9)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: GestureDetector(
                      onTap: _openNavigationApp,
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _themeColor.withOpacity(0.3)),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CustomPaint(
                              size: const Size(double.infinity, double.infinity),
                              painter: NavigationRoadPainter(themeColor: _themeColor, roadProgress: _roadAnimTick / 100.0),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.touch_app, color: _themeColor, size: 16),
                                const SizedBox(width: 4),
                                Text('لمس برای باز کردن نقشه', style: TextStyle(fontSize: 10, color: _themeColor)),
                              ],
                            ),
                          ],
                        ),
                      ),
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

  Widget _buildBottomDock() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0B132B).withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _themeColor.withOpacity(0.4), width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _dockItem(Icons.map, 'نقشه', _openNavigationApp),
          _dockItem(Icons.radio, 'رادیو', _openMusicPlayer),
          _dockItem(Icons.phone, 'تماس', _openDialer),
          _dockItem(Icons.apps, 'برنامه‌ها', _openAndroidSettings),
          _dockItem(Icons.tune, 'نورپردازی', _showSettingsDialog),
        ],
      ),
    );
  }

  Widget _dockItem(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: _themeColor, size: 22),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[300])),
          ],
        ),
      ),
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
    final center = Offset(size.width / 2, size.height / 2 + 10);
    const radius = 135.0;

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
      double innerR = radius - (i % 40 == 0 ? 12 : 8);
      double outerR = radius;

      Offset p1 = Offset(center.dx + innerR * math.cos(angle), center.dy + innerR * math.sin(angle));
      Offset p2 = Offset(center.dx + outerR * math.cos(angle), center.dy + outerR * math.sin(angle));

      final tickPaint = Paint()
        ..color = i <= speed ? themeColor : Colors.grey.withOpacity(0.5)
        ..strokeWidth = i % 40 == 0 ? 3 : 1.5;

      canvas.drawLine(p1, p2, tickPaint);

      if (i % 40 == 0) {
        double textR = radius - 26;
        Offset tp = Offset(center.dx + textR * math.cos(angle), center.dy + textR * math.sin(angle));

        textPainter.text = TextSpan(
          text: '$i',
          style: TextStyle(color: Colors.grey[300], fontSize: 10, fontWeight: FontWeight.bold),
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
      ..moveTo(center.dx, center.dy - 14)
      ..lineTo(center.dx + 14, center.dy)
      ..lineTo(center.dx, center.dy + 14)
      ..lineTo(center.dx - 14, center.dy)
      ..close();

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, paint);

    final innerPath = Path()
      ..moveTo(center.dx, center.dy - 8)
      ..lineTo(center.dx + 6, center.dy)
      ..lineTo(center.dx, center.dy + 8)
      ..lineTo(center.dx - 6, center.dy)
      ..close();
    canvas.drawPath(innerPath, paint);
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
      ..moveTo(w * 0.3, h)
      ..lineTo(w * 0.45, h * 0.2)
      ..moveTo(w * 0.7, h)
      ..lineTo(w * 0.55, h * 0.2);

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
      size.height * 0.2,
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
