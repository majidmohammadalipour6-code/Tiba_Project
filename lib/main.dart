import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

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
      title: 'Tiba 2 Cockpit',
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

class _DashboardScreenState extends State<DashboardScreen> {
  // GPS State
  double _currentSpeed = 0.0;
  double _altitude = 0.0;
  String _gpsStatus = "SEARCHING GPS...";
  bool _hasGpsSignal = false;
  StreamSubscription<Position>? _positionStream;

  // Visual Customization States (قابل تغییر در پنل تنظیمات داخل برنامه)
  Color _themeColor = const Color(0xFF00E5FF); // فیروزه‌ای پیش‌فرض
  double _panelOpacity = 0.22;
  double _neonGlow = 1.0;
  bool _showGridBackground = true;

  // Media Player State (شبیه‌ساز UI لانچر)
  bool _isPlaying = false;
  int _currentTrackIndex = 0;
  final List<String> _playlist = [
    "Jaddeye Shomal - Playlist 01",
    "Deep Electro Bass - Drive",
    "Persian Chill Mix",
  ];

  @override
  void initState() {
    super.initState();
    _initGps();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }

  Future<void> _initGps() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) setState(() => _gpsStatus = "GPS IS OFF (TURN ON)");
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) setState(() => _gpsStatus = "GPS PERMISSION DENIED");
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) setState(() => _gpsStatus = "GPS BLOCKED IN SETTINGS");
      return;
    }

    // گوش دادن به داده واقعی ماهواره
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 1,
    );

    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings).listen(
      (Position position) {
        // سرعت به متر بر ثانیه است؛ ضرب در 3.6 به کیلومتر بر ساعت تبدیل می‌شود
        double speedKmh = position.speed * 3.6;
        if (speedKmh < 1.0) speedKmh = 0.0; // حذف لرزش در حالت سکون

        if (mounted) {
          setState(() {
            _currentSpeed = speedKmh;
            _altitude = position.altitude;
            _hasGpsSignal = true;
            _gpsStatus = "GPS CONNECTED (LIVE)";
          });
        }
      },
      onError: (e) {
        if (mounted) {
          setState(() {
            _hasGpsSignal = false;
            _gpsStatus = "GPS WEAK SIGNAL";
          });
        }
      },
    );
  }

  void _openSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: AlertDialog(
                backgroundColor: const Color(0xFF0F172A).withOpacity(0.9),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: BorderSide(color: _themeColor.withOpacity(0.5), width: 1.5),
                ),
                title: Row(
                  children: [
                    Icon(Icons.tune_rounded, color: _themeColor),
                    const SizedBox(width: 10),
                    const Text('تنظیمات ظاهر داشبورد (داخلی)', style: TextStyle(color: Colors.white, fontSize: 18)),
                  ],
                ),
                content: SizedBox(
                  width: 450,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("رنگ نئون و تم اصلی:", style: TextStyle(color: Colors.white70, fontSize: 13)),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildColorChoice(const Color(0xFF00E5FF), setModalState), // Cyan
                          _buildColorChoice(const Color(0xFF00FF88), setModalState), // Neon Green
                          _buildColorChoice(const Color(0xFFFF5500), setModalState), // Orange/Amber
                          _buildColorChoice(const Color(0xFFBD00FF), setModalState), // Purple
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text("شفافیت گلس پنل‌ها: ${(_panelOpacity * 100).toInt()}%",
                          style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      Slider(
                        value: _panelOpacity,
                        min: 0.1,
                        max: 0.5,
                        activeColor: _themeColor,
                        onChanged: (val) {
                          setModalState(() => _panelOpacity = val);
                          setState(() => _panelOpacity = val);
                        },
                      ),
                      Text("شدت درخشش نئون (Glow): ${(_neonGlow * 100).toInt()}%",
                          style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      Slider(
                        value: _neonGlow,
                        min: 0.3,
                        max: 2.0,
                        activeColor: _themeColor,
                        onChanged: (val) {
                          setModalState(() => _neonGlow = val);
                          setState(() => _neonGlow = val);
                        },
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('بستن و ذخیره', style: TextStyle(color: _themeColor, fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildColorChoice(Color color, StateSetter setModalState) {
    bool isSelected = _themeColor.value == color.value;
    return GestureDetector(
      onTap: () {
        setModalState(() => _themeColor = color);
        setState(() => _themeColor = color);
      },
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: isSelected ? Colors.white : Colors.transparent, width: 3),
          boxShadow: [
            if (isSelected) BoxShadow(color: color.withOpacity(0.8), blurRadius: 10, spreadRadius: 2),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // پس‌زمینه سایبرپانک و گرید
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.2),
                  radius: 1.2,
                  colors: [Color(0xFF0F1A30), Color(0xFF050811)],
                ),
              ),
            ),
          ),

          // محتوای اصلی داشبورد (۳ ستون)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                children: [
                  // ستون چپ: نقشه زنده و مدیاپلیر
                  Expanded(
                    flex: 7,
                    child: Column(
                      children: [
                        Expanded(flex: 6, child: _buildMapWidget()),
                        const SizedBox(height: 12),
                        Expanded(flex: 4, child: _buildMediaWidget()),
                      ],
                    ),
                  ),

                  const SizedBox(width: 14),

                  // ستون وسط: کیلومترشمار نئونی GPS
                  Expanded(
                    flex: 9,
                    child: _buildSpeedometerWidget(),
                  ),

                  const SizedBox(width: 14),

                  // ستون راست: پنل وضعیت هوشمند تیبا ۲
                  Expanded(
                    flex: 7,
                    child: _buildVehicleStatusWidget(),
                  ),
                ],
              ),
            ),
          ),

          // دکمه چرخ‌دنده تنظیمات گوشه بالا راست
          Positioned(
            top: 16,
            right: 16,
            child: _buildGlassButton(
              icon: Icons.settings_rounded,
              onTap: _openSettingsDialog,
            ),
          ),
        ],
      ),
    );
  }

  // --- کارت شیشه‌ای گلس‌مورفیسم ---
  Widget _buildGlassCard({required Widget child, EdgeInsetsGeometry? padding}) {
    return ClipRRect(
      borderRadius: circularRadius(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: padding ?? const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(_panelOpacity),
            borderRadius: circularRadius(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.12),
              width: 1.2,
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  BorderRadius circularRadius(double r) => BorderRadius.circular(r);

  // --- ویجت نقشه ---
  Widget _buildMapWidget() {
    return _buildGlassCard(
      padding: EdgeInsets.zero,
      child: Stack(
        children: [
          // بک‌گراند راداری
          Positioned.fill(
            child: CustomPaint(
              painter: RadarMapPainter(themeColor: _themeColor),
            ),
          ),
          Positioned(
            top: 12,
            left: 12,
            child: Row(
              children: [
                Icon(Icons.navigation_rounded, color: _themeColor, size: 20),
                const SizedBox(width: 6),
                const Text("LIVE RADAR & GPS", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              ],
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.my_location_rounded, color: _themeColor, size: 36),
                const SizedBox(height: 6),
                Text(
                  _hasGpsSignal ? "TRACKING ACTIVE" : "ACQUIRING SATELLITES...",
                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 10, letterSpacing: 1.5),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  // --- ویجت مدیا پلیر ---
  Widget _buildMediaWidget() {
    return _buildGlassCard(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _themeColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.music_note_rounded, color: _themeColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_playlist[_currentTrackIndex],
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    const Text("Bluetooth / Local Audio", style: TextStyle(color: Colors.white54, fontSize: 10)),
                  ],
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 26),
                onPressed: () {
                  setState(() {
                    _currentTrackIndex = (_currentTrackIndex - 1 + _playlist.length) % _playlist.length;
                  });
                },
              ),
              GestureDetector(
                onTap: () => setState(() => _isPlaying = !_isPlaying),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _themeColor.withOpacity(0.25),
                    shape: BoxShape.circle,
                    border: Border.all(color: _themeColor, width: 1.5),
                  ),
                  child: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 26),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 26),
                onPressed: () {
                  setState(() {
                    _currentTrackIndex = (_currentTrackIndex + 1) % _playlist.length;
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- ویجت کیلومترشمار نئونی متصل به GPS مانیتور ---
  Widget _buildSpeedometerWidget() {
    return GestureDetector(
      // نگه داشتن ۳ ثانیه برای ورود به تنظیمات
      onLongPress: _openSettingsDialog,
      child: _buildGlassCard(
        child: Column(
          children: [
            // هدر سرعت‌سنج
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _hasGpsSignal ? const Color(0xFF00FF88) : Colors.orangeAccent,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _gpsStatus,
                      style: TextStyle(
                        fontSize: 9,
                        letterSpacing: 1.1,
                        color: _hasGpsSignal ? const Color(0xFF00FF88) : Colors.orangeAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Text(
                  "HOLD TO TUNE",
                  style: TextStyle(fontSize: 9, color: Colors.white.withOpacity(0.3), letterSpacing: 1.0),
                ),
              ],
            ),

            Expanded(
              child: Center(
                child: SizedBox(
                  width: 250,
                  height: 250,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // رسم عقربه و رینگ نئونی
                      CustomPaint(
                        size: const Size(250, 250),
                        painter: NeonSpeedGaugePainter(
                          speed: _currentSpeed,
                          maxSpeed: 200,
                          themeColor: _themeColor,
                          glowMultiplier: _neonGlow,
                        ),
                      ),
                      // عدد دیجیتال سرعت بر اساس جی‌پی‌اس
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _currentSpeed.toInt().toString(),
                            style: TextStyle(
                              fontSize: 78,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -2,
                              shadows: [
                                Shadow(
                                  color: _themeColor.withOpacity(0.8 * _neonGlow),
                                  blurRadius: 20,
                                ),
                              ],
                            ),
                          ),
                          const Text(
                            "KM / H",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Colors.white70,
                              letterSpacing: 3,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // نوار اطلاعات وضعیت حرکت در پایین گیج
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _gaugeFooterItem("ELEVATION", "${_altitude.toInt()} m"),
                  _gaugeFooterItem("LIMIT", "120"),
                  _gaugeFooterItem("SYSTEM", "STABLE"),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _gaugeFooterItem(String title, String val) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: const TextStyle(fontSize: 8, color: Colors.white38, letterSpacing: 1.1)),
        const SizedBox(height: 2),
        Text(val, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
      ],
    );
  }

  // --- ستون راست: کارت وضعیت خودرو (بدون نیاز به سنسور فیک در) ---
  Widget _buildVehicleStatusWidget() {
    return _buildGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "TIBA 2 HATCHBACK",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  letterSpacing: 1.2,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _themeColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _themeColor.withOpacity(0.4)),
                ),
                child: Text(
                  "COCKPIT READY",
                  style: TextStyle(color: _themeColor, fontSize: 9, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // مشخصات واقعی سیستم و حسگرهای مانیتور
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildCarStatusTile(
                  icon: Icons.satellite_alt_rounded,
                  title: "ماهواره جی‌پی‌اس",
                  value: _hasGpsSignal ? "سیگنال فعال" : "در حال رصد",
                  isGood: _hasGpsSignal,
                ),
                _buildCarStatusTile(
                  icon: Icons.android_rounded,
                  title: "سیستم‌عامل مانیتور",
                  value: "Android 10 Infotainment",
                  isGood: true,
                ),
                _buildCarStatusTile(
                  icon: Icons.speed_rounded,
                  title: "حالت کیلومترشمار",
                  value: "سرعت ماهواره‌ای (km/h)",
                  isGood: true,
                ),
                _buildCarStatusTile(
                  icon: Icons.sensors_off_rounded,
                  title: "سنسور درب‌ها و OBD",
                  value: "غیرفعال (بدون سنسور)",
                  isGood: false,
                ),
              ],
            ),
          ),

          // دکمه میانبر ریفرش جی‌پی‌اس در پایین کارت
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _initGps,
              icon: Icon(Icons.refresh_rounded, size: 16, color: _themeColor),
              label: Text("ریست اتصال GPS", style: TextStyle(color: _themeColor, fontSize: 11)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: _themeColor.withOpacity(0.4)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCarStatusTile({
    required IconData icon,
    required String title,
    required String value,
    required bool isGood,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: isGood ? _themeColor : Colors.white38),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 11, color: Colors.white70)),
                Text(value, style: TextStyle(fontSize: 10, color: isGood ? Colors.white : Colors.white38, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isGood ? const Color(0xFF00FF88) : Colors.white24,
            ),
          )
        ],
      ),
    );
  }

  Widget _buildGlassButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }
}

// --- پینتر گیج نئونی دو حلقه‌ای دور سرعت‌سنج ---
class NeonSpeedGaugePainter extends CustomPainter {
  final double speed;
  final double maxSpeed;
  final Color themeColor;
  final double glowMultiplier;

  NeonSpeedGaugePainter({
    required this.speed,
    required this.maxSpeed,
    required this.themeColor,
    required this.glowMultiplier,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 12;

    const startAngle = 2.4; // حدود ساعت ۷
    const totalSweep = 4.6; // تا حدود ساعت ۵

    // رینگ خاکستری زیرین
    final bgPaint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      totalSweep,
      false,
      bgPaint,
    );

    // محاسبه پیشرفت سرعت
    final progress = (speed / maxSpeed).clamp(0.0, 1.0);
    final currentSweep = totalSweep * progress;

    if (currentSweep > 0) {
      // هاله درخشان نئون (Glow)
      final glowPaint = Paint()
        ..color = themeColor.withOpacity(0.4 * glowMultiplier)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 10 * glowMultiplier)
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        currentSweep,
        false,
        glowPaint,
      );

      // خط اصلی نئون
      final activePaint = Paint()
        ..color = themeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        currentSweep,
        false,
        activePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant NeonSpeedGaugePainter oldDelegate) {
    return oldDelegate.speed != speed ||
        oldDelegate.themeColor != themeColor ||
        oldDelegate.glowMultiplier != glowMultiplier;
  }
}

// --- پینتر رادار پس‌زمینه نقشه ---
class RadarMapPainter extends CustomPainter {
  final Color themeColor;
  RadarMapPainter({required this.themeColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final gridPaint = Paint()
      ..color = themeColor.withOpacity(0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // دوایر راداری
    canvas.drawCircle(center, 40, gridPaint);
    canvas.drawCircle(center, 80, gridPaint);
    canvas.drawCircle(center, 120, gridPaint);

    // خطوط متقاطع
    canvas.drawLine(Offset(0, center.dy), Offset(size.width, center.dy), gridPaint);
    canvas.drawLine(Offset(center.dx, 0), Offset(center.dx, size.height), gridPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDele
