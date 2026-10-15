import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
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

class _DashboardScreenState extends State<DashboardScreen> with SingleTickerProviderStateMixin {
  static const platform = MethodChannel('com.tiba2.launcher/actions');
  static const locationChannel = EventChannel('com.tiba2.launcher/gps');

  double currentSpeed = 0.0;
  double speedMultiplier = 1.0; // ضریب کالیبراسیون GPS
  String selectedGear = 'D';
  bool isPlaying = false;
  String currentTrack = 'آماده برای پخش';
  
  // اپلیکیشن‌های پیش‌فرض
  String navPackage = "ir.balad.app";
  String radioPackage = "";
  String musicPackage = "";

  late AnimationController _roadAnimController;
  Timer? _clockTimer;
  String _currentTime = "";

  @override
  void initState() {
    super.initState();
    _initAnimation();
    _updateClock();
    _requestGpsPermission();
    _initLocationListener();
  }

  void _initAnimation() {
    _roadAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  void _updateClock() {
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final now = DateTime.now();
      setState(() {
        _currentTime = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
      });
    });
  }

  Future<void> _requestGpsPermission() async {
    try {
      await platform.invokeMethod('location_settings');
    } catch (_) {}
  }

  void _initLocationListener() {
    // دریافت سرعت به‌صورت شبیه‌ساز تست یا ایونت واقعی
    // در صورت وصل شدن لیسنر نیتیو سرعت آپدیت می‌شود
    locationChannel.receiveBroadcastStream().listen((dynamic speed) {
      if (speed is num) {
        double calc = speed.toDouble() * 3.6 * speedMultiplier; // تبدیل m/s به km/h
        setState(() {
          currentSpeed = calc < 3.0 ? 0.0 : calc;
        });
      }
    }, onError: (_) {});
  }

  Future<void> _callNative(String action, {String pkg = ""}) async {
    try {
      await platform.invokeMethod('call', {'action': action, 'pkg': pkg});
    } catch (_) {}
  }

  @override
  void dispose() {
    _roadAnimController.dispose();
    _clockTimer?.cancel();
    super.dispose();
  }

  // دیالوگ انتخاب یا تغییر پکیج برای رادیو/موزیک/مسیریاب
  void _showAppSelectDialog(String title, String currentPkg, Function(String) onSelected) {
    TextEditingController controller = TextEditingController(text: currentPkg);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F1A2E),
        title: Text(title, style: const TextStyle(color: Colors.cyanAccent, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "نام پکیج برنامه را وارد کنید یا یکی از گزینه‌ها را بزنید:",
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.black26,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                hintText: "مثال: com.spotify.music",
                hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                ActionChip(
                  label: const Text('نشان'),
                  onPressed: () => controller.text = 'org.neshan.maps',
                ),
                ActionChip(
                  label: const Text('بلد'),
                  onPressed: () => controller.text = 'ir.balad.app',
                ),
                ActionChip(
                  label: const Text('گوگل مپ'),
                  onPressed: () => controller.text = 'com.google.android.apps.maps',
                ),
                ActionChip(
                  label: const Text('موزیک سامسونگ'),
                  onPressed: () => controller.text = 'com.sec.android.app.music',
                ),
                ActionChip(
                  label: const Text('اسپاتیفای'),
                  onPressed: () => controller.text = 'com.spotify.music',
                ),
              ],
            )
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("لغو", style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.cyan),
            onPressed: () {
              onSelected(controller.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text("ذخیره", style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // ستون ۱: سایدبار عمودی داک
          _buildDock(),

          // ستون ۲: مسیریاب هوشمند
          Expanded(flex: 3, child: _buildNavCard()),

          // ستون ۳: سرعت‌سنج، جاده متحرک، آرم سایپا و تصویر عقب تیبا
          Expanded(flex: 4, child: _buildCenterSpeedoHUD()),

          // ستون ۴: مدیاپلیر و نمای جانبی تیبا ۲
          Expanded(flex: 3, child: _buildRightMediaPanel()),
        ],
      ),
    );
  }

  Widget _buildDock() {
    return Container(
      width: 75,
      decoration: BoxDecoration(
        color: const Color(0xFF0C1322),
        border: Border(right: BorderSide(color: Colors.cyan.withOpacity(0.2))),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Text(_currentTime, style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 13)),
          _dockIcon(Icons.settings, "تنظیمات", () => _callNative("settings")),
          _dockIcon(Icons.navigation_outlined, "مسیریاب", () => _callNative("nav", pkg: navPackage),
              onLongPress: () => _showAppSelectDialog("تنظیم مسیریاب", navPackage, (val) => setState(() => navPackage = val))),
          _dockIcon(Icons.radio, "رادیو", () => _callNative("radio", pkg: radioPackage),
              onLongPress: () => _showAppSelectDialog("تنظیم پکیج رادیو", radioPackage, (val) => setState(() => radioPackage = val))),
          _dockIcon(Icons.phone, "تماس", () => _callNative("phone")),
          _dockIcon(Icons.apps, "برنامه‌ها", () => _callNative("apps")),
        ],
      ),
    );
  }

  Widget _dockIcon(IconData icon, String label, VoidCallback onTap, {VoidCallback? onLongPress}) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        child: Column(
          children: [
            Icon(icon, color: Colors.cyanAccent, size: 24),
            const SizedBox(height: 3),
            Text(label, style: const TextStyle(color: Colors.white60, fontSize: 9)),
          ],
        ),
      ),
    );
  }

  Widget _buildNavCard() {
    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1726),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.cyan.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.near_me, color: Colors.cyanAccent, size: 16),
                  SizedBox(width: 6),
                  Text("ناوبری ماهواره‌ای", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.tune, color: Colors.cyanAccent, size: 16),
                onPressed: () => _showAppSelectDialog("انتخاب مسیریاب پیش‌فرض", navPackage, (val) => setState(() => navPackage = val)),
              )
            ],
          ),
          const Spacer(),
          Center(
            child: InkWell(
              onTap: () => _callNative("nav", pkg: navPackage),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(colors: [Colors.cyan.withOpacity(0.3), Colors.blue.withOpacity(0.1)]),
                  border: Border.all(color: Colors.cyanAccent),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.map_outlined, color: Colors.cyanAccent, size: 36),
                    SizedBox(height: 6),
                    Text("ورود به نقشه و مسیریاب", style: TextStyle(color: Colors.white, fontSize: 11)),
                  ],
                ),
              ),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildCenterSpeedoHUD() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0A101D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.cyan.withOpacity(0.2)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // ۱. جاده نئونی متحرک
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 120,
            child: AnimatedBuilder(
              animation: _roadAnimController,
              builder: (context, child) {
                return CustomPaint(
                  painter: CyberRoadPainter(progress: _roadAnimController.value),
                );
              },
            ),
          ),

          // ۲. محتوای سرعت و خودرو
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // سرعت‌سنج دیجیتال
              Text(
                currentSpeed.toInt().toString(),
                style: const TextStyle(
                  fontSize: 54,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -2,
                ),
              ),
              const Text(
                "KM/H",
                style: TextStyle(color: Colors.cyanAccent, fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 6),

              // آرم نئونی سایپا
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.cyanAccent.withOpacity(0.5)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  "S A I P A",
                  style: TextStyle(color: Colors.cyanAccent, fontSize: 9, letterSpacing: 3, fontWeight: FontWeight.bold),
                ),
              ),

              const SizedBox(height: 8),

              // عکس نمای عقب تیبا روی جاده
              SizedBox(
                height: 85,
                child: Image.asset(
                  "tiba2_rear.png",
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(Icons.directions_car, color: Colors.cyanAccent, size: 60),
                ),
              ),

              // دنده‌های نئونی P R N D
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: ['P', 'R', 'N', 'D'].map((gear) {
                  bool isSelected = gear == selectedGear;
                  return GestureDetector(
                    onTap: () => setState(() => selectedGear = gear),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.cyanAccent : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.cyanAccent.withOpacity(0.5)),
                      ),
                      child: Text(
                        gear,
                        style: TextStyle(
                          color: isSelected ? Colors.black : Colors.white70,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRightMediaPanel() {
    return Container(
      margin: const EdgeInsets.all(8),
      child: Column(
        children: [
          // عکس اصلی نمای جانبی تیبا ۲
          Expanded(
            flex: 5,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF0E1726),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.cyan.withOpacity(0.3)),
              ),
              child: Center(
                child: Image.asset(
                  "tiba2.png",
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(Icons.car_rental, color: Colors.cyanAccent, size: 70),
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // موزیک پلیر
          Expanded(
            flex: 5,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF0E1726),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.cyan.withOpacity(0.3)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Icon(Icons.music_note, color: Colors.cyanAccent, size: 16),
                      Expanded(
                        child: Text(
                          currentTrack,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.tune, color: Colors.cyanAccent, size: 14),
                        onPressed: () => _showAppSelectDialog("تنظیم اپ موزیک", musicPackage, (val) => setState(() => musicPackage = val)),
                      )
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.skip_previous, color: Colors.cyanAccent),
                        onPressed: () => _callNative("media_prev"),
                      ),
                      IconButton(
                        icon: Icon(isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill, color: Colors.cyanAccent, size: 36),
                        onPressed: () {
                          setState(() => isPlaying = !isPlaying);
                          if (musicPackage.isNotEmpty) {
                            _callNative("nav", pkg: musicPackage);
                          } else {
                            _callNative("music");
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.skip_next, color: Colors.cyanAccent),
                        onPressed: () => _callNative("media_next"),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// نقاش جاده پرسپکتیو نئونی
class CyberRoadPainter extends CustomPainter {
  final double progress;
  CyberRoadPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paintLine = Paint()
      ..color = Colors.cyanAccent.withOpacity(0.4)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final paintGlow = Paint()
      ..color = Colors.cyanAccent.withOpacity(0.15)
      ..style = PaintingStyle.fill;

    // خطوط کناره‌های جاده به سمت نقطه گریز در افق
    final path = Path()
      ..moveTo(size.width * 0.40, 0)
      ..lineTo(size.width * 0.1, size.height)
      ..lineTo(size.width * 0.9, size.height)
      ..lineTo(size.width * 0.60, 0)
      ..close();
    canvas.drawPath(path, paintGlow);

    canvas.drawLine(Offset(size.width * 0.40, 0), Offset(size.width * 0.1, size.height), paintLine);
    canvas.drawLine(Offset(size.width * 0.60, 0), Offset(size.width * 0.9, size.height), paintLine);

    // خطوط افقی متحرک جاده با حرکت پرسپکتیو
    for (int i = 0; i < 5; i++) {
      double t = (i / 5.0 + progress) % 1.0;
      double y = math.pow(t, 2) * size.height;
      double leftX = (size.width * 0.40) - (size.width * 0.30 * t);
      double rightX = (size.width * 0.60) + (size.width * 0.30 * t);

      paintLine.color = Colors.cyanAccent.withOpacity(0.1 + (0.5 * t));
      canvas.drawLine(Offset(leftX, y), Offset(rightX, y), paintLine);
    }
  }

  @override
  bool shouldRepaint(covariant CyberRoadPainter oldDelegate) => true;
}
