import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TibaLauncherApp());
}

class TibaLauncherApp extends StatefulWidget {
  const TibaLauncherApp({super.key});

  @override
  State<TibaLauncherApp> createState() => _TibaLauncherAppState();
}

class _TibaLauncherAppState extends State<TibaLauncherApp> {
  Color _primaryNeon = const Color(0xFF00F0FF);
  double _speedOffset = 0.0;

  void _updateTheme(Color color, double offset) {
    setState(() {
      _primaryNeon = color;
      _speedOffset = offset;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Tiba 2 Launcher',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF070B14),
      ),
      home: DashboardScreen(
        primaryNeon: _primaryNeon,
        speedOffset: _speedOffset,
        onUpdateTheme: _updateTheme,
      ),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  final Color primaryNeon;
  final double speedOffset;
  final Function(Color, double) onUpdateTheme;

  const DashboardScreen({
    super.key,
    required this.primaryNeon,
    required this.speedOffset,
    required this.onUpdateTheme,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  double _rawSpeed = 0.0;
  StreamSubscription<Position>? _positionStream;
  bool _isPlayingMusic = false;
  late AnimationController _equalizerController;

  @override
  void initState() {
    super.initState();
    _initGps();
    _equalizerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _equalizerController.dispose();
    super.dispose();
  }

  Future<void> _initGps() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 0,
    );

    _positionStream =
        Geolocator.getPositionStream(locationSettings: locationSettings)
            .listen((Position position) {
      if (mounted) {
        setState(() {
          // تبدیل متر بر ثانیه به کیلومتر بر ساعت
          double speedKmH = (position.speed * 3.6);
          _rawSpeed = speedKmH > 1.5 ? speedKmH : 0.0;
        });
      }
    });
  }

  int get _displaySpeed {
    int finalSpeed = (_rawSpeed + widget.speedOffset).round();
    return finalSpeed < 0 ? 0 : finalSpeed;
  }

  Future<void> _launchApp(String urlScheme, String webFallback) async {
    final Uri uri = Uri.parse(urlScheme);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      final Uri fallbackUri = Uri.parse(webFallback);
      await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
    }
  }

  void _openSettingsDialog() {
    Color selectedColor = widget.primaryNeon;
    double tempOffset = widget.speedOffset;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'تنظیمات نئون و کالیبراسیون GPS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _colorPickerDot(const Color(0xFF00F0FF), selectedColor,
                          (c) => setModalState(() => selectedColor = c)),
                      _colorPickerDot(const Color(0xFF39FF14), selectedColor,
                          (c) => setModalState(() => selectedColor = c)),
                      _colorPickerDot(const Color(0xFFFF0055), selectedColor,
                          (c) => setModalState(() => selectedColor = c)),
                      _colorPickerDot(const Color(0xFFFFB800), selectedColor,
                          (c) => setModalState(() => selectedColor = c)),
                      _colorPickerDot(const Color(0xFF9D00FF), selectedColor,
                          (c) => setModalState(() => selectedColor = c)),
                    ],
                  ),
                  const SizedBox(height: 25),
                  Text(
                    'افزایش / کاهش خطای سرعت‌سنج: ${tempOffset > 0 ? "+$tempOffset" : tempOffset} km/h',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  Slider(
                    value: tempOffset,
                    min: -15,
                    max: 15,
                    divisions: 30,
                    activeColor: selectedColor,
                    onChanged: (val) {
                      setModalState(() {
                        tempOffset = val;
                      });
                    },
                  ),
                  const SizedBox(height: 15),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: selectedColor,
                      foregroundColor: Colors.black,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () {
                      widget.onUpdateTheme(selectedColor, tempOffset);
                      Navigator.pop(context);
                    },
                    child: const Text('ذخیره و اعمال',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _colorPickerDot(
      Color color, Color currentSelected, Function(Color) onTap) {
    bool isSel = color.value == currentSelected.value;
    return GestureDetector(
      onTap: () => onTap(color),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: isSel ? Border.all(color: Colors.white, width: 3) : null,
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.6),
              blurRadius: 10,
              spreadRadius: 2,
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            children: [
              // نوار بالایی: ساعت، تظیمات
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(Icons.palette_outlined,
                        color: widget.primaryNeon, size: 28),
                    onPressed: _openSettingsDialog,
                  ),
                  StreamBuilder(
                    stream: Stream.periodic(const Duration(seconds: 1)),
                    builder: (context, snapshot) {
                      final now = DateTime.now();
                      final timeStr =
                          "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
                      return Text(
                        timeStr,
                        style: TextStyle(
                          color: widget.primaryNeon,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                          shadows: [
                            Shadow(
                                color: widget.primaryNeon.withOpacity(0.8),
                                blurRadius: 12)
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),

              // ۳ ستون اصلی داشبورد
              Expanded(
                child: Row(
                  children: [
                    // ستون چپ: مسیریاب‌ها و پلیر موزیک با اکولایزر
                    Expanded(
                      flex: 3,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildNavCard(),
                          const SizedBox(height: 14),
                          _buildMusicCard(),
                        ],
                      ),
                    ),

                    const SizedBox(width: 14),

                    // ستون وسط: کیلومترشمار نئونی با ۳ ثانیه نگه‌داشتن برای تنظیمات
                    Expanded(
                      flex: 4,
                      child: Center(child: _buildSpeedometer()),
                    ),

                    const SizedBox(width: 14),

                    // ستون راست: فقط تیبا ۲ و نام خودرو (بدون هیچ سنسور اضافه)
                    Expanded(
                      flex: 3,
                      child: _buildTibaCarCard(),
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

  Widget _buildNavCard() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withOpacity(0.8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: widget.primaryNeon.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            'NAVIGATION',
            style: TextStyle(
              color: widget.primaryNeon,
              fontWeight: FontWeight.bold,
              fontSize: 12,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNavButton(
                title: 'نشان',
                icon: Icons.navigation_rounded,
                onTap: () => _launchApp('nshn://', 'https://neshan.org/maps'),
              ),
              _buildNavButton(
                title: 'بلد',
                icon: Icons.map_rounded,
                onTap: () => _launchApp('balad://', 'https://balad.ir'),
              ),
              _buildNavButton(
                title: 'گوگل',
                icon: Icons.explore_rounded,
                onTap: () => _launchApp(
                    'google.navigation:q=', 'https://maps.google.com'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNavButton({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        child: Column(
          children: [
            Icon(icon, color: widget.primaryNeon, size: 28),
            const SizedBox(height: 4),
            Text(title,
                style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildMusicCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withOpacity(0.8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: widget.primaryNeon.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.music_note, color: widget.primaryNeon, size: 18),
                  const SizedBox(width: 4),
                  const Text('CAR AUDIO',
                      style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                ],
              ),
              // اکولایزر متحرک نئونی
              _buildAnimatedEqualizer(),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: const Icon(Icons.skip_previous_rounded,
                    color: Colors.white, size: 26),
                onPressed: () {},
              ),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isPlayingMusic = !_isPlayingMusic;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: widget.primaryNeon,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: widget.primaryNeon.withOpacity(0.6),
                        blurRadius: 10,
                      )
                    ],
                  ),
                  child: Icon(
                    _isPlayingMusic ? Icons.pause : Icons.play_arrow_rounded,
                    color: Colors.black,
                    size: 26,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.skip_next_rounded,
                    color: Colors.white, size: 26),
                onPressed: () {},
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildAnimatedEqualizer() {
    return AnimatedBuilder(
      animation: _equalizerController,
      builder: (context, child) {
        return Row(
          children: List.generate(4, (index) {
            double height = _isPlayingMusic
                ? (8 + (12 * ((_equalizerController.value + index * 0.2) % 1)))
                : 4;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 3.5,
              height: height,
              decoration: BoxDecoration(
                color: widget.primaryNeon,
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildSpeedometer() {
    return GestureDetector(
      // باز شدن تنظیمات با ۳ ثانیه نگه‌داشتن روی سرعت‌سنج
      onLongPress: _openSettingsDialog,
      child: Container(
        width: 220,
        height: 220,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF0B132B).withOpacity(0.7),
          border: Border.all(
            color: widget.primaryNeon,
            width: 3.5,
          ),
          boxShadow: [
            BoxShadow(
              color: widget.primaryNeon.withOpacity(0.35),
              blurRadius: 28,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$_displaySpeed',
              style: TextStyle(
                color: Colors.white,
                fontSize: 68,
                fontWeight: FontWeight.w900,
                letterSpacing: -2,
                shadows: [
                  Shadow(
                    color: widget.primaryNeon,
                    blurRadius: 20,
                  )
                ],
              ),
            ),
            Text(
              'KM/H',
              style: TextStyle(
                color: widget.primaryNeon,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'GPS LIVE',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 10,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTibaCarCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withOpacity(0.8),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: widget.primaryNeon.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'TIBA 2',
            style: TextStyle(
              color: widget.primaryNeon,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: 3,
              shadows: [
                Shadow(
                  color: widget.primaryNeon.withOpacity(0.7),
                  blurRadius: 10,
                )
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Center(
              child: Image.asset(
                'tiba2.png',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Image.asset(
                    'assets/tiba2.png',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        Icons.directions_car_filled_rounded,
                        color: widget.primaryNeon,
                        size: 90,
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
