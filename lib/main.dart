import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const TibaLauncherApp());
}

class TibaLauncherApp extends StatelessWidget {
  const TibaLauncherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Tiba 2 Launcher',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0B0F19),
        primaryColor: Colors.cyanAccent,
      ),
      home: const DashboardScreen(),
    );
  }
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $urlString');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              // ستون چپ: لانچر مسیریاب‌ها
              Expanded(
                flex: 1,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.cyanAccent.withOpacity(0.3)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('NAVIGATION', style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () => _launchURL('https://neshan.org'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
                        child: const Text('نشان (Neshan)'),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: () => _launchURL('https://balad.ir'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
                        child: const Text('بلد (Balad)'),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: () => _launchURL('https://maps.google.com'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
                        child: const Text('گوگل مپ (Google)'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // ستون وسط: سرعت‌سنج دیجیتال
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.cyanAccent.withOpacity(0.3)),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('0', style: TextStyle(fontSize: 72, fontWeight: FontWeight.bold, color: Colors.cyanAccent)),
                      Text('KM/H', style: TextStyle(color: Colors.white54, letterSpacing: 2)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // ستون راست: وضعیت خودرو (تیبا ۲)
              Expanded(
                flex: 1,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.cyanAccent.withOpacity(0.3)),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('TIBA 2 STATUS', style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
                      SizedBox(height: 20),
                      Text('Battery: 14.2V', style: TextStyle(color: Colors.greenAccent)),
                      SizedBox(height: 10),
                      Text('Water Temp: 88°C', style: TextStyle(color: Colors.orangeAccent)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
