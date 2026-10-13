import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
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
      title: 'Tiba 2 Cockpit Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF040711),
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
  // سرعت مانیتور GPS (کیلومتر بر ساعت)
  double _currentSpeed = 0.0;
  String _gpsStatus = "GPS LOCKED (ACTIVE)";

  // تنظیمات نئون و تم
  Color _themeColor = const Color(0xFF00E5FF); // آبی یخی اسپرت
  double _panelOpacity = 0.25;
  double _neonGlow = 1.3;

  // انتخاب اپلیکیشن مسیریاب
  String _selectedNavApp = "Neshan";
  final List<String> _navApps = ["Neshan", "Balad", "Google Maps", "Waze"];

  // موزیک پلیر اختصاصی داخلی
  bool _isPlaying = false;
  int _currentTrackIndex = 0;
  final List<Map<String, String>> _playlist = [
    {"title": "Deep Bass Drive", "artist": "Persian Night Club"},
    {"title": "Jaddeye Shomal Track", "artist": "Electronic Chill Mix"},
    {"title": "Tehran Midnight Cruise", "artist": "Cyber Speed FX"},
  ];

  void _openSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: AlertDialog(
                backgroundColor: const Color(0xFF0B132B).withOpacity(0.95),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: BorderSide(color: _themeColor.withOpacity(0.6), width: 1.5),
                ),
                title: Row(
                  children: [
                    Icon(Icons.tune_rounded, color: _themeColor),
                    const SizedBox(width: 10),
                    const Text('تنظیمات اختصاصی تیبا ۲', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                  ],
                ),
                content: SizedBox(
                  width: 440,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("پالت نورپردازی نئون کیلومتر:", style: TextStyle(color: Colors.white70, fontSize: 13)),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _colorChoice(const Color(0xFF00E5FF), setModalState), // آبی یخی
                            _colorChoice(const Color(0xFF00FF88), setModalState), // سبز لیمویی
                            _colorChoice(const Color(0xFFFF9900), setModalState), // کهربایی ریسینگ
                            _colorChoice(const Color(0xFFBD00FF), setModalState), // بنفش سایبرپانک
                            _colorChoice(const Color(0xFFFF2A55), setModalState), // قرمز آتشین
                          ],
                        ),
                        const SizedBox(height: 20),
                        const Text("انتخاب اپلیکیشن مسیریاب:", style: TextStyle(color: Colors.white70, fontSize: 13)),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: _selectedNavApp,
                          dropdownColor: const Color(0xFF0F172A),
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.06),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _themeColor.withOpacity(0.3))),
                          ),
                          items: _navApps.map((app) => DropdownMenuItem(value: app, child: Text(app))).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setModalState(() => _selectedNavApp = val);
                              setState(() => _selectedNavApp = val);
                            }
                          },
                        ),
                        const SizedBox(height: 20),
                        Text("شفافیت پنل شیشه‌ای: ${(_panelOpacity * 100).toInt()}%", style: const TextStyle(color: Colors.white70, fontSize: 13)),
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
                        Text("شدت درخشش هاله نئون: ${(_neonGlow * 100).toInt()}%", style: const TextStyle(color: Colors.white70, fontSize: 13)),
                        Slider(
                          value: _neonGlow,
                          min: 0.5,
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
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('ذخیره و خروج', style: TextStyle(color: _themeColor, fontSize: 16, fontWeight: FontWeight.bold)),
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
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: isSelected ? Colors.white : Colors.transparent, width: 3),
          boxShadow: [
            if (isSelected) BoxShadow(color: color.withOpacity(0.85), blurRadius: 14, spreadRadius: 2),
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
          // پس‌زمینه عمیق فیبر کربن و نایت ریسینگ
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.1),
                  radius: 1.35,
                  colors: [Color(0xFF0F1E36), Color(0xFF030712)],
                ),
              ),
            ),
          ),

          // ۳ ستون اصلی + داک کنترل
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        // ستون ۱ (سمت چپ): مسیریاب انتخابی + موزیک پلیر داخلی
                        Expanded(
                          flex: 7,
                          child: Column(
                            children: [
                              Expanded(flex: 5, child: _buildNavigationWidget()),
                              const SizedBox(height: 10),
                              Expanded(flex: 5, child: _buildMusicPlayerWidget()),
                            ],
                          ),
                        ),

                        const SizedBox(width: 12),

                        // ستون ۲ (وسط): کیلومترشمار مدرن خارجی (HUD Digital Cluster)
                        Expanded(
                          flex: 9,
                          child: _buildSpeedometerWidget(),
                        ),

                        const SizedBox(width: 12),

                        // ستون ۳ (سمت راست): عکس سه‌بعدی تیبا ۲ + اطلاعات وضعیت
                        Expanded(
                          flex: 7,
                          child: _buildVehicleStatusWidget(),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // ردیف میانبرهای سریع پایین (Dock)
                  _buildBottomDock(),
                ],
              ),
            ),
          ),

          // آیکون چرخ‌دنده تنظیمات بالا
          Positioned(
            top: 14,
            right: 14,
            child: GestureDetector(
              onTap: _openSettingsDialog,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _themeColor.withOpacity(0.5)),
                    ),
                    child: Icon(Icons.settings_rounded, color: _themeColor, size: 22),
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
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: padding ?? const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(_panelOpacity),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _themeColor.withOpacity(0.28),
              width: 1.2,
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  // ستون چپ: ویجت ناوبری
  Widget _buildNavigationWidget() {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('در حال اتصال به مسیر یاب $_selectedNavApp...'), duration: const Duration(seconds: 2)),
        );
      },
      child: _buildGlassCard(
        padding: EdgeInsets.zero,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: RadarMapPainter(themeColor: _themeColor),
              ),
            ),
            Positioned(
              top: 10,
              left: 12,
              child: Row(
                children: [
                  Icon(Icons.explore_rounded, color: _themeColor, size: 18),
                  const SizedBox(width: 6),
                  Text("NAV: $_selectedNavApp", style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                ],
              ),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _themeColor.withOpacity(0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: _themeColor, width: 1.5),
                    ),
                    child: Icon(Icons.navigation_rounded, color: _themeColor, size: 28),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "لمس جهت باز کردن $_selectedNavApp",
                    style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // موزیک پلیر اختصاصی داخلی
  Widget _buildMusicPlayerWidget() {
    final track = _playlist[_currentTrackIndex];
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
                  color: _themeColor.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _themeColor.withOpacity(0.5)),
                ),
                child: Icon(Icons.music_note_rounded, color: _themeColor, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(track["title"]!, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(track["artist"]!, style: const TextStyle(color: Colors.white54, fontSize: 10)),
                  ],
                ),
              ),
            ],
          ),
          LinearProgressIndicator(
            value: 0.45,
            backgroundColor: Colors.white10,
            color: _themeColor,
            minHeight: 3,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 22),
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
                    color: _themeColor.withOpacity(0.35),
                    shape: BoxShape.circle,
                    border: Border.all(color: _themeColor, width: 1.5),
                  ),
                  child: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 22),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 22),
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

  // کیلومترشمار مدرن HUD با دو حلقه نئونی
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
                    Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF00FF88))),
                    const SizedBox(width: 6),
                    Text(_gpsStatus, style: const TextStyle(fontSize: 9, letterSpacing: 1.0, color: Color(0xFF00FF88), fontWeight: FontWeight.bold)),
                  ],
                ),
                Text("HOLD FOR SETTINGS", style: TextStyle(fontSize: 8, color: Colors.white.withOpacity(0.4), letterSpacing: 1.0)),
              ],
            ),

            Expanded(
              child: Center(
                child: SizedBox(
                  width: 230,
                  height: 230,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size(230, 230),
                        painter: CyberClusterGaugePainter(
                          speed: _currentSpeed,
                          maxSpeed: 220,
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
                                Shadow(color: _themeColor.withOpacity(0.9 * _neonGlow), blurRadius: 24),
                              ],
                            ),
                          ),
                          const Text(
                            "KM / H",
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.white70, letterSpacing: 3),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _FooterInfo(title: "VEHICLE", val: "TIBA 2"),
                  _FooterInfo(title: "DRIVE MODE", val: "SPORT+"),
                  _FooterInfo(title: "SENSORS", val: "OK"),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  // پنل سه‌بعدی تیبا ۲
  Widget _buildVehicleStatusWidget() {
    return _buildGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("TIBA 2 HATCHBACK", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1.1)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: _themeColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _themeColor.withOpacity(0.5)),
                ),
                child: Text("EDITION 2026", style: TextStyle(color: _themeColor, fontSize: 9, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // نمایش خودروی تیبا ۲ سه‌بعدی
          Expanded(
            flex: 6,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // خودرو با سایه‌های نئونی و رفلکس نور زیر بدنه
                  Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0, 0.4),
                        radius: 0.9,
                        colors: [
                          _themeColor.withOpacity(0.25),
                          const Color(0xFF030712),
                        ],
                      ),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.directions_car_filled_rounded, size: 76, color: Colors.white.withOpacity(0.9)),
                          const SizedBox(height: 4),
                          Container(
                            height: 4,
                            width: 110,
                            decoration: BoxDecoration(
                              color: _themeColor,
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: [
                                BoxShadow(color: _themeColor, blurRadius: 16, spreadRadius: 3),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
                      child: const Text("Saipa Tiba 2 - Hatchback", style: TextStyle(color: Colors.white70, fontSize: 8)),
                    ),
                  )
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),

          Expanded(
            flex: 4,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildMiniStatusRow(Icons.bolt_rounded, "باتری و دینام", "14.2 V (شارژ کامل)"),
                _buildMiniStatusRow(Icons.thermostat_rounded, "دمای آب موتور", "88°C (بهینه)"),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStatusRow(IconData icon, String label, String val) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: _themeColor),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.white70)),
          const Spacer(),
          Text(val, style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // ردیف داک میانبرها در پایین
  Widget _buildBottomDock() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _themeColor.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _dockIcon(Icons.radio_rounded, "رادیو"),
              _dockIcon(Icons.music_note_rounded, "موزیک"),
              _dockIcon(Icons.navigation_rounded, "مسیریاب"),
              _dockIcon(Icons.bluetooth_audio_rounded, "بلوتوث"),
              _dockIcon(Icons.settings_suggest_rounded, "تنظیمات"),
              _dockIcon(Icons.apps_rounded, "برنامه‌ها"),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dockIcon(IconData icon, String label) {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('میانبر: $label'), duration: const Duration(milliseconds: 900)),
        );
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: _themeColor, size: 20),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 8, color: Colors.white70)),
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
        Text(title, style: const TextStyle(fontSize: 8, color: Colors.white38, letterSpacing: 1.0)),
        const SizedBox(height: 1),
        Text(val, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
      ],
    );
  }
}

