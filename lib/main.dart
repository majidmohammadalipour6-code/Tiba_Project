import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
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

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  // سرعت و انیمیشن
  double _currentSpeed = 0.0;
  double _targetSpeed = 0.0;
  StreamSubscription<Position>? _gpsSubscription;

  // وضعیت و زمان
  late Timer _clockTimer;
  late Timer _roadAnimTimer;
  String _timeString = "";
  String _dateString = "";
  double _roadOffset = 0.0;

  // وضعیت موزیک و سیستم
  bool _isPlaying = true;
  String _songTitle = "Shadmehr - Ghoroor";
  String _artistName = "Cyber Wave Mix";
  double _musicProgress = 0.42;

  // شخصی‌سازی نئون (ذخیره در SharedPreferences)
  Color _neonThemeColor = const Color(0xFF00E5FF);
  double _neonGlowFactor = 1.0;

  final List<Color> _availableColors = const [
    Color(0xFF00E5FF), // فیروزه‌ای سایبری
    Color(0xFF0077FF), // آبی نئونی غلیظ
    Color(0xFFFF0055), // سرخ / صورتی سایبرپانک
    Color(0xFF00FF66), // سبز نئونی ماتریسی
    Color(0xFFFFB300), // کهربایی گرم
    Color(0xFF9D00FF), // بنفش نئون
  ];

  @override
  void initState superInit() {
    super.initState();
    _loadSettings();
    _updateTime();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) => _updateTime());

    // تایمر حرکت خطوط جاده زیر خودرو و نقشه
    _roadAnimTimer = Timer.periodic(const Duration(milliseconds: 33), (_) {
      if (mounted) {
        setState(() {
          double speedFactor = _currentSpeed > 5 ? (_currentSpeed / 40.0) : 0.8;
          _roadOffset = (_roadOffset + (0.02 * speedFactor)) % 1.0;
        });
      }
    });

    _initGps();
  }

  @override
  void initState() {
    superInit();
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
    if (colorVal != null) {
      _neonThemeColor = Color(colorVal);
    }
    if (glowVal != null) {
      _neonGlowFactor = glowVal;
    }
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

  void _updateTime() {
    final now = DateTime.now();
    setState(() {
      _timeString = DateFormat('HH:mm').format(now);
      _dateString = DateFormat('EEE, d MMM').format(now);
    });
  }

  Future<void> _initGps() async {
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
    ).listen((Position position) {
      double rawSpeed = position.speed; // متر بر ثانیه
      if (rawSpeed < 0 || rawSpeed.isNaN) rawSpeed = 0.0;
      double kmh = rawSpeed * 3.6;
      setState(() {
        _targetSpeed = kmh.clamp(0.0, 240.0);
        _currentSpeed = _targetSpeed;
      });
    });
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
                  const Text('انتخاب طیف رنگ نئونی:', style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    children: _availableColors.map((c) {
                      bool isSel = c.value == selectedColor.value;
                      return GestureDetector(
                        onTap: () => setDialogState(() => selectedColor = c),
                        child: Container(
                          width: 42,
                          height: 42,
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
                      const Text('شدت روشنایی (Glow):', style: TextStyle(color: Colors.white70)),
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
            colors: [
              Color(0xFF0A1526),
              Color(0xFF04070D),
              Color(0xFF010306),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // نوار بالایی هدر
              _buildTopBar(theme, glow),

              // سه ستون اصلی HUD داشبورد
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
                  child: Row(
                    children: [
                      // ستون سمت چپ: مسیریاب سه‌بعدی نئونی
                      Expanded(
                        flex: 31,
                        child: _buildNavigationCard(theme, glow),
                      ),
                      const SizedBox(width: 14),

                      // ستون مرکزی: سرعت‌شمار دایره‌ای با سایپا و تیبا روی جاده
                      Expanded(
                        flex: 38,
                        child: _buildSpeedometerCenter(theme, glow),
                      ),
                      const SizedBox(width: 14),

                      // ستون سمت راست: وضعیت خودرو و پلیر موزیک
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

              // نوار اپلیکیشن‌های پایین
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
          // ساعت و تاریخ نئونی
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
              Text(
                _dateString,
                style: const TextStyle(fontSize: 13, color: Colors.white60),
              ),
            ],
          ),

          // نام تیبا و آیکون وضعیت‌ها
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
        border: Border.all(
          color: color.withOpacity(0.35 * glow),
          width: 1.5,
        ),
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

  // ۱. پنل مسیریاب زنده نئونی
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
                  Text(
                    "مسیریاب زنده",
                    style: TextStyle(color: theme, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
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

          // جاده نئون سه‌بعدی مسیریابی
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
            children: const [
              _NavMetric(title: "۸ دقیقه", subtitle: "تا مقصد"),
              _NavMetric(title: "۴.۲ km", subtitle: "فاصله باقی‌مانده"),
              _NavMetric(title: "۱۹:۴۵", subtitle: "زمان رسیدن"),
            ],
          ),
        ],
      ),
    );
  }

  // ۲. سرعت‌شمار بزرگ نئون + آرم سایپا + تیبا ۲ روی جاده
  Widget _buildSpeedometerCenter(Color theme, double glow) {
    return _neonPanel(
      color: theme,
      glow: glow,
      padding: EdgeInsets.zero,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // خطوط جاده پرسپکتیو در نیمه پایینی
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

          // خودروی واقعی تیبا ۲ روی جاده
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

          // صفحه مدرج دایره‌ای سرعت‌شمار
          Positioned.fill(
            child: CustomPaint(
              painter: SpeedometerDialPainter(
                speed: _currentSpeed,
                themeColor: theme,
                glow: glow,
              ),
            ),
          ),

          // آرم نئونی شرکت سایپا در بالای سرعت‌شمار
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

          // عدد بزرگ سرعت در مرکز
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

  // ۳. وضعیت فنی خودرو
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
              _CarMetricItem(icon: Icons.local_gas_station, label: "بنزین", value: "۶۸٪", color: theme),
              _CarMetricItem(icon: Icons.speed, label: "باد لاستیک", value: "32 PSI", color: theme),
              _CarMetricItem(icon: Icons.thermostat, label: "دما", value: "۸۸°C", color: theme),
            ],
          ),
          const Spacer(),
        ],
      ),
    );
  }

  // ۴. پخش‌کننده موسیقی نئونی
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

  // ۵. نوار دسترسی سریع پایین
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
          _DockButton(icon: Icons.map, label: "نقشه", color: theme, onTap: () {}),
          _DockButton(icon: Icons.radio, label: "رادیو", color: theme, onTap: () {}),
          _DockButton(icon: Icons.phone, label: "تماس", color: theme, onTap: () {}),
          _DockButton(icon: Icons.apps, label: "برنامه‌ها", color: theme, onTap: () {}),
          _DockButton(icon: Icons.tune, label: "نورپردازی", color: theme, onTap: _openSettingsDialog),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------
// نقاش آرم نئونی شرکت سایپا
// -------------------------------------------------------------
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

// -------------------------------------------------------------
// نقاش صفحه مدرج سرعت‌شمار دایره‌ای (۰ تا ۲۴۰)
// -------------------------------------------------------------
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

    // کمان پس‌زمینه
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

    // کمان نئونی متناسب با سرعت
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

    // خطوط تیک و شماره‌گذاری‌ها (۰ تا ۲۴۰)
    final tickPaint = Paint()..strokeCap = StrokeCap.round;
    for (int i = 0; 
