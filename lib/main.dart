import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audio_session/audio_session.dart';
import 'package:file_picker/file_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TibaLauncherApp());
  
  Future.microtask(() async {
    try {
      await JustAudioBackground.init(
        androidNotificationChannelId: 'com.tiba.launcher.audio',
        androidNotificationChannelName: 'Tiba 2 Music',
        androidNotificationOngoing: true,
      );
    } catch (_) {}
  });
}

class TibaLauncherApp extends StatefulWidget {
  const TibaLauncherApp({super.key});
  @override
  State<TibaLauncherApp> createState() => _TibaLauncherAppState();
}

class _TibaLauncherAppState extends State<TibaLauncherApp> {
  Color _neon = const Color(0xFF00F0FF);
  double _offset = 0.0, _maxSpeed = 180;
  bool _use24h = true, _keepAwake = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await SharedPreferences.getInstance();
      setState(() {
        _neon = Color(p.getInt('neon') ?? 0xFF00F0FF);
        _offset = p.getDouble('offset') ?? 0.0;
        _maxSpeed = p.getDouble('maxSpeed') ?? 180;
        _use24h = p.getBool('use24h') ?? true;
        _keepAwake = p.getBool('keepAwake') ?? true;
      });
      WakelockPlus.toggle(enable: _keepAwake);
    } catch (_) {}
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setInt('neon', _neon.value);
    await p.setDouble('offset', _offset);
    await p.setDouble('maxSpeed', _maxSpeed);
    await p.setBool('use24h', _use24h);
    await p.setBool('keepAwake', _keepAwake);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF060913),
      ),
      home: Dashboard(
        neon: _neon,
        offset: _offset,
        maxSpeed: _maxSpeed,
        use24h: _use24h,
        keepAwake: _keepAwake,
        onSave: (c, o, m, u, k) {
          setState(() {
            _neon = c;
            _offset = o;
            _maxSpeed = m;
            _use24h = u;
            _keepAwake = k;
          });
          WakelockPlus.toggle(enable: k);
          _save();
        },
      ),
    );
  }
}

class Dashboard extends StatefulWidget {
  final Color neon;
  final double offset, maxSpeed;
  final bool use24h, keepAwake;
  final Function(Color, double, double, bool, bool) onSave;

