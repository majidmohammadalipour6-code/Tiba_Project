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
  // سرعت بر حسب کیلومتر بر ساعت
  double _currentSpeed = 0.0;
  final String _gpsStatus = "GPS LOCKED (ACTIVE)";

  // تنظیمات نئون و تم
  Color _themeColor = const Color(0xFF00E5FF); // آبی یخی اسپرت
  double _panelOpacity = 0.25;

  // انتخاب اپلیکیشن مسیریاب
  String _selectedNavApp = "نشان (Neshan)";
  final List<String> _navApps = [
    "نشان (Neshan)",
    "بلد (Balad)",
    "Google Maps",
    "Waze"
  ];

  // موزیک پلیر داخلی
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
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: AlertDialog(
                backgroundColor: const Color(0xFF0B132B).withOpacity(0.95),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: _themeColor.withOpacity(0.6), width: 1.5),
                ),
                title: Row(
                  children: [
                    Icon(Icons.tune_rounded, color: _themeColor),
                    const SizedBox(width: 10),
                    const Text('تنظیمات اختصاصی تیبا ۲',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
                content: SizedBox(
                  width: 420,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("رنگ نئون و نشانگرها:", style: TextStyle(color: Colors.white70, fontSize: 13)),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _colorChoice(const Color(0xFF00E5FF), setModalState),
                            _colorChoice(const Color(0xFF00FF88), setModalState),
                            _colorChoice(const Color(0xFFFF9900), setModalState),
                            _colorChoice(const Color(0xFFBD00FF), setModalState),
                            _colorChoice(const Color(0xFFFF2A55), setModalState),
                          ],
                        ),
                        const SizedBox(height: 18),
                        const Text("مسیریاب پیش‌فرض سمت چپ:", style: TextStyle(color: Colors.white70, fontSize: 13)),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          value: _selectedNavApp,
                          dropdownColor: const Color(0xFF0F172A),
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.06),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: _themeColor.withOpacity(0.3)),
                            ),
                          ),
                          items: _navApps.map((app) => DropdownMenuItem(value: app, child: Text(app))).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setModalState(() => _selectedNavApp = val);
                              setState(() => _selectedNavApp = val);
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        Text("شفافیت پنل شیشه‌ای: ${(_panelOpacity * 100).toInt()}%",
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
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('تایید و بازگشت',
                        style: TextStyle(color: _themeColor, fontSize: 15, fontWeight: FontWeight.bold)),
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
    final isSelected = _themeColor.value == color.value;
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
            if (isSelected) BoxShadow(color: color.withOpacity(0.8), blurRadius: 12, spreadRadius: 2),
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
          // پس‌زمینه اسپرت
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.1),
                  radius: 1.3,
                  colors: [Color(0xFF0F1E36), Color(0xFF030712)],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        // ستون چپ: مسیریاب + موزیک پلیر
                        Expanded(
                          flex: 7,
                          child: Column(
                            children: [
                              Expanded(flex: 5, child: _buildNavigationWidget()),
                              const SizedBox(height: 8),
                              Expanded(flex: 5, child: _buildMusicPlayerWidget()),
                            ],
                          ),
                        ),

                        const SizedBox(width: 10),

                        // ستون وسط: کیلومترشمار مدرن HUD
                        Expanded(
                          flex: 9,
                          child: _buildSpeedometerWidget(),
                        ),

                        const SizedBox(width: 10),

                        // ستون راست: وضعیت خودروی تیبا ۲
                        Expanded(
                          flex: 7,
                          child: _buildVehicleStatusWidget(),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // داک پایین
                  _buildBottomDock(),
                ],
              ),
            ),
          ),

          // دکمه تنظیمات بالا سمت راست
          Positioned(
            top: 12,
            right: 12,
            child: GestureDetector(
              onTap: _openSettingsDialog,
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _themeColor.withOpacity(0.5)),
                ),
                child: Icon(Icons.settings_rounded, color: _themeColor, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassCard({required Widget child, EdgeInsetsGeometry? padding}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: padding ?? const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(_panelOpacity),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _themeColor.withOpacity(0.25), width: 1.2),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildNavigationWidget() {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('در حال اجرای $_selectedNavApp...'),
            duration: const Duration(seconds: 1),
          ),
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
              top: 8,
              left: 10,
              child: Row(
                children: [
                  Icon(Icons.explore_rounded, color: _themeColor, size: 16),
                  const SizedBox(width: 6),
                  Text(_selectedNavApp,
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _themeColor.withOpacity(0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: _themeColor, width: 1.5),
                    ),
                    child: Icon(Icons.navigation_rounded, color: _themeColor, size: 26),
                  ),
                  const SizedBox(height: 6),
                  const Text("لمس برای باز کردن نقشه",
                      style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMusicPlayerWidget() {
    final track = _playlist[_currentTrackIndex];
    return _buildGlassCard(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: _themeColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _themeColor.withOpacity(0.5)),
                ),
                child: Icon(Icons.music_note_rounded, color: _themeColor, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(track["title"]!,
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis),
                    Text(track["artist"]!,
                        style: const TextStyle(color: Colors.white54, fontSize: 9)),
                  ],
                ),
              ),
            ],
          ),
          LinearProgressIndicator(
            value: 0.4,
            backgroundColor: Colors.white10,
            color: _themeColor,
            minHeight: 3,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 20),
                onPressed: () {
                  setState(() {
                    _currentTrackIndex = (_currentTrackIndex - 1 + _playlist.length) % _playlist.length;
                  });
                },
              ),
              GestureDetector(
                onTap: () => setState(() => _isPlaying = !_isPlaying),
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: _themeColor.withOpacity(0.3),
                    shape: BoxShape.circle,
                    border: Border.all(color: _themeColor, width: 1.5),
                  ),
                  child: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 20),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 20),
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
                    Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF00FF88))),
                    const SizedBox(width: 6),
                    Text(_gpsStatus,
                        style: const TextStyle(fontSize: 8, color: Color(0xFF00FF88), fontWeight: FontWeight.bold, letterSpacing: 0.8)),
                  ],
                ),
                Text("تنظیمات: لمس ۳ ثانیه",
                    style: TextStyle(fontSize: 8, color: Colors.white.withOpacity(0.4))),
              ],
            ),
            Expanded(
              child: Center(
                child: SizedBox(
                  width: 210,
                  height: 210,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size(210, 210),
                        painter: SafeCyberClusterPainter(
                          speed: _currentSpeed,
                          maxSpeed: 220,
                          themeColor: _themeColor,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _currentSpeed.toInt().toString(),
                            style: TextStyle(
                              fontSize: 66,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -2,
                              shadows: [
                                Shadow(color: _themeColor.withOpacity(0.9), blurRadius: 20),
                              ],
                            ),
                          ),
                          const Text(
                            "KM / H",
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.white70, letterSpacing: 2.5),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.4),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white10),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _FooterInfo(title: "VEHICLE", val: "TIBA 2"),
                  _FooterInfo(title: "DRIVE MODE", val: "SPORT+"),
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
              const Text("TIBA 2 HATCHBACK",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1.0)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _themeColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _themeColor.withOpacity(0.5)),
                ),
                child: Text("HATCHBACK", style: TextStyle(color: _themeColor, fontSize: 8, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(
            flex: 6,
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, 0.3),
                  radius: 0.85,
                  colors: [_themeColor.withOpacity(0.2), const Color(0xFF030712)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.directions_car_filled_rounded, size: 68, color: Colors.white.withOpacity(0.92)),
                    const SizedBox(height: 4),
                    Container(
                      height: 3,
                      width: 90,
                      decoration: BoxDecoration(
                        color: _themeColor,
                        borderRadius: BorderRadius.circular(3),
                        boxShadow: [
                          BoxShadow(color: _themeColor, blurRadius: 12, spreadRadius: 2),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            flex: 4,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildMiniStatusRow(Icons.bolt_rounded, "باتری و دینام", "14.2 V"),
                _buildMiniStatusRow(Icons.thermostat_rounded, "دمای آب موتور", "88°C"),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStatusRow(IconData icon, String label, String val) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 13, color: _themeColor),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 9, color: Colors.white70)),
          const Spacer(),
          Text(val, style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildBottomDock() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
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
    );
  }

  Widget _dockIcon(IconData icon, String label) {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('میانبر $label باز شد'), duration: const Duration(milliseconds: 700)),
        );
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: _themeColor, size: 18),
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
        Text(title, style: const TextStyle(fontSize: 7, color: Colors.white38, letterSpacing: 0.8)),
        Text(val, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white)),
      ],
    );
  }
}

