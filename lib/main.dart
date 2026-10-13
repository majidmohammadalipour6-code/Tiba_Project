import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';

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
      debugShowCheckedModeBanner: false,
      title: 'Tiba 2 Cyber HUD',
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

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentSpeed = 0;
  StreamSubscription<Position>? _positionStream;
  bool _isPlaying = false;
  Timer? _longPressTimer;

  @override
  void initState() {
    super.initState();
    _initGpsSpeed();
  }

  Future<void> _initGpsSpeed() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 1,
    );

    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings).listen(
      (Position position) {
        if (mounted) {
          // تبدیل متر بر ثانیه به کیلومتر بر ساعت
          double speedKmh = position.speed * 3.6;
          setState(() {
            _currentSpeed = speedKmh > 1.0 ? speedKmh.round() : 0;
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _longPressTimer?.cancel();
    super.dispose();
  }

  void _openSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF101728).withOpacity(0.95),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.settings, color: Colors.cyanAccent),
                SizedBox(width: 12),
                Text(
                  'تنظیمات تیبا ۲',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ],
            ),
            const Divider(color: Colors.white24, height: 28),
            ListTile(
              leading: const Icon(Icons.gps_fixed, color: Colors.cyanAccent),
              title: const Text('کالیبراسیون سنسور GPS'),
              subtitle: const Text('دریافت زنده سرعت از ماژول خودرو'),
              onTap: () {
                _initGpsSpeed();
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.palette_outlined, color: Colors.cyanAccent),
              title: const Text('پوسته سایبرپانک / شیشه‌ای'),
              subtitle: const Text('فعال'),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchApp(String urlString) async {
    final Uri uri = Uri.parse(urlString);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // پس‌زمینه نئونی انتزاعی
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.0, -0.2),
                  radius: 1.2,
                  colors: [
                    Color(0xFF0F2038),
                    Color(0xFF060B14),
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
              child: Column(
                children: [
                  // نوار بالایی: وضعیت و دکمه چرخ‌دنده تنظیمات
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: Colors.cyanAccent,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(color: Colors.cyanAccent, blurRadius: 6),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'TIBA 2 HUD • ONLINE',
                            style: TextStyle(
                              color: Colors.cyanAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.settings, color: Colors.cyanAccent, size: 26),
                        tooltip: 'تنظیمات',
                        onPressed: _openSettings,
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // سه بخش اصلی داشبورد
                  Expanded(
                    child: Row(
                      children: [
                        // ستون چپ: مسیریابی و کنترل موسیقی
                        Expanded(
                          flex: 3,
                          child: Column(
                            children: [
                              Expanded(
                                flex: 3,
                                child: _buildGlassCard(
                                  title: 'مسیریاب',
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                    children: [
                                      _buildNavBtn('نشان (Neshan)', 'nshn://', Icons.navigation_rounded),
                                      _buildNavBtn('بلد (Balad)', 'balad://', Icons.map_outlined),
                                      _buildNavBtn('Google Maps', 'geo:0,0', Icons.explore_outlined),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Expanded(
                                flex: 2,
                                child: _buildGlassCard(
                                  title: 'پخش موسیقی',
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.skip_previous, color: Colors.white70, size: 28),
                                        onPressed: () {},
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                                          color: Colors.cyanAccent,
                                          size: 42,
                                        ),
                                        onPressed: () => setState(() => _isPlaying = !_isPlaying),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.skip_next, color: Colors.white70, size: 28),
                                        onPressed: () {},
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 16),

                        // ستون وسط: سرعت‌سنج HUD مدرن شیشه‌ای
                        Expanded(
                          flex: 4,
                          child: GestureDetector(
                            onTapDown: (_) {
                              _longPressTimer = Timer(const Duration(seconds: 3), () {
                                _openSettings();
                              });
                            },
                            onTapUp: (_) => _longPressTimer?.cancel(),
                            onTapCancel: () => _longPressTimer?.cancel(),
                            child: _buildGlassCard(
                              title: 'سرعت زنده GPS (۳ ثانیه لمس = تنظیمات)',
                              child: Center(
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Container(
                                      width: 200,
                                      height: 200,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.cyanAccent.withOpacity(0.2), width: 3),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.cyanAccent.withOpacity(0.1),
                                            blurRadius: 30,
                                            spreadRadius: 2,
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      width: 165,
                                      height: 165,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.cyanAccent, width: 2),
                                      ),
                                    ),
                                    Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          '$_currentSpeed',
                                          style: const TextStyle(
                                            fontSize: 70,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.white,
                                            letterSpacing: -2,
                                          ),
                                        ),
                                        const Text(
                                          'KM / H',
                                          style: TextStyle(
                                            color: Colors.cyanAccent,
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 2,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 16),

                        // ستون راست: وضعیت سنسورهای تیبا ۲
                        Expanded(
                          flex: 3,
                          child: _buildGlassCard(
                            title: 'وضعیت خودرو تیبا ۲',
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildCarStatusTile('باتری دینام', '13.8 V', Icons.battery_charging_full, Colors.greenAccent),
                                _buildCarStatusTile('دمای آب موتور', '88 °C', Icons.thermostat, Colors.orangeAccent),
                                _buildCarStatusTile('وضعیت GPS', 'متصل', Icons.satellite_alt, Colors.cyanAccent),
                              ],
                            ),
                          ),
                        ),
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

  Widget _buildGlassCard({required String title, required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF131D31).withOpacity(0.55),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavBtn(String title, String url, IconData icon) {
    return InkWell(
      onTap: () => _launchApp(url),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.cyanAccent, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white38, size: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildCarStatusTile(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
          Text(
            value,
            style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
