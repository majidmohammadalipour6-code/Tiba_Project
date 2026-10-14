import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';

void main() {
  runApp(const TibaLauncherApp());
}

class TibaLauncherApp extends StatefulWidget {
  const TibaLauncherApp({super.key});

  @override
  State<TibaLauncherApp> createState() => _TibaLauncherAppState();
}

class _TibaLauncherAppState extends State<TibaLauncherApp> {
  Color _primaryNeon = const Color(0xFF00F0FF);
  double _glowIntensity = 0.85;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tiba 2 Cockpit HUD',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF060911),
      ),
      home: DashboardScreen(
        primaryNeon: _primaryNeon,
        glowIntensity: _glowIntensity,
        onThemeChanged: (color, intensity) {
          setState(() {
            _primaryNeon = color;
            _glowIntensity = intensity;
          });
        },
      ),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  final Color primaryNeon;
  final double glowIntensity;
  final Function(Color, double) onThemeChanged;

  const DashboardScreen({
    super.key,
    required this.primaryNeon,
    required this.glowIntensity,
    required this.onThemeChanged,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  double _currentSpeed = 0.0;
  StreamSubscription<Position>? _positionStream;
  late Color _currentColor;
  late double _currentIntensity;

  final List<Color> _presetColors = [
    const Color(0xFF00F0FF), // فیروزه‌ای
    const Color(0xFFFF0055), // قرمز اسپرت
    const Color(0xFF00FF66), // سبز نئون
    const Color(0xFFFFB703), // طلایی نارنجی
    const Color(0xFFA855F7), // بنفش نئون
    const Color(0xFFE2E8F0), // سفید یخی
  ];

  @override
  void initState() {
    super.initState();
    _currentColor = widget.primaryNeon;
    _currentIntensity = widget.glowIntensity;
    _initGps();
  }

  Future<void> _initGps() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    const LocationSettings settings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 0,
    );

    _positionStream = Geolocator.getPositionStream(locationSettings: settings).listen(
      (Position position) {
        if (mounted) {
          setState(() {
            double kmh = position.speed * 3.6;
            _currentSpeed = kmh < 1.0 ? 0.0 : kmh;
          });
        }
      },
    );
  }

  Future<void> _openApp(String scheme, String fallbackUrl) async {
    try {
      final Uri uri = Uri.parse(scheme);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalNonBrowserApplication);
      } else {
        await launchUrl(Uri.parse(fallbackUrl), mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      await launchUrl(Uri.parse(fallbackUrl), mode: LaunchMode.externalApplication);
    }
  }

  void _openSettingsDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0C111D),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'تنظیمات رنگ و نور داشبورد تیبا ۲',
                        style: TextStyle(
                          color: _currentColor,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white60),
                        onPressed: () => Navigator.pop(ctx),
                      )
                    ],
                  ),
                  const Divider(color: Colors.white12),
                  const SizedBox(height: 10),

                  const Text('انتخاب رنگ نئون:', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: _presetColors.map((color) {
                      bool isSelected = _currentColor.value == color.value;
                      return GestureDetector(
                        onTap: () {
                          setModalState(() => _currentColor = color);
                          setState(() => _currentColor = color);
                          widget.onThemeChanged(_currentColor, _currentIntensity);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? Colors.white : Colors.transparent,
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: color.withOpacity(isSelected ? 0.9 : 0.2),
                                blurRadius: isSelected ? 14 : 4,
                              )
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  Text(
                    'کمرنگ و پررنگ شدن نور (${(_currentIntensity * 100).toInt()}%):',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  Slider(
                    value: _currentIntensity,
                    min: 0.2,
                    max: 1.0,
                    activeColor: _currentColor,
                    inactiveColor: Colors.white12,
                    onChanged: (val) {
                      setModalState(() => _currentIntensity = val);
                      setState(() => _currentIntensity = val);
                      widget.onThemeChanged(_currentColor, _currentIntensity);
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Color glow = _currentColor.withOpacity(_currentIntensity);

    return Scaffold(
      body: Stack(
        children: [
          // طرح وکتوری نئونی ماشین در مرکز پس‌زمینه
          Positioned.fill(
            child: Opacity(
              opacity: 0.18 * _currentIntensity,
              child: Center(
                child: Icon(
                  Icons.directions_car_filled_outlined,
                  size: 340,
                  color: glow,
                ),
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.directions_car, color: glow, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            'TIBA 2 HUD DASHBOARD',
                            style: TextStyle(
                              color: glow,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                              shadows: [Shadow(color: glow, blurRadius: 15)],
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: Icon(Icons.palette_outlined, color: glow, size: 26),
                        onPressed: _openSettingsDialog,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  Expanded(
                    child: Row(
                      children: [
                        // ۱. ستون چپ: مسیریاب‌ها و پلیر موزیک
                        Expanded(
                          flex: 3,
                          child: Column(
                            children: [
                              Expanded(
                                flex: 6,
                                child: _glassCard(
                                  glow,
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                    children: [
                                      Text('مسیریابی', style: TextStyle(color: glow, fontSize: 13, fontWeight: FontWeight.bold)),
                                      _appBtn('نشان', const Color(0xFFEE4036), () => _openApp('nshn://', 'https://nshn.ir')),
                                      _appBtn('بلد', const Color(0xFF00C853), () => _openApp('balad://', 'https://balad.ir')),
                                      _appBtn('گوگل مپ', const Color(0xFF2979FF), () => _openApp('google.navigation:q=', 'https://maps.google.com')),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Expanded(
                                flex: 4,
                                child: _glassCard(
                                  glow,
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                                    children: [
                                      Icon(Icons.skip_previous, color: glow, size: 30),
                                      Icon(Icons.play_circle_fill, color: glow, size: 44),
                                      Icon(Icons.skip_next, color: glow, size: 30),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),

                        // ۲. ستون وسط: سرعت‌سنج HUD با قابلیت لمس طولانی ۳ ثانیه
                        Expanded(
                          flex: 5,
                          child: GestureDetector(
                            onLongPress: _openSettingsDialog,
                            child: _glassCard(
                              glow,
                              Center(
                                child: Container(
                                  width: 210,
                                  height: 210,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: glow, width: 3.5),
                                    boxShadow: [
                                      BoxShadow(
                                        color: glow.withOpacity(0.35 * _currentIntensity),
                                        blurRadius: 32,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        _currentSpeed.toStringAsFixed(0),
                                        style: TextStyle(
                                          fontSize: 68,
                                          fontWeight: FontWeight.w900,
                                          color: glow,
                                          shadows: [Shadow(color: glow, blurRadius: 20)],
                                        ),
                                      ),
                                      Text(
                                        'KM / H',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 2,
                                          color: Colors.white.withOpacity(0.75),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // ۳. ستون راست: وضعیت سنسورها
                        Expanded(
                          flex: 3,
                          child: _glassCard(
                            glow,
                            Column(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                Text('وضعیت خودرو', style: TextStyle(color: glow, fontSize: 13, fontWeight: FontWeight.bold)),
                                _sensorRow(Icons.battery_charging_full, 'ولتاژ دینام', '14.1 V', Colors.greenAccent),
                                _sensorRow(Icons.thermostat, 'دمای آب', '89 °C', Colors.amberAccent),
                                _sensorRow(Icons.speed, 'دور موتور', '850 RPM', Colors.cyanAccent),
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

  Widget _glassCard(Color glow, Widget child) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1523).withOpacity(0.65),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: glow.withOpacity(0.38 * _currentIntensity), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: glow.withOpacity(0.08 * _currentIntensity),
            blurRadius: 18,
          )
        ],
      ),
      child: child,
    );
  }

  Widget _appBtn(String title, Color color, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      height: 40,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withOpacity(0.2),
          foregroundColor: Colors.white,
          side: BorderSide(color: color.withOpacity(0.8), width: 1.2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 0,
        ),
        onPressed: onTap,
        child: Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _sensorRow(IconData icon, String label, String val, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(fontSize: 11, color: Colors.white70)),
            ],
          ),
          Text(val, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}
