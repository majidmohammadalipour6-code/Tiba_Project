import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  // سرعت بر اساس کیلومتر بر ساعت
  double _currentSpeed = 0.0;
  String _gpsStatus = "READY (STANDBY)";
  
  // تنظیمات ظاهری (قابل تنظیم از داخل خود برنامه)
  Color _themeColor = const Color(0xFF00E5FF); // فیروزه‌ای نئون
  double _panelOpacity = 0.22;
  double _neonGlow = 1.0;

  // وضعیت موزیک پلیر
  bool _isPlaying = false;
  int _currentTrackIndex = 0;
  final List<String> _playlist = [
    "Jaddeye Shomal - Mix 01",
    "Deep Bass Electro Drive",
    "Persian Chill Trip",
  ];

  void _openSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: AlertDialog(
                backgroundColor: const Color(0xFF0F172A).withOpacity(0.92),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: BorderSide(color: _themeColor.withOpacity(0.5), width: 1.5),
                ),
                title: Row(
                  children: [
                    Icon(Icons.tune_rounded, color: _themeColor),
                    const SizedBox(width: 10),
                    const Text('تنظیمات ظاهر داشبورد', style: TextStyle(color: Colors.white, fontSize: 18)),
                  ],
                ),
                content: SizedBox(
                  width: 420,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("رنگ نور نئون و تم:", style: TextStyle(color: Colors.white70, fontSize: 13)),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _colorChoice(const Color(0xFF00E5FF), setModalState), // Cyan
                          _colorChoice(const Color(0xFF00FF88), setModalState), // Green
                          _colorChoice(const Color(0xFFFF5500), setModalState), // Amber/Orange
                          _colorChoice(const Color(0xFFBD00FF), setModalState), // Purple
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text("شفافیت شیشه (گلس): ${(_panelOpacity * 100).toInt()}%",
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
                      Text("شدت روشنایی نئون: ${(_neonGlow * 100).toInt()}%",
                          style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      Slider(
                        value: _neonGlow,
                        min: 0.4,
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
                    child: Text('تایید و ذخیره', style: TextStyle(color: _themeColor, fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _colorChoice(Color color, StateSetter setModalState) {
    bool isSelected = _themeColor.value == color.value;
    return GestureDetector(
      onTap: () {
        setModalState(() => _themeColor = color);
        setState(() => _themeColor = color);
      },
      child: Container(
        width: 36,
        height: 36,
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
          // پس‌زمینه دارک نئونی
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

          // ۳ ستون اصلی رابط کاربری
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                children: [
                  // ستون چپ: نقشه و موزیک
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

                  // ستون وسط: کیلومترشمار نئونی با قابلیت هولد ۳ ثانیه
                  Expanded(
                    flex: 9,
                    child: _buildSpeedometerWidget(),
                  ),

                  const SizedBox(width: 14),

                  // ستون راست: وضعیت خودرو تیبا ۲
                  Expanded(
                    flex: 7,
                    child: _buildVehicleStatusWidget(),
                  ),
                ],
              ),
            ),
          ),

          // دکمه چرخ‌دنده تنظیمات بالا سمت راست
          Positioned(
            top: 16,
            right: 16,
            child: GestureDetector(
              onTap: _openSettingsDialog,
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
                    child: const Icon(Icons.settings_rounded, color: Colors.white, size: 22),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassCard({required Widget child, EdgeInsetsGeometry? padding}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: padding ?? const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(_panelOpacity),
            borderRadius: BorderRadius.circular(20),
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

  Widget _buildMapWidget() {
    return _buildGlassCard(
      padding: EdgeInsets.zero,
      child: Stack(
        children: [
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
                Icon(Icons.navigation_rounded, color: _themeColor, size: 18),
                const SizedBox(width: 6),
                const Text("LIVE GPS RADAR", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
              ],
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.near_me_rounded, color: _themeColor, size: 36),
                const SizedBox(height: 6),
                Text(
                  "SATELLITE POSITIONING",
                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 9, letterSpacing: 1.4),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildMediaWidget() {
    return _buildGlassCard(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _themeColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.music_note_rounded, color: _themeColor, size: 20),
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
                    const Text("Infotainment Audio", style: TextStyle(color: Colors.white54, fontSize: 10)),
                  ],
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 24),
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
                  child: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 24),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 24),
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

  Widget _buildSpeedometerWidget() {
    return GestureDetector(
      onLongPress: _openSettingsDialog,
      child: _buildGlassCard(
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF00FF88),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _gpsStatus,
                      style: const TextStyle(fontSize: 9, letterSpacing: 1.1, color: Color(0xFF00FF88), fontWeight: FontWeight.bold),
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
                  width: 240,
                  height: 240,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size(240, 240),
                        painter: NeonSpeedGaugePainter(
                          speed: _currentSpeed,
                          maxSpeed: 200,
                          themeColor: _themeColor,
                          glowMultiplier: _neonGlow,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _currentSpeed.toInt().toString(),
                            style: TextStyle(
                              fontSize: 74,
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
                              fontSize: 13,
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

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _FooterInfo(title: "MONITOR", val: "TIBA 2"),
                  _FooterInfo(title: "MAX LIMIT", val: "120"),
                  _FooterInfo(title: "SYSTEM", val: "OK"),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

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
                  fontSize: 12,
                  letterSpacing: 1.1,
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
                  "ONLINE",
                  style: TextStyle(color: _themeColor, fontSize: 9, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildStatusTile(
                  icon: Icons.android_rounded,
                  title: "سیستم‌عامل مانیتور",
                  value: "Android 10 Infotainment",
                ),
                _buildStatusTile(
                  icon: Icons.speed_rounded,
                  title: "واحد سرعت‌سنج",
                  value: "کیلومتر بر ساعت (km/h)",
                ),
                _buildStatusTile(
                  icon: Icons.display_settings_rounded,
                  title: "رابط کاربری",
                  value: "Glassmorphism Cyberpunk",
                ),
                _buildStatusTile(
                  icon: Icons.tune_rounded,
                  title: "دسترسی تنظیمات",
                  value: "چرخ‌دنده / لمس طولانی",
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTile({
    required IconData icon,
    required String title,
    required String value,
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
          Icon(icon, size: 18, color: _themeColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 11, color: Colors.white70)),
                Text(value, style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FooterInfo extends StatelessWidget {
  final String title;
  final String val;
  const _FooterInfo({required this.title, required this.val});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: const TextStyle(fontSize: 8, color: Colors.white38, letterSpacing: 1.1)),
        const SizedBox(height: 2),
        Text(val, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
      ],
    );
  }
}

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

    const startAngle = 2.4;
    const totalSweep = 4.6;

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

    final progress = (speed / maxSpeed).clamp(0.0, 1.0);
    final currentSweep = totalSweep * progress;

    if (currentSweep > 0) {
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

    canvas.drawCircle(center, 40, gridPaint);
    canvas.drawCircle(center, 80, gridPaint);
    canvas.drawCircle(center, 120, gridPaint);

    canvas.drawLine(Offset(0, center.dy), Offset(size.width, center.dy), gridPaint);
    canvas.drawLine(Offset(center.dx, 0), Offset(center.dx, size.height), gridPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