  const Dashboard({
    super.key,
    required this.neon,
    required this.offset,
    required this.maxSpeed,
    required this.use24h,
    required this.keepAwake,
    required this.onSave,
  });

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  double _rawSpeed = 0.0;
  StreamSubscription<Position>? _gpsSub;
  final AudioPlayer _player = AudioPlayer();
  final List<String> _playlist = [];
  int _idx = -1;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _startGps();
        _initAudio();
      }
    });
  }

  @override
  void dispose() {
    _gpsSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _startGps() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.denied) return;
      }
      _gpsSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 2,
        ),
      ).listen((p) {
        if (mounted) {
          final kmh = p.speed * 3.6;
          setState(() => _rawSpeed = kmh > 1.5 ? kmh : 0.0);
        }
      });
    } catch (_) {}
  }

  Future<void> _initAudio() async {
    try {
      final s = AudioSession.instance;
      await (await s).configure(const AudioSessionConfiguration.music());
      
      final sp = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() => _playlist.addAll(sp.getStringList('playlist') ?? []));
      }

      _player.playerStateStream.listen((st) {
        if (st.processingState == ProcessingState.completed) _next();
        if (mounted) setState(() {});
      });

      final last = sp.getInt('lastIdx') ?? -1;
      if (last >= 0 && last < _playlist.length) {
        setState(() => _idx = last);
        await _player.setAudioSource(_sourceFor(last));
      }
    } catch (_) {}
  }

  AudioSource _sourceFor(int i) {
    final p = _playlist[i];
    return AudioSource.uri(
      Uri.file(p),
      tag: MediaItem(id: p, title: p.split('/').last, album: 'Tiba 2'),
    );
  }

  int get _speed {
    int s = (_rawSpeed + widget.offset).round();
    return s < 0 ? 0 : s;
  }

  Future<void> _pick() async {
    try {
      final res = await FilePicker.platform.pickFiles(type: FileType.audio, allowMultiple: true);
      if (res == null) return;
      setState(() {
        for (final p in res.paths) {
          if (p != null && !_playlist.contains(p)) _playlist.add(p);
        }
      });
      final sp = await SharedPreferences.getInstance();
      await sp.setStringList('playlist', _playlist);
      if (_idx == -1 && _playlist.isNotEmpty) _play(0);
    } catch (_) {}
  }

  Future<void> _play(int i) async {
    if (i < 0 || i >= _playlist.length) return;
    setState(() => _idx = i);
    try {
      await _player.setAudioSource(_sourceFor(i));
      await _player.play();
    } catch (_) {
      _next();
    }
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setInt('lastIdx', _idx);
    } catch (_) {}
  }

  void _next() => _playlist.isNotEmpty ? _play((_idx + 1) % _playlist.length) : null;
  void _prev() => _playlist.isNotEmpty ? _play((_idx - 1 + _playlist.length) % _playlist.length) : null;

  void _toggle() {
    if (_playlist.isEmpty) { _pick(); return; }
    if (_idx == -1) { _play(0); return; }
    _player.playing ? _player.pause() : _player.play();
    setState(() {});
  }

  Future<void> _openApp(String packageName) async {
    try {
      const platform = MethodChannel('com.tiba.launcher/app');
      await platform.invokeMethod('openApp', {'package': packageName});
    } catch (_) {}
  }

  void _showAllAppsModal() async {
    List<Map<dynamic, dynamic>> apps = [];
    try {
      const platform = MethodChannel('com.tiba.launcher/app');
      final List result = await platform.invokeMethod('getInstalledApps');
      apps = result.cast<Map<dynamic, dynamic>>();
    } catch (_) {}

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0B0F19),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 14),
              Text('تمام نرم‌افزارهای دستگاه',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: widget.neon)),
              const SizedBox(height: 16),
              Expanded(
                child: apps.isEmpty
                    ? const Center(child: Text('هیچ برنامه‌ای یافت نشد'))
                    : GridView.builder(
                        controller: scrollController,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.1,
                        ),
                        itemCount: apps.length,
                        itemBuilder: (context, index) {
                          final app = apps[index];
                          final name = app['name'] ?? '';
                          final pkg = app['package'] ?? '';
                          return InkWell(
                            onTap: () {
                              Navigator.pop(ctx);
                              _openApp(pkg);
                            },
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: widget.neon.withOpacity(0.25)),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.android, color: widget.neon, size: 30),
                                  const SizedBox(height: 6),
                                  Text(
                                    name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 11, color: Colors.white),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSettings() {
    Color col = widget.neon;
    double off = widget.offset, maxS = widget.maxSpeed;
    bool u24 = widget.use24h, ka = widget.keepAwake;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('تنظیمات لانچر تیبا ۲',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Color(0xFF00F0FF),
                  const Color(0xFF7DD3FC),
                  const Color(0xFF39FF14),
                  const Color(0xFFFF0055),
                  const Color(0xFFFFB800),
                ].map((c) => GestureDetector(
                  onTap: () => setM(() => col = c),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: col.value == c.value ? Border.all(color: Colors.white, width: 3) : null,
                    ),
                  ),
                )).toList(),
              ),
              const SizedBox(height: 12),
              Text('خطای سرعت‌سنج: ${off.round()} km/h'),
              Slider(
                value: off,
                min: -15,
                max: 15,
                divisions: 30,
                activeColor: col,
                onChanged: (v) => setM(() => off = v),
              ),
              SwitchListTile(
                title: const Text('ساعت ۲۴ ساعته'),
                value: u24,
                activeColor: col,
                onChanged: (v) => setM(() => u24 = v),
              ),
              SwitchListTile(
                title: const Text('روشن ماندن صفحه'),
                value: ka,
                activeColor: col,
                onChanged: (v) => setM(() => ka = v),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: col,
                  foregroundColor: Colors.black,
                  minimumSize: const Size(double.infinity, 44),
                ),
                onPressed: () {
                  widget.onSave(col, off, maxS, u24, ka);
                  Navigator.pop(ctx);
                },
                child: const Text('ذخیره و اعمال', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.neon;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.settings, color: c, size: 26),
                        onPressed: _showSettings,
                      ),
                      const SizedBox(width: 6),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: c.withOpacity(0.12),
                          foregroundColor: Colors.white,
                          side: BorderSide(color: c.withOpacity(0.4)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _showAllAppsModal,
                        icon: Icon(Icons.apps, color: c, size: 20),
                        label: const Text('نرم‌افزارها', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  StreamBuilder(
                    stream: Stream.periodic(const Duration(seconds: 1)),
                    builder: (_, __) {
                      final n = DateTime.now();
                      return Text(
                        widget.use24h
                            ? "${n.hour.toString().padLeft(2, '0')}:${n.minute.toString().padLeft(2, '0')}"
                            : "${n.hour % 12 == 0 ? 12 : n.hour % 12}:${n.minute.toString().padLeft(2, '0')}",
                        style: TextStyle(color: c, fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Column(
                        children: [
                          Expanded(
                            child: _card(
                              c,
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.navigation, color: c, size: 14),
                                      const SizedBox(width: 4),
                                      Text('NAVIGATION', style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                                    children: [
                                      _navBtn('نشان', () => _openApp('ir.neshan.taksi'), c),
                                      _navBtn('بلد', () => _openApp('ir.map.balad'), c),
                                      _navBtn('گوگل مپ', () => _openApp('com.google.android.apps.maps'), c),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: _card(
                              c,
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.music_note, color: c, size: 14),
                                          const SizedBox(width: 4),
                                          Text('MUSIC', style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
                                        ],
                                      ),
                                      TextButton(
                                        onPressed: _pick,
                                        style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(50, 30)),
                                        child: Text('+ انتخاب آهنگ', style: TextStyle(color: c, fontSize: 11)),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    _idx >= 0 && _idx < _playlist.length ? _playlist[_idx].split('/').last : 'موزیک در حال پخش...',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                                  ),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      IconButton(icon: const Icon(Icons.skip_previous, size: 26), onPressed: _prev),
                                      IconButton(
                                        icon: Icon(_player.playing ? Icons.pause_circle_filled : Icons.play_circle_filled),
                                        color: c,
                                        iconSize: 40,
                                        onPressed: _toggle,
                                      ),
                                      IconButton(icon: const Icon(Icons.skip_next, size: 26), onPressed: _next),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 4,
                      child: Center(
                        child: CustomPaint(
                          painter: SpeedPainter(speed: _speed, max: widget.maxSpeed, color: c),
                          child: SizedBox(
                            width: 190,
                            height: 190,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('$_speed', style: const TextStyle(fontSize: 52, fontWeight: FontWeight.bold, color: Colors.white)),
                                Text('KM/H', style: TextStyle(color: c, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 2)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: _card(
                        c,
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('TIBA 2', style: TextStyle(color: c, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 2)),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: c.withOpacity(0.1),
                                border: Border.all(color: c.withOpacity(0.4), width: 2),
                                boxShadow: [BoxShadow(color: c.withOpacity(0.2), blurRadius: 10, spreadRadius: 2)],
                              ),
                              child: Icon(Icons.directions_car, color: c, size: 52),
                            ),
                            const SizedBox(height: 12),
                            const Text('سایپا تیبا ۲', style: TextStyle(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.w600)),
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

  Widget _card(Color c, Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.withOpacity(0.3), width: 1.5),
        boxShadow: [BoxShadow(color: c.withOpacity(0.04), blurRadius: 8, spreadRadius: 1)],
      ),
      child: child,
    );
  }

  Widget _navBtn(String label, VoidCallback tap, Color c) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: c.withOpacity(0.15),
        foregroundColor: Colors.white,
        side: BorderSide(color: c.withOpacity(0.5)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: tap,
      child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }
}

class SpeedPainter extends CustomPainter {
  final int speed;
  final double max;
  final Color color;
  SpeedPainter({required this.speed, required this.max, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 12;
    
    final bgPaint = Paint()
      ..color = Colors.white.withOpacity(0.07)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 10;
    canvas.drawArc(Rect.fromCircle(center: center, radius: r), -math.pi * 1.25, math.pi * 1.5, false, bgPaint);

    final sweep = (speed / max).clamp(0.0, 1.0) * math.pi * 1.5;
    final progPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 10;
    canvas.drawArc(Rect.fromCircle(center: center, radius: r), -math.pi * 1.25, sweep, false, progPaint);
  }

  @override
  bool shouldRepaint(covariant SpeedPainter old) => old.speed != speed || old.color != color;
}
