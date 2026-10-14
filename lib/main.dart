import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

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
  double _glowIntensity = 0.85;

  void _updateTheme(Color color, double glow) {
    setState(() {
      _primaryNeon = color;
      _glowIntensity = glow;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tiba 2 Cyber HUD',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF05070D),
      ),
      home: DashboardScreen(
        primaryNeon: _primaryNeon,
        glowIntensity: _glowIntensity,
        onThemeChanged: _updateTheme,
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

class _DashboardScreenState extends State<DashboardScreen> with TickerProviderStateMixin {
  double _currentSpeed = 0.0;
  double _calibrationFactor = 1.0;
  StreamSubscription<Position>? _positionStream;

  // Music Player States
  bool _isPlaying = false;
  late AnimationController _equalizerController;
  final List<double> _eqBars = [0.3, 0.7, 0.4, 0.9, 0.5, 0.8, 0.2, 0.6];

  @override
  void initState() {
    super.initState();
    _startGpsSpeedometer();
    _equalizerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..addListener(() {
        if (_isPlaying) {
          setState(() {
            for (int i = 0; i < _eqBars.length; i++) {
              _eqBars[i] = (Random().nextDouble() * 0.8) + 0.2;
            }
          });
        }
      });
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _equalizerController.dispose();
    super.dispose();
  }

  Future<void> _startGpsSpeedometer() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 1,
      ),
    ).listen((Position pos) {
      if (pos.speed >= 0) {
        setState(() {
          _currentSpeed = (pos.speed * 3.6) * _calibrationFactor;
        });
      }
    });
  }

  Future<void> _launchApp(String uriScheme, String fallbackUrl) async {
    final uri = Uri.parse(uriScheme);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(Uri.parse(fallbackUrl), mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      // Fallback
    }
  }

  void _openSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0C101A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'HUD Settings',
                        style: TextStyle(
                          color: widget.primaryNeon,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'GPS Calibration: ${((_calibrationFactor - 1.0) * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  Slider(
                    value: _calibrationFactor,
                    min: 0.8,
                    max: 1.2,
                    divisions: 40,
                    activeColor: widget.primaryNeon,
                    onChanged: (val) {
                      setModalState(() => _calibrationFactor = val);
                      setState(() => _calibrationFactor = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  const Text('Neon Theme:', style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _colorPreset(const Color(0xFF00F0FF)),
                      const SizedBox(width: 14),
                      _colorPreset(const Color(0xFF00FF66)),
                      const SizedBox(width: 14),
                      _colorPreset(const Color(0xFFFF0055)),
                      const SizedBox(width: 14),
                      _colorPreset(const Color(0xFFFFB700)),
                      const SizedBox(width: 14),
                      _colorPreset(const Color(0xFFB000FF)),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _colorPreset(Color color) {
    bool isSelected = widget.primaryNeon.value == color.value;
    return GestureDetector(
      onTap: () {
        widget.onThemeChanged(color, widget.glowIntensity);
        Navigator.pop(context);
      },
      child: Container(
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
              color: color.withOpacity(0.5),
              blurRadius: 10,
              spreadRadius: 1,
            ),
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
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'TIBA 2 CYBER HUD',
                    style: TextStyle(
                      color: widget.primaryNeon,
                      letterSpacing: 3,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      shadows: [
                        Shadow(color: widget.primaryNeon, blurRadius: 12),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.tune_rounded, color: widget.primaryNeon),
                    onPressed: _openSettings,
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // 3-Column Main Content
              Expanded(
                child: Row(
                  children: [
                    // Left Column: Nav + Music Player
                    Expanded(
                      flex: 3,
                      child: Column(
                        children: [
                          _buildNavCard(),
                          const SizedBox(height: 12),
                          Expanded(child: _buildMusicPlayerCard()),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Center Column: Circular Neon Speedometer
                    Expanded(
                      flex: 4,
                      child: GestureDetector(
                        onLongPress: _openSettings,
                        child: _buildSpeedometerCard(),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Right Column: Dedicated Tiba 2 Image & Header Only
                    Expanded(
                      flex: 3,
                      child: _buildCarDisplayCard(),
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
      padding: const EdgeInsets.all(12),
      decoration: _cyberGlassDecoration(),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navIconBtn('Neshan', Icons.navigation_rounded, () {
            _launchApp('nshn://', 'https://neshan.org');
          }),
          _navIconBtn('Balad', Icons.alt_route_rounded, () {
            _launchApp('balad://', 'https://balad.ir');
          }),
          _navIconBtn('Google', Icons.map_rounded, () {
            _launchApp('geo:0,0', 'https://maps.google.com');
          }),
        ],
      ),
    );
  }

  Widget _navIconBtn(String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.primaryNeon.withOpacity(0.12),
              border: Border.all(color: widget.primaryNeon.withOpacity(0.4)),
            ),
            child: Icon(icon, color: widget.primaryNeon, size: 22),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildMusicPlayerCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cyberGlassDecoration(),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.graphic_eq_rounded, color: widget.primaryNeon, size: 20),
              const SizedBox(width: 8),
              const Text(
                'NEON EQUALIZER',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          // Equalizer Bars
          SizedBox(
            height: 55,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: _eqBars.map((h) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 6,
                  height: 55 * h,
                  decoration: BoxDecoration(
                    color: widget.primaryNeon,
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                        color: widget.primaryNeon.withOpacity(widget.glowIntensity * 0.7),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          // Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.skip_previous_rounded, color: Colors.white70),
                onPressed: () {},
              ),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isPlaying = !_isPlaying;
                    if (_isPlaying) {
                      _equalizerController.repeat();
                    } else {
                      _equalizerController.stop();
                    }
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.primaryNeon,
                    boxShadow: [
                      BoxShadow(
                        color: widget.primaryNeon.withOpacity(0.5),
                        blurRadius: 14,
                      ),
                    ],
                  ),
                  child: Icon(
                    _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Colors.black,
                    size: 26,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.skip_next_rounded, color: Colors.white70),
                onPressed: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSpeedometerCard() {
    return Container(
      decoration: _cyberGlassDecoration(),
      child: Center(
        child: AspectRatio(
          aspectRatio: 1,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer Glow Dial
              Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: widget.primaryNeon.withOpacity(0.35),
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: widget.primaryNeon.withOpacity(0.18 * widget.glowIntensity),
                      blurRadius: 30,
                      spreadRadius: 6,
                    ),
                  ],
                ),
              ),
              // Dial Arcs
              SizedBox(
                width: 210,
                height: 210,
                child: CircularProgressIndicator(
                  value: (_currentSpeed.clamp(0, 200)) / 200.0,
                  strokeWidth: 9,
                  backgroundColor: Colors.white.withOpacity(0.06),
                  valueColor: AlwaysStoppedAnimation<Color>(widget.primaryNeon),
                ),
              ),
              // Speed Digits
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _currentSpeed.toInt().toString(),
                    style: TextStyle(
                      fontSize: 66,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'monospace',
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: widget.primaryNeon,
                          blurRadius: 20 * widget.glowIntensity,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'KM / H',
                    style: TextStyle(
                      color: widget.primaryNeon,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 3,
                      fontSize: 13,
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

  Widget _buildCarDisplayCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: _cyberGlassDecoration(),
      child: Column(
        children: [
          // Header Only
          Text(
            'TIBA 2',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: 4,
              color: widget.primaryNeon,
              shadows: [
                Shadow(color: widget.primaryNeon, blurRadius: 14),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Center(
              child: Image.asset(
                'assets/tiba2.png',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.directions_car_filled_rounded,
                    size: 130,
                    color: widget.primaryNeon.withOpacity(0.7),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _cyberGlassDecoration() {
    return BoxDecoration(
      color: const Color(0xFF0F1523).withOpacity(0.72),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: widget.primaryNeon.withOpacity(0.28),
        width: 1.2,
      ),
      boxShadow: [
        BoxShadow(
          color: widget.primaryNeon.withOpacity(0.08 * widget.glowIntensity),
          blurRadius: 18,
          spreadRadius: 2,
        ),
      ],
    );
  }
}
