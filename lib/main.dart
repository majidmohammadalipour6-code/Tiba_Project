import 'dart:math' as math;
import 'package:flutter/material.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TibaLauncherApp());
}

class TibaLauncherApp extends StatelessWidget {
  const TibaLauncherApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Tiba Cockpit OS',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF080B11),
      ),
      home: const CockpitDashboard(),
    );
  }
}

class CockpitDashboard extends StatefulWidget {
  const CockpitDashboard({Key? key}) : super(key: key);

  @override
  State<CockpitDashboard> createState() => _CockpitDashboardState();
}

class _CockpitDashboardState extends State<CockpitDashboard> {
  int currentSpeed = 78;
  bool isPlaying = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070A10),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
          child: Column(
            children: [
              // نوار بالایی: وضعیت سیستم، ساعت و وضعیت خودرو
              _buildTopBar(),
              const SizedBox(height: 10),

              // بخش اصلی داشبورد: ۳ بخش (نقشه، سرعت‌سنج، پلیر و سنسورها)
              Expanded(
                child: Row(
                  children: [
                    // ۱. ستون چپ: پنل ناوبری و نقشه مدرن
                    Expanded(
                      flex: 11,
                      child: _buildNavigationPanel(),
                    ),
                    const SizedBox(width: 12),

                    // ۲. ستون وسط: آمپر سرعت‌سنج و دور موتور دیجیتال نئونی
                    Expanded(
                      flex: 12,
                      child: _buildClusterGauge(),
                    ),
                    const SizedBox(width: 12),

                    // ۳. ستون راست: موزیک پلیر و کارت وضعیت سنسورهای تیبا
                    Expanded(
                      flex: 11,
                      child: _buildRightControlsPanel(),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),
              // نوار پایینی: لانچر برنامه‌ها (Apps Dock)
              _buildBottomAppDock(),
            ],
          ),
        ),
      ),
    );
  }

  // --- نوار وضعیت بالا ---
  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF111726).withOpacity(0.65),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: const [
              Icon(Icons.directions_car, color: Color(0xFF00E5FF), size: 18),
              SizedBox(width: 8),
              Text("TIBA COCKPIT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.5)),
            ],
          ),
          Row(
            children: const [
              Icon(Icons.bluetooth, color: Colors.blueAccent, size: 16),
              SizedBox(width: 12),
              Icon(Icons.wifi, color: Colors.greenAccent, size: 16),
              SizedBox(width: 12),
              Text("24°C", style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
              SizedBox(width: 12),
              Text("19:42", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  // --- پنل ناوبری و نقشه شبیه‌سازی شده شب ---
  Widget _buildNavigationPanel() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D1322),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.6), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // شبیه‌ساز پس‌زمینه گرافیکی نقشه
          CustomPaint(
            size: Size.infinite,
            painter: MapGraphicPainter(),
          ),
          // پنل جهت‌یابی روی نقشه
          Positioned(
            top: 14,
            left: 14,
            right: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF090E1A).withOpacity(0.85),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.4)),
              ),
              child: Row(
                children: const [
                  Icon(Icons.turn_right_rounded, color: Color(0xFF00E5FF), size: 28),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("در ۲۰۰ متر آینده به راست بپیچید", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                        Text("بزرگراه شهید همت", style: TextStyle(color: Colors.white54, fontSize: 10)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text("GPS CONNECTED", style: TextStyle(color: Colors.greenAccent, fontSize: 9, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }

  // --- آمپر مرکزی دیجیتال سرعت‌سنج نئونی ---
  Widget _buildClusterGauge() {
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          colors: [const Color(0xFF142036).withOpacity(0.8), const Color(0xFF0A0F1A)],
          radius: 0.85,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(color: const Color(0xFF00E5FF).withOpacity(0.08), blurRadius: 20, spreadRadius: 1),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // رسم دایره نئونی درجه‌بندی
          SizedBox(
            width: 220,
            height: 220,
            child: CustomPaint(
              painter: GaugeDialPainter(speed: currentSpeed),
            ),
          ),
          // نمایشگر عدد سرعت
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("SPEED", style: TextStyle(color: Colors.white38, fontSize: 11, letterSpacing: 2)),
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    "$currentSpeed",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 68,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
              const Text("KM / H", style: TextStyle(color: Color(0xFF00E5FF), fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 2)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text("GEAR  D", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- ستون سمت راست: پلیر و سنسور خودرو ---
  Widget _buildRightControlsPanel() {
    return Column(
      children: [
        // کارت شیشه‌ای موزیک پلیر
        Expanded(
          flex: 5,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF101726).withOpacity(0.85),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        gradient: const LinearGradient(colors: [Colors.purpleAccent, Colors.blueAccent]),
                      ),
                      child: const Icon(Icons.music_note, color: Colors.white, size: 26),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text("Night Ride (Synthwave)", overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                          SizedBox(height: 2),
                          Text("Cyber Horizon", style: TextStyle(color: Colors.white54, fontSize: 10)),
                        ],
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.skip_previous_rounded, color: Colors.white70, size: 24),
                      onPressed: () {},
                    ),
                    GestureDetector(
                      onTap: () => setState(() => isPlaying = !isPlaying),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF00E5FF),
                        ),
                        child: Icon(isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.black, size: 20),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.skip_next_rounded, color: Colors.white70, size: 24),
                      onPressed: () {},
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),

        // کارت وضعیت سنسورها (بنزین، باتری و باد لاستیک)
        Expanded(
          flex: 5,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF101726).withOpacity(0.85),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildCarStatusItem(Icons.local_gas_station, "سوخت", "75%", Colors.amberAccent),
                _buildCarStatusItem(Icons.battery_charging_full, "باتری", "14.2V", Colors.greenAccent),
                _buildCarStatusItem(Icons.speed, "باد تایر", "32 PSI", const Color(0xFF00E5FF)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCarStatusItem(IconData icon, String title, String val, Color color) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 6),
        Text(val, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 2),
        Text(title, style: const TextStyle(color: Colors.white38, fontSize: 10)),
      ],
    );
  }

  // --- نوار کلیدها و اپلیکیشن‌ها در پایین ---
  Widget _buildBottomAppDock() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1422).withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildDockIcon(Icons.navigation_outlined, "مسیریاب", true),
          _buildDockIcon(Icons.radio_rounded, "رادیو", false),
          _buildDockIcon(Icons.phone, "تماس", false),
          _buildDockIcon(Icons.apps_rounded, "برنامه‌ها", false),
          _buildDockIcon(Icons.settings, "تنظیمات", false),
        ],
      ),
    );
  }

  Widget _buildDockIcon(IconData icon, String label, bool active) {
    return InkWell(
      onTap: () {},
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: active ? const Color(0xFF00E5FF) : Colors.white60, size: 22),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: active ? const Color(0xFF00E5FF) : Colors.white38, fontSize: 9)),
        ],
      ),
    );
  }
}

