import 'package:flutter/material.dart';

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
        scaffoldBackgroundColor: const Color(0xFF0B0F19),
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
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              // ستون اول: نقشه / ناوبری
              Expanded(
                flex: 2,
                child: GlassContainer(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.navigation, size: 48, color: Colors.cyanAccent),
                      SizedBox(height: 8),
                      Text('Navigation', style: TextStyle(color: Colors.white70, fontSize: 14)),
                      SizedBox(height: 4),
                      Text('GPS Active', style: TextStyle(color: Colors.greenAccent, fontSize: 11)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              
              // ستون دوم: سرعت‌سنج دیجیتال مرکزی
              Expanded(
                flex: 3,
                child: GlassContainer(
                  borderColor: Colors.cyanAccent,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Text('0', style: TextStyle(fontSize: 72, fontWeight: FontWeight.bold, color: Colors.cyanAccent)),
                      Text('KM/H', style: TextStyle(fontSize: 16, color: Colors.white60, letterSpacing: 2)),
                      SizedBox(height: 12),
                      LinearProgressIndicator(value: 0.2, color: Colors.cyanAccent, backgroundColor: Colors.white10),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              
              // ستون سوم: مدیا و وضعیت خودرو
              Expanded(
                flex: 2,
                child: GlassContainer(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.music_note, size: 36, color: Colors.purpleAccent),
                      SizedBox(height: 6),
                      Text('Media Player', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      Divider(color: Colors.white24, height: 20),
                      Icon(Icons.directions_car, size: 36, color: Colors.greenAccent),
                      SizedBox(height: 4),
                      Text('TIBA 2: Ready', style: TextStyle(color: Colors.greenAccent, fontSize: 12)),
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

class GlassContainer extends StatelessWidget {
  final Widget child;
  final Color borderColor;

  const GlassContainer({Key? key, required this.child, this.borderColor = Colors.white24}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 10,
            spreadRadius: 2,
          )
        ],
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: child,
        ),
      ),
    );
  }
}
