// lib/main.dart
// Tiba 2 Launcher — full production-ready main.dart
// Features:
//  1. Startup auto-request for permissions (location, storage, audio) via permission_handler
//  2. Music folder action using file_picker (FileType.audio, multiple files) + selected track
//  3. Speedometer repositioned higher (above Saipa emblem, with proper spacing)
//  4. Music player positioned lower / vertically centered with margins
//  5. All custom painters fully closed: CyberArcSpeedometerPainter, EqualizerPainter,
//     RealisticCyberRoadPainter, SaipaLogoPainter
//  6. Neon color palette, GPS speed calibration/stream, navigation app selection intent,
//     Android system settings intent
//
// pubspec.yaml dependencies:
//   permission_handler: ^11.3.1
//   file_picker: ^8.0.6
//   shared_preferences: ^2.2.3
//   audioplayers: ^6.1.0
//   geolocator: ^12.0.0
//   url_launcher: ^6.3.0
//
// AndroidManifest.xml:
//   <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
//   <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
//   <uses-permission android:name="android.permission.READ_MEDIA_AUDIO"/>
//   <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"
//       android:maxSdkVersion="32"/>

import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const Tiba2LauncherApp());
}

// ───────────────────────────── Neon Palette ─────────────────────────────

class NeonPalette {
  static const Color bg = Color(0xFF060B18);
  static const Color card = Color(0xFF0C1526);
  static const Color cyan = Color(0xFF00E5FF);
  static const Color blue = Color(0xFF2979FF);
  static const Color magenta = Color(0xFFFF2FD0);
  static const Color amber = Color(0xFFFFB300);
  static const Color green = Color(0xFF00E676);
  static const Color red = Color(0xFFFF1744);
  static const Color text = Colors.white;
  static const Color dim = Color(0xFF8FA3BF);

  static List<Color> get neonRamp => const [cyan, blue, magenta];
}

// ───────────────────────────── App Root ─────────────────────────────

class Tiba2LauncherApp extends StatelessWidget {
  const Tiba2LauncherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tiba 2 Launcher',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: NeonPalette.bg,
        colorScheme: const ColorScheme.dark(primary: NeonPalette.cyan),
        useMaterial3: true,
        fontFamily: 'Vazirmatn',
      ),
      home: const LauncherHome(),
    );
  }
}

// ───────────────────────────── Launcher Home ─────────────────────────────

class LauncherHome extends StatefulWidget {
  const LauncherHome({super.key});

  @override
  State<LauncherHome> createState() => _LauncherHomeState();
}

class _LauncherHomeState extends State<LauncherHome>
    with SingleTickerProviderStateMixin {
  // GPS speed stream
  StreamSubscription<Position>? _gpsSub;
  double _gpsSpeedKmh = 0; // raw device speed
  double _calibrationFactor = 1.0; // GPS calibration multiplier
  double _displaySpeed = 0;

  // Music
  final AudioPlayer _player = AudioPlayer();
  List<PlatformFile> _tracks = [];
  int _currentTrackIndex = -1;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration?>? _durSub;
  StreamSubscription<PlayerState>? _stateSub;

  // Navigation app
  String _navApp = 'Google Maps';

  // Animation for equalizer / road
  late final AnimationController _fx;

  @override
  void initState() {
    super.initState();
    _fx = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _calibrationFactor = prefs.getDouble('calibration') ?? 1.0;
      _navApp = prefs.getString('navApp') ?? 'Google Maps';
    });
    await _requestStartupPermissions();
    _startGpsStream();
    _listenPlayer();
  }

  // 1) Startup auto permission request: location, storage, audio
  Future<void> _requestStartupPermissions() async {
    await [
      ph.Permission.location,
      ph.Permission.locationWhenInUse,
      ph.Permission.storage,
      ph.Permission.mediaLibrary,
      ph.Permission.audio, // Android 13 READ_MEDIA_AUDIO
    ].request();
  }

  // 6) GPS speed stream with calibration
  void _startGpsStream() {
    _gpsSub?.cancel();
    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 1,
      ),
    ).listen((pos) {
      if (!mounted) return;
      final raw = (pos.speed <= 0 ? 0 : pos.speed) * 3.6; // m/s -> km/h
      setState(() {
        _gpsSpeedKmh = raw;
        _displaySpeed = (raw * _calibrationFactor).clamp(0, 220);
      });
    }, onError: (_) {});
  }

  void _listenPlayer() {
    _posSub = _player.onPositionChanged.listen((d) {
      if (mounted) setState(() => _position = d);
    });
    _durSub = _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _stateSub = _player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _isPlaying = s == PlayerState.playing);
    });
  }

  // 2) Music folder action via file_picker (audio, multiple)
  Future<void> _pickMusicFolder() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: true,
    );
    if (res == null || res.files.isEmpty) return;
    setState(() {
      _tracks = res.files;
      _currentTrackIndex = 0;
    });
    await _playTrack(0);
  }

  Future<void> _playTrack(int i) async {
    if (_tracks.isEmpty) return;
    setState(() => _currentTrackIndex = i);
    try {
      await _player.play(DeviceFileSource(_tracks[i].path!));
    } catch (_) {}
  }

  Future<void> _togglePlay() async {
    if (_tracks.isEmpty) {
      await _pickMusicFolder();
      return;
    }
    if (_isPlaying) {
      await _player.pause();
    } else {
      await _player.resume();
    }
  }

  Future<void> _nextTrack() async {
    if (_tracks.isEmpty) return;
    await _playTrack((_currentTrackIndex + 1) % _tracks.length);
  }

  Future<void> _prevTrack() async {
    if (_tracks.isEmpty) return;
    await _playTrack(
        (_currentTrackIndex - 1 + _tracks.length) % _tracks.length);
  }

  // 6) Navigation app selection + launch intent
  Future<void> _selectNavApp() async {
    final apps = ['Google Maps', 'Waze', 'Neshan', 'Balad'];
    final chosen = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: NeonPalette.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: apps
              .map((a) => ListTile(
                    leading: Icon(Icons.near_me,
                        color: a == _navApp
                            ? NeonPalette.cyan
                            : NeonPalette.dim),
                    title: Text(a),
                    trailing: a == _navApp
                        ? const Icon(Icons.check,
                            color: NeonPalette.cyan)
                        : null,
                    onTap: () => Navigator.pop(context, a),
                  ))
              .toList(),
        ),
      ),
    );
    if (chosen != null) {
      setState(() => _navApp = chosen);
      (await SharedPreferences.getInstance()).setString('navApp', chosen);
    }
  }

  Future<void> _launchNav() async {
    final Uri uri;
    switch (_navApp) {
      case 'Waze':
        uri = Uri.parse('waze://');
        break;
      case 'Neshan':
        uri = Uri.parse('neshan://');
        break;
      case 'Balad':
        uri = Uri.parse('balad://');
        break;
      default:
        uri = Uri.parse('geo:0,0?q=');
    }
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      await launchUrl(Uri.parse('https://maps.google.com'),
          mode: LaunchMode.externalApplication);
    }
  }

  // 6) Android system settings intent
  Future<void> _openSystemSettings() async {
    await openAppSettings(); // permission_handler settings intent
  }

  Future<void> _calibrateSpeed() async {
    final ctrl = TextEditingController(
        text: _calibrationFactor.toStringAsFixed(3));
    final v = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NeonPalette.card,
        title: const Text('GPS Speed Calibration (ضریب کالیبراسیون)'),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(hintText: 'مثال: 1.05'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('لغو')),
          FilledButton(
            onPressed: () =>
                Navigator.pop(ctx, double.tryParse(ctrl.text) ?? 1.0),
            child: const Text('ذخیره'),
          ),
        ],
      ),
    );
    if (v != null && v > 0) {
      setState(() => _calibrationFactor = v);
      (await SharedPreferences.getInstance())
          .setDouble('calibration', v);
    }
  }

  String _fmt(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  void dispose() {
    _gpsSub?.cancel();
    _posSub?.cancel();
    _durSub?.cancel();
    _stateSub?.cancel();
    _fx.dispose();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.4),
            radius: 1.4,
            colors: [Color(0xFF101B33), NeonPalette.bg],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(builder: (context, c) {
            final w = c.maxWidth;
            final h = c.maxHeight;
            return Stack(
              children: [
                // Animated cyber road background
                Positioned.fill(
                  child: CustomPaint(
                    painter: RealisticCyberRoadPainter(progress: _fx.value),
                  ),
                ),
                Row(
                  children: [
                    _buildSideDock(),
                    Expanded(
                      child: Column(
                        children: [
                          // 3) Speedometer positioned HIGHER (small top spacing,
                          //    clearly above the Saipa emblem area with gap)
                          SizedBox(height: h * 0.03),
                          SizedBox(
                            height: h * 0.42,
                            child: _buildSpeedometer(w),
                          ),
                          SizedBox(height: h * 0.06), // emblem spacing
                          _buildSaipaEmblem(),
                          const Spacer(),
                          // 4) Music player positioned LOWER / vertically
                          //    centered-ish with margins
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                                w * 0.04, 0, w * 0.04, h * 0.05),
                            child: _buildMusicPlayer(w),
                          ),
                        ],
                      ),
                    ),
                    _buildRightColumn(h),
                  ],
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  // ── Side dock ──
  Widget _buildSideDock() {
    Widget dockBtn(IconData ic, String label, VoidCallback onTap) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: NeonPalette.card.withOpacity(.8),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: NeonPalette.cyan.withOpacity(.4)),
                boxShadow: [
                  BoxShadow(
                    color: NeonPalette.cyan.withOpacity(.25),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: Icon(ic, color: NeonPalette.cyan),
            ),
          ),
        );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          dockBtn(Icons.home_filled, 'home', () {}),
          dockBtn(Icons.near_me, 'nav', _launchNav),
          dockBtn(Icons.apps_rounded, 'apps', _selectNavApp),
          dockBtn(Icons.library_music_rounded, 'music', _pickMusicFolder),
          dockBtn(Icons.speed_rounded, 'calib', _calibrateSpeed),
          dockBtn(Icons.settings_rounded, 'settings', _openSystemSettings),
        ],
      ),
    );
  }

  // ── Speedometer ──
  Widget _buildSpeedometer(double w) {
    return GestureDetector(
      onTap: _calibrateSpeed,
      child: CustomPaint(
        painter: CyberArcSpeedometerPainter(
          speed: _displaySpeed,
          maxSpeed: 220,
          progress: _fx.value,
        ),
        child: SizedBox(
          width: math.min(w * 0.3, 260),
          height: math.min(w * 0.3, 260),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _displaySpeed.toStringAsFixed(0),
                  style: const TextStyle(
                    fontSize: 46,
                    fontWeight: FontWeight.w900,
                    color: NeonPalette.text,
                    shadows: [
                      Shadow(color: NeonPalette.cyan, blurRadius: 24)
                    ],
                  ),
                ),
                const Text('km/h  •  GPS',
                    style: TextStyle(color: NeonPalette.dim, fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Saipa emblem ──
  Widget _buildSaipaEmblem() {
    return SizedBox(
      width: 150,
      height: 44,
      child: CustomPaint(
        painter: SaipaLogoPainter(glow: _fx.value),
        child: const Center(
          child: Text(
            'TIBA 2',
            style: TextStyle(
              color: NeonPalette.dim,
              fontSize: 11,
              letterSpacing: 6,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  // ── Music player (lower, centered, margins) ──
  Widget _buildMusicPlayer(double w) {
    final title = _tracks.isNotEmpty && _currentTrackIndex >= 0
        ? _tracks[_currentTrackIndex].name
        : 'آهنگی انتخاب نشده — پوشه موزیک را انتخاب کنید';
    final total = _duration.inMilliseconds == 0
        ? 1.0
        : _position.inMilliseconds / _duration.inMilliseconds;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: NeonPalette.card.withOpacity(.88),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: NeonPalette.cyan.withOpacity(.35)),
        boxShadow: [
          BoxShadow(
            color: NeonPalette.cyan.withOpacity(.18),
            blurRadius: 24,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        children: [
          // Equalizer art
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                colors: NeonPalette.neonRamp,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: CustomPaint(
              painter: EqualizerPainter(progress: _fx.value, playing: _isPlaying),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: NeonPalette.text, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 6),
                  ),
                  child: Slider(
                    value: total.clamp(0, 1),
                    activeColor: NeonPalette.cyan,
                    inactiveColor: NeonPalette.dim.withOpacity(.3),
                    onChanged: (v) {
                      if (_duration > Duration.zero) {
                        _player.seek(_duration * v);
                      }
                    },
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_fmt(_position),
                        style:
                            const TextStyle(color: NeonPalette.dim, fontSize: 11)),
                    Text(_fmt(_duration),
                        style:
                            const TextStyle(color: NeonPalette.dim, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
              onPressed: _prevTrack,
              icon: const Icon(Icons.skip_previous_rounded,
                  color: NeonPalette.text, size: 32)),
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(colors: [NeonPalette.cyan, NeonPalette.blue]),
              boxShadow: [
                BoxShadow(
                    color: NeonPalette.cyan.withOpacity(.5), blurRadius: 18)
              ],
            ),
            child: IconButton(
              onPressed: _togglePlay,
              iconSize: 30,
              icon: Icon(
                _isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                color: Colors.black,
              ),
            ),
          ),
          IconButton(
              onPressed: _nextTrack,
              icon: const Icon(Icons.skip_next_rounded,
                  color: NeonPalette.text, size: 32)),
        ],
      ),
    );
  }

  // ── Right column: clock, GPS status, nav button ──
  Widget _buildRightColumn(double h) {
    final now = DateTime.now();
    final t =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(t,
              style: const TextStyle(
                  color: NeonPalette.text,
                  fontSize: 22,
                  fontWeight: FontWeight.bold)),
          Text('GPS: ${_gpsSpeedKmh.toStringAsFixed(1)} km/h',
              style: const TextStyle(color: NeonPalette.dim, fontSize: 12)),
          Text('Cal: ×${_calibrationFactor.toStringAsFixed(3)}',
              style: const TextStyle(color: NeonPalette.dim, fontSize: 12)),
          const Spacer(),
          _navPill(),
        ],
      ),
    );
  }

  Widget _navPill() => InkWell(
        onTap: _launchNav,
        onLongPress: _selectNavApp,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: NeonPalette.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: NeonPalette.magenta.withOpacity(.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.navigation_rounded,
                  color: NeonPalette.magenta, size: 18),
              const SizedBox(width: 8),
              Text(_navApp, style: const TextStyle(color: NeonPalette.text)),
            ],
          ),
        ),
      );
}

// ═══════════════════ Custom Painters (all fully closed) ═══════════════════

// ── Cyber arc speedometer ──
class CyberArcSpeedometerPainter extends CustomPainter {
  final double speed;
  final double maxSpeed;
  final double progress;

  CyberArcSpeedometerPainter({
    required this.speed,
    this.maxSpeed = 220,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = math.min(size.width, size.height) / 2 - 8;
    final rect = Rect.fromCircle(center: c, radius: r);
    const start = math.pi * 0.75;
    const sweep = math.pi * 1.5;

    // Outer dark arc track
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round
      ..shader = const LinearGradient(colors: [
        Color(0xFF14243F),
        Color(0xFF0C1526),
      ]).createShader(rect);
    canvas.drawArc(rect, start, sweep, false, track);

    // Neon active arc
    final frac = (speed / maxSpeed).clamp(0.0, 1.0);
    final active = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: start,
        endAngle: start + sweep,
        colors: const [
          NeonPalette.cyan,
          NeonPalette.blue,
          NeonPalette.magenta
        ],
        transform: const GradientRotation(-math.pi / 4),
      ).createShader(rect);
    canvas.drawArc(rect, start, sweep * frac, false, active);

    // Glow tick pulse
    final pulse = (math.sin(progress * 2 * math.pi) + 1) / 2;
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4 + 2 * pulse
      ..color = NeonPalette.cyan.withOpacity(.35 + .3 * pulse);
    canvas.drawArc(rect.deflate(12), start, sweep * frac, false, glow);

    // Tick marks
    final tick = Paint()
      ..strokeWidth = 2
      ..color = NeonPalette.dim.withOpacity(.6);
    for (int i = 0; i <= 22; i++) {
      final a = start + sweep * i / 22;
      final p1 =
          c + Offset(math.cos(a), math.sin(a)) * (r - 22);
      final p2 =
          c + Offset(math.cos(a), math.sin(a)) * (r - 30);
      canvas.drawLine(p1, p2, tick);
    }
  }

  @override
  bool shouldRepaint(covariant CyberArcSpeedometerPainter old) =>
      old.speed != speed || old.progress != progress;
}

// ── Equalizer ──
class EqualizerPainter extends CustomPainter {
  final double progress;
  final bool playing;

  EqualizerPainter({required this.progress, required this.playing});

  @override
  void paint(Canvas canvas, Size size) {
    final bars = 5;
    final bw = size.width / (bars * 2 - 1);
    final paint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < bars; i++) {
      final t = playing
          ? (math.sin(progress * 2 * math.pi + i * 0.9) + 1) / 2
          : 0.25;
      final bh = size.height * (0.2 + 0.7 * t);
      paint.shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          NeonPalette.cyan.withOpacity(.9),
          NeonPalette.magenta.withOpacity(.9),
        ],
      ).createShader(
          Rect.fromLTWH(i * 2 * bw, size.height - bh, bw, bh));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(i * 2 * bw, size.height - bh, bw, bh),
          const Radius.circular(3),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant EqualizerPainter old) =>
      old.progress != progress || old.playing != playing;
}

// ── Realistic cyber road background ──
class RealisticCyberRoadPainter extends CustomPainter {
  final double progress;
  RealisticCyberRoadPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final horizon = size.height * 0.32;

    // Horizon glow
    final glow = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          NeonPalette.blue.withOpacity(.15),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, horizon));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, horizon), glow);

    // Road trapezoid
    final road = Path()
      ..moveTo(cx - 30, horizon)
      ..lineTo(cx + 30, horizon)
      ..lineTo(size.width * 1.1, size.height)
      ..lineTo(-size.width * 0.1, size.height)
      ..close();
    canvas.drawPath(
      road,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF0A1322).withOpacity(.8),
            const Color(0xFF101B33).withOpacity(.9),
          ],
        ).createShader(Rect.fromLTWH(0, horizon, size.width, size.height - horizon)),
    );

    // Animated lane dashes
    final dash = Paint()
      ..strokeWidth = 5
      ..color = NeonPalette.cyan.withOpacity(.7)
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 7; i++) {
      final t = ((progress + i / 7) % 1);
      final y1 = horizon + (size.height - horizon) * math.pow(t, 2.2).toDouble();
      final y2 =
          horizon + (size.height - horizon) * math.pow(t + 0.04, 2.2).toDouble();
      final w1 = 1 + 6 * t;
      canvas.drawLine(
        Offset(cx - w1 / 2, y1),
        Offset(cx - w1 / 2, y2),
        dash..strokeWidth = 2 + 5 * t,
      );
    }

    // Side neon rails
    final rail = Paint()
      ..strokeWidth = 3
      ..color = NeonPalette.magenta.withOpacity(.55);
    canvas.drawLine(Offset(cx - 30, horizon), Offset(-size.width * 0.1, size.height), rail);
    canvas.drawLine(Offset(cx + 30, horizon), Offset(size.width * 1.1, size.height), rail);
  }

  @override
  bool shouldRepaint(covariant RealisticCyberRoadPainter old) =>
      old.progress != progress;
}

