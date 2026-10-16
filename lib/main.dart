import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

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
        scaffoldBackgroundColor: const Color(0xFF030712),
      ),
      home: const LauncherHome(),
    );
  }
}

class NeonPalette {
  static const Color cyan = Color(0xFF00E5FF);
  static const Color blue = Color(0xFF0077FE);
  static const Color darkBlue = Color(0xFF001F54);
  static const Color red = Color(0xFFFF2A6D);
  static const Color green = Color(0xFF05FFA1);
  static const Color panelBg = Color(0xCC071126);
  static const Color panelBorder = Color(0x6600E5FF);

  static const List<Color> neonRamp = [
    Color(0xFF00E5FF),
    Color(0xFF00B4D8),
    Color(0xFF0077FE),
  ];
}

class LauncherHome extends StatefulWidget {
  const LauncherHome({super.key});

  @override
  State<LauncherHome> createState() => _LauncherHomeState();
}

class _LauncherHomeState extends State<LauncherHome>
    with TickerProviderStateMixin {
  // GPS & Speed
  double _currentSpeed = 0.0;
  double _gpsMultiplier = 1.0;
  StreamSubscription<Position>? _positionSub;

  // Music Player
  final AudioPlayer _player = AudioPlayer();
  List<PlatformFile> _tracks = [];
  int _currentTrackIndex = -1;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  // Selected Gear
  String _currentGear = 'P';

  // Navigation app choice
  String _preferredNavApp = 'neshan';

  // Animation controller for road & HUD pulse
  late AnimationController _roadAnimCtrl;
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();

    _roadAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _initAudioListeners();
    _loadPreferences();
    _requestPermissionsAndStartGPS();
  }

  void _initAudioListeners() {
    _player.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = (state == PlayerState.playing);
        });
      }
    });

    _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });

    _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });

    _player.onPlayerComplete.listen((_) {
      _playNextTrack();
    });
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _gpsMultiplier = prefs.getDouble('gps_multiplier') ?? 1.0;
      _preferredNavApp = prefs.getString('preferred_nav_app') ?? 'neshan';
    });
  }

  Future<void> _requestPermissionsAndStartGPS() async {
    // درخواست دسترسی‌ها
    await [
      Permission.locationWhenInUse,
      Permission.storage,
      Permission.audio,
    ].request();

    _startGpsStream();
  }

  void _startGpsStream() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 1,
    );

    _positionSub?.cancel();
    _positionSub = Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen((Position position) {
      if (mounted) {
        double rawKmh = (position.speed >= 0 ? position.speed : 0) * 3.6;
        double speed = rawKmh * _gpsMultiplier;
        setState(() {
          _currentSpeed = speed.clamp(0.0, 240.0);
          if (_currentSpeed < 3.0) {
            _currentGear = 'P';
          } else {
            _currentGear = 'D';
          }
        });
      }
    });
  }

  Future<void> _pickAudioFiles() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'wav', 'aac', 'm4a', 'flac', 'ogg'],
      allowMultiple: true,
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _tracks = result.files.where((f) => f.path != null).toList();
        _currentTrackIndex = 0;
      });
      if (_tracks.isNotEmpty) {
        _playTrack(_tracks[0].path!);
      }
    }
  }

  Future<void> _playTrack(String path) async {
    await _player.stop();
    await _player.play(DeviceFileSource(path));
    setState(() {
      _isPlaying = true;
    });
  }

  void _togglePlayPause() async {
    if (_tracks.isEmpty) {
      await _pickAudioFiles();
      return;
    }
    if (_isPlaying) {
      await _player.pause();
    } else {
      await _player.resume();
    }
  }

  void _playNextTrack() {
    if (_tracks.isEmpty) return;
    int nextIndex = (_currentTrackIndex + 1) % _tracks.length;
    setState(() => _currentTrackIndex = nextIndex);
    _playTrack(_tracks[nextIndex].path!);
  }

  void _playPrevTrack() {
    if (_tracks.isEmpty) return;
    int prevIndex = (_currentTrackIndex - 1 + _tracks.length) % _tracks.length;
    setState(() => _currentTrackIndex = prevIndex);
    _playTrack(_tracks[prevIndex].path!);
  }

  Future<void> _openAndroidSettings() async {
    await openAppSettings();
  }

  Future<void> _launchNavigation() async {
    Uri uri;
    switch (_preferredNavApp) {
      case 'neshan':
        uri = Uri.parse('neshan://');
        break;
      case 'balad':
        uri = Uri.parse('balad://');
        break;
      case 'google':
      default:
        uri = Uri.parse('google.navigation:q=');
        break;
    }

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      final webUri = Uri.parse('https://maps.google.com');
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _launchRadio() async {
    final uri = Uri.parse('radio://');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('برنامه رادیو پیدا نشد')),
      );
    }
  }

  Future<void> _launchPhone() async {
    final uri = Uri.parse('tel:');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('برنامه تماس پیدا نشد')),
      );
    }
  }

  void _showCalibrationDialog() {
    double tempMult = _gpsMultiplier;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          title: const Text('تنظیمات و کالیبراسیون GPS',
              style: TextStyle(color: NeonPalette.cyan)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('ضریب اصلاح سرعت: ${tempMult.toStringAsFixed(2)}x',
                  style: const TextStyle(color: Colors.white70)),
              Slider(
                value: tempMult,
                min: 0.7,
                max: 1.3,
                divisions: 60,
                activeColor: NeonPalette.cyan,
                onChanged: (val) {
                  setDlgState(() => tempMult = val);
                },
              ),
              const Divider(color: Colors.white24),
              const Text('اپلیکیشن پیش‌فرض مسیریابی:',
                  style: TextStyle(color: Colors.white70)),
              DropdownButton<String>(
                value: _preferredNavApp,
                dropdownColor: const Color(0xFF1E293B),
                items: const [
                  DropdownMenuItem(value: 'neshan', child: Text('نشان (Neshan)')),
                  DropdownMenuItem(value: 'balad', child: Text('بلد (Balad)')),
                  DropdownMenuItem(value: 'google', child: Text('Google Maps')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _preferredNavApp = val);
                    setDlgState(() {});
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('انصراف', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: NeonPalette.cyan),
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setDouble('gps_multiplier', tempMult);
                await prefs.setString('preferred_nav_app', _preferredNavApp);
                setState(() => _gpsMultiplier = tempMult);
                if (mounted) Navigator.pop(ctx);
              },
              child: const Text('ذخیره', style: TextStyle(color: Colors.black)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _roadAnimCtrl.dispose();
    _pulseCtrl.dispose();
    _positionSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            // Side Bar (Dock)
            _buildDock(),

            // Main Dashboard 3 Columns
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    // Column 1: Navigation Widget
                    Expanded(flex: 3, child: _buildNavColumn()),

                    const SizedBox(width: 8),

                    // Column 2: Center (Tiba 2, Speed, Saipa, Rear Image, Road, Music Player)
                    Expanded(flex: 4, child: _buildCenterColumn()),

                    const SizedBox(width: 8),

                    // Column 3: Right (Car Full View + Music Picker button)
                    Expanded(flex: 3, child: _buildRightColumn()),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDock() {
    return Container(
      width: 64,
      decoration: BoxDecoration(
        color: const Color(0x99050B14),
        border: Border(right: BorderSide(color: NeonPalette.panelBorder, width: 1)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: const Icon(Icons.settings, color: NeonPalette.cyan),
            onPressed: _openAndroidSettings,
            tooltip: 'تنظیمات اندروید',
          ),
          IconButton(
            icon: const Icon(Icons.navigation, color: NeonPalette.cyan),
            onPressed: _launchNavigation,
            tooltip: 'مسیریاب',
          ),
          IconButton(
            icon: const Icon(Icons.radio, color: NeonPalette.cyan),
            onPressed: _launchRadio,
            tooltip: 'رادیو',
          ),
          IconButton(
            icon: const Icon(Icons.phone, color: NeonPalette.cyan),
            onPressed: _launchPhone,
            tooltip: 'تماس',
          ),
          IconButton(
            icon: const Icon(Icons.tune, color: NeonPalette.cyan),
            onPressed: _showCalibrationDialog,
            tooltip: 'کالیبراسیون و تنظیمات لانچر',
          ),
        ],
      ),
    );
  }

  Widget _buildNavColumn() {
    return Container(
      decoration: BoxDecoration(
        color: NeonPalette.panelBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: NeonPalette.panelBorder),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: const [
              Icon(Icons.explore, color: NeonPalette.cyan, size: 20),
              SizedBox(width: 6),
              Text(
                'مسیریابی هوشمند',
                style: TextStyle(
                  color: NeonPalette.cyan,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Spacer(),
          Center(
            child: Icon(
              Icons.navigation_outlined,
              size: 72,
              color: NeonPalette.cyan.withOpacity(0.8),
            ),
          ),
          const Spacer(),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0x3300E5FF),
              side: const BorderSide(color: NeonPalette.cyan),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _launchNavigation,
            icon: const Icon(Icons.near_me, color: NeonPalette.cyan),
            label: const Text('شروع مسیریابی', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildCenterColumn() {
    return Container(
      decoration: BoxDecoration(
        color: NeonPalette.panelBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: NeonPalette.panelBorder),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background Cyber Road
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _roadAnimCtrl,
              builder: (context, _) => CustomPaint(
                painter: CyberRoadPainter(offset: _roadAnimCtrl.value),
              ),
            ),
          ),

          // Central Elements Column
          Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top Title: TIBA 2
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Column(
                  children: const [
                    Text(
                      'TIBA 2',
                      style: TextStyle(
                        color: NeonPalette.cyan,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 4,
                      ),
                    ),
                    Text(
                      'تیبا ۲',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),

              // Center Speedometer + Saipa + Rear Image
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Speed Arc & Value
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 130,
                        height: 70,
                        child: CustomPaint(
                          painter: SpeedArcPainter(speed: _currentSpeed),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _currentSpeed.toStringAsFixed(0),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Text(
                            'KM/H',
                            style: TextStyle(
                              color: NeonPalette.cyan,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 4),

                  // SAIPA Neon Title
                  const Text(
                    'SAIPA',
                    style: TextStyle(
                      color: NeonPalette.cyan,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 3,
                    ),
                  ),

                  // Tiba 2 Rear Image
                  SizedBox(
                    height: 55,
                    child: Image.asset(
                      'tiba2_rear.png',
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.directions_car,
                        color: NeonPalette.cyan,
                        size: 40,
                      ),
                    ),
                  ),

                  // Gear indicators P R N D
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: ['P', 'R', 'N', 'D'].map((g) {
                      bool isCur = (_currentGear == g);
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6.0),
                        child: Text(
                          g,
                          style: TextStyle(
                            color: isCur ? NeonPalette.cyan : Colors.white24,
                            fontWeight: isCur ? FontWeight.bold : FontWeight.normal,
                            fontSize: 14,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),

              // Center Horizontal Mini Music Player
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0, left: 12.0, right: 12.0),
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xBB081426),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: NeonPalette.panelBorder),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        iconSize: 20,
                        icon: const Icon(Icons.skip_previous, color: NeonPalette.cyan),
                        onPressed: _playPrevTrack,
                      ),
                      IconButton(
                        iconSize: 24,
                        icon: Icon(
                          _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                          color: NeonPalette.cyan,
                        ),
                        onPressed: _togglePlayPause,
                      ),
                      IconButton(
                        iconSize: 20,
                        icon: const Icon(Icons.skip_next, color: NeonPalette.cyan),
                        onPressed: _playNextTrack,
                      ),
                      Expanded(
                        child: Text(
                          _tracks.isNotEmpty && _currentTrackIndex >= 0
                              ? _tracks[_currentTrackIndex].name
                              : 'آهنگی انتخاب نشده',
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRightColumn() {
    return Container(
      decoration: BoxDecoration(
        color: NeonPalette.panelBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: NeonPalette.panelBorder),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // Top Button: Open Storage / Audio Files
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0x3300E5FF),
              side: const BorderSide(color: NeonPalette.cyan),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              minimumSize: const Size.fromHeight(40),
            ),
            onPressed: _pickAudioFiles,
            icon: const Icon(Icons.folder_open, color: NeonPalette.cyan, size: 20),
            label: const Text(
              'انتخاب فایل‌های موزیک',
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),

          const Spacer(),

          // Main Car Image: tiba2.png
          Expanded(
            flex: 5,
            child: Image.asset(
              'tiba2.png',
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Center(
                child: Icon(Icons.drive_eta, color: NeonPalette.cyan, size: 80),
              ),
            ),
          ),

          const Spacer(),
        ],
      ),
    );
  }
}

class SpeedArcPainter extends CustomPainter {
  final double speed;
  SpeedArcPainter({required this.speed});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = size.width * 0.45;

    final bgPaint = Paint()
      ..color = Colors.white12
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round;

    final valPaint = Paint()
      ..color = NeonPalette.cyan
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round;

    // 180 degrees arc (from pi to 2*pi)
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi,
      math.pi,
      false,
      bgPaint,
    );

    double sweep = (speed / 240.0).clamp(0.0, 1.0) * math.pi;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi,
      sweep,
      false,
      valPaint,
    );
  }

  @override
  bool shouldRepaint(covariant SpeedArcPainter oldDelegate) =>
      oldDelegate.speed != speed;
}

class CyberRoadPainter extends CustomPainter {
  final double offset;
  CyberRoadPainter({required this.offset});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x1A00E5FF)
      ..strokeWidth = 1.5;

    // Horizon center
    final hCenter = Offset(size.width / 2, size.height * 0.35);

    // Grid lines perspective
    for (double i = -size.width * 0.8; i <= size.width * 0.8; i += 40) {
      canvas.drawLine(
        hCenter,
        Offset(size.width / 2 + i * 2, size.height),
        paint,
      );
    }

    // Horizontal moving stripes
    for (int i = 0; i < 6; i++) {
      double pos = ((i + offset) / 6.0);
      double y = size.height * 0.35 + (size.height * 0.65) * (pos * pos);
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CyberRoadPainter oldDelegate) => true;
}
