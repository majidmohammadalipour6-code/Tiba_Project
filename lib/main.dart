import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

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
        scaffoldBackgroundColor: const Color(0xFF04060A),
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

class _DashboardScreenState extends State<DashboardScreen> with SingleTickerProviderStateMixin {
  double _rawSpeed = 0.0;
  double _speedCalibration = 1.0; // ضریب کالیبره GPS (مثلاً 1.05 یا 0.95)
  StreamSubscription<Position>? _positionStream;
  late Color _currentColor;
  late double _currentIntensity;

  // وضعیت موزیک پلیر و اکولایزر
  bool _isPlaying = false;
  List<String> _musicFiles = [];
  int _currentTrackIndex = 0;
  String _currentTrackName = "آماده پخش";
  late AnimationController _equalizerController;

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
    _scanMusicFiles();

    _equalizerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    )..addListener(() {
        if (_isPlaying) setState(() {});
      });
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
            double kmh = (position.speed * 3.6);
            _rawSpeed = kmh < 1.2 ? 0.0 : kmh;
          });
        }
      },
    );
  }

  // جستجوی فایل‌های موزیک در حافظه دستگاه
  Future<void> _scanMusicFiles() async {
    try {
      List<String> found = [];
      List<Directory> searchDirs = [
        Directory('/storage/emulated/0/Music'),
        Directory('/storage/emulated/0/Download'),
      ];

      for (var dir in searchDirs) {
        if (await dir.exists()) {
          final files = dir.listSync(recursive: false);
          for (var f in files) {
            if (f is File && (f.path.endsWith('.mp3') || f.path.endsWith('.wav') || f.path.endsWith('.m4a'))) {
              found.add(f.path);
            }
          }
        }
      }

      if (mounted && found.isNotEmpty) {
        setState(() {
          _musicFiles = found;
          _currentTrackName = found.first.split('/').last;
        });
      }
    } catch (_) {
      // در صورت محدودیت دسترسی پیش‌فرض
    }
  }

  void _togglePlayPause() {
    setState(() {
      _isPlaying = !_isPlaying;
      if (_isPlaying) {
        _equalizerController.repeat(reverse: true);
        if (_musicFiles.isNotEmpty) {
          _currentTrackName = _musicFiles[_currentTrackIndex].split('/').last;
        } else {
          _currentTrackName = "در حال پخش...";
        }
      } else {
        _equalizerController.stop();
      }
    });
  }

  void _nextTrack() {
    if (_musicFiles.isEmpty) return;
    setState(() {
      _currentTrackIndex = (_currentTrackIndex + 1) % _musicFiles.length;
      _currentTrackName = _musicFiles[_currentTrackIndex].split('/').last;
    });
  }

  void _prevTrack() {
    if (_musicFiles.isEmpty) return;
    setState(() {
      _currentTrackIndex = (_currentTrackIndex - 1 + _musicFiles.length) % _musicFiles.length;
      _currentTrackName = _musicFiles[_currentTrackIndex].split('/').last;
    });
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
      backgroundColor: const Color(0xFF0A0F1A),
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
                        'تنظیمات داشبورد و کالیبره GPS',
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

                  // کالیبراسیون GPS
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('کالیبراسیون سرعت GPS:', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      Text(
                        '${((_speedCalibration - 1.0) * 100).toStringAsFixed(0)}%',
                        style: TextStyle(color: _currentColor, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Slider(
                    value: _speedCalibration,
                    min: 0.80,
                    max: 1.20,
                    divisions: 40,
                    activeColor: _currentColor,
                    inactiveColor: Colors.white12,
                    onChanged: (val) {
                      setModalState(() => _speedCalibration = val);
                      setState(() => _speedCalibration = val);
                    },
                  ),
                  const SizedBox(height: 14),

                  // پالت رنگ
                  const Text('انتخاب تم رنگی نئون:', style: TextStyle(color: Colors.white70, fontSize: 13)),
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
                  const SizedBox(height: 20),

                  Text(
                    'روشنایی و نور نئون (${(_currentIntensity * 100).toInt()}%):',
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
    _equalizerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Color glow = _currentColor.withOpacity(_currentIntensity);
    double displaySpeed = _rawSpeed * _speedCalibration;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            children: [
              // هدر بالا
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.speed, color: glow, size: 22),
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
                    // ۱. ستون سمت چپ: مسیریاب‌ها + موزیک‌پلیر همراه اکولایزر
                    Expanded(
                      flex: 4,
                      child: Column(
                        children: [
                          // دکمه‌های مسیریابی سریع
                          _glassCard(
                            glow,
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _appMiniBtn('نشان', const Color(0xFFEE4036), () => _openApp('nshn://', 'https://nshn.ir')),
                                const SizedBox(width: 6),
                                _appMiniBtn('بلد', const Color(0xFF00C853), () => _openApp('balad://', 'https://balad.ir')),
                                const SizedBox(width: 6),
                                _appMiniBtn('مپ', const Color(0xFF2979FF), () => _openApp('google.navigation:q=', 'https://maps.google.com')),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),

                          // پلیر موزیک اختصاصی
                          Expanded(
                            child: _glassCard(
                              glow,
                              Column(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.music_note, color: glow, size: 20),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _currentTrackName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(0.9),
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),

                                  // اکولایزر نئونی متحرک
                                  _buildNeonEqualizer(glow),

                                  // کنترل‌های پلیر
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      IconButton(
                                        icon: Icon(Icons.skip_previous_rounded, color: glow, size: 34),
                                        onPressed: _prevTrack,
                                      ),
                                      const SizedBox(width: 8),
                                      GestureDetector(
                                        onTap: _togglePlayPause,
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: glow.withOpacity(0.2),
                                            border: Border.all(color: glow, width: 2),
                                            boxShadow: [BoxShadow(color: glow.withOpacity(0.5), blurRadius: 12)],
                                          ),
                                          child: Icon(
                                            _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                            color: Colors.white,
                                            size: 34,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: Icon(Icons.skip_next_rounded, color: glow, size: 34),
                                        onPressed: _nextTrack,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),

                    // ۲. ستون وسط: کیلومترشمار دایره‌ای دیجیتال و شیشه‌ای نئونی
                    Expanded(
                      flex: 5,
                      child: GestureDetector(
                        onLongPress: _openSettingsDialog,
                        child: _glassCard(
                          glow,
                          Center(
                            child: SizedBox(
                              width: 250,
                              height: 250,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // خطوط درجه‌بندی دور کیلومتر
                                  CustomPaint(
                                    size: const Size(250, 250),
                                    painter: DialGaugePainter(color: glow, speed: displaySpeed),
                                  ),

                                  // کادر شیشه‌ای و نئونی وسط
                                  Container(
                                    width: 180,
                                    height: 180,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: RadialGradient(
                                        colors: [
                                          const Color(0xFF0F1523).withOpacity(0.95),
                                          glow.withOpacity(0.15 * _currentIntensity),
                                        ],
                                      ),
                                      border: Border.all(color: glow.withOpacity(0.8), width: 3),
                                      boxShadow: [
                                        BoxShadow(
                                          color: glow.withOpacity(0.4 * _currentIntensity),
                                          blurRadius: 35,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          displaySpeed.toStringAsFixed(0),
                                          style: TextStyle(
                                            fontSize: 70,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.white,
                                            shadows: [
                                              Shadow(color: glow, blurRadius: 25),
                                              Shadow(color: glow, blurRadius: 10),
                                            ],
                                          ),
                                        ),
                                        Text(
                                          'KM / H',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 2,
                                            color: glow,
                                            shadows: [Shadow(color: glow, blurRadius: 10)],
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
                      ),
                    ),
                    const SizedBox(width: 12),

                    // ۳. ستون سمت راست: صرفاً عکس تیبا ۲ + تایتل نئونی اختصاصی
                    Expanded(
                      flex: 4,
                      child: _glassCard(
                        glow,
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'TIBA 2',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 4,
                                color: glow,
                                shadows: [Shadow(color: glow, blurRadius: 20)],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Expanded(
                              child: Center(
                                child: Image.network(
                                  'https://raw.githubusercontent.com/Saipa/Assets/main/tiba2.png',
                                  fit: BoxFit.contain,
                                  errorBuilder: (ctx, err, stack) => Icon(
                                    Icons.directions_car_filled_rounded,
                                    size: 150,
                                    color: glow.withOpacity(0.8),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'SPORT EDITION',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 3,
                                color: Colors.white.withOpacity(0.5),
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

  // اکولایزر نئونی زیبا
  Widget _buildNeonEqualizer(Color glow) {
    final rand = math.Random();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(14, (index) {
        double barHeight = _isPlaying ? (10.0 + rand.nextInt(38)) : 6.0;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 2.5),
          width: 5,
          height: barHeight,
          decoration: BoxDecoration(
            color: glow,
            borderRadius: BorderRadius.circular(3),
            boxShadow: [
              BoxShadow(
                color: glow.withOpacity(0.7),
                blurRadius: 6,
              )
            ],
          ),
        );
      }),
    );
  }

  Widget _glassCard(Color glow, Widget child) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0C101A).withOpacity(0.75),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: glow.withOpacity(0.35 * _currentIntensity), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: glow.withOpacity(0.08 * _currentIntensity),
            blurRadius: 20,
          )
        ],
      ),
      child: child,
    );
  }

  Widget _appMiniBtn(String title, Color color, VoidCallback onTap) {
    return Expanded(
      child: SizedBox(
        height: 38,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: color.withOpacity(0.18),
            foregroundColor: Colors.white,
            side: BorderSide(color: color.withOpacity(0.7), width: 1.2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: EdgeInsets.zero,
            elevation: 0,
          ),
          onPressed: onTap,
          child: Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}

// رسم درجه‌بندی عقربه‌ای و دایره‌ای دور کیلومترشمار نئونی
class DialGaugePainter extends CustomPainter {
  final Color color;
  final double speed;

  DialGaugePainter({required this.color, required this.speed});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final totalTicks = 40;

    for (int i = 0; i < totalTicks; i++) {
      final double angle = (i * (360 / totalTicks)) * (math.pi / 180);
      final bool isHighlight = (i / totalTicks) <= (speed / 200).clamp(0.0, 1.0);

      final p1 = Offset(
        center.dx + (radius - 12) * math.cos(angle),
        center.dy + (radius - 12) * math.sin(angle),
      );
      final p2 = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );

      final paint = Paint()
        ..color = isHighlight ? color : Colors.white12
        ..strokeWidth = isHighlight ? 2.5 : 1.5
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(p1, p2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant DialGaugePainter oldDelegate) {
    return oldDelegate.speed != speed || oldDelegate.color != color;
  }
}
