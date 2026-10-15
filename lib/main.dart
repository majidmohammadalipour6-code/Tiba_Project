import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
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
        scaffoldBackgroundColor: const Color(0xFF04070D),
        fontFamily: 'sans-serif',
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
  double _currentSpeed = 0.0;
  StreamSubscription<Position>? _gpsSubscription;

  late Timer _clockTimer;
  late Timer _roadAnimTimer;
  String _timeString = "--:--";
  String _dateString = "";
  double _roadOffset = 0.0;

  bool _isPlaying = true;
  final String _songTitle = "Shadmehr - Ghoroor";
  final String _artistName = "Cyber Wave Mix";
  final double _musicProgress = 0.45;

  Color _neonThemeColor = const Color(0xFF00E5FF);
  double _neonGlowFactor = 1.0;

  final List<Color> _availableColors = const [
    Color(0xFF00E5FF),
    Color(0xFF0077FF),
    Color(0xFFFF0055),
    Color(0xFF00FF66),
    Color(0xFFFFB300),
    Color(0xFF9D00FF),
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _updateClock();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) => _updateClock());

    _roadAnimTimer = Timer.periodic(const Duration(milliseconds: 33), (_) {
      if (mounted) {
        setState(() {
          double factor = _currentSpeed > 5 ? (_currentSpeed / 40.0) : 0.8;
          _roadOffset = (_roadOffset + (0.02 * factor)) % 1.0;
        });
      }
    });

    _initGps();
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    _roadAnimTimer.cancel();
    _gpsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final colorVal = prefs.getInt('neon_color');
    final glowVal = prefs.getDouble('neon_glow');
    if (colorVal != null) _neonThemeColor = Color(colorVal);
    if (glowVal != null) _neonGlowFactor = glowVal;
    if (mounted) setState(() {});
  }

  Future<void> _saveSettings(Color color, double glow) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('neon_color', color.value);
    await prefs.setDouble('neon_glow', glow);
    setState(() {
      _neonThemeColor = color;
      _neonGlowFactor = glow;
    });
  }

  void _updateClock() {
    final now = DateTime.now();
    final h = now.hour.toString().padLeft(2, '0');
    final m = now.minute.toString().padLeft(2, '0');
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    setState(() {
      _timeString = "$h:$m";
      _dateString = "${days[now.weekday - 1]}, ${now.day} ${months[now.month - 1]}";
    });
  }

  Future<void> _initGps() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      _gpsSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 1,
        ),
      ).listen((Position pos) {
        double raw = pos.speed;
        if (raw < 0 || raw.isNaN) raw = 0.0;
        setState(() {
          _currentSpeed = (raw * 3.6).clamp(0.0, 240.0);
        });
      });
    } catch (_) {}
  }

  void _openSettingsDialog() {
    Color selectedColor = _neonThemeColor;
    double selectedGlow = _neonGlowFactor;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF0A101D),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: selectedColor.withOpacity(0.5)),
            ),
            title: Text(
              'تنظیمات نئون و نورپردازی تیبا',
              textAlign: TextAlign.center,
              style: TextStyle(color: selectedColor, fontWeight: FontWeight.bold),
            ),
            content: SizedBox(
              width: 380,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('طیف رنگی نئون:', style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    children: _availableColors.map((c) {
                      bool isSel = c.value == selectedColor.value;
                      return GestureDetector(
                        onTap: () => setDialogState(() => selectedColor = c),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSel ? Colors.white : Colors.transparent,
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: c.withOpacity(0.7),
                                blurRadius: isSel ? 14 : 4,
                                spreadRadius: isSel ? 3 : 0,
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('شدت درخشش (Glow):', style: TextStyle(color: Colors.white70)),
                      Text('${(selectedGlow * 100).toInt()}%', style: TextStyle(color: selectedColor)),
                    ],
                  ),
                  Slider(
                    value: selectedGlow,
                    min: 0.3,
                    max: 1.8,
                    activeColor: selectedColor,
                    inactiveColor: Colors.white24,
                    onChanged: (val) => setDialogState(() => selectedGlow = val),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('انصراف', style: TextStyle(color: Colors.white60)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: selectedColor.withOpacity(0.3),
                  side: BorderSide(color: selectedColor),
                ),
                onPressed: () {
                  _saveSettings(selectedColor, selectedGlow);
                  Navigator.pop(ctx);
                },
                child: const Text('ذخیره تغییرات', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = _neonThemeColor;
    final glow = _neonGlowFactor;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.0, -0.2),
            radius: 1.2,
            colors: [Color(0xFF0A1526), Color(0xFF04070D), Color(0xFF010306)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildTopBar(theme, glow),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
                  child: Row(
                    children: [
                      Expanded(flex: 31, child: _buildNavigationCard(theme, glow)),
                      const SizedBox(width: 14),
                      Expanded(flex: 38, child: _buildSpeedometerCenter(theme, glow)),
                      const SizedBox(width: 14),
                      Expanded(
                        flex: 31,
                        child: Column(
                          children: [
                            Expanded(flex: 48, child: _buildCarStatusCard(theme, glow)),
                            const SizedBox(height: 12),
                            Expanded(flex: 52, child: _buildMusicCard(theme, glow)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _buildBottomQuickDock(theme, glow),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(Color theme, double glow) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.access_time_filled, color: theme, size: 20),
              const SizedBox(width: 8),
              Text(
                _timeString,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [Shadow(color: theme.withOpacity(0.8 * glow), blurRadius: 10)],
                ),
              ),
              const SizedBox(width: 12),
              Text(_dateString, style: const TextStyle(fontSize: 13, color: Colors.white60)),
            ],
          ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.withOpacity(0.4)),
                ),
                child: Text(
                  'TIBA 2 • CYBER HUD',
                  style: TextStyle(
                    color: theme,
                    fontSize: 11,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Icon(Icons.wifi, color: theme, size: 20),
              const SizedBox(width: 10),
              Icon(Icons.bluetooth, color: theme, size: 20),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: _openSettingsDialog,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.06),
                    border: Border.all(color: theme.withOpacity(0.5)),
                  ),
                  child: Icon(Icons.settings, color: theme, size: 18),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _neonPanel({
    required Widget child,
    required Color color,
    required double glow,
    EdgeInsetsGeometry padding = const EdgeInsets.all(12),
  }) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: const Color(0xFF090E17).withOpacity(0.85),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withOpacity(0.35 * glow), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.15 * glow),
            blurRadius: 16 * glow,
            spreadRadius: 1,
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildNavigationCard(Color theme, double glow) {
    return _neonPanel(
      color: theme,
      glow: glow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.navigation_rounded, color: theme, size: 18),
                  const SizedBox(width: 6),
                  Text("مسیریاب زنده", style: TextStyle(color: theme, fontSize: 13, fontWeight: FontWeight.bold)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.greenAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text("GPS فعال", style: TextStyle(color: Colors.greenAccent, fontSize: 10)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CustomPaint(
                    painter: NavigationRoadPainter(
                      themeColor: theme,
                      roadProgress: _roadOffset,
                    ),
                  ),
                  Positioned(
                    top: 10,
                    left: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.65),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: theme.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.turn_right_rounded, color: theme, size: 24),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("۲۵۰ متر بعد، خروجی بزرگراه",
                                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                Text("بزرگراه شهید ستاری جنوب",
                                    style: TextStyle(color: Colors.white54, fontSize: 9)),
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
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navMetricItem("۸ دقیقه", "تا مقصد"),
              _navMetricItem("۴.۲ km", "فاصله باقی‌مانده"),
              _navMetricItem("۱۹:۴۵", "زمان رسیدن"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _navMetricItem(String title, String subtitle) {
    return Column(
      children: [
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 9)),
      ],
    );
  }

  Widget _buildSpeedometerCenter(Color theme, double glow) {
    return _neonPanel(
      color: theme,
      glow: glow,
      padding: EdgeInsets.zero,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 140,
            child: CustomPaint(
              painter: RoadPerspectivePainter(
                neonColor: theme,
                progress: _roadOffset,
              ),
            ),
          ),
          Positioned(
            bottom: 12,
            child: Image.asset(
              'tiba2.png',
              width: 175,
              height: 105,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Icon(Icons.directions_car, size: 85, color: theme);
              },
            ),
          ),
          Positioned.fill(
            child: CustomPaint(
              painter: SpeedometerDialPainter(
                speed: _currentSpeed,
                themeColor: theme,
                glow: glow,
              ),
            ),
          ),
          Positioned(
            top: 22,
            child: SizedBox(
              width: 44,
              height: 44,
              child: CustomPaint(
                painter: SaipaNeonLogoPainter(color: theme, glow: glow),
              ),
            ),
          ),
          Positioned(
            top: 86,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _currentSpeed.toInt().toString(),
                  style: TextStyle(
                    fontSize: 66,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        color: theme.withOpacity(0.9 * glow),
                        blurRadius: 22 * glow,
                      ),
                    ],
                  ),
                ),
                Text(
                  'KM / H',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                    color: theme.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCarStatusCard(Color theme, double glow) {
    return _neonPanel(
      color: theme,
      glow: glow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("وضعیت سیستم تیبا", style: TextStyle(color: theme, fontSize: 12, fontWeight: FontWeight.bold)),
              Icon(Icons.check_circle_outline, color: theme, size: 16),
            ],
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _carMetricWidget(Icons.local_gas_station, "بنزین", "۶۸٪", theme),
              _carMetricWidget(Icons.speed, "باد لاستیک", "32 PSI", theme),
              _carMetricWidget(Icons.thermostat, "دما", "۸۸°C", theme),
            ],
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _carMetricWidget(IconData icon, String label, String value, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 9)),
      ],
    );
  }

  Widget _buildMusicCard(Color theme, double glow) {
    return _neonPanel(
      color: theme,
      glow: glow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.music_note, color: theme, size: 16),
              const SizedBox(width: 4),
              Text("سیستم صوتی", style: TextStyle(color: theme, fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
          const Spacer(),
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: theme.withOpacity(0.5)),
                  gradient: LinearGradient(
                    colors: [theme.withOpacity(0.3), Colors.black],
                  ),
                ),
                child: Icon(Icons.album, color: theme, size: 28),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_songTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(_artistName,
                        maxLines: 1,
                        style: const TextStyle(color: Colors.white54, fontSize: 10)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: _musicProgress,
            backgroundColor: Colors.white12,
            valueColor: AlwaysStoppedAnimation<Color>(theme),
            minHeight: 3,
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                iconSize: 20,
                icon: const Icon(Icons.skip_previous, color: Colors.white70),
                onPressed: () {},
              ),
              GestureDetector(
                onTap: () => setState(() => _isPlaying = !_isPlaying),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.withOpacity(0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: theme),
                  ),
                  child: Icon(
                    _isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
              IconButton(
                iconSize: 20,
                icon: const Icon(Icons.skip_next, color: Colors.white70),
                onPressed: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomQuickDock(Color theme, double glow) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF070B12).withOpacity(0.9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.withOpacity(0.25 * glow)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _dockButtonWidget(Icons.map, "نقشه", theme, () {}),
          _dockButtonWidget(Icons.radio, "رادیو", theme, () {}),
          _dockButtonWidget(Icons.phone, "تماس", theme, () {}),
          _dockButtonWidget(Icons.apps, "برنامه‌ها", theme, () {}),
          _dockButtonWidget(Icons.tune, "نورپردازی", theme, _openSettingsDialog),
        ],
      ),
    );
  }

  Widget _dockButtonWidget(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

class SaipaNeonLogoPainter extends CustomPainter {
  final Color color;
  final double glow;

  SaipaNeonLogoPainter({required this.color, required this.glow});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width * 0.42;

    final glowPaint = Paint()
      ..color = color.withOpacity(0.7 * glow)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 6 * glow);

    final linePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    Path path = Path();
    for (int i = 0; i < 3; i++) {
      double angle = -math.pi / 2 + (i * 2 * math.pi / 3);
      double tipX = center.dx + r * math.cos(angle);
      double tipY = center.dy + r * math.sin(angle);

      double baseAngle1 = angle + (math.pi * 0.55);
      double baseAngle2 = angle - (math.pi * 0.55);
      double baseR = r * 0.38;

      double b1X = center.dx + baseR * math.cos(baseAngle1);
      double b1Y = center.dy + baseR * math.sin(baseAngle1);
      double b2X = center.dx + baseR * math.cos(baseAngle2);
      double b2Y = center.dy + baseR * math.sin(baseAngle2);

      path.moveTo(tipX, tipY);
      path.lineTo(b1X, b1Y);
      path.lineTo(b2X, b2Y);
      path.close();
    }

    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant SaipaNeonLogoPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.glow != glow;
}

class SpeedometerDialPainter extends CustomPainter {
  final double speed;
  final Color themeColor;
  final double glow;

  SpeedometerDialPainter({
    required this.speed,
    required this.themeColor,
    required this.glow,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.48);
    final radius = size.width * 0.38;

    const startAngle = 135 * (math.pi / 180);
    const sweepAngle = 270 * (math.pi / 180);

    final bgArcPaint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      bgArcPaint,
    );

    double progressRatio = (speed / 240.0).clamp(0.0, 1.0);
    final activeGlowPaint = Paint()
      ..color = themeColor.withOpacity(0.85 * glow)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 8
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 10 * glow);

    final activeLinePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle * progressRatio,
      false,
      activeGlowPaint,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle * progressRatio,
      false,
      activeLinePaint,
    );

    final tickPaint = Paint()..strokeCap = StrokeCap.round;
    for (int i = 0; i <= 24; i++) {
      int tickVal = i * 10;
      double tickFraction = i / 24.0;
      double angle = startAngle + (tickFraction * sweepAngle);
      bool isMajor = i % 2 == 0;

      double outerR = radius - 8;
      double innerR = outerR - (isMajor ? 12 : 6);

      bool isPassed = tickVal <= speed;
      tickPaint.color = isPassed ? themeColor : Colors.white24;
      tickPaint.strokeWidth = isMajor ? 2.2 : 1.2;

      Offset p1 = Offset(center.dx + innerR * math.cos(angle), center.dy + innerR * math.sin(angle));
      Offset p2 = Offset(center.dx + outerR * math.cos(angle), center.dy + outerR * math.sin(angle));
      canvas.drawLine(p1, p2, tickPaint);

      if (isMajor && tickVal % 20 == 0) {
        final textSpan = TextSpan(
          text: '$tickVal',
          style: TextStyle(
            color: isPassed ? Colors.white : Colors.white38,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        );
        final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr);
        tp.layout();
        double numR = innerR - 12;
        Offset numPos = Offset(
          center.dx + numR * math.cos(angle) - (tp.width / 2),
          center.dy + numR * math.sin(angle) - (tp.height / 2),
        );
        tp.paint(canvas, numPos);
      }
    }
  }

  @override
  bool shouldRepaint(covariant SpeedometerDialPainter oldDelegate) =>
      oldDelegate.speed != speed || oldDelegate.themeColor != themeColor || oldDelegate.glow != glow;
}

