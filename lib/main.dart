import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const TibaDashboardApp());
}

class TibaDashboardApp extends StatelessWidget {
  const TibaDashboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tiba 2 Cyber HUD',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF030814),
      ),
      home: const DashboardHomeScreen(),
    );
  }
}

class DashboardHomeScreen extends StatefulWidget {
  const DashboardHomeScreen({super.key});

  @override
  State<DashboardHomeScreen> createState() => _DashboardHomeScreenState();
}

class _DashboardHomeScreenState extends State<DashboardHomeScreen> {
  static const platform = MethodChannel('com.tiba2.launcher/intent');

  double _speed = 0.0;
  double _calibrationFactor = 1.0;
  Timer? _clockTimer;
  String _timeStr = "";
  bool _isPlaying = false;
  String _selectedGear = "D";

  @override
  void initState() {
    super.initState();
    _updateTime();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) => _updateTime());
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  void _updateTime() {
    final now = DateTime.now();
    setState(() {
      _timeStr = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
    });
  }

  Future<void> _launchIntent(String action, {String? uri, String? packageName}) async {
    try {
      await platform.invokeMethod('launchIntent', {
        'action': action,
        'uri': uri,
        'package': packageName,
      });
    } catch (_) {}
  }

  void _openGpsCalibration() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          backgroundColor: const Color(0xFF0A1428),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Colors.cyanAccent),
          ),
          title: const Text("کالیبراسیون سرعت و GPS", style: TextStyle(color: Colors.cyanAccent, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "ضریب: ${_calibrationFactor.toStringAsFixed(2)}x",
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Slider(
                value: _calibrationFactor,
                min: 0.7,
                max: 1.3,
                divisions: 24,
                activeColor: Colors.cyanAccent,
                onChanged: (v) {
                  setDlgState(() => _calibrationFactor = v);
                  setState(() => _calibrationFactor = v);
                },
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

  void _showNavPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF081224),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: Colors.cyanAccent, width: 1),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("انتخاب مسیر‌یاب", style: TextStyle(color: Colors.cyanAccent, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.navigation_rounded, color: Colors.greenAccent),
              title: const Text("نشان (Neshan)", style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _launchIntent("android.intent.action.VIEW", packageName: "org.neshan.maps");
              },
            ),
            ListTile(
              leading: const Icon(Icons.map_rounded, color: Colors.cyanAccent),
              title: const Text("بلد (Balad)", style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _launchIntent("android.intent.action.VIEW", packageName: "ir.balad.navigation");
              },
            ),
            ListTile(
              leading: const Icon(Icons.explore_rounded, color: Colors.orangeAccent),
              title: const Text("گوگل مپ (Google Maps)", style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _launchIntent("android.intent.action.VIEW", uri: "geo:0,0?q=");
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF040A18), Color(0xFF01040A)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildTopStatusBar(),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Row(
                    children: [
                      // سایدبار داک سمت چپ
                      _buildLeftSidebar(),
                      const SizedBox(width: 10),
                      // کارت مسیریاب
                      Expanded(flex: 30, child: _buildNavCard()),
                      const SizedBox(width: 10),
                      // ستون وسط (سرعت‌سنج، جاده و تیبا ۲ پشت)
                      Expanded(flex: 38, child: _buildCenterSpeedPanel()),
                      const SizedBox(width: 10),
                      // ستون سمت راست (موزیک و عکس خودرو تیبا ۲)
                      Expanded(flex: 32, child: _buildRightControls()),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // نوار مشکی بالای صفحه
  Widget _buildTopStatusBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt_rounded, color: Colors.cyanAccent, size: 20),
              const SizedBox(width: 10),
              Text(
                _timeStr,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1),
              ),
              const SizedBox(width: 10),
              const Icon(Icons.signal_cellular_alt_rounded, color: Colors.white70, size: 16),
              const SizedBox(width: 4),
              const Text("4G", style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
          Row(
            children: [
              GestureDetector(
                onTap: _openGpsCalibration,
                child: const Row(
                  children: [
                    Icon(Icons.gps_fixed_rounded, color: Colors.cyanAccent, size: 16),
                    SizedBox(width: 4),
                    Text("GPS", style: TextStyle(color: Colors.cyanAccent, fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              const Icon(Icons.wifi_rounded, color: Colors.cyanAccent, size: 18),
              const SizedBox(width: 10),
              const Icon(Icons.bluetooth_rounded, color: Colors.cyanAccent, size: 18),
              const SizedBox(width: 10),
              const Icon(Icons.battery_full_rounded, color: Colors.greenAccent, size: 20),
              const SizedBox(width: 4),
              const Text("100%", style: TextStyle(color: Colors.white70, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  // نوار باریک عمودی آیکون‌ها
  Widget _buildLeftSidebar() {
    return Container(
      width: 54,
      decoration: BoxDecoration(
        color: const Color(0xFF09142A).withOpacity(0.9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.cyanAccent.withOpacity(0.35), width: 1.2),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _sidebarIcon(Icons.grid_view_rounded, () => _launchIntent("android.intent.action.MAIN")),
          _sidebarIcon(Icons.explore_rounded, _showNavPicker),
          _sidebarIcon(Icons.music_note_rounded, () => _launchIntent("android.intent.action.MAIN", packageName: "com.android.fmradio")),
          _sidebarIcon(Icons.dialpad_rounded, () => _launchIntent("android.intent.action.DIAL")),
          _sidebarIcon(Icons.settings_rounded, () => _launchIntent("android.settings.SETTINGS")),
        ],
      ),
    );
  }

  Widget _sidebarIcon(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Icon(icon, color: Colors.cyanAccent, size: 24),
      ),
    );
  }

  // پنل کارت مسیریاب
  Widget _buildNavCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF081329).withOpacity(0.85),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.cyanAccent.withOpacity(0.35), width: 1.2),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.navigation_rounded, color: Colors.cyanAccent, size: 24),
              SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("مسیر مستقیم", style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                    Text("آماده جهت شروع ناوبری", style: TextStyle(color: Colors.white54, fontSize: 10)),
                  ],
                ),
              ),
              Icon(Icons.explore_outlined, color: Colors.redAccent, size: 20),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    color: const Color(0xFF040A1A),
                    child: CustomPaint(painter: PerspectiveRoadPainter()),
                  ),
                  const Center(
                    child: Icon(Icons.navigation_rounded, color: Colors.cyanAccent, size: 40),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D284F),
              foregroundColor: Colors.cyanAccent,
              minimumSize: const Size.fromHeight(40),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: Colors.cyanAccent, width: 1),
              ),
            ),
            onPressed: _showNavPicker,
            icon: const Icon(Icons.near_me_rounded, size: 18),
            label: const Text("شروع مسیریابی", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  // ستون مرکزی (کیلومتر، آرم سایپا و عکس تیبا ۲ پشت)
  Widget _buildCenterSpeedPanel() {
    double displaySpeed = _speed * _calibrationFactor;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF081329).withOpacity(0.85),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.cyanAccent.withOpacity(0.4), width: 1.2),
      ),
      child: Column(
        children: [
          const SizedBox(height: 6),
          // سرعت‌سنج دیجیتال
          SizedBox(
            height: 150,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(200, 150),
                  painter: CurvedSpeedGaugePainter(speed: displaySpeed),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      displaySpeed.toInt().toString(),
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        shadows: [Shadow(color: Colors.cyanAccent, blurRadius: 20)],
                      ),
                    ),
                    const Text("KM / H", style: TextStyle(color: Colors.cyanAccent, fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.change_history_rounded, color: Colors.cyanAccent, size: 14),
                        SizedBox(width: 4),
                        Text("SAIPA", style: TextStyle(color: Colors.cyanAccent, fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          // جاده نئونی و تصویر نمای پشت تیبا ۲
          Expanded(
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                Positioned.fill(
                  child: CustomPaint(painter: PerspectiveRoadPainter()),
                ),
                Positioned(
                  bottom: 8,
                  child: Image.asset(
                    'tiba2_rear.png',
                    height: 80,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(Icons.directions_car_rounded, size: 60, color: Colors.cyanAccent),
                  ),
                ),
              ],
            ),
          ),
          // دنده نئونی P R N D
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: ["P", "R", "N", "D"].map((gear) {
                bool isSelected = gear == _selectedGear;
                return GestureDetector(
                  onTap: () => setState(() => _selectedGear = gear),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.cyanAccent.withOpacity(0.2) : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isSelected ? Colors.cyanAccent : Colors.white24, width: 1.2),
                    ),
                    child: Text(
                      gear,
                      style: TextStyle(
                        color: isSelected ? Colors.cyanAccent : Colors.white60,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ستون سمت راست (کارت موزیک پلیر + کارت خودروی تیبا ۲)
  Widget _buildRightControls() {
    return Column(
      children: [
        // کارت موزیک
        Expanded(
          flex: 5,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF081329).withOpacity(0.85),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.cyanAccent.withOpacity(0.35), width: 1.2),
            ),
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("پخش موسیقی", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.folder_open_rounded, color: Colors.cyanAccent, size: 18),
                      onPressed: () => _launchIntent("android.intent.action.MAIN", packageName: "com.android.fmradio"),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const Spacer(),
                const Center(
                  child: Text("بدون آهنگ انتخابی", style: TextStyle(color: Colors.cyanAccent, fontSize: 13, fontWeight: FontWeight.bold)),
                ),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.skip_previous_rounded, color: Colors.cyanAccent, size: 28),
                      onPressed: () {},
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _isPlaying = !_isPlaying),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.cyanAccent.withOpacity(0.2),
                          border: Border.all(color: Colors.cyanAccent, width: 1.5),
                        ),
                        child: Icon(
                          _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          color: Colors.cyanAccent,
                          size: 26,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.skip_next_rounded, color: Colors.cyanAccent, size: 28),
                      onPressed: () {},
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        // کارت وضعیت خودرو با تصویر تیبا ۲
        Expanded(
          flex: 5,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF081329).withOpacity(0.85),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.cyanAccent.withOpacity(0.35), width: 1.2),
            ),
            padding: const EdgeInsets.all(8),
            child: Stack(
              children: [
                const Positioned(
                  top: 2,
                  right: 4,
                  child: Text("TIBA 2", style: TextStyle(color: Colors.cyanAccent, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                ),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12.0),
                    child: Image.asset(
                      'tiba2.png',
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(Icons.directions_car, size: 50, color: Colors.cyanAccent),
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

// نقاشی زاویه‌دار و دورانی سرعت‌سنج
class CurvedSpeedGaugePainter extends CustomPainter {
  final double speed;
  CurvedSpeedGaugePainter({required this.speed});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.85);
    final radius = size.width * 0.44;

    const startAngle = 140.0 * (pi / 180.0);
    const sweepAngle = 260.0 * (pi / 180.0);

    final trackPaint = Paint()
      ..color = Colors.white.withOpacity(0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      trackPaint,
    );

    double progress = (speed.clamp(0, 240) / 240.0);
    double activeSweep = sweepAngle * progress;

    if (activeSweep > 0) {
      final activePaint = Paint()
        ..shader = const SweepGradient(
          colors: [Colors.blueAccent, Colors.cyanAccent],
        ).createShader(Rect.fromCircle(center: center, radius: radius))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6.0
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        activeSweep,
        false,
        activePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CurvedSpeedGaugePainter oldDelegate) => oldDelegate.speed != speed;
}

// رسم جاده نئونی پرسپکتیو
class PerspectiveRoadPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.cyanAccent.withOpacity(0.3)
      ..strokeWidth = 1.5;

    // خطوط کناری جاده
    canvas.drawLine(Offset(size.width * 0.4, 0), Offset(size.width * 0.1, size.height), paint);
    canvas.drawLine(Offset(size.width * 0.6, 0), Offset(size.width * 0.9, size.height), paint);

    // خطوط مقطع وسط جاده
    final dashPaint = Paint()
      ..color = Colors.cyanAccent.withOpacity(0.5)
      ..strokeWidth = 2.0;

    for (double i = 0.2; i < 1.0; i += 0.2) {
      canvas.drawLine(
        Offset(size.width * 0.5, size.height * (i - 0.05)),
        Offset(size.width * 0.5, size.height * i),
        dashPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
