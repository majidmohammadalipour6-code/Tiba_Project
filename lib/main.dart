import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // قفل کردن جهت صفحه روی حالت افقی برای مانیتور خودرو
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
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
        scaffoldBackgroundColor: const Color(0xFF030712),
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
  double _speed = 0.0;
  double _calibration = 1.0;
  Timer? _timer;
  String _timeStr = "";
  String _dateStr = "";

  @override
  void initState() {
    super.initState();
    _updateClock();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateClock());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _updateClock() {
    final now = DateTime.now();
    setState(() {
      _timeStr = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
      _dateStr = "${now.year}/${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}";
    });
  }

  // متد ارسال اینتنت بدون نیاز به کدهای نیتیو و بدون کرش
  void _openIntent(String action, {String? uri, String? packageName}) async {
    const channel = MethodChannel('android_intent');
    try {
      await channel.invokeMethod('launch', {
        'action': action,
        'uri': uri,
        'package': packageName,
      });
    } catch (_) {
      // استفاده از متد ثانویه سیستمی
      try {
        final fallbackChannel = const MethodChannel('flutter/platform');
        await fallbackChannel.invokeMethod('SystemNavigator.pop');
      } catch (e) {
        // هیچ کاری نکن
      }
    }
  }

  void _showNavDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0B132B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "انتخاب مسیریاب",
              style: TextStyle(color: Colors.cyanAccent, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _navOptionItem("نشان", Icons.navigation, () {
                  Navigator.pop(ctx);
                  _openIntent("android.intent.action.VIEW", packageName: "org.neshan.maps");
                }),
                _navOptionItem("بلد", Icons.map, () {
                  Navigator.pop(ctx);
                  _openIntent("android.intent.action.VIEW", packageName: "ir.balad.navigation");
                }),
                _navOptionItem("گوگل مپ", Icons.explore, () {
                  Navigator.pop(ctx);
                  _openIntent("android.intent.action.VIEW", uri: "geo:0,0?q=");
                }),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _navOptionItem(String title, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.cyanAccent.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.cyanAccent.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.cyanAccent, size: 32),
            const SizedBox(height: 6),
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  void _showCalibDialog() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          title: const Text("کالیبراسیون سرعت GPS", style: TextStyle(color: Colors.cyanAccent)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "ضریب: ${_calibration.toStringAsFixed(2)}x",
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
              Slider(
                value: _calibration,
                min: 0.7,
                max: 1.3,
                divisions: 12,
                activeColor: Colors.cyanAccent,
                onChanged: (v) {
                  setDlgState(() => _calibration = v);
                  setState(() => _calibration = v);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // پس‌زمینه مشکی/سایبری
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.2,
                colors: [Color(0xFF07111E), Color(0xFF020408)],
              ),
            ),
          ),

          // خطوط نئونی بسیار محو
          Positioned.fill(
            child: Opacity(
              opacity: 0.03,
              child: CustomPaint(painter: GridPainter()),
            ),
          ),

          // ساختار اصلی تمام‌صفحه افقی مانیتور
          SafeArea(
            child: Column(
              children: [
                // ۱. هدر بالا (ساعت، تاریخ، کالیبراسیون و تنظیمات)
                _buildHeader(),

                // ۲. بدنه اصلی (تقسیم دو بخشی افقی)
                Expanded(
                  child: Row(
                    children: [
                      // سمت چپ: سرعت سنج نئونی همراه با آرم سایپا و ماشین عقب
                      Expanded(
                        flex: 5,
                        child: _buildLeftSpeedometerArea(),
                      ),

                      // سمت راست: تصویر کامل تیبا ۲
                      Expanded(
                        flex: 5,
                        child: _buildRightCarArea(),
                      ),
                    ],
                  ),
                ),

                // ۳. نوار پایینی کنترل مانیتور
                _buildBottomBar(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.access_time_filled, color: Colors.cyanAccent, size: 20),
              const SizedBox(width: 8),
              Text(
                _timeStr,
                style: const TextStyle(
                  color: Colors.cyanAccent,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                _dateStr,
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.tune, color: Colors.cyanAccent),
                onPressed: _showCalibDialog,
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.settings, color: Colors.cyanAccent, size: 26),
                onPressed: () {
                  _openIntent("android.settings.SETTINGS");
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLeftSpeedometerArea() {
    double displaySpeed = _speed * _calibration;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // گیج سرعت
        SizedBox(
          width: 210,
          height: 180,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(210, 180),
                painter: DialSpeedPainter(speed: displaySpeed),
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
                      shadows: [Shadow(color: Colors.cyanAccent, blurRadius: 15)],
                    ),
                  ),
                  const Text(
                    "KM/H",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.cyanAccent,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // آرم سایپا بلافاصله زیر سرعت‌سنج
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomPaint(size: const Size(14, 14), painter: SaipaPainter()),
            const SizedBox(width: 6),
            const Text(
              "SAIPA",
              style: TextStyle(
                color: Colors.cyanAccent,
                fontWeight: FontWeight.bold,
                fontSize: 11,
                letterSpacing: 2,
              ),
            ),
          ],
        ),

        const SizedBox(height: 6),

        // تصویر پشت تیبا ۲
        SizedBox(
          height: 70,
          child: Image.asset(
            'tiba2_rear.png',
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const SizedBox(),
          ),
        ),
      ],
    );
  }

  Widget _buildRightCarArea() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Image.asset(
          'tiba2.png',
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const SizedBox(),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0B132B).withOpacity(0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.cyanAccent.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _barBtn(Icons.navigation_rounded, "مسیریاب", _showNavDialog),
          _barBtn(Icons.radio_rounded, "رادیو", () {
            _openIntent("android.intent.action.MAIN", packageName: "com.android
