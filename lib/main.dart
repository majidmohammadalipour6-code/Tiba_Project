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

class TibaLauncherApp extends StatelessWidget {
  const TibaLauncherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tiba 2 Launcher',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF070B14),
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

  // انیمیشن جاده
  late AnimationController _roadAnimController;

  // متغیرها و کنترلر موزیک پلیر داخلی و اکولایزر
  bool _isPlaying = true;
  String _currentTrackTitle = 'سیستم صوتی تیبا ۲ (آماده پخش)';
  double _musicProgress = 0.35;
  late AnimationController _equalizerController;

  static const Color _neon = Color(0xFF00E5FF);
  static const Color _neon2 = Color(0xFF00F5D4);

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
    } on PlatformException catch (e) {
      debugPrint("Native invoke failed on ${ch.name}::$method => ${e.message}");
      return false;
    } catch (e) {
      debugPrint("Native invoke unexpected error on ${ch.name}::$method => $e");
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

  void _showCalibrationDialog() {
    showDialog(
      context: context,
      builder: (context) {
        double tempFactor = _calibrationFactor;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF101728),
              title: const Text('تنظیمات ماهواره و کالیبراسیون GPS',
                  style: TextStyle(color: _neon, fontSize: 16)),
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
                      await _openAction(
                        'location_settings',
                        legacyMethod: 'openLocationSettings',
                      );
                    },
                    icon: const Icon(Icons.location_on, color: _neon),
                    label: const Text('باز کردن تنظیمات موقعیت مکانی اندروید',
                        style: TextStyle(color: Colors.white, fontSize: 12)),
                  )
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('تأیید و بستن', style: TextStyle(color: _neon)),
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
              const Text('انتخاب مسیریاب پیش‌فرض',
                  style: TextStyle(
                      color: _neon,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              Divider(color: _neon.withOpacity(0.8)),
              ...apps.map((app) => ListTile(
                    title: Text(app,
                        style: const TextStyle(color: Colors.white)),
                    trailing: _selectedNavApp == app
                        ? const Icon(Icons.check, color: _neon)
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
            // ۱. سایدبار داک سمت چپ
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
                    tooltip: 'تنظیمات',
                    onTap: () => _openAction(
                      'settings',
                      legacyMethod: 'openSettings',
                    ),
                  ),
                  _buildDockIconButton(
                    icon: Icons.navigation_rounded,
                    tooltip: 'مسیریاب',
                    onTap: () => _openAction(
                      'nav',
                      extras: {'app': _selectedNavApp},
                      legacyMethod: 'openNav',
                    ),
                  ),
                  _buildDockIconButton(
                    icon: Icons.radio_rounded,
                    tooltip: 'رادیو',
                    onTap: () => _openAction(
                      'radio',
                      legacyMethod: 'openRadio',
                    ),
                  ),
                  _buildDockIconButton(
                    icon: Icons.phone_in_talk_rounded,
                    tooltip: 'تماس',
                    onTap: () => _openAction(
                      'phone',
                      legacyMethod: 'openPhone',
                    ),
                  ),
                  _buildDockIconButton(
                    icon: Icons.apps_rounded,
                    tooltip: 'برنامه‌ها',
                    onTap: () => _openAction(
                      'apps',
                      legacyMethod: 'openApps',
                    ),
                  ),
                ],
              ),
            ),

            // ۲. صفحه اصلی (۳ ستونه)
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
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return AspectRatio(
      aspectRatio: 1.0,
      child: Padding(
        padding: const EdgeInsets.all(6.0),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _neon.withOpacity(0.2),
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
                child: Icon(icon, color: _neon, size: 26),
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _neon.withOpacity(0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.arrow_drop_down, color: _neon, size: 16),
                        Text(_selectedNavApp,
                            style: const TextStyle(color: _neon, fontSize: 11)),
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
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.map_outlined, color: _neon, size: 48),
                      SizedBox(height: 8),
                      Text('لمس جهت باز شدن نقشه',
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

  // ستون مرکزی: عنوان با GPS در بالا سمت چپ + موزیک پلیر + کیلومتر بزرگ + جاده
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
          // هدر بالای ستون وسط: دکمه GPS در سمت چپ عنوان TIBA2
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
                      child: const Icon(Icons.satellite_alt_rounded,
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

          // موزیک‌پلیر اختصاصی با اکولایزر نئونی
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
                    // اکولایزر نئونی متحرک
                    AnimatedBuilder(
                      animation: _equalizerController,
                      builder: (context, child) {
                        return CustomPaint(
                          size: const Size(44, 20),
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
                    // کنترل‌های پلیر
                    IconButton(
                      icon: const Icon(Icons.skip_previous_rounded,
                          color: _neon, size: 20),
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
                      icon: const Icon(Icons.skip_next_rounded,
                          color: _neon, size: 20),
                      onPressed: () => _openAction('music_next', legacyMethod: 'musicNext'),
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                  ],
                ),
                // نوار وضعیت / پیشرفت موزیک
                const SizedBox(height: 2),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: _musicProgress,
                    backgroundColor: Colors.white10,
                    valueColor: const AlwaysStoppedAnimation<Color>(_neon),
                    minHeight: 2.2,
                  ),
                ),
              ],
            ),
          ),

          // محفظه کیلومتر بزرگ‌تر و جاده متحرک
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final h = constraints.maxHeight;
                const roadHeight = 125.0;
                // بزرگ‌تر شدن ارتفاع و ابعاد کیلومتر و مماس شدن به زیر موزیک
                const speedoHeight = 150.0;
                final speedoTop = (h - roadHeight) - (speedoHeight * 0.65);

                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // جاده سه‌بعدی
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
                          return const Icon(Icons.directions_car,
                              color: _neon, size: 48);
                        },
                      ),
                    ),

                    // آرم SAIPA (بالاتر کشیده شده تا به هیچ‌وجه روی ماشین نیفتد)
                    Positioned(
                      bottom: 84,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF070B14).withOpacity(0.9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: _neon.withOpacity(0.5), width: 1),
                          boxShadow: [
                            BoxShadow(
                              color: _neon.withOpacity(0.25),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: const Text(
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

                    // صفحه کیلومتر آنالوگ و دیجیتال بزرگ‌تر
                    Positioned(
                      top: speedoTop.clamp(2.0, 30.0),
                      left: 0,
                      right: 0,
                      child: SizedBox(
                        height: speedoHeight,
                        child: CustomPaint(
                          painter: DualCyberSpeedometerPainter(
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
                                  const Text(
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

                    // دنده‌ها
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
          shadows: active
              ? const [
                  Shadow(color: _neon, blurRadius: 8),
                ]
              : null,
        ),
      ),
    );
  }

  // پنل سمت راست (تصویر تیبا ۲ + دکمه باز کردن فایل‌های موزیک)
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
              onPressed: () => _openAction(
                'music_files',
                legacyMethod: 'openMusicFiles',
              ),
              icon: const Icon(Icons.folder_open_rounded, color: _neon, size: 20),
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
                  return const Center(
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
// نقاش کیلومتر دوگانه آنالوگ (عقربه نئونی + درجات) و دیجیتال
// ---------------------------------------------------------------------------
class DualCyberSpeedometerPainter extends CustomPainter {
  final double speed;
  final Color neon;

  DualCyberSpeedometerPainter({required this.speed, required this.neon});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.95);
    // شعاع بزرگتر شده
    final radius = math.min(size.width * 0.46, 120.0);

    const startAngle = math.pi;
    const sweepAngle = math.pi;

    // قوس پس‌زمینه
    final bgPaint = Paint()
      ..color = Colors.white12
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      bgPaint,
    );

    final progress = (speed / 130.0).clamp(0.0, 1.0);
    final activePaint = Paint()
      ..color = neon
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4.5
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle * progress,
      false,
      activePaint,
    );

    // کشیدن درجه‌ها و اعداد آنالوگ (۰ تا ۱۳۰)
    const totalDivisions = 13;
    for (int i = 0; i <= totalDivisions; i++) {
      final angle = startAngle + (sweepAngle * (i / totalDivisions));
      final isMajor = i % 2 != 0 || i == 0 || i == totalDivisions;
      final tickLength = isMajor ? 9.0 : 4.5;

      final p1 = Offset(
        center.dx + (radius - 4) * math.cos(angle),
        center.dy + (radius - 4) * math.sin(angle),
      );
      final p2 = Offset(
        center.dx + (radius - 4 - tickLength) * math.cos(angle),
        center.dy + (radius - 4 - tickLength) * math.sin(angle),
      );

      final tickPaint = Paint()
        ..color = (i / totalDivisions <= progress) ? neon : Colors.white30
        ..strokeWidth = isMajor ? 2.2 : 1.2;

      canvas.drawLine(p1, p2, tickPaint);

      if (i > 0) {
        final textRadius = radius - 18;
        final textOffset = Offset(
          center.dx + textRadius * math.cos(angle),
          center.dy + textRadius * math.sin(angle),
        );

        final textSpan = TextSpan(
          text: '${i * 10}',
          style: TextStyle(
            color: (i / totalDivisions <= progress) ? neon : Colors.white54,
            fontSize: 9.0,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
          ),
        );
        final tp = TextPainter(
          text: textSpan,
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
        )..layout();

        tp.paint(
          canvas,
          Offset(textOffset.dx - (tp.width / 2),
              textOffset.dy - (tp.height / 2)),
        );
      }
    }

    // عقربه آنالوگ نئونی (Needle)
    final needleAngle = startAngle + (sweepAngle * progress);
    final needleLength = radius - 10;
    final needleTarget = Offset(
      center.dx + needleLength * math.cos(needleAngle),
      center.dy + needleLength * math.sin(needleAngle),
    );

    final needlePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 2);

    canvas.drawLine(center, needleTarget, needlePaint);

    final needleCenterGlow = Paint()
      ..color = neon
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 4.5, needleCenterGlow);
  }

  @override
  bool shouldRepaint(covariant DualCyberSpeedometerPainter oldDelegate) {
    return oldDelegate.speed != speed || oldDelegate.neon != neon;
  }
}

