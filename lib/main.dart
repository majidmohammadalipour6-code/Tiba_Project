import 'package:flutter/material.dart';
import 'dart:ui';

void main() {
  runApp(const TibaDashboardApp());
}

class TibaDashboardApp extends StatelessWidget {
  const TibaDashboardApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Tiba Dashboard',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0A0E17),
      ),
      home: const DashboardScreen(),
    );
  }
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF020617)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                // ستون سمت چپ: نقشه و وضعیت مسیر
                Expanded(
                  flex: 3,
                  child: Column(
                    children: [
                      // نوار بالا (ساعت و اطلاعات اتصال)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('10:42', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          Row(
                            children: const [
                              Icon(Icons.signal_cellular_alt, color: Colors.white, size: 16),
                              SizedBox(width: 8),
                              Text('4G LTE', style: TextStyle(color: Colors.white70, fontSize: 12)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(dir: TextDirection.ltr, height: 12),
                      // کارت نقشه
                      Expanded(
                        child: GlassCard(
                          child: Stack(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Center(
                                  child: Icon(Icons.map, color: Colors.blueAccent, size: 64),
                                ),
                              ),
                              Positioned(
                                top: 12,
                                left: 12,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    '0.5 mi - Route 101',
                                    style: TextStyle(color: Colors.white, fontSize: 12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),

                // ستون وسط: سرعت‌سنج دیجیتال نئونی
                Expanded(
                  flex: 4,
                  child: GlassCard(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'RPM x1000',
                          style: TextStyle(color: Colors.cyanAccent, fontSize: 12, letterSpacing: 1.5),
                        ),
                        const SizedBox(height: 20),
                        // دایره سرعت‌سنج
                        Container(
                          width: 220,
                          height: 220,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.cyan.withOpacity(0.5), width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.cyan.withOpacity(0.2),
                                blurRadius: 20,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Text(
                                  '74',
                                  style: TextStyle(
                                    fontSize: 64,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    shadows: [Shadow(color: Colors.cyanAccent, blurRadius: 10)],
                                  ),
                                ),
                                Text(
                                  'MPH',
                                  style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // ستون سمت راست: مدیا پلیر و وضعیت خودرو
                Expanded(
                  flex: 3,
                  child: Column(
                    children: [
                      // مدیا پلیر
                      Expanded(
                        flex: 5,
                        child: GlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Now Playing', style: TextStyle(color: Colors.orangeAccent, fontSize: 12)),
                              const SizedBox(height: 8),
                              const Text('Track Info', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                              const Text('Tirac Music', style: TextStyle(color: Colors.white54, fontSize: 12)),
                              const Spacer(),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: const [
                                  Icon(Icons.skip_previous, color: Colors.white),
                                  Icon(Icons.play_arrow, color: Colors.orangeAccent, size: 32),
                                  Icon(Icons.skip_next, color: Colors.white),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // وضعیت خودرو (Car Status)
                      Expanded(
                        flex: 4,
                        child: GlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Car Status', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              const Spacer(),
                              Center(
                                child: Icon(
                                  Icons.directions_car,
                                  color: Colors.cyanAccent.withOpacity(0.8),
                                  size: 48,
                                ),
                              ),
                              const Spacer(),
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
      ),
    );
  }
}

// ویجت کمکی برای ایجاد افکت شیشه‌ای (Glassmorphism)
class GlassCard extends StatelessWidget {
  final Widget child;
  const GlassCard({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.sigmaX(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: child,
        ),
      ),
    );
  }
}