// رسم کلاستر ضد کرش و سازگار با زاویه صفر
class SafeCyberClusterPainter extends CustomPainter {
  final double speed;
  final double maxSpeed;
  final Color themeColor;

  SafeCyberClusterPainter({
    required this.speed,
    required this.maxSpeed,
    required this.themeColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 12;

    const startAngle = 2.3;
    const totalSweep = 4.8;

    // رینگ پس‌زمینه
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

    // محاسبه پیشرفت با شرط ایمن بودن زاویه
    final progress = (speed / maxSpeed).clamp(0.0, 1.0);
    final currentSweep = totalSweep * progress;

    if (currentSweep > 0.01) {
      final activePaint = Paint()
        ..color = themeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
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
  bool shouldRepaint(covariant SafeCyberClusterPainter oldDelegate) {
    return oldDelegate.speed != speed || oldDelegate.themeColor != themeColor;
  }
}

class RadarMapPainter extends CustomPainter {
  final Color themeColor;
  RadarMapPainter({required this.themeColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final gridPaint = Paint()
      ..color = themeColor.withOpacity(0.07)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawCircle(center, 40, gridPaint);
    canvas.drawCircle(center, 80, gridPaint);
    canvas.drawLine(Offset(0, center.dy), Offset(size.width, center.dy), gridPaint);
    canvas.drawLine(Offset(center.dx, 0), Offset(center.dx, size.height), gridPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