// ---------------------------------------------------------------------------
// نقاش اکولایزر نئونی متحرک
// ---------------------------------------------------------------------------
class EqualizerPainter extends CustomPainter {
  final double progress;
  final Color color;

  EqualizerPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final barPaint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.0;

    const barCount = 5;
    final spacing = size.width / (barCount - 1);

    for (int i = 0; i < barCount; i++) {
      final factor = math.sin((progress * math.pi) + (i * 0.8)).abs();
      final h = (size.height * 0.25) + (size.height * 0.75 * factor);

      final x = i * spacing;
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x, size.height - h),
        barPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant EqualizerPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

// ---------------------------------------------------------------------------
// نقاش جاده سایبری و افق سه‌بعدی
// ---------------------------------------------------------------------------
class RealisticCyberRoadPainter extends CustomPainter {
  final double progress;
  final Color neon;

  RealisticCyberRoadPainter({required this.progress, required this.neon});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final horizonY = h * 0.1;
    final topRoadW = w * 0.18;
    final bottomRoadW = w * 0.95;

    final roadPath = Path()
      ..moveTo(w / 2 - topRoadW / 2, horizonY)
      ..lineTo(w / 2 + topRoadW / 2, horizonY)
      ..lineTo(w / 2 + bottomRoadW / 2, h)
      ..lineTo(w / 2 - bottomRoadW / 2, h)
      ..close();