// رسم نئونی آمپر سرعت‌سنج
class GaugeDialPainter extends CustomPainter {
  final int speed;
  GaugeDialPainter({required this.speed});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 14;

    // خط زمینه آمپر
    final bgPaint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi * 0.75,
      math.pi * 1.5,
      false,
      bgPaint,
    );

    // خط پیشرفت نئونی روشن
    final progressPaint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    double sweepAngle = (speed / 200) * (math.pi * 1.5);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi * 0.75,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// رسم خطوط فرضی نقشه شبیه‌سازی شده
class MapGraphicPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paintRoad = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..strokeWidth = 18
      ..style = PaintingStyle.stroke;

    final pathRoad = Path();
    pathRoad.moveTo(0, size.height * 0.3);
    pathRoad.quadraticBezierTo(size.width * 0.5, size.height * 0.4, size.width, size.height * 0.8);
    canvas.drawPath(pathRoad, paintRoad);

    // مسیر مسیریابی روشن نئونی (Cyan GPS Route)
    final paintRoute = Paint()
      ..color = const Color(0xFF00E5FF)
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke;

    final pathRoute = Path();
    pathRoute.moveTo(size.width * 0.2, size.height);
    pathRoute.quadraticBezierTo(size.width * 0.4, size.height * 0.5, size.width * 0.8, size.height * 0.2);
    canvas.drawPath(pathRoute, paintRoute);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
