import 'dart:async';
import 'dart:math' as math;
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
      title: 'Tiba 2 Launcher',
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

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  static const MethodChannel _platform =
      MethodChannel('com.tiba.launcher/methods');
  static const EventChannel _speedEvent =
      EventChannel('com.tiba.launcher/speed');

  double _speed = 0.0;
  double _calibrationFactor = 1.0;
  String _selectedNavApp = 'نشان';
  StreamSubscription? _speedSubscription;

  late AnimationController _roadAnimController;

  @override
  void initState() {
    super.initState();
    _initSpeedStream();
    _roadAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  void _initSpeedStream() {
    try {
      _speedSubscription = _speedEvent
          .receiveBroadcastStream()
          .listen((dynamic event) {
        if (event is num) {
          setState(() {
            _speed = (event.toDouble() * _calibrationFactor).clamp(0.0, 160.0);
            _updateRoadSpeed();
          });
        }
      }, onError: (dynamic error) {
        debugPrint('Speed error: $error');
      });
    } catch (e) {
      debugPrint('Channel setup error: $e');
    }
  }

  void _updateRoadSpeed() {
    int durationMs = (1200 - (_speed * 6.5)).clamp(180, 1200).toInt();
    _roadAnimController.duration = Duration(milliseconds: durationMs);
    if (!_roadAnimController.isAnimating) {
      _roadAnimController.repeat();
    }
  }

  @override
  void dispose() {
    _speedSubscription?.cancel();
    _roadAnimController.dispose();
    super.dispose();
  }

  Future<void> _invokeNative(String method, [Map<String, dynamic>? args]) async {
    try {
      await _platform.invokeMethod(method, args ?? <String, dynamic>{});
    } on PlatformException catch (e) {
      debugPrint("Native invoke error: ${e.message}");
    }
  }

  void _showCalibrationDialog() {
    showDialog(
      context: context,
      builder: (context) {
        double tempFactor = _calibrationFactor;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF101728),
              title: const Text('کالیبراسیون و GPS',
                  style: TextStyle(color: Colors.cyanAccent)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'ضریب کالیبراسیون: ${tempFactor.toStringAsFixed(2)}x',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  Slider(
                    value: tempFactor,
                    min: 0.7,
                    max: 1.3,
                    divisions: 12,
                    activeColor: Colors.cyanAccent,
                    onChanged: (val) {
                      setDialogState(() => tempFactor = val);
                      setState(() => _calibrationFactor = val);
                    },
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.cyan.withOpacity(0.2),
                      side: const BorderSide(color: Colors.cyanAccent),
                    ),
                    onPressed: () {
                      _invokeNative('openLocationSettings');
                    },
                    icon: const Icon(Icons.location_on, color: Colors.cyanAccent),
                    label: const Text('تنظیمات موقعیت مکانی مانیتور',
                        style: TextStyle(color: Colors.white)),
                  )
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('بستن',
                      style: TextStyle(color: Colors.cyanAccent)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showNavAppSelector() {
    final apps = ['نشان', 'بلد', 'گوگل مپ', 'ویز'];
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF101728),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('انتخاب اپلیکیشن مسیریاب پیش‌فرض',
                  style: TextStyle(
                      color: Colors.cyanAccent,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              const Divider(color: Colors.cyanAccent),
              ...apps.map((app) => ListTile(
                    title: Text(app,
                        style: const TextStyle(color: Colors.white)),
                    trailing: _selectedNavApp == app
                        ? const Icon(Icons.check, color: Colors.cyanAccent)
                        : null,
                    onTap: () {
                      setState(() => _selectedNavApp = app);
                      Navigator.pop(context);
                    },
                  )),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final dockWidth = (size.width * 0.08).clamp(65.0, 85.0);

    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            // ۱. سایدبار داک سمت چپ (ضد کشیدگی با AspectRatio قفل‌شده)
            Container(
              width: dockWidth,
              decoration: BoxDecoration(
                color: const Color(0xFF0B111E).withOpacity(0.95),
                border: Border(
                  right: BorderSide(
                    color: Colors.cyanAccent.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildDockIconButton(
                    icon: Icons.settings_rounded,
                    tooltip: 'تنظیمات',
                    onTap: () => _invokeNative('openSettings'),
                  ),
                  _buildDockIconButton(
                    icon: Icons.navigation_rounded,
                    tooltip: 'مسیریاب',
                    onTap: () => _invokeNative('openNav', {'app': _selectedNavApp}),
                  ),
                  _buildDockIconButton(
                    icon: Icons.radio_rounded,
                    tooltip: 'رادیو',
                    onTap: () => _invokeNative('openRadio'),
                  ),
                  _buildDockIconButton(
                    icon: Icons.phone_in_talk_rounded,
                    tooltip: 'تماس',
                    onTap: () => _invokeNative('openPhone'),
                  ),
                  _buildDockIconButton(
                    icon: Icons.apps_rounded,
                    tooltip: 'برنامه‌ها',
                    onTap: () => _invokeNative('openApps'),
                  ),
                ],
              ),
            ),

            // ۲. صفحه اصلی (داشبورد ۳ ستونه)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Row(
                  children: [
                    // کارت ناوبری و ساعت سمت چپ
                    Expanded(
                      flex: 3,
                      child: _buildLeftCard(),
                    ),
                    const SizedBox(width: 10),

                    // ستون مرکزی: کیلومترشمار نیم‌دایره نئونی + جاده ۳ بعدی + نمای پشت تیبا
                    Expanded(
                      flex: 4,
                      child: _buildCenterGaugeRoad(),
                    ),
                    const SizedBox(width: 10),

                    // کارت موزیک و تصویر خودرو تیبا ۲ سمت راست
                    Expanded(
                      flex: 3,
                      child: _buildRightCard(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ویجت دکمه‌های داک با نسبت ابعاد دقیق ۱:۱
  Widget _buildDockIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return AspectRatio(
      aspectRatio: 1.0,
      child: Padding(
        padding: const EdgeInsets.all(6.0),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.cyanAccent.withOpacity(0.2),
                  width: 1.2,
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.cyanAccent.withOpacity(0.15),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Center(
                child: Icon(
                  icon,
                  color: Colors.cyanAccent,
                  size: 26,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // پنل سمت چپ
  Widget _buildLeftCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withOpacity(0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.cyanAccent.withOpacity(0.25),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: _showNavAppSelector,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.cyanAccent.withOpacity(0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.arrow_drop_down, color: Colors.cyanAccent, size: 16),
                        Text(_selectedNavApp,
                            style: const TextStyle(color: Colors.cyanAccent, fontSize: 11)),
                      ],
                    ),
                  ),
                ),
                StreamBuilder(
                  stream: Stream.periodic(const Duration(seconds: 1)),
                  builder: (context, snapshot) {
                    final now = DateTime.now();
                    final timeStr =
                        "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
                    return Text(
                      timeStr,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => _invokeNative('openNav', {'app': _selectedNavApp}),
              child: Container(
                margin: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.black45,
                  border: Border.all(color: Colors.white10),
                ),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.map_outlined, color: Colors.cyanAccent, size: 48),
                      SizedBox(height: 8),
                      Text('لمس جهت باز شدن نقشه',
                          style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // پنل مرکزی: کیلومتر نیم‌دایره نئونی واقعی (۱۰ تا ۱۳۰) + هاله نوری + جاده ۳ بعدی
  Widget _buildCenterGaugeRoad() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0B101D).withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.cyanAccent.withOpacity(0.3)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // لایه ۱: جاده پرسپکتیو ۳ بعدی در نیمه پایین
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 150,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
              child: AnimatedBuilder(
                animation: _roadAnimController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: RealisticCyberRoadPainter(
                      progress: _roadAnimController.value,
                    ),
                  );
                },
              ),
            ),
          ),

          // لایه ۲: نمای پشت تیبا ۲ مستقر در مرکز جاده
          Positioned(
            bottom: 22,
            child: Image.asset(
              'tiba2_rear.png',
              height: 72,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(Icons.directions_car,
                    color: Colors.cyanAccent, size: 60);
              },
            ),
          ),

          // لایه ۳: نشان سایپا با افکت نئونی زیر سرعت‌سنج
          Positioned(
            top: 138,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.cyanAccent.withOpacity(0.4)),
              ),
              child: const Text(
                'SAIPA',
                style: TextStyle(
                  color: Colors.cyanAccent,
                  fontSize: 10,
                  letterSpacing: 3,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),

          // لایه ۴: سرعت‌سنج نیم‌دایره نئونی (۱۰ تا ۱۳۰) با هاله نوری درخشان
          Positioned(
            top: 10,
            left: 0,
            right: 0,
            child: SizedBox(
              height: 140,
              child: CustomPaint(
                painter: SemiCircleSpeedometerPainter(speed: _speed),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // عدد سرعت با Glow نئونی عمیق
                        Text(
                          _speed.toInt().toString(),
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'monospace',
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                color: Colors.cyanAccent.withOpacity(0.9),
                                blurRadius: 18,
                              ),
                              Shadow(
                                color: Colors.cyanAccent.withOpacity(0.6),
                                blurRadius: 36,
                              ),
                              const Shadow(
                                color: Colors.blueAccent,
                                blurRadius: 50,
                              ),
                            ],
                          ),
                        ),
                        const Text(
                          'KM/H',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                            color: Colors.cyanAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // دکمه کالیبراسیون و وضعیت GPS در گوشه بالا
          Positioned(
            top: 8,
            left: 8,
            child: IconButton(
              icon: const Icon(Icons.satellite_alt_rounded,
                  color: Colors.cyanAccent, size: 20),
              onPressed: _showCalibrationDialog,
            ),
          ),

          // وضعیت دنده‌های خودرو P R N D نئونی
          Positioned(
            bottom: 4,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildGearText('P', false),
                _buildGearText('R', false),
                _buildGearText('N', false),
                _buildGearText('D', true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGearText(String gear, bool active) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Text(
        gear,
        style: TextStyle(
          color: active ? Colors.cyanAccent : Colors.white24,
          fontSize: 13,
          fontWeight: FontWeight.bold,
          shadows: active
              ? const [
                  Shadow(
                    color: Colors.cyanAccent,
                    blurRadius: 10,
                  )
                ]
              : null,
        ),
      ),
    );
  }

  // پنل سمت راست (موزیک + تصویر تیبا ۲)
  Widget _buildRightCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withOpacity(0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.cyanAccent.withOpacity(0.25),
        ),
      ),
      child: Column(
        children: [
          // کنترل موزیک پلیر
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: const Icon(Icons.skip_previous_rounded,
                      color: Colors.cyanAccent, size: 26),
                  onPressed: () => _invokeNative('musicPrev'),
                ),
                IconButton(
                  icon: const Icon(Icons.play_circle_fill_rounded,
                      color: Colors.cyanAccent, size: 36),
                  onPressed: () => _invokeNative('musicPlayPause'),
                ),
                IconButton(
                  icon: const Icon(Icons.skip_next_rounded,
                      color: Colors.cyanAccent, size: 26),
                  onPressed: () => _invokeNative('musicNext'),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          // تصویر اصلی تیبا ۲
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Image.asset(
                'tiba2.png',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Center(
                    child: Icon(Icons.car_rental,
                        color: Colors.cyanAccent, size: 50),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// نقاش سرعت‌سنج نیم‌دایره نئونی با اعداد ۱۰ تا ۱۳۰
// ---------------------------------------------------------------------------
class SemiCircleSpeedometerPainter extends CustomPainter {
  final double speed;

  SemiCircleSpeedometerPainter({required this.speed});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.95);
    final radius = math.min(size.width * 0.42, 110.0);

    const startAngle = math.pi;
    const sweepAngle = math.pi;

    // کمان پس‌زمینه
    final bgPaint = Paint()
      ..color = Colors.white12
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      bgPaint,
    );

    // کمان پیشرفت سرعت به رنگ نئون
    final progress = (speed / 130.0).clamp(0.0, 1.0);
    final activePaint = Paint()
      ..color = Colors.cyanAccent
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 3);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle * progress,
      false,
      activePaint,
    );

    // تیک‌ها و اعداد ۱۰ تا ۱۳۰ دور کیلومتر
    const totalDivisions = 13;
    for (int i = 0; i <= totalDivisions; i++) {
      final angle = startAngle + (sweepAngle * (i / totalDivisions));
      final isMajor = i % 2 != 0 || i == 0 || i == totalDivisions;
      final tickLength = isMajor ? 9.0 : 5.0;

      final p1 = Offset(
        center.dx + (radius - 4) * math.cos(angle),
        center.dy + (radius - 4) * math.sin(angle),
      );
      final p2 = Offset(
        center.dx + (radius - 4 - tickLength) * math.cos(angle),
        center.dy + (radius - 4 - tickLength) * math.sin(angle),
      );

      final tickPaint = Paint()
        ..color = (i / totalDivisions <= progress)
            ? Colors.cyanAccent
            : Colors.white38
        ..strokeWidth = isMajor ? 2.0 : 1.0;

      canvas.drawLine(p1, p2, tickPaint);

      // رسم اعداد ۱۰، ۲۰، ۳۰ ... ۱۳۰
      if (i > 0) {
        final textRadius = radius - 18;
        final textOffset = Offset(
          center.dx + textRadius * math.cos(angle),
          center.dy + textRadius * math.sin(angle),
        );

        final textSpan = TextSpan(
          text: '${i * 10}',
          style: TextStyle(
            color: (i / totalDivisions <= progress)
                ? Colors.cyanAccent
                : Colors.white54,
            fontSize: 9,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
          ),
        );
        final tp = TextPainter(
          text: textSpan,
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
        )..layout();

        tp.paint(
          canvas,
          Offset(textOffset.dx - (tp.width / 2), textOffset.dy - (tp.height / 2)),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant SemiCircleSpeedometerPainter oldDelegate) {
    return oldDelegate.speed != speed;
  }
}

// ---------------------------------------------------------------------------
// نقاش جاده نئونی طبیعی با پرسپکتیو ۳ بعدی
// ---------------------------------------------------------------------------
class RealisticCyberRoadPainter extends CustomPainter {
  final double progress;

  RealisticCyberRoadPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final horizonY = h * 0.1;
    final topRoadW = w * 0.18;
    final bottomRoadW = w * 0.95;

    // سطح آسفالت گرادیانی
    final roadPath = Path()
      ..moveTo(w / 2 - topRoadW / 2, horizonY)
      ..lineTo(w / 2 + topRoadW / 2, horizonY)
      ..lineTo(w / 2 + bottomRoadW / 2, h)
      ..lineTo(w / 2 - bottomRoadW / 2, h)
      ..close();

    final roadGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.black.withOpacity(0.1),
        const Color(0xFF030D1A).withOpacity(0.8),
      ],
    );

    canvas.drawPath(
      roadPath,
      Paint()
        ..shader = roadGradient.createShader(Rect.fromLTWH(0, 0, w, h))
        ..style = PaintingStyle.fill,
    );

    // خطوط مرزی کناری
    final borderPaint = Paint()
      ..color = Colors.cyanAccent.withOpacity(0.6)
      ..strokeWidth = 2.5
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4);

    canvas.drawLine(
      Offset(w / 2 - topRoadW / 2, horizonY),
      Offset(w / 2 - bottomRoadW / 2, h),
      borderPaint,
    );
    canvas.drawLine(
      Offset(w / 2 + topRoadW / 2, horizonY),
      Offset(w / 2 + bottomRoadW / 2, h),
      borderPaint,
    );

    // خطوط منقطع وسط جاده
    const dashCount = 6;
    for (int i = 0; i < dashCount; i++) {
      double t = (i / dashCount + progress) % 1.0;
      double perspectiveT = math.pow(t, 2.2).toDouble();

      double y = horizonY + (h - horizonY) * perspectiveT;
      double dashH = 4 + (18 * perspectiveT);
      double dashW = 1.5 + (3.5 * perspectiveT);
      double alpha = (0.2 + (0.8 * perspectiveT)).clamp(0.0, 1.0);

      final dashPaint = Paint()
        ..color = Colors.cyanAccent.withOpacity(alpha)
        ..strokeWidth = dashW
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 2);

      canvas.drawLine(
        Offset(w / 2, y),
        Offset(w / 2, math.min(y + dashH, h)),
        dashPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant RealisticCyberRoadPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
