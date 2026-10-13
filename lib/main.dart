import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'dart:math' as math;

void main() {
  runApp(const TibaLauncherApp());
}

class TibaLauncherApp extends StatelessWidget {
  const TibaLauncherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tiba 2 Cyber HUD Launcher',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF050811),
        fontFamily: 'monospace',
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

class _DashboardScreenState extends State<DashboardScreen> with TickerProviderStateMixin {
  double _speed = 0.0;
  bool _isSettingsOpen = false;
  
  // تنظیمات رنگ نئون و روشنایی پنل‌ها
  Color _neonColor = const Color(0xFF00E5FF);
  double _glassOpacity = 0.15;

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    // شبیه‌سازی تست سرعت (می‌توانی بعداً به GPS واقعی متصل کنی)
    Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!mounted) return;
      setState(() {
        _speed = (_speed == 0.0) ? 45.0 : (_speed == 45.0 ? 82.0 : 0.0);
      });
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  // تابع باز کردن اپ‌های ناوبری (نشان، بلد، گوگل مپ، وِیز)
  Future<void> _launchNavigation(String appType) async {
    String url = '';
    if (appType == 'neshan') {
      url = 'https://neshan.org/maps';
    } else if (appType == 'balad') {
      url = 'https://balad.ir';
    } else if (appType == 'google') {
      url = 'https://maps.google.com';
    } else if (appType == 'waze') {
      url = 'https://www.waze.com';
    }

    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      debugPrint('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.2,
            colors: [Color(0xFF0A1128), Color(0xFF02040A)],
          ),
        ),
        child: Stack(
          children: [
            // لایه اصلی داشبورد (3 ستون)
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  // ستون چپ: لانچر ناوبری + پخش‌کننده موزیک
                  Expanded(
                    flex: 3,
                    child: Column(
                      children: [
                        Expanded(flex: 3, child: _buildNavigationLauncher()),
                        const SizedBox(height: 10),
                        Expanded(flex: 2, child: _buildMusicPlayerWidget()),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),

                  // ستون وسط: کیلومترشمار دیجیتال سایبرپانک
                  Expanded(
                    flex: 4,
                    child: GestureDetector(
                      onLongPress: () {
                        setState(() {
                          _isSettingsOpen = true;
                        });
                      },
                      child: _buildSpeedometerWidget(),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // ستون راست: وضعیت تیبا ۲ هچ‌بک (شامل عکس گرافیکی ماشین و سنسورها)
                  Expanded(
                    flex: 3,
                    child: _buildTibaCarStatusWidget(),
                  ),
                ],
              ),
            ),

            // دکمه تنظیمات بالا سمت راست
            Positioned(
              top: 10,
              right: 15,
              child: IconButton(
                icon: const Icon(Icons.settings, color: Colors.white70, size: 28),
                onPressed: () {
                  setState(() {
                    _isSettingsOpen = true;
                  });
                },
              ),
            ),

            // مودال تنظیمات در صورت باز بودن
            if (_isSettingsOpen) _buildSettingsModal(),
          ],
        ),
      ),
    );
  }

  // --- ویجت ستون چپ: لانچر ناوبری با دکمه‌های کاملاً فعال ---
  Widget _buildNavigationLauncher() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(_glassOpacity),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _neonColor.withOpacity(0.4), width: 1.5),
        boxShadow: [BoxShadow(color: _neonColor.withOpacity(0.1), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.navigation, color: _neonColor, size: 18),
              const SizedBox(width: 8),
              const Text('NAVIGATION', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
          const Divider(color: Colors.white24, height: 16),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 2.2,
              children: [
                _navButton('نشان', 'neshan', Colors.orangeAccent),
                _navButton('بلد', 'balad', Colors.greenAccent),
                _navButton('گوگل مپ', 'google', Colors.blueAccent),
                _navButton('ویز', 'waze', Colors.purpleAccent),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _navButton(String title, String type, Color color) {
    return InkWell(
      onTap: () => _launchNavigation(type),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color, width: 1),
        ),
        child: Center(
          child: Text(
            title,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ),
      ),
    );
  }

  // --- ویجت پخش‌کننده موزیک ---
  Widget _buildMusicPlayerWidget() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(_glassOpacity),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _neonColor.withOpacity(0.4), width: 1.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Row(
            children: [
              Icon(Icons.music_note, color: Colors.pinkAccent, size: 18),
              SizedBox(width: 8),
              Text('MEDIA PLAYER', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
          const Spacer(),
          const Text('در حال پخش: موزیک رانندگی', style: TextStyle(color: Colors.white70, fontSize: 11)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(icon: const Icon(Icons.skip_previous, color: Colors.white, size: 22), onPressed: () {}),
              IconButton(
                icon: const Icon(Icons.play_circle_fill, color: Colors.cyanAccent, size: 36),
                onPressed: () {},
              ),
              IconButton(icon: const Icon(Icons.skip_next, color: Colors.white, size: 22), onPressed: () {}),
            ],
          ),
        ],
      ),
    );
  }

  // --- ویجت وسط: کیلومترشمار سایبرپانک امن (بدون خطای زاویه صفر) ---
  Widget _buildSpeedometerWidget() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(_glassOpacity),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _neonColor, width: 2),
        boxShadow: [BoxShadow(color: _neonColor.withOpacity(0.3), blurRadius: 20)],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: CustomPaint(
              painter: SafeCyberClusterPainter(speed: _speed, neonColor: _neonColor),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _speed.toStringAsFixed(0),
                      style: TextStyle(
                        color: _neonColor,
                        fontSize: 52,
                        fontWeight: FontWeight.bold,
                        shadows: [Shadow(color: _neonColor, blurRadius: 15)],
                      ),
                    ),
                    const Text('KM/H', style: TextStyle(color: Colors.white60, fontSize: 12, letterSpacing: 2)),
                  ],
                ),
              ),
            ),
          ),
          const Text('برای تنظیمات طولانی‌مدت لمس کنید', style: TextStyle(color: Colors.white38, fontSize: 10)),
        ],
      ),
    );
  }

  // --- ویجت ستون راست: وضعیت خودروی تیبا ۲ هچ‌بک (همراه با تصویر گرافیکی ماشین) ---
  Widget _buildTibaCarStatusWidget() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(_glassOpacity),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _neonColor.withOpacity(0.4), width: 1.5),
        boxShadow: [BoxShadow(color: _neonColor.withOpacity(0.1), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(Icons.directions_car, color: _neonColor, size: 18),
              const SizedBox(width: 8),
              const Text('TIBA 2 STATUS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
          const Divider(color: Colors.white24, height: 14),

          // رندرینگ گرافیکی وکتور ماشین تیبا ۲ هچ‌بک با نورپردازی نئونی
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF03050B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.cyanAccent.withOpacity(0.3)),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // افکت نور زیر ماشین (Ground Glow)
                  Positioned(
                    bottom: 15,
                    child: Container(
                      width: 120,
                      height: 12,
                      decoration: BoxDecoration(
                        boxShadow: [BoxShadow(color: _neonColor.withOpacity(0.6), blurRadius: 20, spreadRadius: 4)],
                      ),
                    ),
                  ),
                  // طراحی بدنه سایبرپانک تیبا ۲ هچ‌بک
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.electric_car, size: 64, color: Colors.cyanAccent),
                      const SizedBox(height: 4),
                      Text(
                        'SAIPA TIBA 2',
                        style: TextStyle(color: _neonColor, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1),
                      ),
                      const Text('HATCHBACK', style: TextStyle(color: Colors.white54, fontSize: 10)),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // اطلاعات پایداری و باتری
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _statusIndicator('BATTERY', '14.2V', Icons.bolt, Colors.amber),
              _statusIndicator('WATER', '88°C', Icons.thermostat, Colors.redAccent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusIndicator(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.white54, fontSize: 8)),
              Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  // --- پنل تنظیمات سفارشی‌سازی ---
  Widget _buildSettingsModal() {
    return Container(
      color: Colors.black87,
      child: Center(
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _neonColor, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('تنظیمات داشبورد تیبا', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              const Divider(color: Colors.white24),
              const SizedBox(height: 10),
              const Text('انتخاب رنگ نئون:', style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _colorPickerBtn(const Color(0xFF00E5XX), Colors.cyanAccent),
                  _colorPickerBtn(Colors.greenAccent, Colors.greenAccent),
                  _colorPickerBtn(Colors.pinkAccent, Colors.pinkAccent),
                  _colorPickerBtn(Colors.amberAccent, Colors.amberAccent),
                ],
              ),
              const SizedBox(height: 20),
              Center(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: _neonColor, foregroundColor: Colors.black),
                  onPressed: () {
                    setState(() {
                      _isSettingsOpen = false;
                    });
                  },
                  child: const Text('ذخیره و بازگشت', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _colorPickerBtn(Color color, Color displayColor) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _neonColor = displayColor;
        });
      },
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: displayColor,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
      ),
    );
  }
}

// نقاش امن سرعت‌سنج برای جلوگیری از خطای زاویه صفر فلاتر
class SafeCyberClusterPainter extends CustomPainter {
  final double speed;
  final Color neonColor;

  SafeCyberClusterPainter({required this.speed, required this.neonColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.42;

    final paintBg = Paint()
      ..color = Colors.white12
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0;

    canvas.drawCircle(center, radius, paintBg);

    final paintProgress = Paint()
      ..color = neonColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 8.0;

    // محاسبه زاویه امن (حتی در سرعت صفر زاویه معتبر دارد تا ارور ندهد)
    double sweepAngle = (speed / 200.0) * 2 * math.pi;
    if (sweepAngle < 0.05) sweepAngle = 0.05;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi * 0.75,
      sweepAngle,
      false,
      paintProgress,
    );
  }

  @override
  bool shouldRepaint(covariant SafeCyberClusterPainter oldDelegate) {
    return oldDelegate.speed != speed || oldDelegate.neonColor != neonColor;
  }
}