// ── Saipa logo ──
class SaipaLogoPainter extends CustomPainter {
  final double glow;
  SaipaLogoPainter({required this.glow});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height * 0.35);
    final r = math.min(size.width, size.height) * 0.28;

    // Glow ring
    final pulse = (math.sin(glow * 2 * math.pi) + 1) / 2;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..shader = SweepGradient(
        colors: const [NeonPalette.cyan, NeonPalette.blue, NeonPalette.cyan],
        transform: GradientRotation(glow * 2 * math.pi),
      ).createShader(Rect.fromCircle(center: c, radius: r));
    canvas.drawCircle(c, r, ring);

    // Inner glow
    canvas.drawCircle(
      c,
      r * 0.9,
      Paint()
        ..color = NeonPalette.cyan.withOpacity(.08 + .08 * pulse)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );

    // Stylized Saipa "S" chevron mark
    final mark = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round
      ..color = NeonPalette.cyan;
    final path = Path()
      ..moveTo(c.dx - r * 0.45, c.dy - r * 0.25)
      ..lineTo(c.dx, c.dy + r * 0.15)
      ..lineTo(c.dx + r * 0.45, c.dy - r * 0.25)
      ..moveTo(c.dx - r * 0.45, c.dy + r * 0.1)
      ..lineTo(c.dx, c.dy + r * 0.5)
      ..lineTo(c.dx + r * 0.45, c.dy + r * 0.1);
    canvas.drawPath(path, mark);
  }

  @override
  bool shouldRepaint(covariant SaipaLogoPainter old) => old.glow != glow;
}