class RoadPerspectivePainter extends CustomPainter {
  final Color neonColor;
  final double progress;

  RoadPerspectivePainter({required this.neonColor, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final horizonY = 0.0;
    final bottomY = size.height;
    final centerX = size.width / 2;

    final roadPaint = Paint()
      ..color = neonColor.withOpacity(0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawLine(Offset(centerX - 15, horizonY), Offset(centerX - 130, bottomY), roadPaint);
    canvas.drawLine(Offset(centerX + 15, horizonY), Offset(centerX + 130, bottomY), roadPaint);

    for (int i = 0; i < 5; i++) {
      double t = (i / 5.0 + progress) % 1.0;
      double y = horizonY + math.pow(t, 2.2) * (bottomY - horizonY);
      double width = 30 + math.pow(t, 2.2) * 200;

      final stripePaint = Paint()
        ..color = neonColor.withOpacity(t * 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;

      canvas.drawLine(Offset(centerX - width / 2, y), Offset(centerX + width / 2, y), stripePaint);
    }
  }

  @override
  bool shouldRepaint(covariant RoadPerspectivePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.neonColor != neonColor;
}

class NavigationRoadPainter extends CustomPainter {
  final Color themeColor;
  final double roadProgress;

  NavigationRoadPainter({required this.themeColor, required this.roadProgress});

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = const Color(0xFF060B14);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final gridPaint = Paint()
      ..color = themeColor.withOpacity(0.08)
      ..strokeWidth = 1.0;

    for (double x = 0; x < size.width; x += 25) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += 25) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final path = Path();
    path.moveTo(size.width * 0.5, size.height);
    path.quadraticBezierTo(
      size.width * 0.5,
      size.height * 0.45,
      size.width * 0.8,
      size.height * 0.15,
    );

    final routeGlowPaint = Paint()
      ..color = themeColor.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    final routePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawPath(path, routeGlowPaint);
    canvas.drawPath(path, routePaint);
  }

  @override
  bool shouldRepaint(covariant NavigationRoadPainter oldDelegate) =>
      oldDelegate.roadProgress != roadProgress || oldDelegate.themeColor != themeColor;
}
