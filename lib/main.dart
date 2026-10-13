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
        scaffoldBackgroundColor: const Color(0xFF070A10),
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
  int currentSpeed = 74;
  bool isPlaying = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070A10),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          child: Column(
            children: [
              // نوار بالایی سیستم خودرو
              _buildTopBar(),
              const SizedBox(height: 8),

              // سه ستون اصلی داشبورد دقیقاً مشابه عکس
              Expanded(
                child: Row(
                  children: [
                    // ۱. ستون چپ: نقشه کوچک‌تر + دکمه‌های لانچر گوشه نقشه
                    Expanded(
                      flex: 10,
                      child: _buildNavigationPanel(),
                    ),
                    const SizedBox(width: 10),

                    // ۲. ستون وسط: سرعت‌سنج و دور موتور دایره‌ای دقیقاً مثل عکس
                    Expanded(
                      flex: 13,
                      child: _buildClusterGauge(),
                    ),
                    const SizedBox(width: 10),

                    // ۳. ستون راست: موزیک پلیر + وضعیت خودرو با طرح تیبا ۲
                    Expanded(
                      flex: 10,
                      child: _buildRightControlsPanel(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- نوار بالایی ---
  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1320).withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: const [
              Text("10:42", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              SizedBox(width: 10),
              Text("4G LTE", style: TextStyle(color: Colors.white54, fontSize: 11)),
            ],
          ),
          Row(
            children: const [
              Icon(Icons.bluetooth, color: Color(0xFF00E5FF), size: 14),
              SizedBox(width: 8),
              Icon(Icons.wifi, color: Colors.greenAccent, size: 14),
              SizedBox(width: 12),
              Text("TIBA 2 COCKPIT", style: TextStyle(color: Colors.white70, fontSize: 11, letterSpacing: 1)),
            ],
          ),
        ],
      ),
    );
  }

  // --- ستون چپ: نقشه و مسیر ---
  Widget _buildNavigationPanel() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0B101D),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          CustomPaint(
            size: Size.infinite,
            painter: MapGraphicPainter(),
          ),
          // کادر راهنمای مسیر بالا
          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF070B16).withOpacity(0.9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.4)),
              ),
              child: Row(
                children: const [
                  Icon(Icons.turn_right, color: Color(0xFF00E5FF), size: 22),
                  SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("0.5 mi -", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        Text("Route 101", style: TextStyle(color: Colors.white54, fontSize: 9)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // آیکون‌های برنامه‌ها در گوشه سمت چپ (مشابه کارپلی توی عکس)
          Positioned(
            bottom: 10,
            left: 8,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: const [
                  Icon(Icons.map, color: Colors.redAccent, size: 16),
                  SizedBox(height: 6),
                  Icon(Icons.music_note, color: Colors.greenAccent, size: 16),
                  SizedBox(height: 6),
                  Icon(Icons.phone, color: Colors.blueAccent, size: 16),
                  SizedBox(height: 6),
                  Icon(Icons.apps, color: Colors.amberAccent, size: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- ستون وسط: سرعت‌سنج دو دایره‌ای (نارنجی RPM و آبی Speed) دقیقاً مثل عکس ---
  Widget _buildClusterGauge() {
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          colors: [const Color(0xFF131D31), const Color(0xFF070B16)],
          radius: 0.85,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(color: const Color(0xFF00E5FF).withOpacity(0.06), blurRadius: 15),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // رسم خطوط و اعداد دو حلقه (RPM نارنجی و Speed آبی)
          SizedBox(
            width: 210,
            height: 210,
            child: CustomPaint(
              painter: DualGaugePainter(speed: currentSpeed),
            ),
          ),
          // عدد مرکزی سرعت
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Text(
                "$currentSpeed",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 62,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace',
                ),
              ),
              const Text("MPH", style: TextStyle(color: Color(0xFF00E5FF), fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 2)),
              const SizedBox(height: 6),
              const Text("RPM  x1000", style: TextStyle(color: Colors.orangeAccent, fontSize: 9, letterSpacing: 1)),
            ],
          ),
        ],
      ),
    );
  }

  // --- ستون راست: موزیک پلیر و وضعیت ماشین (تیبا ۲) ---
  Widget _buildRightControlsPanel() {
    return Column(
      children: [
        // موزیک پلیر (Now Playing)
        Expanded(
          flex: 5,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF0B101D),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text("Now Playing", style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
                    Icon(Icons.music_note, color: Colors.amberAccent, size: 14),
                  ],
                ),
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        gradient: const LinearGradient(colors: [Colors.deepOrange, Colors.purpleAccent]),
                      ),
                      child: const Icon(Icons.album, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text("Track Info", overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                          SizedBox(height: 2),
                          Text("Traclc", style: TextStyle(color: Colors.white54, fontSize: 9)),
                        ],
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    const Icon(Icons.skip_previous, color: Colors.white70, size: 20),
                    GestureDetector(
                      onTap: () => setState(() => isPlaying = !isPlaying),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF00E5FF),
                        ),
                        child: Icon(isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.black, size: 16),
                      ),
                    ),
                    const Icon(Icons.skip_next, color: Colors.white70, size: 20),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),

        // وضعیت خودرو (Car Status) با شماتیک تیبا ۲ هاچ‌بک
        Expanded(
          flex: 5,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF0B101D),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Car Status", style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
                Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // شبیه‌سازی گرافیکی بدنه خودرو هاچ‌بک (تیبا ۲)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00E5FF).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.directions_car, color: Color(0xFF00E5FF), size: 28),
                            SizedBox(width: 6),
                            Text("TIBA 2", style: TextStyle(color: Color(0xFF00E5FF), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text("Fuel: 78%", style: TextStyle(color: Colors.greenAccent, fontSize: 9)),
                    Text("Doors: OK", style: TextStyle(color: Colors.white54, fontSize: 9)),
                    Text("Tires: Normal", style: TextStyle(color: Colors.white54, fontSize: 9)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// رسم کننده دو دایره سرعت (آبی) و دور موتور (نارنجی) دقیقا مثل عکس ارسالی
class DualGaugePainter extends CustomPainter {
  final int speed;
  DualGaugePainter({required this.speed});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    
    // حلقه بیرونی دور موتور (RPM - نارنجی)
    final rpmRadius = size.width / 2 - 10;
    final rpmPaint = Paint()
      ..color = Colors.orangeAccent.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: rpmRadius),
      math.pi * 0.75,
      math.pi * 1.5 * 0.75, // تا ۷۵ درصد دور موتور
      false,
      rpmPaint,
    );

    // خط زمینه حلقه داخلی سرعت
    final speedBgPaint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    final speedRadius = size.width / 2 - 24;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: speedRadius),
      math.pi * 0.75,
      math.pi * 1.5,
      false,
      speedBgPaint,
    );

    // حلقه نئونی پیشرفت سرعت (آبی فیروزه‌ای)
    final speedProgressPaint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    double sweepAngle = (speed / 160) * (math.pi * 1.5);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: speedRadius),
      math.pi * 0.75,
      sweepAngle,
      false,
      speedProgressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// نقشه شبیه‌سازی‌شده مدرن شب
class MapGraphicPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paintRoad = Paint()
      ..color = Colors.white.withOpacity(0.04)
      ..strokeWidth = 14
      ..style = PaintingStyle.stroke;

    final pathRoad = Path();
    pathRoad.moveTo(0, size.height * 0.4);
    pathRoad.quadraticBezierTo(size.width * 0.6, size.height * 0.2, size.width, size.height * 0.7);
    canvas.drawPath(pathRoad, paintRoad);

    final paintRoute = Paint()
      ..color = const Color(0xFF00E5FF)
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke;

    final pathRoute = Path();
    pathRoute.moveTo(size.width * 0.3, size.height);
    pathRoute.quadraticBezierTo(size.width * 0.5, size.height * 0.6, size.width * 0.8, size.height * 0.2);
    canvas.drawPath(pathRoute, paintRoute);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
