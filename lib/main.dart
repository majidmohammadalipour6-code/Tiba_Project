import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

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
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF070B12),
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
  double _currentSpeed = 0.0;
  bool _isPlayingMusic = false;

  @override
  void initState() {
    super.initState();
    _initGps();
  }

  void _initGps() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 1,
      ),
    ).listen((Position position) {
      if (mounted) {
        setState(() {
          // سرعت جی‌پی‌اس بر حسب متر بر ثانیه است؛ تبدیل به کیلومتر بر ساعت:
          double speedKmH = (position.speed * 3.6);
          _currentSpeed = speedKmH > 1 ? speedKmH : 0.0;
        });
      }
    });
  }

  // باز کردن اپلیکیشن‌های مسیریاب با Intent استاندارد اندروید
  Future<void> _openApp(String schemeUri, String fallbackWeb) async {
    final uri = Uri.parse(schemeUri);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalNonBrowserApplication);
      } else {
        await launchUrl(Uri.parse(fallbackWeb), mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      await launchUrl(Uri.parse(fallbackWeb), mode: LaunchMode.externalApplication);
    }
  }

  void _showSettingsModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A).withOpacity(0.85),
            borderRadius: const verticalTopRadius(24),
            border: Border.all(color: Colors.cyanAccent.withOpacity(0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white30, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              const Text("تنظیمات داشبورد تیبا ۲", style: TextStyle(color: Colors.cyanAccent, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.gps_fixed, color: Colors.cyanAccent),
                title: const Text("کالیبراسیون و وضعیت GPS", style: TextStyle(color: Colors.white)),
                subtitle: const Text("سرعت فعال از سنسور ماهواره‌ای مانیتور", style: TextStyle(color: Colors.white54)),
                trailing: const Icon(Icons.check_circle, color: Colors.greenAccent),
              ),
              ListTile(
                leading: const Icon(Icons.bluetooth, color: Colors.orangeAccent),
                title: const Text("ماژول OBD-II (دیاگ تیبا)", style: TextStyle(color: Colors.white)),
                subtitle: const Text("آماده اتصال به بلوتوث خودرو", style: TextStyle(color: Colors.white54)),
                trailing: const Text("قطع", style: TextStyle(color: Colors.redAccent)),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // پس‌زمینه سایبرپانک لوکس
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.0, -0.2),
                radius: 1.2,
                colors: [
                  Color(0xFF0D1B2A),
                  Color(0xFF060B12),
                  Color(0xFF020408),
                ],
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Column(
                children: [
                  // نوار ابزار فوقانی (Header) شبیه عکس دوم و سوم
                  _buildHeader(),
                  const SizedBox(height: 12),

                  // محتوای اصلی داشبورد: ۳ ستون
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ستون چپ: لانچر ناوبری و میان‌برها
                        Expanded(flex: 3, child: _buildLeftNavigationPanel()),
                        const SizedBox(width: 14),

                        // ستون وسط: آمپر سرعت دیجیتال شیشه‌ای دوحلقه‌ای
                        Expanded(flex: 4, child: _buildCenterSpeedometer()),
                        const SizedBox(width: 14),

                        // ستون راست: موزیک پلیر و وضعیت تیبا ۲
                        Expanded(flex: 3, child: _buildRightStatusPanel()),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // هدر بالا شبیه طرح
  Widget _buildHeader() {
    return GlassCard(
      borderRadius: 14,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: const [
              Text(
                "TIBA 2 COCKPIT",
                style: TextStyle(
                  color: Colors.cyanAccent,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  fontSize: 14,
                ),
              ),
              SizedBox(width: 8),
              Icon(Icons.wifi, color: Colors.cyanAccent, size: 16),
              SizedBox(width: 6),
              Icon(Icons.bluetooth, color: Colors.cyanAccent, size: 16),
            ],
          ),
          Row(
            children: [
              IconButton(
                splashRadius: 20,
                icon: const Icon(Icons.settings, color: Colors.cyanAccent, size: 22),
                onPressed: _showSettingsModal,
              ),
            ],
          )
        ],
      ),
    );
  }

  // پنل ناوبری سمت چپ با دکمه‌های مستقیم اپلیکیشن
  Widget _buildLeftNavigationPanel() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: const [
              Icon(Icons.near_me_outlined, color: Colors.cyanAccent, size: 18),
              SizedBox(width: 8),
              Text(
                "NAVIGATION",
                style: TextStyle(
                  color: Colors.cyanAccent,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildNavLauncherBtn(
            title: "نشان (Neshan)",
            icon: Icons.navigation_rounded,
            color: const Color(0xFF00C853),
            onTap: () => _openApp("nshn://", "https://neshan.org"),
          ),
          const SizedBox(height: 12),
          _buildNavLauncherBtn(
            title: "بلد (Balad)",
            icon: Icons.explore_rounded,
            color: const Color(0xFF2979FF),
            onTap: () => _openApp("balad://", "https://balad.ir"),
          ),
          const SizedBox(height: 12),
          _buildNavLauncherBtn(
            title: "گوگل مپ (Google Maps)",
            icon: Icons.map_rounded,
            color: const Color(0xFFFF9100),
            onTap: () => _openApp("google.navigation:q=", "https://maps.google.com"),
          ),
        ],
      ),
    );
  }

  Widget _buildNavLauncherBtn({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.4), width: 1),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              const Icon(Icons.arrow_forward_ios, color: Colors.white38, size: 12),
            ],
          ),
        ),
      ),
    );
  }

  // مرکز: سرعت سنج شیشه‌ای و نئونی با قابلیت هولد ۳ ثانیه‌ای برای تنظیمات
  Widget _buildCenterSpeedometer() {
    return GestureDetector(
      onLongPress: _showSettingsModal, // نگه داشتن ۳ ثانیه برای باز شدن تنظیمات
      child: GlassCard(
        borderColor: Colors.cyanAccent.withOpacity(0.35),
        child: Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              // حلقه‌های نئونی بیرونی HUD
              SizedBox(
                width: 210,
                height: 210,
                child: CircularProgressIndicator(
                  value: (_currentSpeed / 200).clamp(0.0, 1.0),
                  strokeWidth: 9,
                  backgroundColor: Colors.white.withOpacity(0.06),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.cyanAccent),
                ),
              ),
              SizedBox(
                width: 180,
                height: 180,
                child: CircularProgressIndicator(
                  value: (_currentSpeed / 200 * 0.85).clamp(0.0, 1.0),
                  strokeWidth: 4,
                  backgroundColor: Colors.transparent,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.orangeAccent),
                ),
              ),

              // ارقام سرعت و واحد km/h
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _currentSpeed.toInt().toString(),
                    style: const TextStyle(
                      fontSize: 68,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -1,
                      shadows: [
                        Shadow(color: Colors.cyanAccent, blurRadius: 18),
                      ],
                    ),
                  ),
                  const Text(
                    "KM / H",
                    style: TextStyle(
                      color: Colors.cyanAccent,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "HOLD FOR SETTINGS",
                    style: TextStyle(
                      color: Colors.white24,
                      fontSize: 9,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ستون سمت راست: وضعیت تیبا ۲ و کنترل مدیا
  Widget _buildRightStatusPanel() {
    return Column(
      children: [
        // کارت موزیک پلیر
        Expanded(
          flex: 1,
          child: GlassCard(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text("NOW PLAYING", style: TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.bold)),
                    Icon(Icons.music_note, color: Colors.orangeAccent, size: 16),
                  ],
                ),
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.pinkAccent.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.pinkAccent.withOpacity(0.4)),
                      ),
                      child: const Icon(Icons.album, color: Colors.pinkAccent),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text("Tiba Car Audio", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12), overflow: TextOverflow.ellipsis),
                          Text("Bluetooth Connected", style: TextStyle(color: Colors.white38, fontSize: 10)),
                        ],
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(icon: const Icon(Icons.skip_previous, size: 20), onPressed: () {}),
                    IconButton(
                      icon: Icon(_isPlayingMusic ? Icons.pause_circle_filled : Icons.play_circle_fill, color: Colors.cyanAccent, size: 30),
                      onPressed: () => setState(() => _isPlayingMusic = !_isPlayingMusic),
                    ),
                    IconButton(icon: const Icon(Icons.skip_next, size: 20), onPressed: () {}),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),

        // وضعیت سیستم‌های تیبا ۲
        Expanded(
          flex: 1,
          child: GlassCard(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text("TIBA 2 STATUS", style: TextStyle(color: Colors.cyanAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                    Icon(Icons.directions_car, color: Colors.cyanAccent, size: 16),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text("Battery Volts:", style: TextStyle(color: Colors.white54, fontSize: 12)),
                    Text("14.2 V", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text("Coolant Temp:", style: TextStyle(color: Colors.white54, fontSize: 12)),
                    Text("88 °C", style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 13)),
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

// ویجت پایه شیشه‌ای (Glassmorphism Card) با بلور واقعی
class GlassCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;

  const GlassCard({
    super.key,
    required this.child,
    this.borderRadius = 16,
    this.padding = const EdgeInsets.all(16),
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: const Color(0xFF131D2E).withOpacity(0.55),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: borderColor ?? Colors.white.withOpacity(0.12),
              width: 1.2,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

BorderRadius verticalTopRadius(double r) => BorderRadius.vertical(top: Radius.circular(r));