    final roadGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.black.withOpacity(0.1),
        const Color(0xFF030D1A).withOpacity(0.85),
      ],
    );

    canvas.drawPath(
      roadPath,
      Paint()
        ..shader = roadGradient.createShader(Rect.fromLTWH(0, 0, w, h))
        ..style = PaintingStyle.fill,
    );

    final borderPaint = Paint()
      ..color = neon.withOpacity(0.6)
      ..strokeWidth = 2.5
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4);

    canvas.drawLine(
      Offset(w / 2 - topRoadW / 2, horizonY),
      Offset(w / 2 - bottomRoadW / 2, h),
      borderPaint,
    );
    canvas.drawLine(
      Offset(w / 2 + topRoadW / 2, horizonY),
      Offset(w / 2 + bottomRoadW / 2, h),
      borderPaint,
    );

    const dashCount = 6;
    for (int i = 0; i < dashCount; i++) {
      double t = (i / dashCount + progress) % 1.0;
      double perspectiveT = math.pow(t, 2.2).toDouble();

      double y = horizonY + (h - horizonY) * perspectiveT;
      double dashH = 4 + (16 * perspectiveT);
      double dashW = 1.5 + (3.0 * perspectiveT);
      double alpha = (0.2 + (0.8 * perspectiveT)).clamp(0.0, 1.0);

      final dashPaint = Paint()
        ..color = neon.withOpacity(alpha)
        ..strokeWidth = dashW
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 2);

      canvas.drawLine(
        Offset(w / 2, y),
        Offset(w / 2, math.min(y + dashH, h)),
        dashPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant RealisticCyberRoadPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.neon != neon;
  }
}
