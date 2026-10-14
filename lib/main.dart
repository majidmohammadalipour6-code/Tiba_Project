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
  double _glowIntensity = 0.85; // شدت نور و شفافیت
  bool _showCarImage = true;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tiba 2 Cockpit HUD',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF06090F),
      ),
      home: DashboardScreen(
        primaryNeon: _primaryNeon,
        glowIntensity: _glowIntensity,
        showCarImage: _showCarImage,
        onThemeChanged: (color, intensity, showCar) {
          setState(() {
            _primaryNeon = color;
            _glowIntensity = intensity;
            _showCarImage = showCar;
          });
        },
      ),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  final Color primaryNeon;
  final double glowIntensity;
  final bool showCarImage;
  final Function(Color, double, bool) onThemeChanged;

  const DashboardScreen({
    super.key,
    required this.primaryNeon,
    required this.glowIntensity,
    required this.showCarImage,
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
  late bool _currentShowCar;

  final List<Color> _presetColors = [
    const Color(0xFF00F0FF), // سایبر فیروزه‌ای
    const Color(0xFFFF0055), // قرمز اسپرت
    const Color(0xFF00FF66), // سبز نئون
    const Color(0xFFFFB703), // نارنجی مسابقه‌ای
    const Color(0xFF9D4EDD), // بنفش سایبر
    const Color(0xFFFFFFFF), // سفید یخی
  ];

  @override
  void initState() {
    super.initState();
    _currentColor = widget.primaryNeon;
    _currentIntensity = widget.glowIntensity;
    _currentShowCar = widget.showCarImage;
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
      backgroundColor: const Color(0xFF0E131F),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'شخصی‌سازی HUD تیبا ۲',
                        style: TextStyle(
                          color: _currentColor,
                          fontSize: 18,
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
                  const SizedBox(height: 8),

                  // انتخاب رنگ
                  const Text('پالت رنگ نئون داشبورد:', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: _presetColors.map((color) {
                      bool isSelected = _currentColor.value == color.value;
                      return GestureDetector(
                        onTap: () {
                          setModalState(() => _currentColor = color);
                          setState(() => _currentColor = color);
                          widget.onThemeChanged(_currentColor, _currentIntensity, _currentShowCar);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? Colors.white : Colors.transparent,
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: color.withOpacity(isSelected ? 0.8 : 0.2),
                                blurRadius: isSelected ? 14 : 4,
                              )
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // اسلایدر شدت نور و روشنایی
                  Text(
                    'شدت و پررنگی نور نئون (${(_currentIntensity * 100).toInt()}%):',
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
                      widget.onThemeChanged(_currentColor, _currentIntensity, _currentShowCar);
                    },
                  ),

                  // کلید نمایش تصویر ماشین تیبا
                  SwitchListTile(
                    title: const Text('نمایش تصویر سه بعدی تیبا ۲', style: TextStyle(fontSize: 14)),
                    activeColor: _currentColor,
                    contentPadding: EdgeInsets.zero,
                    value: _currentShowCar,
                    onChanged: (val) {
                      setModalState(() => _currentShowCar = val);
                      setState(() => _currentShowCar = val);
                      widget.onThemeChanged(_currentColor, _currentIntensity, _currentShowCar);
                    },
                  ),
                  const SizedBox(height: 12),
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
          // تصویر پس‌زمینه ماشین تیبا ۲
          if (_currentShowCar)
            Positioned.fill(
              child: Opacity(
                opacity: 0.28 * _currentIntensity,
                child: Image.asset(
                  'assets/tiba.png',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [glow.withOpacity(0.15), Colors.transparent],
                        radius: 0.9,
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // خطوط نئونی بالا و پایین شبیه کابین سایبرپانک
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 10.0),
              child: Column(
                children: [
                  // نوار بالای صفحه
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.directions_car, color: glow, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            'TIBA 2 CYBER COCKPIT',
                            style: TextStyle(
                              color: glow,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2.2,
                              shadows: [Shadow(color: glow, blurRadius: 16)],
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: Icon(Icons.tune_rounded, color: glow, size: 26),
                        onPressed: _openSettingsDialog,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // بدنه اصلی ۳ بخشی لانچر
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
                                      Text(
                                        'مسیریابی هوشمند',
                                        style: TextStyle(color: glow, fontSize: 13, fontWeight: FontWeight.bold),
                                      ),
                                      _appTile('نشان', const Color(0xFFEE4036), () => _openApp('nshn://', 'https://nshn.ir')),
                                      _appTile('بلد', const Color(0xFF00C853), () => _openApp('balad://', 'https://balad.ir')),
                                      _appTile('گوگل مپ', const Color(0xFF2979FF), () => _openApp('google.navigation:q=', 'https://maps.google.com')),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Expanded(
                                flex: 4,
                                child: _glassCard(
                                  glow,
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                                    children: [
                                      Icon(Icons.skip_previous, color: glow, size: 30),
                                      Icon(Icons.play_circle_fill, color: glow, size: 42),
                                      Icon(Icons.skip_next, color: glow, size: 30),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),

                        // ۲. ستون وسط: سرعت‌سنج HUD با لمس ۳ ثانیه‌ای
                        Expanded(
                          flex: 5,
                          child: GestureDetector(
                            onLongPress: _openSettingsDialog,
                            child: _glassCard(
                              glow,
                              Center(
                                child: Container(
                                  width: 200,
                                  height: 200,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: glow, width: 3.5),
                                    boxShadow: [
                                      BoxShadow(
                                        color: glow.withOpacity(0.35 * _currentIntensity),
                                        blurRadius: 35,
                                        spreadRadius: 4,
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        _currentSpeed.toStringAsFixed(0),
                                        style: TextStyle(
                                          fontSize: 66,
                                          fontWeight: FontWeight.w900,
                                          color: glow,
                                          shadows: [
                                            Shadow(color: glow, blurRadius: 20),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        'KM / H',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
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
                        const SizedBox(width: 14),

                        // ۳. ستون راست: وضعیت سنسورها و تیبا ۲
                        Expanded(
                          flex: 3,
                          child: _glassCard(
                            glow,
                            Column(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                Text('سنسورهای خودرو', style: TextStyle(color: glow, fontSize: 13, fontWeight: FontWeight.bold)),
                                _sensorBox(Icons.battery_charging_full, 'ولتاژ دینام', '14.1 V', Colors.greenAccent),
                                _sensorBox(Icons.thermostat, 'دمای آب', '89 °C', Colors.amberAccent),
                                _sensorBox(Icons.speed, 'دور موتور تقریبی', '850 RPM', Colors.cyanAccent),
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
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: glow.withOpacity(0.35 * _currentIntensity), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: glow.withOpacity(0.08 * _currentIntensity),
            blurRadius: 18,
            spreadRadius: 1,
          )
        ],
      ),
      child: child,
    );
  }

  Widget _appTile(String title, Color color, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      height: 42,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withOpacity(0.2),
          foregroundColor: Colors.white,
          side: BorderSide(color: color.withOpacity(0.8), width: 1.2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        onPressed: onTap,
        child: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _sensorBox(IconData icon, String label, String value, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(fontSize: 11, color: Colors.white70)),
            ],
          ),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}
