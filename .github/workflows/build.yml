import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';

void main() {
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
        scaffoldBackgroundColor: const Color(0xFF0B0F19),
        primaryColor: const Color(0xFF00F0FF),
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
  StreamSubscription<Position>? _positionStream;

  @override
  void initState() {
    super.initState();
    _initGPS();
  }

  Future<void> _initGPS() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (permission == LocationPermission.deniedForever) return;

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 1,
      ),
    ).listen((Position position) {
      setState(() {
        // تبدیل سرعت از متر بر ثانیه به کیلومتر بر ساعت
        _currentSpeed = (position.speed * 3.6).clamp(0.0, 240.0);
      });
    });
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }

  // باز کردن اپلیکیشن‌های ناوبر با اینتنت مستقیم
  Future<void> _launchApp(String packageName, String universalUrl) async {
    final Uri uri = Uri.parse(universalUrl);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // حالت پشتیبان وب
        await launchUrl(Uri.parse('https://maps.google.com'), mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error launching: $e');
    }
  }

  void _openSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF131B2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          height: 250,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'تنظیمات داشبورد تیبا ۲',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.palette, color: Color(0xFF00F0FF)),
                title: const Text('پوسته سایبرپانک (فعال)', style: TextStyle(color: Colors.white)),
                trailing: const Icon(Icons.check, color: Colors.green),
                onTap: () {},
              ),
              ListTile(
                leading: const Icon(Icons.gps_fixed, color: Color(0xFF00F0FF)),
                title: const Text('کالیبراسیون GPS', style: TextStyle(color: Colors.white)),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              // هدر بالا (نوار وضعیت + دکمه تنظیمات)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'TIBA 2 HUD DASHBOARD',
                    style: TextStyle(color: Color(0xFF00F0FF), fontSize: 14, letterSpacing: 2, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings, color: Color(0xFF00F0FF)),
                    onPressed: _openSettings,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // بدنه اصلی ۳ ستونه
              Expanded(
                child: Row(
                  children: [
                    // ستون چپ: لانچر ناوبرها و موزیک پلیر
                    Expanded(
                      flex: 1,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.03),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('مسیریاب‌ها', style: TextStyle(color: Colors.white70, fontSize: 12)),
                            const SizedBox(height: 8),
                            _buildNavButton('نشان', Colors.redAccent, () => _launchApp('ir.neshan.masir', 'nshn://')),
                            const SizedBox(height: 6),
                            _buildNavButton('بلد', Colors.greenAccent, () => _launchApp('ir.balad.map', 'balad://')),
                            const SizedBox(height: 6),
                            _buildNavButton('گوگل مپ', Colors.blueAccent, () => _launchApp('com.google.android.apps.maps', 'https://maps.google.com')),
                            const Spacer(),
                            const Divider(color: Colors.white24),
                            const Text('موزیک پلیر', style: TextStyle(color: Colors.white70, fontSize: 12)),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(icon: const Icon(Icons.skip_previous, color: Colors.white), onPressed: () {}),
                                IconButton(icon: const Icon(Icons.play_arrow, color: Color(0xFF00F0FF), size: 32), onPressed: () {}),
                                IconButton(icon: const Icon(Icons.skip_next, color: Colors.white), onPressed: () {}),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // ستون وسط: سرعت‌سنج دیجیتال نئونی (با قابلیت لمس ۳ ثانیه‌ای برای تنظیمات)
                    Expanded(
                      flex: 2,
                      child: GestureDetector(
                        onLongPress: _openSettings,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.03),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFF00F0FF).withOpacity(0.3)),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF00F0FF).withOpacity(0.1),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 180,
                                height: 180,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: const Color(0xFF00F0FF), width: 4),
                                  boxShadow: [
                                    BoxShadow(color: const Color(0xFF00F0FF).withOpacity(0.4), blurRadius: 15),
                                  ],
                                ),
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        _currentSpeed.toStringAsFixed(0),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 54,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const Text(
                                        'KM/H',
                                        style: TextStyle(
                                          color: Color(0xFF00F0FF),
                                          fontSize: 14,
                                          letterSpacing: 2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 15),
                              const Text(
                                'برای تنظیمات، ۳ ثانیه روی سرعت‌سنج نگه دارید',
                                style: TextStyle(color: Colors.white38, fontSize: 10),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // ستون راست: وضعیت تیبا ۲ (ولتاژ باتری و دمای آب)
                    Expanded(
                      flex: 1,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.03),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('وضعیت خودرو', style: TextStyle(color: Colors.white70, fontSize: 12)),
                            const SizedBox(height: 16),
                            _buildStatusCard('ولتاژ باتری', '14.2 V', Icons.battery_charging_full, Colors.greenAccent),
                            const SizedBox(height: 12),
                            _buildStatusCard('دمای آب', '88 °C', Icons.thermostat, Colors.orangeAccent),
                            const Spacer(),
                            const Center(
                              child: Text(
                                'TIBA 2 Android 10',
                                style: TextStyle(color: Colors.white24, fontSize: 10),
                              ),
                            ),
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
    );
  }

  Widget _buildNavButton(String title, Color color, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withOpacity(0.2),
          foregroundColor: Colors.white,
          side: BorderSide(color: color),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(vertical: 8),
        ),
        onPressed: onTap,
        child: Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildStatusCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.white60, fontSize: 9)),
              Text(value, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }
}
