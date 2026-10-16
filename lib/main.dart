import 'dart:async';
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

// ------------------------------------------------------------
// پنج تم از پیش تعریف‌شده
// ------------------------------------------------------------

class LauncherTheme {
  final String id;
  final String name;
  final String subtitle;
  final IconData icon;
  final Color accent;
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
    accent: Color(0xFF00E5FF),
    background: Color(0xFF061321),
    background2: Color(0xFF02050D),
    panel: Color(0xFF091725),
    radius: 20,
  ),
  LauncherTheme(
    id: 'racing',
    name: 'اسپرت مسابقه‌ای',
    subtitle: 'RACING SPORT',
    icon: Icons.speed,
    accent: Color(0xFFFF304F),
    background: Color(0xFF20080D),
    background2: Color(0xFF070608),
    panel: Color(0xFF180D12),
    radius: 5,
    racing: true,
  ),
  LauncherTheme(
    id: 'luxury',
    name: 'لوکس و مینیمال',
    subtitle: 'LUXURY MINIMAL',
    icon: Icons.diamond_outlined,
    accent: Color(0xFFD6B779),
    background: Color(0xFF171613),
    background2: Color(0xFF070707),
    panel: Color(0xFF131210),
    radius: 13,
    minimal: true,
  ),
  LauncherTheme(
    id: 'holographic',
    name: 'هولوگرافیک فضایی',
    subtitle: 'HOLOGRAPHIC SPACE',
    icon: Icons.blur_on,
    accent: Color(0xFFB388FF),
    background: Color(0xFF170C32),
    background2: Color(0xFF030511),
    panel: Color(0xFF140E29),
    radius: 23,
    holographic: true,
  ),
  LauncherTheme(
    id: 'classic',
    name: 'کلاسیک خودرو',
    subtitle: 'CLASSIC AUTOMOTIVE',
    icon: Icons.directions_car_filled,
    accent: Color(0xFFFFBF55),
    background: Color(0xFF20180D),
    background2: Color(0xFF080906),
    panel: Color(0xFF17150F),
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

  Color _neonColor = const Color(0xFF00E5FF);
  String _selectedTheme = 'cyber';

  LauncherTheme get _theme {
    return launcherThemes.firstWhere(
      (t) => t.id == _selectedTheme,
      orElse: () => launcherThemes.first,
    );
  }

  static const List<MapEntry<String, Color>> _neonColors = [
    MapEntry('فیروزه‌ای', Color(0xFF00E5FF)),
    MapEntry('بنفش', Color(0xFFB388FF)),
    MapEntry('قرمز', Color(0xFFFF3B5C)),
    MapEntry('سبز', Color(0xFF39FF88)),
    MapEntry('نارنجی', Color(0xFFFF9F1C)),
    MapEntry('سفید یخی', Color(0xFFEAF7FF)),
    MapEntry('صورتی', Color(0xFFFF4FD8)),
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
        final speed = (call.arguments as num).toDouble();
        if (mounted) {
          setState(() => _rawSpeed = speed < 1 ? 0 : speed);
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

      _selectedNav =
          prefs.getString('selected_nav') ?? 'ir.neshan.sp';

      _selectedTheme = prefs.getString('launcher_theme') ?? 'cyber';

      final colorVal = prefs.getInt('neon_color');
      if (colorVal != null) {
        _neonColor = Color(colorVal);
      } else {
        _neonColor = _theme.accent;
      }
    });
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setDouble('gps_multiplier', _gpsMultiplier);
    await prefs.setDouble('neon_intensity', _neonIntensity);
    await prefs.setDouble('road_intensity', _roadIntensity);
    await prefs.setDouble(
        'speedometer_intensity', _speedometerIntensity);
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
    final now = DateTime.now();

    if (!mounted) return;

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
    await [
      Permission.location,
      Permission.storage,
      Permission.audio,
    ].request();

    try {
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
      try {
        await platform.invokeMethod(
          'open',
          {'action': 'media_play_pause'},
        );
      } catch (_) {}
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
      await _playTrack(
        (_currentTrackIndex + 1) % _tracks.length,
      );
    } else {
      try {
        await platform.invokeMethod(
          'open',
          {'action': 'media_next'},
        );
      } catch (_) {}
    }
  }

  Future<void> _prevTrack() async {
    if (_tracks.isNotEmpty) {
      await _playTrack(
        (_currentTrackIndex - 1 + _tracks.length) % _tracks.length,
      );
    } else {
      try {
        await platform.invokeMethod(
          'open',
          {'action': 'media_prev'},
        );
      } catch (_) {}
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

  // ------------------------------------------------------------
  // ظاهر مشترک پنل‌ها
  // ------------------------------------------------------------

  BoxDecoration _panelDecoration({
    double opacity = 0.88,
    bool highlighted = false,
  }) {
    final glow = _theme.minimal ? 0.04 : 0.16;

    return BoxDecoration(
      color: _theme.panel.withOpacity(opacity),
      borderRadius: BorderRadius.circular(_theme.radius),
      border: Border.all(
        color: _neonColor.withOpacity(
          (highlighted ? 0.85 : 0.30) * _neonIntensity,
        ),
        width: _theme.racing ? 1.7 : 1,
      ),
      boxShadow: [
        if (!_theme.minimal)
          BoxShadow(
            color: _neonColor.withOpacity(glow * _neonIntensity),
            blurRadius: _theme.holographic ? 22 : 12,
            spreadRadius: _theme.holographic ? 1 : 0,
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

  // ------------------------------------------------------------
  // انتخاب تم
  // ------------------------------------------------------------

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
                side: BorderSide(color: _neonColor, width: 1.4),
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
                        borderRadius:
                            BorderRadius.circular(theme.radius),
                        onTap: () async {
                          await _selectTheme(theme.id);

                          if (dialogContext.mounted) {
                            setDialogState(() {});
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                theme.background,
                                theme.background2,
                              ],
                            ),
                            borderRadius:
                                BorderRadius.circular(theme.radius),
                            border: Border.all(
                              color: selected
                                  ? theme.accent
                                  : Colors.white24,
                              width: selected ? 2 : 1,
                            ),
                            boxShadow: selected
                                ? [
                                    BoxShadow(
                                      color: theme.accent.withOpacity(0.22),
                                      blurRadius: 14,
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
                                  color: theme.accent.withOpacity(0.13),
                                  borderRadius: BorderRadius.circular(
                                    theme.radius * 0.7,
                                  ),
                                  border: Border.all(
                                    color: theme.accent.withOpacity(0.8),
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
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      theme.name,
                                      style: TextStyle(
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
                  child: Text(
                    'بستن',
                    style: TextStyle(color: _neonColor),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ------------------------------------------------------------
  // تنظیمات اصلی
  // ------------------------------------------------------------

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
                  leading: Icon(Icons.dashboard_customize,
                      color: _neonColor),
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
                  'کالیبراسیون ضریب سرعت: '
                  '${_gpsMultiplier.toStringAsFixed(2)}',
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

  // ------------------------------------------------------------
  // تنظیم نور و رنگ
  // ------------------------------------------------------------

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
                        final selected =
                            _neonColor.value == entry.value.value;

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
                                  color: selected
                                      ? Colors.white
                                      : Colors.white30,
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
                      onChanged: (v) => updateSetting(
                        () => _neonIntensity = v,
                      ),
                    ),
                    intensityControl(
                      title: 'شدت نور جاده متحرک',
                      value: _roadIntensity,
                      min: 0.1,
                      max: 1.5,
                      onChanged: (v) => updateSetting(
                        () => _roadIntensity = v,
                      ),
                    ),
                    intensityControl(
                      title: 'شدت نور سرعت‌سنج',
                      value: _speedometerIntensity,
                      min: 0.1,
                      max: 1.5,
                      onChanged: (v) => updateSetting(
                        () => _speedometerIntensity = v,
                      ),
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

  // ------------------------------------------------------------
  // صفحه اصلی
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final speed = (_rawSpeed * _gpsMultiplier).round();

    return Scaffold(
      backgroundColor: _theme.background2,
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: _theme.racing
                ? const Alignment(0, -0.8)
                : const Alignment(0, -0.2),
            radius: _theme.holographic ? 1.45 : 1.2,
            colors: [
              _theme.background,
              _theme.background2,
            ],
          ),
        ),
        child: SafeArea(
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
          _sideButton(
            Icons.settings,
            'تنظیمات اصلی',
            _openSettingsDialog,
          ),
          _sideButton(
            Icons.dashboard_customize,
            'انتخاب تم',
            _openThemePicker,
          ),
          _sideButton(
            Icons.palette_outlined,
            'تنظیم رنگ و نور',
            _openNeonSettings,
          ),
          _sideButton(
            Icons.navigation_outlined,
            'مسیریاب',
            () => _launchIntent('nav', pkg: _selectedNav),
          ),
          _sideButton(
            Icons.radio,
            'رادیو',
            () => _launchIntent('radio'),
          ),
          _sideButton(
            Icons.phone,
            'تلفن',
            () => _launchIntent('phone'),
          ),
          _sideButton(
            Icons.apps,
            'برنامه‌ها',
            () => _launchIntent('apps'),
          ),
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
                  shadows: _theme.minimal
                      ? []
                      : [
                          Shadow(
                            color: _neonColor,
                            blurRadius: 10 * _neonIntensity,
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
                  _neonColor.withOpacity(0.14),
                  Colors.transparent,
                ],
              ),
            ),
            child: Center(
              child: Icon(
                _theme.classic
                    ? Icons.explore
                    : Icons.explore_outlined,
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
        backgroundColor: _neonColor.withOpacity(
          _theme.minimal ? 0.08 : 0.18,
        ),
        foregroundColor: Colors.white,
        side: BorderSide(color: _neonColor.withOpacity(0.9)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_theme.radius),
        ),
        padding: const EdgeInsets.symmetric(vertical: 13),
      ),
      onPressed: onPressed,
      icon: Icon(icon, color: _neonColor),
      label: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // داشبورد مرکزی و سرعت‌سنج
  // ------------------------------------------------------------

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
                  shadows: _theme.minimal
                      ? []
                      : [
                          Shadow(
                            color: _neonColor.withOpacity(_neonIntensity),
                            blurRadius: 15 * _neonIntensity,
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
                          (0.4 * _neonIntensity * _roadIntensity)
                              .clamp(0.0, 1.0)
                              .toDouble(),
                        ),
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
        color: _theme.background2.withOpacity(
          _theme.holographic ? 0.64 : 0.42,
        ),
        borderRadius: BorderRadius.circular(_theme.radius),
        border: Border.all(
          color: _neonColor.withOpacity(
            _theme.minimal ? 0.25 : 0.55,
          ),
          width: _theme.racing ? 2 : 1,
        ),
        boxShadow: [
          if (!_theme.minimal)
            BoxShadow(
              color: _neonColor.withOpacity(0.12 * _neonIntensity),
              blurRadius: _theme.holographic ? 28 : 16,
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
              color: _neonColor,
            ),
          if (_theme.classic)
            Icon(
              Icons.speed,
              color: _neonColor.withOpacity(0.8),
              size: 23,
            ),
          Text(
            '$speed',
            style: TextStyle(
              color: _theme.classic ? _neonColor : Colors.white,
              fontSize: _theme.racing ? 66 : 68,
              fontWeight: FontWeight.w900,
              fontFeatures: const [FontFeature.tabularFigures()],
              shadows: _theme.minimal
                  ? []
                  : [
                      Shadow(
                        color: _neonColor.withOpacity(speedGlow),
                        blurRadius: 20 * speedGlow,
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
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              border: Border.all(
                color: _neonColor.withOpacity(0.5 * _neonIntensity),
              ),
              borderRadius: BorderRadius.circular(
                _theme.classic ? 4 : _theme.radius,
              ),
              color: Colors.black.withOpacity(0.4),
            ),
            child: Text(
              _theme.racing ? 'SAIPA  /  SPORT' : 'SAIPA • سایپا',
              style: TextStyle(
                color: _neonColor,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Image.asset(
            'tiba2_rear.png',
            height: 52,
            errorBuilder: (_, __, ___) => const SizedBox(height: 52),
          ),
          if (_theme.racing)
            Container(
              height: 3,
              width: 110,
              margin: const EdgeInsets.only(top: 8),
              color: _neonColor,
            ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // موزیک پلیر
  // ------------------------------------------------------------

  Widget _buildBottomPlayerBar() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
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
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'آهنگ قبلی',
            icon: Icon(
              Icons.skip_previous,
              color: _neonColor,
            ),
            onPressed: _prevTrack,
          ),
          IconButton(
            tooltip: _isPlaying ? 'توقف موقت' : 'پخش',
            icon: Icon(
              _isPlaying
                  ? Icons.pause_circle_filled
                  : Icons.play_circle_filled,
              color: _neonColor,
              size: 34,
            ),
            onPressed: _togglePlayPause,
          ),
          IconButton(
            tooltip: 'آهنگ بعدی',
            icon: Icon(
              Icons.skip_next,
              color: _neonColor,
            ),
            onPressed: _nextTrack,
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // پنل خودرو
  // ------------------------------------------------------------

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
            child: Image.asset(
              'tiba2.png',
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) {
                return Center(
                  child: Icon(
                    Icons.directions_car,
                    size: 90,
                    color: _neonColor.withOpacity(0.5 * _neonIntensity),
                  ),
                );
              },
            ),
          ),
          const Spacer(),
          if (_theme.holographic)
            _sectionLabel('HOLOGRAPHIC DISPLAY'),
          if (_theme.racing)
            _sectionLabel('SPORT MODE'),
          if (_theme.classic)
            _sectionLabel('CLASSIC DASHBOARD'),
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

// ------------------------------------------------------------
// جاده متحرک با شکل متفاوت در هر تم
// ------------------------------------------------------------

class RoadPainter extends CustomPainter {
  final double progress;
  final Color color;
  final String themeId;

  RoadPainter({
    required this.progress,
    required this.color,
    this.themeId = 'cyber',
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final isRacing = themeId == 'racing';
    final isLuxury = themeId == 'luxury';
    final isHolographic = themeId == 'holographic';
    final isClassic = themeId == 'classic';

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = isRacing ? 2.8 : (isLuxury ? 1 : 1.7)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final top = Offset(size.width * 0.5, size.height * 0.18);
    final bottomLeft = Offset(
      size.width * (isRacing ? 0.02 : 0.08),
      size.height,
    );
    final bottomRight = Offset(
      size.width * (isRacing ? 0.98 : 0.92),
      size.height,
    );

    // خطوط کناری جاده
    canvas.drawLine(top, bottomLeft, linePaint);
    canvas.drawLine(top, bottomRight, linePaint);

    // تم فضایی: خطوط شبکه افقی و نورهای موازی
    if (isHolographic) {
      final gridPaint = Paint()
        ..color = color.withOpacity(0.42)
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke;

      for (int i = 0; i < 9; i++) {
        final t = (progress + i / 9) % 1.0;
        final y = top.dy + (size.height - top.dy) * t * t;
        final halfWidth = size.width * 0.48 * t;

        canvas.drawLine(
          Offset(size.width / 2 - halfWidth, y),
          Offset(size.width / 2 + halfWidth, y),
          gridPaint,
        );
      }

      for (int i = -2; i <= 2; i++) {
        final endX = size.width / 2 + i * size.width * 0.16;

        canvas.drawLine(
          top,
          Offset(endX, size.height),
          gridPaint,
        );
      }

      return;
    }

    // تم کلاسیک: خطوط باریک و منظم، بدون جلوه پرنور
    if (isClassic) {
      final centerPaint = Paint()
        ..color = color.withOpacity(0.75)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;

      for (int i = 0; i < 7; i++) {
        final t = (progress + i / 7) % 1.0;
        final y = top.dy + (size.height - top.dy) * t * t;
        final halfWidth = size.width * 0.06 * t;

        canvas.drawLine(
          Offset(size.width / 2 - halfWidth, y),
          Offset(size.width / 2 + halfWidth, y),
          centerPaint,
        );
      }

      return;
    }

    // تم لوکس: تعداد خطوط کمتر و نور ملایم‌تر
    final count = isLuxury ? 3 : (isRacing ? 8 : 5);

    for (int i = 0; i < count; i++) {
      final t = (progress + i / count) % 1.0;
      final y = top.dy + (size.height - top.dy) * t * t;

      final x1 = top.dx - (top.dx - bottomLeft.dx) * t;
      final x2 = top.dx + (bottomRight.dx - top.dx) * t;

      canvas.drawLine(
        Offset(x1, y),
        Offset(x2, y),
        linePaint,
      );
    }

    // تم مسابقه‌ای: خطوط سرعت در حاشیه‌ها
    if (isRacing) {
      final streakPaint = Paint()
        ..color = color.withOpacity(0.65)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;

      for (int i = 0; i < 4; i++) {
        final t = (progress + i / 4) % 1.0;
        final y = top.dy + (size.height - top.dy) * t * t;
        final width = size.width * 0.06 * t;

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
  }

  @override
  bool shouldRepaint(covariant RoadPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.themeId != themeId;
  }
}
