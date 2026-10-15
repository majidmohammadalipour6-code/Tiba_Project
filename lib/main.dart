import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:just_audio/just_audio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:android_intent_plus/android_intent.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const TibaLauncherApp());
}

class TibaLauncherApp extends StatefulWidget {
  const TibaLauncherApp({super.key});

  @override
  State<TibaLauncherApp> createState() => _TibaLauncherAppState();
}

class _TibaLauncherAppState extends State<TibaLauncherApp> {
  Color _primaryColor = const Color(0xFF00E5FF);
  double _glowIntensity = 1.0;

  @override
  void initState() {
    super.initState();
    _loadThemePreferences();
  }

  Future<void> _loadThemePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final colorVal = prefs.getInt('theme_color') ?? 0xFF00E5FF;
    final glow = prefs.getDouble('glow_intensity') ?? 1.0;
    setState(() {
      _primaryColor = Color(colorVal);
      _glowIntensity = glow;
    });
  }

  void _updateTheme(Color color, double glow) async {
    setState(() {
      _primaryColor = color;
      _glowIntensity = glow;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_color', color.value);
    await prefs.setDouble('glow_intensity', glow);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Tiba 2 CyberHUD',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF030712),
      ),
      home: DashboardScreen(
        primaryColor: _primaryColor,
        glowIntensity: _glowIntensity,
        onThemeChanged: _updateTheme,
      ),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  final Color primaryColor;
  final double glowIntensity;
  final Function(Color, double) onThemeChanged;

  const DashboardScreen({
    super.key,
    required this.primaryColor,
    required this.glowIntensity,
    required this.onThemeChanged,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with TickerProviderStateMixin {
  // Speed & GPS
  double _currentSpeed = 0.0;
  StreamSubscription<Position>? _positionStream;

  // Music Player
  late AudioPlayer _audioPlayer;
  String _currentSongTitle = "بدون آهنگ انتخابی";
  String _currentArtist = "Unknown Artist";
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  // Gear & Clock
  String _selectedGear = 'D';
  late Timer _clockTimer;
  String _timeString = "";

  // Animated perspective road
  late AnimationController _roadAnimCtrl;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _initTime();
    _initLocation();
    _initAudio();

    _roadAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  void _initTime() {
    _updateClock();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (timer) => _updateClock());
  }

  void _updateClock() {
    final now = DateTime.now();
    setState(() {
      _timeString = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
    });
  }

  Future<void> _initLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 1,
      );

      _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings).listen((Position pos) {
        if (mounted) {
          setState(() {
            _currentSpeed = (pos.speed < 0 ? 0.0 : pos.speed * 3.6); // km/h
          });
        }
      });
    } catch (_) {}
  }

  void _initAudio() {
    _audioPlayer = AudioPlayer();
    _audioPlayer.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing;
        });
      }
    });

    _audioPlayer.positionStream.listen((p) {
      if (mounted) setState(() => _position = p);
    });

    _audioPlayer.durationStream.listen((d) {
      if (mounted) setState(() => _duration = d ?? Duration.zero);
    });
  }

  Future<void> _pickAudioFolder() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'm4a', 'wav', 'flac'],
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final playlist = ConcatenatingAudioSource(
          children: result.files
              .where((f) => f.path != null)
              .map((f) => AudioSource.file(f.path!, tag: f.name))
              .toList(),
        );

        await _audioPlayer.setAudioSource(playlist);
        _audioPlayer.currentIndexStream.listen((idx) {
          if (idx != null && idx < result.files.length) {
            setState(() {
              _currentSongTitle = result.files[idx].name.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');
              _currentArtist = "Tiba Media";
            });
          }
        });
        _audioPlayer.play();
      }
    } catch (_) {}
  }

  void _openSettingsDialog() {
    Color selectedColor = widget.primaryColor;
    double glow = widget.glowIntensity;

    final palette = [
      const Color(0xFF00E5FF), // Cyber Cyan
      const Color(0xFF2979FF), // Deep Blue
      const Color(0xFFD500F9), // Cyber Violet
      const Color(0xFFFF1744), // Neon Red
      const Color(0xFFFF9100), // Amber Gold
      const Color(0xFF00E676), // Neon Green
    ];

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF0B132B).withOpacity(0.95),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: selectedColor.withOpacity(0.8), width: 1.5),
              ),
              title: Row(
                children: [
                  Icon(Icons.tune_rounded, color: selectedColor),
                  const SizedBox(width: 10),
                  const Text("تنظیمات تم و روشنایی نئون", style: TextStyle(color: Colors.white, fontSize: 16)),
                ],
              ),
              content: SizedBox(
                width: 360,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("طیف رنگی نئون:", style: TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 12,
                      children: palette.map((c) {
                        final isSel = c.value == selectedColor.value;
                        return GestureDetector(
                          onTap: () {
                            setDialogState(() => selectedColor = c);
                          },
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSel ? Colors.white : Colors.transparent,
                                width: 3,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: c.withOpacity(0.6),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    Text("شدت نور و درخشش نئون (${(glow * 100).toInt()}%):", style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    Slider(
                      value: glow,
                      min: 0.3,
                      max: 1.5,
                      activeColor: selectedColor,
                      inactiveColor: Colors.white24,
                      onChanged: (v) {
                        setDialogState(() => glow = v);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("انصراف", style: TextStyle(color: Colors.white54)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: selectedColor,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () {
                    widget.onThemeChanged(selectedColor, glow);
                    Navigator.pop(ctx);
                  },
                  child: const Text("ذخیره تغییرات", style: TextStyle(fontWeight: FontWeight.bold)),
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
    _clockTimer.cancel();
    _positionStream?.cancel();
    _audioPlayer.dispose();
    _roadAnimCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.primaryColor;
    final glow = widget.glowIntensity;

    return Scaffold(
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.2,
              colors: [Color(0xFF081426), Color(0xFF030712)],
            ),
          ),
          child: Column(
            children: [
              _buildTopStatusBar(theme, glow),
              Expanded(
                child: Row(
                  children: [
                    _buildDockSidebar(theme, glow),
                    Expanded(flex: 30, child: _buildNavigationCard(theme, glow)),
                    Expanded(flex: 38, child: _buildSpeedometerCard(theme, glow)),
                    Expanded(
                      flex: 32,
                      child: Column(
                        children: [
                          Expanded(flex: 52, child: _buildMusicCard(theme, glow)),
                          Expanded(flex: 48, child: _buildCarStatusCard(theme, glow)),
                        ],
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

  // -------------------------------------------------------------
  // TOP STATUS BAR
  // -------------------------------------------------------------
  Widget _buildTopStatusBar(Color theme, double glow) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: theme.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(Icons.flash_on, color: theme, size: 16),
              ),
              const SizedBox(width: 10),
              Text(
                _timeString,
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 1),
              ),
              const SizedBox(width: 10),
              const Icon(Icons.network_cell, color: Colors.white70, size: 14),
              const SizedBox(width: 4),
              const Text("LTE", style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
          Row(
            children: [
              Icon(Icons.wifi, color: theme, size: 16),
              const SizedBox(width: 12),
              const Icon(Icons.bluetooth, color: Colors.blueAccent, size: 16),
              const SizedBox(width: 12),
              const Icon(Icons.mail_outline, color: Colors.white70, size: 16),
              const SizedBox(width: 12),
              const Icon(Icons.battery_charging_full_rounded, color: Color(0xFF00E676), size: 16),
              const SizedBox(width: 4),
              const Text("100%", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // DOCK SIDEBAR
  // -------------------------------------------------------------
  Widget _buildDockSidebar(Color theme, double glow) {
    return Container(
      width: 54,
      margin: const EdgeInsets.only(left: 8, bottom: 8, top: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF06101E).withOpacity(0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.withOpacity(0.3 * glow), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: theme.withOpacity(0.15 * glow),
            blurRadius: 12 * glow,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _sidebarButton(Icons.grid_view_rounded, false, theme, () {}),
          _sidebarButton(Icons.explore_rounded, false, theme, () {}),
          _sidebarButton(Icons.music_note_rounded, true, theme, () {}),
          _sidebarButton(Icons.apps_rounded, false, theme, () {}),
          _sidebarButton(Icons.tune_rounded, false, theme, _openSettingsDialog),
        ],
      ),
    );
  }

  Widget _sidebarButton(IconData icon, bool active, Color theme, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: active ? theme.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: active ? Border.all(color: theme, width: 1.2) : null,
          boxShadow: active
              ? [BoxShadow(color: theme.withOpacity(0.4), blurRadius: 10, spreadRadius: 1)]
              : null,
        ),
        child: Icon(icon, color: active ? theme : Colors.white60, size: 20),
      ),
    );
  }

  // -------------------------------------------------------------
  // NAVIGATION CARD (3D Road Perspective)
  // -------------------------------------------------------------
  Widget _buildNavigationCard(Color theme, double glow) {
    return _neonPanel(
      theme: theme,
      glow: glow,
      child: Stack(
        children: [
          // 3D Styled Road Map Background
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: CustomPaint(
              size: Size.infinite,
              painter: NavigationRoadPainter(themeColor: theme),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: theme.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.navigation_rounded, color: theme, size: 22),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text("0.5 mi - Route 101", style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                          Text("Continue on Route 101", style: TextStyle(color: Colors.white54, fontSize: 10)),
                        ],
                      ),
                    ),
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.redAccent.withOpacity(0.7)),
                      ),
                      child: const Center(
                        child: Text("N", style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                // ETA Row
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: const [
                      _NavMetric(title: "8 min", subtitle: "ETA"),
                      _NavMetric(title: "3.2 mi", subtitle: "Distance"),
                      _NavMetric(title: "23:44", subtitle: "Arrival"),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Start Navigation Button
                SizedBox(
                  width: double.infinity,
                  height: 38,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme,
                      foregroundColor: Colors.black,
                      elevation: 8,
                      shadowColor: theme.withOpacity(0.7 * glow),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      final intent = AndroidIntent(
                        action: 'action_view',
                        data: 'geo:0,0?q=destination',
                      );
                      await intent.launch();
                    },
                    icon: const Icon(Icons.near_me_rounded, size: 16),
                    label: const Text("Start Navigation", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // SPEEDOMETER CARD (Full Numbers + Saipa Neon Logo + Real Tiba 2 & Road)
  // -------------------------------------------------------------
  Widget _buildSpeedometerCard(Color theme, double glow) {
    return _neonPanel(
      theme: theme,
      glow: glow,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 1. Perspective Road Underneath
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 140,
            child: AnimatedBuilder(
              animation: _roadAnimCtrl,
              builder: (context, child) {
                return CustomPaint(
                  painter: RoadPerspectivePainter(
                    themeColor: theme,
                    progress: _roadAnimCtrl.value,
                  ),
                );
              },
            ),
          ),

          // 2. Real Tiba 2 Vehicle Image on Road
          Positioned(
            bottom: 38,
            child: SizedBox(
              width: 140,
              height: 75,
              child: Image.asset(
                'tiba2.png',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.directions_car_filled_rounded, color: Colors.white, size: 55);
                },
              ),
            ),
          ),

          // 3. Dial Gauges with Full Scale Numbers
          Positioned.fill(
            top: 6,
            bottom: 60,
            child: CustomPaint(
              painter: SpeedometerDialPainter(
                speed: _currentSpeed,
                themeColor: theme,
                glow: glow,
              ),
            ),
          ),

          // 4. Center Speed Digital Readout + SAIPA Neon Logo
          Positioned(
            top: 48,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _currentSpeed.toInt().toString(),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    shadows: [
                      Shadow(color: theme.withOpacity(0.9 * glow), blurRadius: 20 * glow),
                    ],
                  ),
                ),
                Text(
                  "KM / H",
                  style: TextStyle(
                    color: theme,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2.5,
                  ),
                ),
                const SizedBox(height: 10),
                // SAIPA Glowing Neon Emblem
                CustomPaint(
                  size: const Size(36, 32),
                  painter: SaipaNeonLogoPainter(color: theme, glow: glow),
                ),
              ],
            ),
          ),

          // 5. Gear Selection (D, P, R, N)
          Positioned(
            bottom: 8,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: ['D', 'P', 'R', 'N'].map((g) {
                final isSelected = _selectedGear == g;
                return GestureDetector(
                  onTap: () => setState(() => _selectedGear = g),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                    decoration: BoxDecoration(
                      color: isSelected ? theme.withOpacity(0.2) : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? theme : Colors.transparent,
                        width: 1.5,
                      ),
                      boxShadow: isSelected
                          ? [BoxShadow(color: theme.withOpacity(0.6 * glow), blurRadius: 10 * glow)]
                          : null,
                    ),
                    child: Text(
                      g,
                      style: TextStyle(
                        color: isSelected ? theme : Colors.white54,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // MUSIC PLAYER CARD
  // -------------------------------------------------------------
  Widget _buildMusicCard(Color theme, double glow) {
    return _neonPanel(
      theme: theme,
      glow: glow,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Now Playing", style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Icon(Icons.folder_open_rounded, color: theme, size: 18),
                  onPressed: _pickAudioFolder,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Row(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF5252), Color(0xFFFF7A00), Color(0xFF7C4DFF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(color: Colors.redAccent.withOpacity(0.3), blurRadius: 10),
                      ],
                    ),
                    child: const Icon(Icons.music_note_rounded, color: Colors.white, size: 30),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _currentSongTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _currentArtist,
                          style: const TextStyle(color: Colors.white54, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Progress Bar
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 8),
                activeTrackColor: theme,
                inactiveTrackColor: Colors.white12,
                thumbColor: Colors.white,
              ),
              child: Slider(
                value: _position.inSeconds.toDouble().clamp(0.0, _duration.inSeconds.toDouble() > 0 ? _duration.inSeconds.toDouble() : 1.0),
                max: _duration.inSeconds.toDouble() > 0 ? _duration.inSeconds.toDouble() : 1.0,
                onChanged: (v) => _audioPlayer.seek(Duration(seconds: v.toInt())),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_formatDuration(_position), style: const TextStyle(color: Colors.white54, fontSize: 9)),
                Text(_formatDuration(_duration), style: const TextStyle(color: Colors.white54, fontSize: 9)),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(icon: const Icon(Icons.shuffle, size: 16, color: Colors.white54), onPressed: () {}),
                IconButton(
                  icon: const Icon(Icon
