import 'dart:async';
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const TibaLauncherApp());
}

class TibaLauncherApp extends StatelessWidget {
  const TibaLauncherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tiba 2 Launcher',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const LauncherHome(),
    );
  }
}

class LauncherTheme {
  final String id;
  final String name;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final Color secondary;
  final Color background;
  final Color background2;
  final Color panel;
  final double radius;
  final bool minimal;
  final bool racing;
  final bool holographic;
  final bool classic;

  const LauncherTheme({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.secondary,
    required this.background,
    required this.background2,
    required this.panel,
    required this.radius,
    this.minimal = false,
    this.racing = false,
    this.holographic = false,
    this.classic = false,
  });
}

const List<LauncherTheme> launcherThemes = [
  LauncherTheme(
    id: 'cyber',
    name: 'سایبر نئونی',
    subtitle: 'CYBER NEON',
    icon: Icons.electric_bolt,
    accent: Color(0xFF64F3FF),
    secondary: Color(0xFF00B8D9),
    background: Color(0xFF082C48),
    background2: Color(0xFF010610),
    panel: Color(0xFF071B2B),
    radius: 20,
  ),
  LauncherTheme(
    id: 'racing',
    name: 'اسپرت مسابقه‌ای',
    subtitle: 'RACING SPORT',
    icon: Icons.speed,
    accent: Color(0xFFFF1744),
    secondary: Color(0xFFA90052),
    background: Color(0xFF480719),
    background2: Color(0xFF090207),
    panel: Color(0xFF210610),
    radius: 5,
    racing: true,
  ),
  LauncherTheme(
    id: 'luxury',
    name: 'لوکس و مینیمال',
    subtitle: 'LUXURY MINIMAL',
    icon: Icons.diamond_outlined,
    accent: Color(0xFFE8D5A3),
    secondary: Color(0xFF987548),
    background: Color(0xFF383020),
    background2: Color(0xFF0C0B09),
    panel: Color(0xFF1D1A14),
    radius: 13,
    minimal: true,
  ),
  LauncherTheme(
    id: 'holographic',
    name: 'هولوگرافیک فضایی',
    subtitle: 'HOLOGRAPHIC SPACE',
    icon: Icons.blur_on,
    accent: Color(0xFFC77DFF),
    secondary: Color(0xFF6A00F4),
    background: Color(0xFF30105B),
    background2: Color(0xFF050313),
    panel: Color(0xFF190B31),
    radius: 23,
    holographic: true,
  ),
  LauncherTheme(
    id: 'classic',
    name: 'کلاسیک خودرو',
    subtitle: 'CLASSIC AUTOMOTIVE',
    icon: Icons.directions_car_filled,
    accent: Color(0xFFFFB86B),
    secondary: Color(0xFFB76532),
    background: Color(0xFF422514),
    background2: Color(0xFF100905),
    panel: Color(0xFF24160D),
    radius: 9,
    classic: true,
  ),
];

class LauncherHome extends StatefulWidget {
  const LauncherHome({super.key});

  @override
  State<LauncherHome> createState() => _LauncherHomeState();
}

