import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const TibaLauncherApp());
}

class TibaLauncherApp extends StatefulWidget {
  const TibaLauncherApp({super.key});

  @override
  State<TibaLauncherApp> createState() => _TibaLauncherAppState();
}

class _TibaLauncherAppState extends State<TibaLauncherApp> {
  // رنگ پایه تم نئونی پیش‌فرض
  Color _themeColor = const Color(0xFF00E5FF);
  double _glowIntensity = 1.0;

  void _updateTheme(Color color, double glow) {
    setState(() {
      _themeColor = color;
      _glowIntensity = glow;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tiba 2 Launcher',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF070B14),
      ),
      home: DashboardScreen(
        themeColor: _themeColor,
        glowIntensity: _glowIntensity,
        onThemeChanged: _updateTheme,
      ),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  final Color themeColor;
  final double glowIntensity;
  final Function(Color, double) onThemeChanged;

  const DashboardScreen({
    super.key,
    required this.themeColor,
    required this.glowIntensity,
    required this.onThemeChanged,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  static const MethodChannel _platformLegacy =
      MethodChannel('com.tiba.launcher/methods');
  static const EventChannel _speedEvent =
      EventChannel('com.tiba.launcher/speed');
  static const MethodChannel _platformActions =
      MethodChannel('com.tiba2.launcher/actions');

  double _speed = 0.0;
  double _calibrationFactor = 1.0;
  String _selectedNavApp = 'نشان';
  StreamSubscription? _speedSubscription;

  late AnimationController _roadAnimController;
  late AnimationController _equalizerController;

  // وضعیت موزیک پلیر
  bool _isPlaying = true;
  String _currentTrackTitle = 'آهنگ پیش‌فرض تیبا ۲';
  double _musicProgress = 0.35;

  Color get _neon => widget.themeColor.withOpacity(widget.glowIntensity.clamp(0.4, 1.0));
  Color get _neon2 => widget.themeColor;

  @override
  void initState() {
    super.initState();
    _initSpeedStream();

    _roadAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();

    _equalizerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
  }

  void _initSpeedStream() {
    try {
      _speedSubscription = _speedEvent
          .receiveBroadcastStream()
          .listen((dynamic event) {
        if (event is num) {
          setState(() {
            _speed = (event.toDouble() * _calibrationFactor).clamp(0.0, 160.0);
            _updateRoadSpeed();
          });
        }
      }, onError: (dynamic error) {
        debugPrint('Speed error: $error');
      });
    } catch (e) {
      debugPrint('Channel setup error: $e');
    }
  }

  void _updateRoadSpeed() {
    int durationMs = (1200 - (_speed * 6.5)).clamp(180, 1200).toInt();
    _roadAnimController.duration = Duration(milliseconds: durationMs);
    if (!_roadAnimController.isAnimating) {
      _roadAnimController.repeat();
    }
  }

  @override
  void dispose() {
    _speedSubscription?.cancel();
    _roadAnimController.dispose();
    _equalizerController.dispose();
    super.dispose();
  }

  Future<bool> _tryInvoke(MethodChannel ch, String method,
      [Map<String, dynamic>? args]) async {
    try {
      await ch.invokeMethod(method, args ?? <String, dynamic>{});
      return true;
    } catch (e) {
      debugPrint("Native invoke error: $e");
      return false;
    }
  }

  Future<void> _openAction(String action,
      {Map<String, dynamic>? extras, String? legacyMethod}) async {
    final ok = await _tryInvoke(_platformActions, 'open', <String, dynamic>{
      'action': action,
      if (extras != null) ...extras,
    });
    if (ok) return;

    if (legacyMethod != null) {
      await _tryInvoke(_platformLegacy, legacyMethod, extras);
      return;
    }

    await _tryInvoke(_platformLegacy, 'open', <String, dynamic>{
      'action': action,
      if (extras != null) ...extras,
    });
  }

  // انتخاب فایل موزیک با دیالوگ مستقیم و ارسال اینتنت فایل منیجر اندروید
  Future<void> _pickMusicFiles() async {
    await _openAction('music_files', legacyMethod: 'openMusicFiles');
    // دیالوگ لیست موزیک برای انتخاب ترک‌های محلی داخل خودرو
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final mockTracks = [
          'Track 01 - Persian Remix Bass.mp3',
          'Track 02 - Deep Car Electro.mp3',
          'Track 03 - Tiba2 Night Drive.mp3',
          'باز کردن پوشه Music در حافظه داخلی...',
        ];
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('انتخاب فایل موسیقی',
                      style: TextStyle(
                          color: _neon,
                          fontSize: 15,
                          fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.pop(context),
                  )
                ],
              ),
              const Divider(color: Colors.white24),
              ...mockTracks.map((title) => ListTile(
                    leading: Icon(
                      title.contains('حافظه')
                          ? Icons.folder_open
                          : Icons.music_note,
                      color: _neon,
                    ),
                    title: Text(title,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 13)),
                    onTap: () {
                      setState(() {
                        if (!title.contains('حافظه')) {
                          _currentTrackTitle = title;
                          _isPlaying = true;
                          _equalizerController.repeat(reverse: true);
                        }
                      });
                      Navigator.pop(context);
                    },
                  )),
            ],
          ),
        );
      },
    );
  }

  void _togglePlayPause() {
    setState(() {
      _isPlaying = !_isPlaying;
      if (_isPlaying) {
        _equalizerController.repeat(reverse: true);
      } else {
        _equalizerController.stop();
      }
    });
    _openAction('music_play_pause', legacyMethod: 'musicPlayPause');
  }

  // دیالوگ تنظیمات رنگ‌بندی و شدت نور نئون
  void _showColorAndBrightnessDialog() {
    final colors = [
      {'name': 'آبی سایبری', 'color': const Color(0xFF00E5FF)},
      {'name': 'سبز نئون', 'color': const Color(0xFF00F562)},
      {'name': 'سرخ مسابقه‌ای', 'color': const Color(0xFFFF2A55)},
      {'name': 'بنفش الکتریک', 'color': const Color(0xFFBF00FF)},
      {'name': 'کهربایی / نارنجی', 'color': const Color(0xFFFF9100)},
    ];

    Color selectedColor = widget.themeColor;
    double glow = widget.glowIntensity;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF101728),
              title: Row(
                children: [
                  Icon(Icons.palette_rounded, color: _neon),
                  const SizedBox(width: 8),
                  const Text('تنظیمات رنگ و روشنایی نئون',
                      style: TextStyle(color: Colors.white, fontSize: 15)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('انتخاب تم رنگی:',
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: colors.map((item) {
                      final c = item['color'] as Color;
                      final isSelected = selectedColor.value == c.value;
                      return GestureDetector(
                        onTap: () {
                          setDialogState(() => selectedColor = c);
                          widget.onThemeChanged(selectedColor, glow);
                        },
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? Colors.white : Colors.transparent,
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: c.withOpacity(0.6),
                                blurRadius: isSelected ? 12 : 4,
                              )
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  Text('شدت روشنایی و درخشش: ${(glow * 100).toInt()}%',
                      style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  Slider(
                    value: glow,
                    min: 0.3,
                    max: 1.0,
                    activeColor: selectedColor,
                    onChanged: (val) {
                      setDialogState(() => glow = val);
                      widget.onThemeChanged(selectedColor, glow);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('بستن', style: TextStyle(color: selectedColor)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showCalibrationDialog() {
    showDialog(
      context: context,
      builder: (context) {
        double tempFactor = _calibrationFactor;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF101728),
              title: Text('تنظیمات ماهواره و کالیبراسیون GPS',
                  style: TextStyle(color: _neon, fontSize: 15)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'ضریب کالیبراسیون سرعت: ${tempFactor.toStringAsFixed(2)}x',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  Slider(
                    value: tempFactor,
                    min: 0.7,
                    max: 1.3,
                    divisions: 12,
                    activeColor: _neon,
                    onChanged: (val) {
                      setDialogState(() => tempFactor = val);
                      setState(() => _calibrationFactor = val);
                    },
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _neon.withOpacity(0.2),
                      side: BorderSide(color: _neon.withOpacity(0.9)),
                    ),
                    onPressed: () async {
                      await _openAction('location_settings',
                          legacyMethod: 'openLocationSettings');
                    },
                    icon: Icon(Icons.location_on, color: _neon),
                    label: const Text('تنظیمات موقعیت مکانی اندروید',
                        style: TextStyle(color: Colors.white, fontSize: 12)),
                  )
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('تأیید', style: TextStyle(color: _neon)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showNavAppSelector() {
    final apps = ['نشان', 'بلد', 'گوگل مپ', 'ویز'];
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF101728),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('انتخاب مسیریاب پیش‌فرض',
                  style: TextStyle(
                      color: _neon,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              Divider(color: _neon.withOpacity(0.8)),
              ...apps.map((app) => ListTile(
                    title: Text(app, style: const TextStyle(color: Colors.white)),
                    trailing: _selectedNavApp == app
                        ? Icon(Icons.check, color: _neon)
                        : null,
                    onTap: () {
                      setState(() => _selectedNavApp = app);
                      Navigator.pop(context);
                    },
                  )),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final dockWidth = (size.width * 0.08).clamp(65.0, 85.0);

    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            // سایدبار داک سمت چپ
            Container(
              width: dockWidth,
              decoration: BoxDecoration(
                color: const Color(0xFF0B111E).withOpacity(0.95),
                border: Border(
                  right: BorderSide(
                    color: _neon.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildDockIconButton(
                    icon: Icons.settings_rounded,
                    onTap: () => _openAction('settings', legacyMethod: 'openSettings'),
                  ),
                  _buildDockIconButton(
                    icon: Icons.palette_rounded, // دکمه تنظیم رنگ و نور
                    onTap: _showColorAndBrightnessDialog,
                  ),
                  _buildDockIconButton(
                    icon: Icons.navigation_rounded,
                    onTap: () => _openAction('nav',
                        extras: {'app': _selectedNavApp},
                        legacyMethod: 'openNav'),
                  ),
                  _buildDockIconButton(
                    icon: Icons.radio_rounded,
                    onTap: () => _openAction('radio', legacyMethod: 'openRadio'),
                  ),
                  _buildDockIconButton(
                    icon: Icons.phone_in_talk_rounded,
                    onTap: () => _openAction('phone', legacyMethod: 'openPhone'),
                  ),
                  _buildDockIconButton(
                    icon: Icons.apps_rounded,
                    onTap: () => _openAction('apps', legacyMethod: 'openApps'),
                  ),
                ],
              ),
            ),

            // داشبورد اصلی
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Row(
                  children: [
                    Expanded(flex: 3, child: _buildLeftCard()),
                    const SizedBox(width: 10),
                    Expanded(flex: 4, child: _buildCenterColumn()),
                    const SizedBox(width: 10),
                    Expanded(flex: 3, child: _buildRightCard()),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDockIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return AspectRatio(
      aspectRatio: 1.0,
      child: Padding(
        padding: const EdgeInsets.all(5.0),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _neon.withOpacity(0.25),
                  width: 1.2,
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _neon.withOpacity(0.15),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Center(
                child: Icon(icon, color: _neon, size: 24),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLeftCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withOpacity(0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _neon.withOpacity(0.25)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: _showNavAppSelector,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _neon.withOpacity(0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.arrow_drop_down, color: _neon, size: 16),
                        Text(_selectedNavApp,
                            style: TextStyle(color: _neon, fontSize: 11)),
                      ],
                    ),
                  ),
                ),
                StreamBuilder(
                  stream: Stream.periodic(const Duration(seconds: 1)),
                  builder: (context, snapshot) {
                    final now = DateTime.now();
                    final timeStr =
                        "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
                    return Text(
                      timeStr,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => _openAction(
                'nav',
                extras: {'app': _selectedNavApp},
                legacyMethod: 'openNav',
              ),
              child: Container(
                margin: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.black45,
                  border: Border.all(color: Colors.white10),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.map_outlined, color: _neon, size: 48),
                      const SizedBox(height: 8),
                      const Text('لمس جهت باز شدن نقشه',
                          style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCenterColumn() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0B101D).withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _neon.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 6),
          // هدر ستون وسط: دکمه GPS بالا سمت چپ
          Stack(
            alignment: Alignment.center,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: _showCalibrationDialog,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: _neon.withOpacity(0.12),
                        shape: BoxShape.circle,
                        border: Border.all(color: _neon.withOpacity(0.5)),
                      ),
                      child: Icon(Icons.satellite_alt_rounded,
                          color: _neon, size: 18),
                    ),
                  ),
                ),
              ),
              _NeonTitle(
                title: 'TIBA2',
                subtitle: 'تیبا ۲',
                neon: _neon,
                neon2: _neon2,
              ),
            ],
          ),

          // موزیک پلیر اختصاصی با اکولایزر نئونی
          Container(
            margin: const EdgeInsets.fromLTRB(14, 6, 14, 2),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _neon.withOpacity(0.35)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    AnimatedBuilder(
                      animation: _equalizerController,
                      builder: (context, child) {
                        return CustomPaint(
                          size: const Size(40, 18),
                          painter: EqualizerPainter(
                            progress: _isPlaying ? _equalizerController.value : 0.0,
                            color: _neon,
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _currentTrackTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.skip_previous_rounded, color: _neon, size: 20),
                      onPressed: () => _openAction('music_prev', legacyMethod: 'musicPrev'),
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                    IconButton(
                      icon: Icon(
                        _isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                        color: _neon,
                        size: 26,
                      ),
                      onPressed: _togglePlayPause,
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                    IconButton(
                      icon: Icon(Icons.skip_next_rounded, color: _neon, size: 20),
                      onPressed: () => _openAction('music_next', legacyMethod: 'musicNext'),
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: _musicProgress,
                    backgroundColor: Colors.white10,
                    valueColor: AlwaysStoppedAnimation<Color>(_neon),
                    minHeight: 2.2,
                  ),
                ),
              ],
            ),
          ),

          // کیلومتر نئونی با خط نوری پیمایشی بیرونی (بدون عقربه)
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final h = constraints.maxHeight;
                const roadHeight = 125.0;
                const speedoHeight = 150.0;
                final speedoTop = (h - roadHeight) - (speedoHeight * 0.65);

                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // جاده متحرک سه‌بعدی
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      height: roadHeight,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(20)),
                        child: AnimatedBuilder(
                          animation: _roadAnimController,
                          builder: (context, child) {
                            return CustomPaint(
                              painter: RealisticCyberRoadPainter(
                                progress: _roadAnimController.value,
                                neon: _neon,
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                    // خودروی تیبا ۲ در عقب
                    Positioned(
                      bottom: 16,
                      child: Image.asset(
                        'tiba2_rear.png',
                        height: 60,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(Icons.directions_car, color: _neon, size: 48);
                        },
                      ),
                    ),

                    // آرم SAIPA (بالای خودرو و زیر کیلومتر)
                    Positioned(
                      bottom: 84,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF070B14).withOpacity(0.9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _neon.withOpacity(0.5), width: 1),
                          boxShadow: [
                            BoxShadow(
                              color: _neon.withOpacity(0.25),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Text(
                          'SAIPA',
                          style: TextStyle(
                            color: _neon,
                            fontSize: 10,
                            letterSpacing: 3,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),

                    // کیلومترشمار نئونی با خط پیمایشی دور دایره
                    Positioned(
                      top: speedoTop.clamp(2.0, 30.0),
                      left: 0,
                      right: 0,
                      child: SizedBox(
                        height: speedoHeight,
                        child: CustomPaint(
                          painter: CyberArcSpeedometerPainter(
                            speed: _speed,
                            neon: _neon,
                          ),
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 36),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _speed.toInt().toString(),
                                    style: TextStyle(
                                      fontSize: 44,
                                      fontWeight: FontWeight.w900,
                                      fontFamily: 'monospace',
                                      color: Colors.white,
                                      shadows: [
                                        Shadow(
                                          color: _neon.withOpacity(0.9),
                                          blurRadius: 18,
                                        ),
                                        Shadow(
                                          color: _neon.withOpacity(0.5),
                                          blurRadius: 32,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    'KM/H',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 2,
                                      color: _neon,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // وضعیت دنده‌ها
                    Positioned(
                      bottom: 2,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildGearText('P', false),
                          _buildGearText('R', false),
                          _buildGearText('N', false),
                          _buildGearText('D', true),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGearText(String gear, bool active) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Text(
        gear,
        style: TextStyle(
          color: active ? _neon : Colors.white24,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          shadows: active ? [Shadow(color: _neon, blurRadius: 8)] : null,
        ),
      ),
    );
  }

  // پنل سمت راست: عکس خودرو + دکمه باز کردن فایل‌های موزیک
  Widget _buildRightCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withOpacity(0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _neon.withOpacity(0.25)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _neon.withOpacity(0.15),
                side: BorderSide(color: _neon.withOpacity(0.6)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                minimumSize: const Size(double.infinity, 38),
              ),
              onPressed: _pickMusicFiles,
              icon: Icon(Icons.folder_open_rounded, color: _neon, size: 20),
              label: const Text(
                'پوشه و فایل‌های موزیک',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Image.asset(
                'tiba2.png',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Center(
                    child: Icon(Icons.car_rental, color: _neon, size: 50),
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

class _NeonTitle extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color neon;
  final Color neon2;

  const _NeonTitle({
    required this.title,
    required this.subtitle,
    required this.neon,
    required this.neon2,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: 5,
            color: Colors.white,
            shadows: [
              Shadow(color: neon.withOpacity(0.9), blurRadius: 16),
              Shadow(color: neon2.withOpacity(0.6), blurRadius: 28),
            ],
          ),
        ),
        const SizedBox(height: 1),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 2,
            fontWeight: FontWeight.bold,
            color: neon,
            shadows: [
              Shadow(color: neon.withOpacity(0.8), blurRadius: 12),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// نقاش کیلومتر با خط نوری پیمایشی بیرونی (بدون عقربه)
// ---------------------------------------------------------------------------
class CyberArcSpeedometerPainter extends CustomPainter {
  final double speed;
  final Color neon;

  CyberArcSpeedometerPainter({required this.speed, required this.neon});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.95);
    final radius = math.min(size.width * 0.46, 120.0);

    const startAngle = math.pi;
    const sweepAngle = math.pi;

    // ۱. قوس خاکستری پس‌زمینه
    final bgPaint = Paint()
      ..color = Colors.white12
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      bgPaint,
    );

    // محاسبه درصد پیشرفت بر مبنای سرعت (حداکثر ۱۶۰)
    final progress = (speed / 140.0).clamp(0.0, 1.0);

    // ۲. خط نوری نئونی درخشان بیرونی که با سرعت پیمایش می‌شود
    if (progress > 0) {
      final glowPaint = Paint()
        ..color = neon.withOpacity(0.4)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 10.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle * progress,
        false,
        glowPaint,
      );

      final activeLinePaint = Paint()
        ..color = neon
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 4.5;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle * progress,
        false,
        activeLinePaint,
      );

      // نقطه یا سر نوری در نوک خط پیمایش
      final tipAngle = startAngle + (sweepAngle * progress);
      final tipX = center.dx + radius * math.cos(tipAngle);
      final tipY = center.dy + radius * math.sin(tipAngle);
      
      final tipPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 3);
      canvas.drawCircle(Offset(tipX, tipY), 4.5, tipPaint);
    }

    // ۳. درجه‌ها و شماره‌ها
    const totalDivisions = 14;
    for (int i = 0; i <= totalDivisions; i++) {
      final angle = startAngle + (sweepAngle * (i / totalDivisions));
      final isMajor = i % 2 == 0;
      final tickLength = isMajor ? 8.0 : 4.0;

      final p1 = Offset(
        center.dx + (radius - 5) * math.cos(angle),
        center.dy + (radius - 5) * math.sin(angle),
      );
      final p2 = Offset(
        center.dx + (radius - 5 - tickLength) * math.cos(angle),
        center.dy + (radius - 5 -
