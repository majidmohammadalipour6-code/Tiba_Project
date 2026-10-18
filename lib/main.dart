import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

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
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF030712),
      ),
      home: const LauncherHome(),
    );
  }
}

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
          setState(() {
            _rawSpeed = speed < 1 ? 0 : speed;
          });
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

      final colorVal = prefs.getInt('neon_color');

      if (colorVal != null) {
        _neonColor = Color(colorVal);
      }
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
  }

  void _initClock() {
    _updateClock();

    _clockTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _updateClock(),
    );
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
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
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

    if (result == null || result.files.isEmpty) return;

    final selected = result.files
        .where((file) => file.path != null)
        .toList();

    if (!mounted) return;

    setState(() {
      _tracks = selected;
      _currentTrackIndex = selected.isNotEmpty ? 0 : -1;
    });

    if (_tracks.isNotEmpty) {
      await _playTrack(0);
    }
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
      await _playTrack(
        (_currentTrackIndex + 1) % _tracks.length,
      );
    } else {
      await _launchIntent('media_next');
    }
  }

  Future<void> _prevTrack() async {
    if (_tracks.isNotEmpty) {
      await _playTrack(
        (_currentTrackIndex - 1 + _tracks.length) %
            _tracks.length,
      );
    } else {
      await _launchIntent('media_prev');
    }
  }

  Future<void> _launchIntent(
    String action, {
    String pkg = '',
  }) async {
    try {
      await platform.invokeMethod(
        'open',
        {
          'action': action,
          'pkg': pkg,
        },
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('این قابلیت هنوز به اندروید متصل نشده: $action'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _openSettingsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF0F172A),
            shape: RoundedRectangleBorder(
              side: BorderSide(color: _neonColor, width: 1.5),
              borderRadius: BorderRadius.circular(16),
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
                    leading: Icon(
                      Icons.settings_suggest,
                      color: _neonColor,
                    ),
                    title: const Text(
                      'تنظیمات اصلی اندروید',
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      _launchIntent('settings');
                    },
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.gps_fixed,
                      color: _neonColor,
                    ),
                    title: const Text(
                      'تنظیمات GPS',
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      _launchIntent('location_settings');
                    },
                  ),
                  const Divider(color: Colors.white24),
                  Text(
                    'ضریب سرعت: ${_gpsMultiplier.toStringAsFixed(2)}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  Slider(
                    value: _gpsMultiplier,
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
                    dropdownColor: const Color(0xFF1E293B),
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
                      if (value == null) return;

                      setDlgState(() => _selectedNav = value);
                      setState(() => _selectedNav = value);
                      _savePreferences();
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  'بستن',
                  style: TextStyle(color: _neonColor),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openStyleSettings() {
    final presets = <MapEntry<String, Color>>[
      const MapEntry('فیروزه‌ای اسپرت', Color(0xFF00E5FF)),
      const MapEntry('بنفش نئونی', Color(0xFFB388FF)),
      const MapEntry('قرمز مسابقه‌ای', Color(0xFFFF3B5C)),
      const MapEntry('سبز اسپرت', Color(0xFF39FF88)),
      const MapEntry('سفید یخی', Color(0xFFEAF7FF)),
    ];

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogContext, setDlgState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF0F172A),
            shape: RoundedRectangleBorder(
              side: BorderSide(color: _neonColor, width: 1.5),
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              'تنظیم سبک نمایش',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _neonColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'سبک نورپردازی را انتخاب کن:',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 12),
                  ...presets.map((preset) {
                    final selected =
                        _neonColor.value == preset.value.value;

                    return ListTile(
                      dense: true,
                      leading: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: preset.value,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: preset.value.withOpacity(0.45),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                      title: Text(
                        preset.key,
                        style: const TextStyle(color: Colors.white),
                      ),
                      trailing: selected
                          ? Icon(
                              Icons.check_circle,
                              color: preset.value,
                            )
                          : null,
                      onTap: () {
                        setState(() => _neonColor = preset.value);
                        setDlgState(() {});
                        _savePreferences();
                      },
                    );
                  }),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  'بستن',
                  style: TextStyle(color: _neonColor),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openNeonSettings() {
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
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
                          style: const TextStyle(
                            color: Colors.white70,
                          ),
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
              backgroundColor: const Color(0xFF0F172A),
              shape: RoundedRectangleBorder(
                side: BorderSide(color: _neonColor, width: 1.5),
                borderRadius: BorderRadius.circular(18),
              ),
              title: Text(
                'تنظیم رنگ و نور نئون',
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
                        onChanged: (value) => updateSetting(
                          () => _neonIntensity = value,
                        ),
                      ),
                      intensityControl(
                        title: 'شدت نور جاده',
                        value: _roadIntensity,
                        min: 0.1,
                        max: 1.5,
                        onChanged: (value) => updateSetting(
                          () => _roadIntensity = value,
                        ),
                      ),
                      intensityControl(
                        title: 'شدت نور سرعت‌سنج',
                        value: _speedometerIntensity,
                        min: 0.1,
                        max: 1.5,
                        onChanged: (value) => updateSetting(
                          () => _speedometerIntensity = value,
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

  @override
  void dispose() {
    _roadAnimCtrl.dispose();
    _clockTimer?.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final speed = (_rawSpeed * _gpsMultiplier).round();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.25),
            radius: 1.25,
            colors: [
              Color(0xFF102C59),
              Color(0xFF061226),
              Color(0xFF01040B),
            ],
            stops: [0, 0.55, 1],
          ),
        ),
        child: Stack(
          children: [
            const Positioned.fill(child: _AmbientGlow()),
            SafeArea(
              child: Column(
                children: [
                  _buildTopStatusBar(),
                  Expanded(
                    child: Row(
                      children: [
                        _buildSidebar(),
                        Expanded(
                          flex: 4,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 7,
                              horizontal: 5,
                            ),
                            child: _buildNavCard(),
                          ),
                        ),
                        Expanded(
                          flex: 6,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 7,
                              horizontal: 5,
                            ),
                            child: _buildCenterDashboard(speed),
                          ),
                        ),
                        Expanded(
                          flex: 4,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 7,
                              horizontal: 5,
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
          ],
        ),
      ),
    );
  }

  Widget _buildTopStatusBar() {
    return Container(
      height: 43,
      margin: const EdgeInsets.fromLTRB(10, 3, 10, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xCC030B1A),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: _neonColor.withOpacity(0.32 * _neonIntensity),
        ),
        boxShadow: [
          BoxShadow(
            color: _neonColor.withOpacity(0.08),
            blurRadius: 14,
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.bolt, color: _neonColor, size: 23),
          const SizedBox(width: 10),
          Text(
            _timeString,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 12),
          const Icon(
            Icons.signal_cellular_alt,
            color: Colors.white70,
            size: 17,
          ),
          const SizedBox(width: 6),
          const Text(
            'LTE',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'تنظیمات وای‌فای',
            onPressed: () => _launchIntent('wifi_settings'),
            icon: const Icon(Icons.wifi, color: Colors.white70, size: 20),
          ),
          IconButton(
            tooltip: 'تنظیمات بلوتوث',
            onPressed: () => _launchIntent('bluetooth_settings'),
            icon: const Icon(
              Icons.bluetooth,
              color: Colors.white70,
              size: 19,
            ),
          ),
          Icon(
            Icons.battery_charging_full,
            color: _neonColor,
            size: 20,
          ),
          const SizedBox(width: 5),
          const Text(
            'TIBA 2',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              letterSpacing: 2,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 72,
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0F1D).withOpacity(0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _neonColor.withOpacity(0.35 * _neonIntensity),
        ),
        boxShadow: [
          BoxShadow(
            color: _neonColor.withOpacity(0.15 * _neonIntensity),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            tooltip: 'تنظیمات اصلی',
            icon: Icon(Icons.settings, color: _neonColor, size: 28),
            onPressed: _openSettingsDialog,
          ),
          IconButton(
            tooltip: 'تنظیم رنگ و نور',
            icon: Icon(
              Icons.palette_outlined,
              color: _neonColor,
              size: 27,
            ),
            onPressed: _openNeonSettings,
          ),
          IconButton(
            tooltip: 'تنظیم سبک',
            icon: Icon(
              Icons.dashboard_customize_outlined,
              color: _neonColor,
              size: 27,
            ),
            onPressed: _openStyleSettings,
          ),
          IconButton(
            tooltip: 'مسیریاب',
            icon: const Icon(
              Icons.navigation_outlined,
              color: Colors.white70,
              size: 28,
            ),
            onPressed: () => _launchIntent(
              'nav',
              pkg: _selectedNav,
            ),
          ),
          IconButton(
            tooltip: 'رادیو',
            icon: const Icon(
              Icons.radio,
              color: Colors.white70,
              size: 28,
            ),
            onPressed: () => _launchIntent('radio'),
          ),
          IconButton(
            tooltip: 'ویدئو',
            icon: const Icon(
              Icons.ondemand_video,
              color: Colors.white70,
              size: 28,
            ),
            onPressed: () => _launchIntent('video'),
          ),
          IconButton(
            tooltip: 'تلفن',
            icon: const Icon(
              Icons.phone,
              color: Colors.white70,
              size: 28,
            ),
            onPressed: () => _launchIntent('phone'),
          ),
        ],
      ),
    );
  }

  Widget _buildNavCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0A0F1D).withOpacity(0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _neonColor.withOpacity(0.3 * _neonIntensity),
        ),
      ),
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
                      color: _neonColor,
                      blurRadius: 10 * _neonIntensity,
                    ),
                  ],
                ),
              ),
              Text(
                _dateString,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const Spacer(),
          Center(
            child: Icon(
              Icons.explore_outlined,
              size: 70,
              color: _neonColor.withOpacity(0.8 * _neonIntensity),
            ),
          ),
          const SizedBox(height: 12),
          const Center(
            child: Text(
              'سیستم مسیریابی هوشمند',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Spacer(),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _neonColor.withOpacity(0.2),
              side: BorderSide(color: _neonColor),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: () => _launchIntent(
              'nav',
              pkg: _selectedNav,
            ),
            icon: const Icon(Icons.near_me, color: Colors.white),
            label: const Text(
              'شروع مسیریابی',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCenterDashboard(int speed) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'TIBA 2',
              style: TextStyle(
                color: _neonColor,
                fontSize: 24,
                letterSpacing: 4,
                fontWeight: FontWeight.w900,
                shadows: [
                  Shadow(
                    color: _neonColor.withOpacity(_neonIntensity),
                    blurRadius: 15 * _neonIntensity,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'تیبا ۲',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
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
                        progress:
                            speed <= 0 ? 0 : _roadAnimCtrl.value,
                        speed: speed,
                        accent: _neonColor,
                      ),
                    );
                  },
                ),
              ),
              LayoutBuilder(
                builder: (context, constraints) {
                  final gaugeWidth = (constraints.maxWidth)
                      .clamp(260.0, 460.0)
                      .toDouble();

                  return SizedBox(
                    width: gaugeWidth,
                    height: constraints.maxHeight,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: SpeedGaugePainter(
                              speed: speed,
                              maxSpeed: 200,
                              color: _neonColor,
                              intensity: _speedometerIntensity
                                  .clamp(0.0, 1.0)
                                  .toDouble(),
                            ),
                          ),
                        ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(height: 38),
                            Text(
                              '$speed',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 62,
                                height: 1,
                                fontWeight: FontWeight.w900,
                                shadows: [
                                  Shadow(
                                    color: _neonColor.withOpacity(
                                      _speedometerIntensity
                                          .clamp(0.0, 1.0)
                                          .toDouble(),
                                    ),
                                    blurRadius: 20 *
                                        _neonIntensity *
                                        _speedometerIntensity,
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              'KM / H',
                              style: TextStyle(
                                color: _neonColor.withOpacity(
                                  _speedometerIntensity
                                      .clamp(0.0, 1.0)
                                      .toDouble(),
                                ),
                                fontSize: 14,
                                letterSpacing: 2,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: _neonColor.withOpacity(
                                    0.5 * _neonIntensity,
                                  ),
                                ),
                                borderRadius: BorderRadius.circular(10),
                                color: Colors.black.withOpacity(0.55),
                              ),
                              child: Text(
                                'SAIPA • سایپا',
                                style: TextStyle(
                                  color: _neonColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Transform.scale(
                              scale: 1.18,
                              child: Image.asset(
                                'tiba2_rear.png',
                                height: 66,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) =>
                                    const SizedBox(height: 66),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRightCarPanel() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xE6081020),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _neonColor.withOpacity(0.38 * _neonIntensity),
            ),
            boxShadow: [
              BoxShadow(
                color: _neonColor.withOpacity(0.08),
                blurRadius: 16,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(
                      color: _neonColor.withOpacity(0.8),
                    ),
                    backgroundColor: _neonColor.withOpacity(0.08),
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 6,
                    ),
                  ),
                  onPressed: _pickMusicFiles,
                  icon: const Icon(Icons.folder_open, size: 19),
                  label: const Text(
                    'انتخاب آهنگ',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          _neonColor.withOpacity(0.55),
                          const Color(0xFF111A35),
                          const Color(0xFF050914),
                        ],
                      ),
                      border: Border.all(
                        color: _neonColor.withOpacity(0.5),
                      ),
                    ),
                    child: Icon(
                      Icons.album_rounded,
                      size: 38,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'در حال پخش',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _currentTrackTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _tracks.isEmpty
                              ? 'آهنگی انتخاب نشده'
                              : 'ترک ${_currentTrackIndex + 1} از ${_tracks.length}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: _prevTrack,
                    icon: const Icon(
                      Icons.skip_previous,
                      color: Colors.white,
                      size: 25,
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: _togglePlayPause,
                    icon: Icon(
                      _isPlaying
                          ? Icons.pause_circle_filled
                          : Icons.play_circle_fill,
                      color: _neonColor,
                      size: 40,
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: _nextTrack,
                    icon: const Icon(
                      Icons.skip_next,
                      color: Colors.white,
                      size: 25,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // تصویر ماشین بدون قاب؛ با سایز بزرگ‌تر و متمایل به پایین
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.only(top: 14.0, bottom: 4.0),
                  child: Transform.translate(
                    offset: const Offset(0, 16),
                    child: Transform.scale(
                      scale: 1.25,
                      child: Image.asset(
                        'tiba2.png',
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.directions_car,
                          size: 200,
                          color: _neonColor.withOpacity(0.7),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'موسیقی',
                      onPressed: () => _launchIntent('music'),
                      icon: const Icon(
                        Icons.music_note,
                        color: Colors.white70,
                        size: 20,
                      ),
                    ),
                    IconButton(
                      tooltip: 'تنظیمات',
                      onPressed: _openSettingsDialog,
                      icon: const Icon(
                        Icons.tune,
                        color: Colors.white70,
                        size: 20,
                      ),
                    ),
                    IconButton(
                      tooltip: 'رنگ و نور',
                      onPressed: _openNeonSettings,
                      icon: Icon(
                        Icons.palette_outlined,
                        color: _neonColor,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AmbientGlow extends StatelessWidget {
  const _AmbientGlow();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _AmbientGlowPainter(),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _AmbientGlowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    final glow = Paint()
      ..shader = const RadialGradient(
        center: Alignment(0.02, 0.10),
        radius: 0.92,
        colors: [
          Color(0x442A70FF),
          Color(0x22204B9B),
          Color(0x00000000),
        ],
        stops: [0, 0.48, 1],
      ).createShader(rect);

    canvas.drawRect(rect, glow);

    final streakPaint = Paint()
      ..color = const Color(0xFF168CFF).withOpacity(0.20)
      ..strokeWidth = 1.2
      ..maskFilter = const MaskFilter.blur(
        BlurStyle.normal,
        4,
      );

    for (int i = 0; i < 5; i++) {
      final y = size.height * (0.12 + i * 0.17);

      canvas.drawLine(
        Offset(size.width * 0.20, y),
        Offset(size.width * 0.80, y - 7),
        streakPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class RoadPainter extends CustomPainter {
  final double progress;
  final int speed;
  final Color accent;

  RoadPainter({
    required this.progress,
    required this.speed,
    required this.accent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final w = size.width;
    final h = size.height;
    final cx = w * 0.5;
    final horizonY = h * 0.56;
    final topHalf = w * 0.055;
    final bottomHalf = w * 0.48;

    final atmosphere = Paint()
      ..shader = const RadialGradient(
        center: Alignment(0, 0.25),
        radius: 0.95,
        colors: [
          Color(0x55205CFF),
          Color(0x33102048),
          Color(0x00030712),
        ],
        stops: [0, 0.55, 1],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      atmosphere,
    );

    final horizonGlow = Paint()
      ..shader = RadialGradient(
        center: Alignment(0, (horizonY / h) * 2 - 1),
        radius: 0.48,
        colors: [
          accent.withOpacity(0.38),
          const Color(0x33235BFF),
          Colors.transparent,
        ],
        stops: const [0, 0.34, 1],
      ).createShader(
        Rect.fromLTWH(0, horizonY - h * 0.22, w, h * 0.48),
      );

    canvas.drawRect(
      Rect.fromLTWH(0, horizonY - h * 0.22, w, h * 0.48),
      horizonGlow,
    );

    final road = Path()
      ..moveTo(cx - topHalf, horizonY)
      ..lineTo(cx + topHalf, horizonY)
      ..lineTo(cx + bottomHalf, h)
      ..lineTo(cx - bottomHalf, h)
      ..close();

    final roadPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF101A2B),
          Color(0xFF07111F),
          Color(0xFF030812),
        ],
      ).createShader(
        Rect.fromLTWH(0, horizonY, w, h - horizonY),
      );

    canvas.drawPath(road, roadPaint);

    final reflection = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Colors.transparent,
          accent.withOpacity(0.10),
          const Color(0x663C7BFF),
          accent.withOpacity(0.10),
          Colors.transparent,
        ],
        stops: const [0, 0.28, 0.5, 0.72, 1],
      ).createShader(
        Rect.fromLTWH(0, horizonY, w, h - horizonY),
      );

    canvas.drawPath(road, reflection);

    void drawPerspectiveLine(
      double topX,
      double bottomX,
      Color color,
      double width,
      double opacity,
    ) {
      final paint = Paint()
        ..color = color.withOpacity(opacity)
        ..strokeWidth = width
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(
        Offset(cx + topX, horizonY),
        Offset(cx + bottomX, h),
        paint,
      );
    }

    drawPerspectiveLine(
      -topHalf,
      -bottomHalf * 0.94,
      const Color(0xFF4B7DFF),
      1.4,
      0.48,
    );

    drawPerspectiveLine(
      topHalf,
      bottomHalf * 0.94,
      const Color(0xFF4B7DFF),
      1.4,
      0.48,
    );

    drawPerspectiveLine(
      -topHalf * 0.62,
      -bottomHalf * 0.70,
      accent,
      2.2,
      0.92,
    );

    drawPerspectiveLine(
      topHalf * 0.62,
      bottomHalf * 0.70,
      accent,
      2.2,
      0.92,
    );

    final glowPaint = Paint()
      ..color = accent.withOpacity(0.28)
      ..strokeWidth = 7
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(
        BlurStyle.normal,
        7,
      );

    canvas.drawLine(
      Offset(cx - topHalf * 0.62, horizonY),
      Offset(cx - bottomHalf * 0.70, h),
      glowPaint,
    );

    canvas.drawLine(
      Offset(cx + topHalf * 0.62, horizonY),
      Offset(cx + bottomHalf * 0.70, h),
      glowPaint,
    );

    final movement =
        speed > 0 ? (progress * (0.20 + speed / 230.0)) % 1 : 0.0;

    for (int i = 0; i < 10; i++) {
      final t = ((i / 10.0) + movement) % 1;
      final p = t * t;
      final y = horizonY + (h - horizonY) * p;
      final dashHeight = 2.0 + h * 0.042 * p;
      final dashWidth = 1.0 + w * 0.009 * p;

      final dashPaint = Paint()
        ..color = Colors.white.withOpacity(0.20 + 0.68 * p)
        ..strokeWidth = dashWidth
        ..strokeCap = StrokeCap.round;

      final endY = (y + dashHeight).clamp(horizonY, h).toDouble();

      canvas.drawLine(
        Offset(cx, y),
        Offset(cx, endY),
        dashPaint,
      );
    }

    for (final side in [-1.0, 1.0]) {
      for (int i = 0; i < 7; i++) {
        final t = ((i / 7.0) + movement * 0.8) % 1;
        final p = t * t;
        final y = horizonY + (h - horizonY) * p;

        final x = cx +
            side *
                (topHalf * 0.6 +
                    (bottomHalf * 0.67 - topHalf * 0.6) * p);

        final dash = Paint()
          ..color = const Color(0xFFB9D7FF).withOpacity(0.16 + 0.52 * p)
          ..strokeWidth = 1 + 2.4 * p
          ..strokeCap = StrokeCap.round;

        canvas.drawLine(
          Offset(x, y),
          Offset(
            x,
            (y + 2 + h * 0.025 * p).clamp(y, h).toDouble(),
          ),
          dash,
        );
      }
    }

    final dots = Paint()
      ..color = const Color(0xFF7FCFFF).withOpacity(0.58);

    for (int i = 0; i < 13; i++) {
      final x = w * (0.12 + i * 0.063);
      final y = horizonY - h * (0.025 + (i % 3) * 0.009);

      canvas.drawCircle(
        Offset(x, y),
        i % 3 == 0 ? 1.5 : 0.8,
        dots,
      );
    }
  }

  @override
  bool shouldRepaint(covariant RoadPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.speed != speed ||
        oldDelegate.accent != accent;
  }
}

class SpeedGaugePainter extends CustomPainter {
  final int speed;
  final int maxSpeed;
  final Color color;
  final double intensity;

  SpeedGaugePainter({
    required this.speed,
    required this.maxSpeed,
    required this.color,
    required this.intensity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final center = Offset(
      size.width / 2,
      size.height * 0.43,
    );

    final radius = math.min(
      size.width * 0.405,
      size.height * 0.405,
    );

    final rect = Rect.fromCircle(
      center: center,
      radius: radius,
    );

    // شروع از پایین چپ و افزایش ساعت‌گرد تا پایین راست
    const startAngle = 2.35619449;
    const sweepAngle = 4.71238898;

    final basePaint = Paint()
      ..color = Colors.white.withOpacity(0.17)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      rect,
      startAngle,
      sweepAngle,
      false,
      basePaint,
    );

    final fraction = (speed / maxSpeed)
        .clamp(0.0, 1.0)
        .toDouble();

    if (fraction > 0) {
      final activePaint = Paint()
        ..color = color.withOpacity(
          (0.5 + 0.5 * intensity).clamp(0.0, 1.0),
        )
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round;

      if (intensity > 0.2) {
        activePaint.maskFilter = const MaskFilter.blur(
          BlurStyle.normal,
          3,
        );
      }

      canvas.drawArc(
        rect,
        startAngle,
        sweepAngle * fraction,
        false,
        activePaint,
      );
    }

    final tickPaint = Paint()
      ..strokeCap = StrokeCap.round;

    final labelStyle = TextStyle(
      color: Colors.white.withOpacity(0.82),
      fontSize: size.width < 280 ? 9 : 11,
      fontWeight: FontWeight.w600,
    );

    for (int i = 0; i <= 20; i++) {
      final angle = startAngle + sweepAngle * i / 20;
      final major = i % 2 == 0;

      final inner = radius - (major ? 13 : 7);
      final outer = radius + 1;

      final p1 = Offset(
        center.dx + math.cos(angle) * inner,
        center.dy + math.sin(angle) * inner,
      );

      final p2 = Offset(
        center.dx + math.cos(angle) * outer,
        center.dy + math.sin(angle) * outer,
      );

      tickPaint
        ..color = (
          i / 20 <= fraction && fraction > 0
              ? color
              : Colors.white
        ).withOpacity(major ? 0.88 : 0.36)
        ..strokeWidth = major ? 2 : 1;

      canvas.drawLine(p1, p2, tickPaint);

      if (i % 2 == 0) {
        final labelRadius = radius - 29;

        final labelPoint = Offset(
          center.dx + math.cos(angle) * labelRadius,
          center.dy + math.sin(angle) * labelRadius,
        );

        final textPainter = TextPainter(
          text: TextSpan(
            text: '${i * 10}',
            style: labelStyle,
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        textPainter.paint(
          canvas,
          Offset(
            labelPoint.dx - textPainter.width / 2,
            labelPoint.dy - textPainter.height / 2,
          ),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant SpeedGaugePainter oldDelegate) {
    return oldDelegate.speed != speed ||
        oldDelegate.maxSpeed != maxSpeed ||
        oldDelegate.color != color ||
        oldDelegate.intensity != intensity;
  }
}
