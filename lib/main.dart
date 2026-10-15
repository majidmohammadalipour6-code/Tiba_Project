import 'dart:async';
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
      home: const CyberDashboard(),
    );
  }
}

class CyberDashboard extends StatefulWidget {
  const CyberDashboard({super.key});

  @override
  State<CyberDashboard> createState() => _CyberDashboardState();
}

class _CyberDashboardState extends State<CyberDashboard>
    with SingleTickerProviderStateMixin {
  static const platform = MethodChannel('com.tiba2.launcher/actions');

  double _speed = 0.0;
  double _calibration = 1.0;
  String _selectedGear = 'D';
  String _selectedNavName = 'نشان (Neshan)';
  String _selectedNavPackage = 'org.neshan.maps.and.navi';
  bool _isPlaying = false;
  late Timer _timer;
  String _timeStr = '';
  String _dateStr = '';

  // کنترلر انیمیشن جاده در حال حرکت
  late AnimationController _roadAnimCtrl;

  @override
  void initState() {
    super.initState();
    _updateClock();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateClock());

    // لوپ بی‌نهایت انیمیشن جاده نئونی
    _roadAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();

    // هندل سرعت از سمت پلتفرم
    platform.setMethodCallHandler((call) async {
      if (call.method == 'onSpeed') {
        final val = (call.arguments as num).toDouble();
        setState(() {
          _speed = val * _calibration;
          // تغییر پویای سرعت جاده بر اساس کیلومتر
          int dur = 900;
          if (_speed > 10) {
            dur = (30000 / _speed).clamp(180, 800).toInt();
          }
          _roadAnimCtrl.duration = Duration(milliseconds: dur);
          if (!_roadAnimCtrl.isAnimating) _roadAnimCtrl.repeat();
        });
      }
    });

    // درخواست دسترسی به موقعیت مکانی (GPS) در زمان اجرای برنامه
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _execute('request_location');
    });
  }

  void _updateClock() {
    final now = DateTime.now();
    setState(() {
      _timeStr =
          "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
      _dateStr =
          "${now.year}/${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}";
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _roadAnimCtrl.dispose();
    super.dispose();
  }

  void _execute(String action, {String? pkg}) {
    platform.invokeMethod('open', {'action': action, 'pkg': pkg ?? ''});
  }

  void _openNavSelector() {
    final apps = [
      {'name': 'نشان (Neshan)', 'pkg': 'org.neshan.maps.and.navi'},
      {'name': 'بلد (Balad)', 'pkg': 'ir.balad.navigation'},
      {'name': 'Google Maps', 'pkg': 'com.google.android.apps.maps'},
      {'name': 'Waze', 'pkg': 'com.waze'},
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'انتخاب اپلیکیشن مسیریاب',
              style: TextStyle(
                color: Colors.cyanAccent,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(color: Colors.white24, height: 24),
            ...apps.map(
              (a) => ListTile(
                leading: const Icon(Icons.navigation, color: Colors.cyanAccent),
                title: Text(a['name']!, style: const TextStyle(color: Colors.white)),
                trailing: _selectedNavPackage == a['pkg']
                    ? const Icon(Icons.check_circle, color: Colors.cyanAccent)
                    : null,
                onTap: () {
                  setState(() {
                    _selectedNavName = a['name']!;
                    _selectedNavPackage = a['pkg']!;
                  });
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openGpsDialog() {
    double temp = _calibration;
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          title: const Text(
            'تنظیم و کالیبراسیون GPS',
            style: TextStyle(color: Colors.cyanAccent),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'ضریب اصلاح سرعت: ${temp.toStringAsFixed(2)}x',
                style: const TextStyle(color: Colors.white70),
              ),
              Slider(
                value: temp,
                min: 0.8,
                max: 1.2,
                divisions: 40,
                activeColor: Colors.cyanAccent,
                onChanged: (v) => setSt(() => temp = v),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E293B),
                ),
                icon: const Icon(Icons.location_on, color: Colors.cyanAccent),
                label: const Text('تنظیمات موقعیت مکانی اندروید'),
                onPressed: () => _execute('location_settings'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('انصراف', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.cyan),
              onPressed: () {
                setState(() => _calibration = temp);
                Navigator.pop(context);
              },
              child: const Text('ذخیره', style: TextStyle(color: Colors.black)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            // ۱. سایدبار داک سمت چپ
            _buildDock(),

            // ۲. ستون اول: کارت ناوبری و ساعت
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: _buildNavigationCard(),
              ),
            ),

            // ۳. ستون دوم: کیلومتر نئونی، آرم سایپا، جاده متحرک و نمای پشت تیبا
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: _buildCenterCluster(),
              ),
            ),

            // ۴. ستون سوم: کنترل موزیک و تصویر بدنه تیبا ۲
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: _buildRightSide(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDock() {
    return Container(
      width: 76,
      margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withOpacity(0.9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.cyanAccent.withOpacity(0.25)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.cyanAccent, size: 28),
            onPressed: () => _execute('settings'),
          ),
          IconButton(
            icon: const Icon(Icons.map, color: Colors.cyanAccent, size: 28),
            onPressed: () => _execute('nav', pkg: _selectedNavPackage),
          ),
          IconButton(
            icon: const Icon(Icons.radio, color: Colors.cyanAccent, size: 28),
            onPressed: () => _execute('radio'),
          ),
          IconButton(
            icon: const Icon(Icons.phone, color: Colors.cyanAccent, size: 28),
            onPressed: () => _execute('phone'),
          ),
          IconButton(
            icon: const Icon(Icons.apps, color: Colors.cyanAccent, size: 28),
            onPressed: () => _execute('apps'),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D1527),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.cyanAccent.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(color: Colors.cyanAccent.withOpacity(0.05), blurRadius: 20)
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.tune, color: Colors.cyanAccent),
                onPressed: _openNavSelector,
              ),
              Row(
                children: [
                  Text(
                    _selectedNavName,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.near_me, color: Colors.cyanAccent, size: 20),
                ],
              ),
            ],
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => _execute('nav', pkg: _selectedNavPackage),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.cyanAccent.withOpacity(0.1),
                    border: Border.all(color: Colors.cyanAccent, width: 2),
                  ),
                  child: const Icon(Icons.navigation,
                      color: Colors.cyanAccent, size: 42),
                ),
                const SizedBox(height: 12),
                const Text(
                  'مسیریابی هوشمند',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          Text(
            _timeStr,
            style: const TextStyle(
              color: Colors.cyanAccent,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          Text(_dateStr,
              style: const TextStyle(color: Colors.white38, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildCenterCluster() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // کالیبراسیون و دنده‌ها
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.satellite_alt,
                  color: Colors.cyanAccent, size: 22),
              onPressed: _openGpsDialog,
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: ['P', 'R', 'N', 'D'].map((g) {
                  final sel = _selectedGear == g;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedGear = g),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        g,
                        style: TextStyle(
                          color: sel ? Colors.cyanAccent : Colors.white24,
                          fontSize: 14,
                          fontWeight:
                              sel ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(width: 40),
          ],
        ),

        // کیلومتر نئونی بزرگ
        Column(
          children: [
            Text(
              _speed.toInt().toString(),
              style: const TextStyle(
                color: Colors.cyanAccent,
                fontSize: 80,
                fontWeight: FontWeight.w900,
                shadows: [Shadow(color: Colors.cyanAccent, blurRadius: 28)],
              ),
            ),
            const Text(
              'KM / H',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 13,
                letterSpacing: 4,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),

        // آرم نئونی سایپا
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.cyanAccent.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.cyanAccent.withOpacity(0.3)),
          ),
          child: const Text(
            'S A I P A',
            style: TextStyle(
              color: Colors.cyanAccent,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 4,
            ),
          ),
        ),

        // جاده متحرک سه‌بعدی نئونی با تصویر پشت تیبا روی آن
        Expanded(
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              // جاده در حال حرکت
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _roadAnimCtrl,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: MovingCyberRoadPainter(
                        progress: _roadAnimCtrl.value,
                      ),
                    );
                  },
                ),
              ),
              // تصویر نمای پشت خودرو
              Positioned(
                bottom: 6,
                child: SizedBox(
                  height: 95,
                  child: Image.asset(
                    'tiba2_rear.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.directions_car,
                      color: Colors.cyanAccent,
                      size: 54,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRightSide() {
    return Column(
      children: [
        // کارت موزیک فابریک
        Container(
          height: 120,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF0D1527),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.cyanAccent.withOpacity(0.2)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.launch,
                        color: Colors.cyanAccent, size: 20),
                    onPressed: () => _execute('music'),
                  ),
                  const Text('پخش‌کننده خودرو',
                      style: TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.skip_previous,
                        color: Colors.cyanAccent),
                    onPressed: () => _execute('media_prev'),
                  ),
                  IconButton(
                    icon: Icon(
                      _isPlaying
                          ? Icons.pause_circle_filled
                          : Icons.play_circle_fill,
                      color: Colors.cyanAccent,
                      size: 38,
                    ),
                    onPressed: () {
                      setState(() => _isPlaying = !_isPlaying);
                      _execute('media_play_pause');
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_next,
                        color: Colors.cyanAccent),
                    onPressed: () => _execute('media_next'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // عکس نمایشی بدنه تیبا ۲
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0D1527),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: Colors.white10),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: Image.asset(
                'tiba2.png',
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Center(
                  child: Icon(Icons.directions_car,
                      color: Colors.white24, size: 50),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// نقاش سفارشی جاده پرسپکتیو نئونی در حال حرکت به جلو
class MovingCyberRoadPainter extends CustomPainter {
  final double progress;
  MovingCyberRoadPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final roadPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.cyanAccent.withOpacity(0.0),
          Colors.cyanAccent.withOpacity(0.08),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    // رسم کفی جاده ذوزنقه‌ای پرسپکتیو
    final roadPath = Path()
      ..moveTo(w * 0.36, 0)
      ..lineTo(w * 0.64, 0)
      ..lineTo(w * 0.90, h)
      ..lineTo(w * 0.10, h)
      ..close();
    canvas.drawPath(roadPath, roadPaint);

    // حاشیه‌های نئونی چپ و راست جاده
    final borderPaint = Paint()
      ..color = Colors.cyanAccent.withOpacity(0.6)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4);

    canvas.drawLine(Offset(w * 0.36, 0), Offset(w * 0.10, h), borderPaint);
    canvas.drawLine(Offset(w * 0.64, 0), Offset(w * 0.90, h), borderPaint);

    // خطوط مقطع نئونی متحرک در مرکز جاده
    final lanePaint = Paint()
      ..color = Colors.cyanAccent.withOpacity(0.85)
      ..strokeWidth = 2.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 3);

    const int totalLines = 5;
    for (int i = 0; i < totalLines; i++) {
      double t = ((i / totalLines) + progress) % 1.0;
      // تبدیل حرکت خطی به پرسپکتیو واقعی
      double curveT = t * t;

      double y = curveT * h;
      double lineLength = 10 + (curveT * 35);
      double endY = (y + lineLength).clamp(0.0, h);

      canvas.drawLine(Offset(w * 0.5, y), Offset(w * 0.5, endY), lanePaint);
    }
  }

  @override
  bool shouldRepaint(covariant MovingCyberRoadPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