class _LauncherHomeState extends State<LauncherHome>
    with SingleTickerProviderStateMixin {
  static const platform = MethodChannel('com.tiba2.launcher/actions');

  double _rawSpeed = 0;
  double _gpsMultiplier = 1;
  double _neonIntensity = 1;
  double _roadIntensity = 1;
  double _speedometerIntensity = 1;

  Color _neonColor = const Color(0xFF64F3FF);
  String _selectedTheme = 'cyber';

  LauncherTheme get _theme => launcherThemes.firstWhere(
        (t) => t.id == _selectedTheme,
        orElse: () => launcherThemes.first,
      );

  static const List<MapEntry<String, Color>> _neonColors = [
    MapEntry('آبی کریستالی', Color(0xFF64F3FF)),
    MapEntry('فیروزه‌ای', Color(0xFF00B8D9)),
    MapEntry('بنفش', Color(0xFFC77DFF)),
    MapEntry('قرمز لیزری', Color(0xFFFF1744)),
    MapEntry('سبز نئونی', Color(0xFF39FF88)),
    MapEntry('طلایی', Color(0xFFE8D5A3)),
    MapEntry('مسی', Color(0xFFFFB86B)),
    MapEntry('صورتی', Color(0xFFFF4FD8)),
    MapEntry('سفید یخی', Color(0xFFEAF7FF)),
  ];

  String _timeString = '';
  String _dateString = '';
  Timer? _clockTimer;

  final AudioPlayer _player = AudioPlayer();
  List<PlatformFile> _tracks = [];
  int _currentTrackIndex = -1;
  bool _isPlaying = false;
  String _currentTrackTitle = 'آهنگی انتخاب نشده';
  String _selectedNav = 'ir.neshan.sp';

  late AnimationController _roadAnimCtrl;

  @override
  void initState() {
    super.initState();

    _roadAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _setupPlatformChannel();
    _loadPreferences();
    _initClock();
    _initAudioPlayer();
    _requestAllPermissions();
  }

  void _setupPlatformChannel() {
    platform.setMethodCallHandler((call) async {
      if (call.method == 'onSpeed') {
        final value = call.arguments;
        if (value is num && mounted) {
          setState(() => _rawSpeed = value.toDouble() < 1 ? 0 : value.toDouble());
        }
      }
    });
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    setState(() {
      _gpsMultiplier = prefs.getDouble('gps_multiplier') ?? 1;
      _neonIntensity = prefs.getDouble('neon_intensity') ?? 1;
      _roadIntensity = prefs.getDouble('road_intensity') ?? 1;
      _speedometerIntensity =
          prefs.getDouble('speedometer_intensity') ?? 1;
      _selectedNav = prefs.getString('selected_nav') ?? 'ir.neshan.sp';
      _selectedTheme = prefs.getString('launcher_theme') ?? 'cyber';

      final savedColor = prefs.getInt('neon_color');
      _neonColor = savedColor == null
          ? _theme.accent
          : Color(savedColor);
    });
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setDouble('gps_multiplier', _gpsMultiplier);
    await prefs.setDouble('neon_intensity', _neonIntensity);
    await prefs.setDouble('road_intensity', _roadIntensity);
    await prefs.setDouble(
      'speedometer_intensity',
      _speedometerIntensity,
    );
    await prefs.setString('selected_nav', _selectedNav);
    await prefs.setInt('neon_color', _neonColor.value);
    await prefs.setString('launcher_theme', _selectedTheme);
  }

  Future<void> _selectTheme(String id) async {
    final selected = launcherThemes.firstWhere(
      (theme) => theme.id == id,
      orElse: () => launcherThemes.first,
    );

    setState(() {
      _selectedTheme = selected.id;
      _neonColor = selected.accent;
    });

    await _savePreferences();
  }

  void _initClock() {
    _updateClock();
    _clockTimer =
        Timer.periodic(const Duration(seconds: 1), (_) => _updateClock());
  }

  void _updateClock() {
    if (!mounted) return;

    final now = DateTime.now();
    setState(() {
      _timeString =
          '${now.hour.toString().padLeft(2, '0')}:'
          '${now.minute.toString().padLeft(2, '0')}';
      _dateString = '${now.year}/${now.month}/${now.day}';
    });
  }

  void _initAudioPlayer() {
    _player.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() => _isPlaying = state == PlayerState.playing);
      }
    });

    _player.onPlayerComplete.listen((_) => _nextTrack());
  }

  Future<void> _requestAllPermissions() async {
    try {
      await [
        Permission.location,
        Permission.storage,
        Permission.audio,
      ].request();

      await platform.invokeMethod(
        'open',
        {'action': 'request_location'},
      );
    } catch (_) {}
  }

  Future<void> _pickMusicFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: [
        'mp3',
        'wav',
        'aac',
        'm4a',
        'flac',
        'ogg',
      ],
    );

    if (result == null || !mounted) return;

    final selected = result.files.where((f) => f.path != null).toList();
    if (selected.isEmpty) return;

    setState(() {
      _tracks = selected;
      _currentTrackIndex = 0;
    });

    await _playTrack(0);
  }

  Future<void> _playTrack(int index) async {
    if (index < 0 || index >= _tracks.length) return;

    final file = _tracks[index];
    if (file.path == null) return;

    await _player.play(DeviceFileSource(file.path!));
    if (!mounted) return;

    setState(() {
      _currentTrackIndex = index;
      _currentTrackTitle = file.name;
      _isPlaying = true;
    });
  }

  Future<void> _togglePlayPause() async {
    if (_tracks.isEmpty) {
      await _launchIntent('media_play_pause');
      return;
    }

    if (_isPlaying) {
      await _player.pause();
    } else if (_currentTrackIndex == -1) {
      await _playTrack(0);
    } else {
      await _player.resume();
    }
  }

  Future<void> _nextTrack() async {
    if (_tracks.isNotEmpty) {
      await _playTrack((_currentTrackIndex + 1) % _tracks.length);
    } else {
      await _launchIntent('media_next');
    }
  }

  Future<void> _prevTrack() async {
    if (_tracks.isNotEmpty) {
      await _playTrack(
        (_currentTrackIndex - 1 + _tracks.length) % _tracks.length,
      );
    } else {
      await _launchIntent('media_prev');
    }
  }

  Future<void> _launchIntent(String action, {String pkg = ''}) async {
    try {
      await platform.invokeMethod(
        'open',
        {'action': action, 'pkg': pkg},
      );
    } catch (_) {}
  }

  BoxDecoration _panelDecoration({
    double opacity = 0.88,
    bool highlighted = false,
  }) {
    final glow = _theme.minimal ? 0.04 : 0.20;

    return BoxDecoration(
      color: _theme.panel.withOpacity(opacity),
      borderRadius: BorderRadius.circular(_theme.radius),
      border: Border.all(
        color: _neonColor.withOpacity(
          ((highlighted ? 0.9 : 0.4) * _neonIntensity)
              .clamp(0.0, 1.0)
              .toDouble(),
        ),
        width: _theme.racing ? 1.8 : 1,
      ),
      boxShadow: [
        if (!_theme.minimal)
          BoxShadow(
            color: _neonColor.withOpacity(
              (glow * _neonIntensity).clamp(0.0, 0.8).toDouble(),
            ),
            blurRadius: _theme.holographic ? 25 : 15,
            spreadRadius: _theme.holographic ? 2 : 0,
          ),
      ],
    );
  }

  Widget _sectionLabel(String title) {
    return Text(
      title,
      style: TextStyle(
        color: _neonColor,
        fontWeight: FontWeight.bold,
        letterSpacing: _theme.racing ? 1.5 : 0.5,
      ),
    );
  }

  void _openThemePicker() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: _theme.panel,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(_theme.radius),
                side: BorderSide(color: _neonColor, width: 1.5),
              ),
              title: Text(
                'انتخاب تم لانچر',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _neonColor,
                  fontWeight: FontWeight.w900,
                ),
              ),
              content: SizedBox(
                width: 440,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: launcherThemes.map((theme) {
                      final selected = _selectedTheme == theme.id;

                      return InkWell(
                        borderRadius: BorderRadius.circular(theme.radius),
                        onTap: () async {
                          await _selectTheme(theme.id);
                          if (dialogContext.mounted) {
                            setDialogState(() {});
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 280),
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                theme.background,
                                theme.background2,
                                theme.panel,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(theme.radius),
                            border: Border.all(
                              color: selected
                                  ? theme.accent
                                  : Colors.white24,
                              width: selected ? 2 : 1,
                            ),
                            boxShadow: selected
                                ? [
                                    BoxShadow(
                                      color: theme.accent.withOpacity(0.3),
                                      blurRadius: 18,
                                    ),
                                  ]
                                : [],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      theme.accent.withOpacity(0.3),
                                      theme.secondary.withOpacity(0.08),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    theme.radius * 0.7,
                                  ),
                                  border: Border.all(
                                    color: theme.accent,
                                  ),
                                ),
                                child: Icon(
                                  theme.icon,
                                  color: theme.accent,
                                  size: 26,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      theme.name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      theme.subtitle,
                                      style: TextStyle(
                                        color: theme.accent,
                                        fontSize: 10,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (selected)
                                Icon(
                                  Icons.check_circle,
                                  color: theme.accent,
                                  size: 25,
                                ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text('بستن', style: TextStyle(color: _neonColor)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _openSettingsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          backgroundColor: _theme.panel,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: _neonColor, width: 1.5),
            borderRadius: BorderRadius.circular(_theme.radius),
          ),
          title: Text(
            'تنظیمات اصلی لانچر تیبا ۲',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _neonColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(Icons.settings_suggest, color: _neonColor),
                  title: const Text(
                    'تنظیمات اصلی تبلت / اندروید',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _launchIntent('settings');
                  },
                ),
                ListTile(
                  leading: Icon(Icons.gps_fixed, color: _neonColor),
                  title: const Text(
                    'تنظیمات موقعیت مکانی (GPS)',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _launchIntent('location_settings');
                  },
                ),
                ListTile(
                  leading: Icon(Icons.dashboard_customize, color: _neonColor),
                  title: const Text(
                    'انتخاب تم ظاهری',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _openThemePicker();
                  },
                ),
                const Divider(color: Colors.white24),
                Text(
                  'کالیبراسیون ضریب سرعت: ${_gpsMultiplier.toStringAsFixed(2)}',
                  style: const TextStyle(color: Colors.white70),
                ),
                Slider(
                  value: _gpsMultiplier.clamp(0.7, 1.3).toDouble(),
                  min: 0.7,
                  max: 1.3,
                  divisions: 12,
                  activeColor: _neonColor,
                  onChanged: (value) {
                    setDlgState(() => _gpsMultiplier = value);
                    setState(() => _gpsMultiplier = value);
                    _savePreferences();
                  },
                ),
                const Divider(color: Colors.white24),
                const Text(
                  'مسیریاب پیش‌فرض',
                  style: TextStyle(color: Colors.white70),
                ),
                DropdownButton<String>(
                  value: _selectedNav,
                  dropdownColor: _theme.panel,
                  style: const TextStyle(color: Colors.white),
                  items: const [
                    DropdownMenuItem(
                      value: 'ir.neshan.sp',
                      child: Text('نشان'),
                    ),
                    DropdownMenuItem(
                      value: 'ir.balad.navigation',
                      child: Text('بلد'),
                    ),
                    DropdownMenuItem(
                      value: 'com.google.android.apps.maps',
                      child: Text('گوگل مپ'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDlgState(() => _selectedNav = value);
                      setState(() => _selectedNav = value);
                      _savePreferences();
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('بستن', style: TextStyle(color: _neonColor)),
            ),
          ],
        ),
      ),
    );
  }

  void _openNeonSettings() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogContext, setDlgState) {
          void updateSetting(VoidCallback update) {
            setState(update);
            setDlgState(() {});
            _savePreferences();
          }

          Widget intensityControl({
            required String title,
            required double value,
            required double min,
            required double max,
            required ValueChanged<double> onChanged,
          }) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                    Text(
                      '${(value * 100).round()}%',
                      style: TextStyle(
                        color: _neonColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: value.clamp(min, max).toDouble(),
                  min: min,
                  max: max,
                  activeColor: _neonColor,
                  inactiveColor: _neonColor.withOpacity(0.18),
                  onChanged: onChanged,
                ),
              ],
            );
          }

          return AlertDialog(
            backgroundColor: _theme.panel,
            shape: RoundedRectangleBorder(
              side: BorderSide(color: _neonColor, width: 1.5),
              borderRadius: BorderRadius.circular(_theme.radius),
            ),
            title: Text(
              'تنظیم رنگ و نور',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _neonColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'انتخاب رنگ',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 12,
                      runSpacing: 12,
                      children: _neonColors.map((entry) {
                        final selected = _neonColor.value == entry.value.value;

                        return Tooltip(
                          message: entry.key,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(30),
                            onTap: () => updateSetting(
                              () => _neonColor = entry.value,
                            ),
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: entry.value,
                                boxShadow: [
                                  if (selected)
                                    BoxShadow(
                                      color: entry.value.withOpacity(0.7),
                                      blurRadius: 14,
                                      spreadRadius: 2,
                                    ),
                                ],
                                border: Border.all(
                                  color: selected ? Colors.white : Colors.white30,
                                  width: selected ? 3 : 1,
                                ),
                              ),
                              child: selected
                                  ? const Icon(
                                      Icons.check,
                                      color: Colors.black,
                                      size: 21,
                                    )
                                  : null,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 18),
                    const Divider(color: Colors.white24),
                    intensityControl(
                      title: 'شدت نور کلی',
                      value: _neonIntensity,
                      min: 0.3,
                      max: 1.5,
                      onChanged: (v) => updateSetting(() => _neonIntensity = v),
                    ),
                    intensityControl(
                      title: 'شدت نور جاده متحرک',
                      value: _roadIntensity,
                      min: 0.1,
                      max: 1.5,
                      onChanged: (v) => updateSetting(() => _roadIntensity = v),
                    ),
                    intensityControl(
                      title: 'شدت نور سرعت‌سنج',
                      value: _speedometerIntensity,
                      min: 0.1,
                      max: 1.5,
                      onChanged: (v) =>
                          updateSetting(() => _speedometerIntensity = v),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'تغییرات به‌صورت خودکار ذخیره می‌شوند.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.55),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('بستن', style: TextStyle(color: _neonColor)),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final speed = (_rawSpeed * _gpsMultiplier).round();

    return Scaffold(
      backgroundColor: _theme.background2,
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: _theme.racing ? Alignment.topCenter : Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _theme.background,
              _theme.background2,
              _theme.secondary.withOpacity(
                _theme.holographic ? 0.18 : 0.08,
              ),
              _theme.background2,
            ],
            stops: const [0, 0.38, 0.72, 1],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -150,
              left: -120,
              child: IgnorePointer(
                child: Container(
                  width: 420,
                  height: 420,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        _theme.accent.withOpacity(
                          _theme.minimal ? 0.06 : 0.15,
                        ),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -180,
              right: -130,
              child: IgnorePointer(
                child: Container(
                  width: 480,
                  height: 480,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        _theme.secondary.withOpacity(
                          _theme.minimal ? 0.04 : 0.16,
                        ),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Row(
                children: [
                  _buildSidebar(),
                  Expanded(
                    flex: 4,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 8,
                      ),
                      child: _buildNavCard(),
                    ),
                  ),
                  Expanded(
                    flex: 6,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 8,
                      ),
                      child: _buildCenterDashboard(speed),
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 8,
                      ),
                      child: _buildRightCarPanel(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 72,
      margin: const EdgeInsets.all(8),
      decoration: _panelDecoration(),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _sideButton(Icons.settings, 'تنظیمات اصلی', _openSettingsDialog),
          _sideButton(Icons.dashboard_customize, 'انتخاب تم', _openThemePicker),
          _sideButton(Icons.palette_outlined, 'تنظیم رنگ و نور', _openNeonSettings),
          _sideButton(
            Icons.navigation_outlined,
            'مسیریاب',
            () => _launchIntent('nav', pkg: _selectedNav),
          ),
          _sideButton(Icons.radio, 'رادیو', () => _launchIntent('radio')),
          _sideButton(Icons.phone, 'تلفن', () => _launchIntent('phone')),
          _sideButton(Icons.apps, 'برنامه‌ها', () => _launchIntent('apps')),
        ],
      ),
    );
  }

  Widget _sideButton(
    IconData icon,
    String tooltip,
    VoidCallback onPressed,
  ) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, color: _neonColor, size: 26),
    );
  }

  Widget _buildNavCard() {
    return Container(
      decoration: _panelDecoration(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _timeString,
                style: TextStyle(
                  color: _neonColor,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      color: _neonColor.withOpacity(
                        _theme.minimal ? 0.2 : _neonIntensity,
                      ),
                      blurRadius: _theme.minimal ? 4 : 12,
                    ),
                  ],
                ),
              ),
              Flexible(
                child: Text(
                  _dateString,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Container(
            height: 100,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_theme.radius),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _theme.accent.withOpacity(0.24),
                  _theme.secondary.withOpacity(0.08),
                  Colors.transparent,
                ],
              ),
              border: Border.all(
                color: _theme.accent.withOpacity(0.35),
              ),
            ),
            child: Center(
              child: Icon(
                _theme.classic ? Icons.explore : Icons.explore_outlined,
                size: 70,
                color: _neonColor.withOpacity(0.85 * _neonIntensity),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Center(
            child: Text(
              'سیستم مسیریابی هوشمند',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Spacer(),
          _actionButton(
            label: 'شروع مسیریابی',
            icon: Icons.near_me,
            onPressed: () => _launchIntent('nav', pkg: _selectedNav),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: _theme.secondary.withOpacity(
          _theme.minimal ? 0.12 : 0.28,
        ),
        foregroundColor: Colors.white,
        side: BorderSide(
          color: _neonColor.withOpacity(0.9),
          width: _theme.racing ? 1.8 : 1,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_theme.radius),
        ),
        padding: const EdgeInsets.symmetric(vertical: 13),
      ),
      onPressed: onPressed,
      icon: Icon(icon, color: _neonColor),
      label: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 13),
      ),
    );
  }

  Widget _buildCenterDashboard(int speed) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                _theme.racing ? 'TIBA 2 SPORT' : 'TIBA 2',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _neonColor,
                  fontSize: _theme.racing ? 20 : 22,
                  letterSpacing: _theme.racing ? 2.5 : 4,
                  fontWeight: FontWeight.w900,
                  shadows: [
                    Shadow(
                      color: _neonColor.withOpacity(
                        _theme.minimal ? 0.25 : _neonIntensity,
                      ),
                      blurRadius: _theme.minimal ? 4 : 16,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'تیبا ۲',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _roadAnimCtrl,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: RoadPainter(
                        progress: _roadAnimCtrl.value,
                        color: _neonColor.withOpacity(
                          (0.65 * _neonIntensity * _roadIntensity)
                              .clamp(0.0, 1.0)
                              .toDouble(),
                        ),
                        secondary: _theme.secondary,
                        themeId: _selectedTheme,
                      ),
                    );
                  },
                ),
              ),
              _buildSpeedDisplay(speed),
            ],
          ),
        ),
        _buildBottomPlayerBar(),
      ],
    );
  }

  Widget _buildSpeedDisplay(int speed) {
    final speedGlow = (_speedometerIntensity * _neonIntensity)
        .clamp(0.0, 1.5)
        .toDouble();

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: _theme.racing ? 25 : 30,
        vertical: _theme.minimal ? 14 : 18,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _theme.panel.withOpacity(0.92),
            _theme.background2.withOpacity(0.76),
            _theme.secondary.withOpacity(_theme.holographic ? 0.18 : 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(_theme.radius),
        border: Border.all(
          color: _neonColor.withOpacity(_theme.minimal ? 0.4 : 0.8),
          width: _theme.racing ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: _neonColor.withOpacity(
              (_theme.minimal ? 0.06 : 0.18 * _neonIntensity)
                  .clamp(0.0, 0.8)
                  .toDouble(),
            ),
            blurRadius: _theme.holographic ? 32 : 18,
            spreadRadius: _theme.holographic ? 2 : 0,
          ),
          BoxShadow(
            color: _theme.secondary.withOpacity(0.12),
            blurRadius: 30,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_theme.racing)
            Container(
              height: 3,
              width: 110,
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: _neonColor,
                boxShadow: [
                  BoxShadow(color: _neonColor, blurRadius: 8),
                ],
              ),
            ),
          if (_theme.classic)
            Icon(Icons.speed, color: _neonColor, size: 23),
          Text(
            '$speed',
            style: TextStyle(
              color: _theme.classic ? _neonColor : Colors.white,
              fontSize: _theme.racing ? 66 : 68,
              fontWeight: FontWeight.w900,
              fontFeatures: const [FontFeature.tabularFigures()],
              shadows: [
                Shadow(
                  color: _neonColor.withOpacity(speedGlow),
                  blurRadius: 22 * speedGlow,
                ),
                if (_theme.holographic)
                  Shadow(
                    color: _theme.secondary.withOpacity(0.8),
                    blurRadius: 28,
                  ),
              ],
            ),
          ),
          Text(
            _theme.classic ? 'KM/H' : 'KM / H',
            style: TextStyle(
              color: _neonColor.withOpacity(
                _speedometerIntensity.clamp(0.0, 1.0).toDouble(),
              ),
              fontSize: 13,
              letterSpacing: _theme.racing ? 3 : 2,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(
                color: _neonColor.withOpacity(0.7 * _neonIntensity),
              ),
              borderRadius: BorderRadius.circular(
                _theme.classic ? 4 : _theme.radius,
              ),
              color: Colors.black.withOpacity(0.4),
            ),
            child: Text(
              _theme.racing ? 'SAIPA / SPORT' : 'SAIPA • سایپا',
              style: TextStyle(
                color: _neonColor,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: _neonColor.withOpacity(
                    _theme.minimal ? 0.02 : 0.16 * _neonIntensity,
                  ),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Image.asset(
              'tiba2_rear.png',
              height: 52,
              errorBuilder: (_, __, ___) => const SizedBox(height: 52),
            ),
          ),
          if (_theme.racing)
            Container(
              height: 3,
              width: 110,
              margin: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                color: _neonColor,
                boxShadow: [BoxShadow(color: _neonColor, blurRadius: 8)],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomPlayerBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: _panelDecoration(),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _currentTrackTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _tracks.isEmpty
                      ? 'پلیر چندرسانه‌ای'
                      : 'تعداد ترک‌ها: ${_tracks.length}',
                  style: const TextStyle(color: Colors.white54, fontSize: 10),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'آهنگ قبلی',
            icon: Icon(Icons.skip_previous, color: _neonColor),
            onPressed: _prevTrack,
          ),
          IconButton(
            tooltip: _isPlaying ? 'توقف موقت' : 'پخش',
            icon: Icon(
              _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
              color: _neonColor,
              size: 34,
            ),
            onPressed: _togglePlayPause,
          ),
          IconButton(
            tooltip: 'آهنگ بعدی',
            icon: Icon(Icons.skip_next, color: _neonColor),
            onPressed: _nextTrack,
          ),
        ],
      ),
    );
  }

  Widget _buildRightCarPanel() {
    return Container(
      decoration: _panelDecoration(),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          _actionButton(
            label: 'پوشه موزیک / فلش',
            icon: Icons.folder_open,
            onPressed: _pickMusicFiles,
          ),
          const Spacer(),
          Expanded(
            flex: 5,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, 0.1),
                  radius: 0.9,
                  colors: [
                    _theme.accent.withOpacity(
                      _theme.minimal ? 0.04 : 0.18 * _neonIntensity,
                    ),
                    _theme.secondary.withOpacity(0.04),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 160,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _neonColor.withOpacity(
                            _theme.minimal ? 0.02 : 0.15 * _neonIntensity,
                          ),
                          blurRadius: 42,
                          spreadRadius: 8,
                        ),
                      ],
                    ),
                  ),
                  Image.asset(
                    'tiba2.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) {
                      return Icon(
                        Icons.directions_car,
                        size: 90,
                        color: _neonColor.withOpacity(0.7 * _neonIntensity),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          if (_theme.holographic) _sectionLabel('HOLOGRAPHIC DISPLAY'),
          if (_theme.racing) _sectionLabel('SPORT MODE'),
          if (_theme.classic) _sectionLabel('CLASSIC DASHBOARD'),
          if (_theme.minimal) _sectionLabel('LUXURY EDITION'),
          if (_theme.id == 'cyber') _sectionLabel('CYBER DRIVE'),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                tooltip: 'موزیک',
                icon: Icon(Icons.music_note, color: _neonColor),
                onPressed: () => _launchIntent('music'),
              ),
              IconButton(
                tooltip: 'تنظیمات',
                icon: Icon(Icons.tune, color: _neonColor),
                onPressed: _openSettingsDialog,
              ),
              IconButton(
                tooltip: 'انتخاب تم',
                icon: Icon(Icons.dashboard_customize, color: _neonColor),
                onPressed: _openThemePicker,
              ),
              IconButton(
                tooltip: 'رنگ و نور',
                icon: Icon(Icons.palette_outlined, color: _neonColor),
                onPressed: _openNeonSettings,
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _roadAnimCtrl.dispose();
    _clockTimer?.cancel();
    _player.dispose();
    super.dispose();
  }
}

class RoadPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color secondary;
  final String themeId;

  RoadPainter({
    required this.progress,
    required this.color,
    required this.secondary,
    this.themeId = 'cyber',
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final isRacing = themeId == 'racing';
    final isLuxury = themeId == 'luxury';
    final isHolographic = themeId == 'holographic';
    final isClassic = themeId == 'classic';

    final centerX = size.width / 2;
    final topY = size.height * 0.15;
    final bottomY = size.height;

    final roadLeft = isRacing ? 0.015 : 0.07;
    final roadRight = isRacing ? 0.985 : 0.93;

    final top = Offset(centerX, topY);
    final leftBottom = Offset(size.width * roadLeft, bottomY);
    final rightBottom = Offset(size.width * roadRight, bottomY);

    final edgePaint = Paint()
      ..color = color.withOpacity(isLuxury ? 0.45 : 0.95)
      ..strokeWidth = isRacing ? 2.8 : (isLuxury ? 1.1 : 1.8)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final roadPath = Path()
      ..moveTo(top.dx, top.dy)
      ..lineTo(leftBottom.dx, leftBottom.dy)
      ..moveTo(top.dx, top.dy)
      ..lineTo(rightBottom.dx, rightBottom.dy);

    canvas.drawPath(roadPath, edgePaint);

    // نور حاشیه‌های جاده
    if (!isLuxury) {
      final glowPaint = Paint()
        ..color = color.withOpacity(0.12)
        ..strokeWidth = isRacing ? 10 : 7
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8)
        ..style = PaintingStyle.stroke;

      canvas.drawPath(roadPath, glowPaint);
    }

    // تم هولوگرافیک: شبکه فضایی بنفش
    if (isHolographic) {
      final gridPaint = Paint()
        ..color = color.withOpacity(0.6)
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke;

      final secondPaint = Paint()
        ..color = secondary.withOpacity(0.55)
        ..strokeWidth = 1.3
        ..style = PaintingStyle.stroke;

      for (int i = 0; i < 12; i++) {
        final t = (progress + i / 12) % 1.0;
        final y = topY + (bottomY - topY) * t * t;
        final halfWidth = size.width * 0.47 * t;

        canvas.drawLine(
          Offset(centerX - halfWidth, y),
          Offset(centerX + halfWidth, y),
          i.isEven ? gridPaint : secondPaint,
        );
      }

      for (int i = -4; i <= 4; i++) {
        canvas.drawLine(
          top,
          Offset(centerX + i * size.width * 0.12, bottomY),
          gridPaint,
        );
      }

      return;
    }

    // تم کلاسیک: خط وسط و نوارهای کوتاه
    if (isClassic) {
      final centerPaint = Paint()
        ..color = color.withOpacity(0.8)
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round;

      for (int i = 0; i < 9; i++) {
        final t = (progress + i / 9) % 1.0;
        final y = topY + (bottomY - topY) * t * t;
        final halfWidth = size.width * 0.025 * t + 1;

        canvas.drawLine(
          Offset(centerX - halfWidth, y),
          Offset(centerX + halfWidth, y),
          centerPaint,
        );
      }

      return;
    }

    // خطوط متحرک جاده
    final count = isLuxury ? 3 : (isRacing ? 10 : 6);

    for (int i = 0; i < count; i++) {
      final t = (progress + i / count) % 1.0;
      final y = topY + (bottomY - topY) * t * t;

      final leftX = centerX - (centerX - leftBottom.dx) * t;
      final rightX = centerX + (rightBottom.dx - centerX) * t;

      final dashPaint = Paint()
        ..color = (i.isEven ? color : secondary).withOpacity(
          (0.25 + 0.75 * t).clamp(0.0, 1.0),
        )
        ..strokeWidth = isRacing ? 2.6 : (isLuxury ? 1.0 : 1.6)
        ..strokeCap = StrokeCap.round;

      final dashLength = isLuxury ? 0.035 : (isRacing ? 0.075 : 0.055);
      final y2 = (y + size.height * dashLength * t).clamp(topY, bottomY);

      canvas.drawLine(
        Offset(leftX, y),
        Offset(centerX - (centerX - leftBottom.dx) * (y2 - topY) / (bottomY - topY), y2),
        dashPaint,
      );

      canvas.drawLine(
        Offset(rightX, y),
        Offset(centerX + (rightBottom.dx - centerX) * (y2 - topY) / (bottomY - topY), y2),
        dashPaint,
      );
    }

    // خطوط سرعت اضافه در تم مسابقه‌ای
    if (isRacing) {
      final streakPaint = Paint()
        ..color = secondary.withOpacity(0.75)
        ..strokeWidth = 2.3
        ..strokeCap = StrokeCap.round;

      for (int i = 0; i < 7; i++) {
        final t = (progress + i / 7) % 1.0;
        final y = topY + (bottomY - topY) * t * t;
        final width = size.width * (0.035 + 0.07 * t);

        canvas.drawLine(
          Offset(0, y),
          Offset(width, y),
          streakPaint,
        );

        canvas.drawLine(
          Offset(size.width - width, y),
          Offset(size.width, y),
          streakPaint,
        );
      }
    }

    // خطوط طلایی موازی و ظریف در تم لوکس
    if (isLuxury) {
      final goldPaint = Paint()
        ..color = secondary.withOpacity(0.65)
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke;

      final innerPath = Path()
        ..moveTo(centerX, topY)
        ..lineTo(size.width * 0.20, bottomY)
        ..moveTo(centerX, topY)
        ..lineTo(size.width * 0.80, bottomY);

      canvas.drawPath(innerPath, goldPaint);
    }
  }

  @override
  bool shouldRepaint(covariant RoadPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.secondary != secondary ||
        oldDelegate.themeId != themeId;
  }
}