// رسم کلاستر مدرن دیجیتال کیلومترشمار
class CyberClusterGaugePainter extends CustomPainter {
  final double speed;
  final double maxSpeed;
  final Color themeColor;
  final double glowMultiplier;

  CyberClusterGaugePainter({
    required this.speed,
    required this.maxSpeed,
    required this.themeColor,
    required this.glowMultiplier,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 14;

    const startAngle = 2.3;
    const totalSweep = 4.8;

    final bgPaint = Paint()
      ..color = Colors.white.withOpacity(0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, totalSweep, false, bgPaint);

    final progress = (speed / maxSpeed).clamp(0.0, 1.0);
    final currentSweep = totalSweep * progress;

    if (currentSweep > 0) {
      final glowPaint = Paint()
        ..color = themeColor.withOpacity(0.5 * glowMultiplier)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 16
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 12 * glowMultiplier)
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, currentSweep, false, glowPaint);

      final activePaint = Paint()
        ..color = themeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, currentSweep, false, activePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CyberClusterGaugePainter oldDelegate) {
    return oldDelegate.speed != speed || oldDelegate.themeColor != themeColor || oldDelegate.glowMultiplier != glowMultiplier;
  }
}

class RadarMapPainter extends CustomPainter {
  final Color themeColor;
  RadarMapPainter({required this.themeColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final gridPaint = Paint()
      ..color = themeColor.withOpacity(0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawCircle(center, 45, gridPaint);
    canvas.drawCircle(center, 90, gridPaint);
    canvas.drawCircle(center, 135, gridPaint);

    canvas.drawLine(Offset(0, center.dy), Offset(size.width, center.dy), gridPaint);
    canvas.drawLine(Offset(center.dx, 0), Offset(center.dx, size.height), gridPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
