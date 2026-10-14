import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:audio_session/audio_session.dart';
import 'package:file_picker/file_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:volume_controller/volume_controller.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.tiba.launcher.audio',
    androidNotificationChannelName: 'Tiba 2 Music',
    androidNotificationOngoing: true,
  );
  runApp(const TibaLauncherApp());
}

class TibaLauncherApp extends StatefulWidget {
  const TibaLauncherApp({super.key});

  @override
  State<TibaLauncherApp> createState() => _TibaLauncherAppState();
}

class _TibaLauncherAppState extends State<TibaLauncherApp> {
  Color _primaryNeon = const Color(0xFF7DD3FC);
  double _speedOffset = 0.0;
  double _maxSpeed = 180;
  bool _use24h = true;
  bool _keepAwake = true;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      _primaryNeon = Color(p.getInt('neon') ?? 0xFF7DD3FC);
      _speedOffset = p.getDouble('offset') ?? 0.0;
      _maxSpeed = p.getDouble('maxSpeed') ?? 180;
      _use24h = p.getBool('use24h') ?? true;
      _keepAwake = p.getBool('keepAwake') ?? true;
    });
    WakelockPlus.toggle(enable: _keepAwake);
  }

  Future<void> _savePrefs() async {
    final p = await SharedPreferences.getInstance();
    await p.setInt('neon', _primaryNeon.value);
    await p.setDouble('offset', _speedOffset);
    await p.setDouble('maxSpeed', _maxSpeed);
    await p.setBool('use24h', _use24h);
    await p.setBool('keepAwake', _keepAwake);
  }

  void _updateTheme(Color color, double offset) {
    setState(() {
      _primaryNeon = color;
      _speedOffset = offset;
    });
    _savePrefs();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Tiba 2 Launcher',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF07090D),
      ),
      home: DashboardScreen(
        primaryNeon: _primaryNeon,
        speedOffset: _speedOffset,
        maxSpeed: _maxSpeed,
        use24h: _use24h,
        keepAwake: _keepAwake,
        onUpdateTheme: _updateTheme,
        onSetMaxSpeed: (v) {
          setState(() => _maxSpeed = v);
          _savePrefs();
        },
        onSetUse24h: (v) {
          setState(() => _use24h = v);
          _savePrefs();
        },
        onSetKeepAwake: (v) {
          setState(() => _keepAwake = v);
          WakelockPlus.toggle(enable: v);
          _savePrefs();
        },
      ),
    );
  }
}

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color accent;

  const GlassCard({
    super.key,
    required this.child,
    required this.accent,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.055),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: accent.withOpacity(0.25), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  final Color primaryNeon;
  final double speedOffset;
  final double maxSpeed;
  final bool use24h;
  final bool keepAwake;
  final Function(Color, double) onUpdateTheme;
  final Function(double) onSetMaxSpeed;
  final Function(bool) onSetUse24h;
  final Function(bool) onSetKeepAwake;

  const DashboardScreen({
    super.key,
    required this.primaryNeon,
    required this.speedOffset,
    required this.maxSpeed,
    required this.use24h,
    required this.keepAwake,
    required this.onUpdateTheme,
    required this.onSetMaxSpeed,
    required this.onSetUse24h,
    required this.onSetKeepAwake,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  double _rawSpeed = 0.0;
  StreamSubscription<Position>? _positionStream;

  final AudioPlayer _player = AudioPlayer();
  final List<String> _playlist = [];
  int _currentIndex = -1;

  double _volume = 0.7;
  late AnimationController _equalizerController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initGps();
    _initAudio();
    _initVolume();
    _equalizerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _savePlaybackState();
    _positionStream?.cancel();
    _player.dispose();
    _equalizerController.dispose();
    VolumeController.instance.removeListener();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _savePlaybackState();
    }
  }

  Future<void> _savePlaybackState() async {
    final p = await SharedPreferences.getInstance();
    await p.setInt('lastIndex', _currentIndex);
    await p.setInt('lastPosMs', _player.position.inMilliseconds);
  }

  Future<void> _initGps() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 0,
    );

    _positionStream =
        Geolocator.getPositionStream(locationSettings: locationSettings)
            .listen((Position position) {
      if (mounted) {
        setState(() {
          double speedKmH = (position.speed * 3.6);
          _rawSpeed = speedKmH > 1.5 ? speedKmH : 0.0;
        });
      }
    });
  }

  Future<void> _initAudio() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    final p = await SharedPreferences.getInstance();
    final saved = p.getStringList('playlist') ?? [];
    setState(() => _playlist.addAll(saved));

    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _playNext();
      }
      if (mounted) setState(() {});
    });
    _player.positionStream.listen((_) {
      if (mounted) setState(() {});
    });

    final lastIndex = p.getInt('lastIndex') ?? -1;
    if (lastIndex >= 0 && lastIndex < _playlist.length) {
      setState(() => _currentIndex = lastIndex);
      try {
        await _player.setAudioSource(_sourceFor(lastIndex));
        final posMs = p.getInt('lastPosMs') ?? 0;
        if (posMs > 0) await _player.seek(Duration(milliseconds: posMs));
      } catch (_) {}
    }
    if (mounted) setState(() {});
  }

  AudioSource _sourceFor(int index) {
    final path = _playlist[index];
    final name = path.split('/').last;
    return AudioSource.uri(
      Uri.file(path),
      tag: MediaItem(
        id: path,
        title: name,
        album: 'Tiba 2',
      ),
    );
  }

  Future<void> _initVolume() async {
    VolumeController.instance.addListener(() {
      if (mounted) setState(() {});
    });
    _volume = await VolumeController.instance.getVolume();
    if (mounted) setState(() {});
  }

  int get _displaySpeed {
    int finalSpeed = (_rawSpeed + widget.speedOffset).round();
    return finalSpeed < 0 ? 0 : finalSpeed;
  }

  Future<void> _pickSongs() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: true,
    );
    if (result == null) return;
    setState(() {
      for (final f in result.paths) {
        if (f != null && !_playlist.contains(f)) _playlist.add(f);
      }
    });
    final p = await SharedPreferences.getInstance();
    await p.setStringList('playlist', _playlist);
    if (_currentIndex == -1 && _playlist.isNotEmpty) {
      await _playIndex(0);
    }
  }

  Future<void> _playIndex(int index) async {
    if (index < 0 || index >= _playlist.length) return;
    setState(() => _currentIndex = index);
    try {
      await _player.setAudioSource(_sourceFor(index));
      await _player.play();
    } catch (_) {
      _playNext();
    }
    _savePlaybackState();
  }

  Future<void> _playNext() async {
    if (_playlist.isEmpty) return;
    await _playIndex((_currentIndex + 1) % _playlist.length);
  }

  Future<void> _playPrev() async {
    if (_playlist.isEmpty) return;
    await _playIndex(
        (_currentIndex - 1 + _playlist.length) % _playlist.length);
  }

  Future<void> _togglePlay() async {
    if (_playlist.isEmpty) {
      await _pickSongs();
      return;
    }
    if (_currentIndex == -1) {
      await _playIndex(0);
      return;
    }
    if (_player.playing) {
      await _player.pause();
      _savePlaybackState();
    } else {
      await _player.play();
    }
    if (mounted) setState(() {});
  }

  String _songName(int i) {
    return _playlist[i].split('/').last;
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _launchApp(String urlScheme, String webFallback) async {
    final Uri uri = Uri.parse(urlScheme);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      final Uri fallbackUri = Uri.parse(webFallback);
      await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
    }
  }

  void _openSettingsDialog() {
    Color selectedColor = widget.primaryNeon;
    double tempOffset = widget.speedOffset;
    double tempMax = widget.maxSpeed;
    bool temp24h = widget.use24h;
    bool tempAwake = widget.keepAwake;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Center(
                      child: Text(
                        'تنظیمات لانچر تیبا ۲',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _sectionTitle('رنگ نئون'),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _colorPickerDot(const Color(0xFF7DD3FC), selectedColor,
                            (c) => setModalState(() => selectedColor = c)),
                        _colorPickerDot(const Color(0xFF00F0FF), selectedColor,
                            (c) => setModalState(() => selectedColor = c)),
                        _colorPickerDot(const Color(0xFF39FF14), selectedColor,
                            (c) => setModalState(() => selectedColor = c)),
                        _colorPickerDot(const Color(0xFFFF0055), selectedColor,
                            (c) => setModalState(() => selectedColor = c)),
                        _colorPickerDot(const Color(0xFFFFB800), selectedColor,
                            (c) => setModalState(() => selectedColor = c)),
                        _colorPickerDot(const Color(0xFF9D00FF), selectedColor,
                            (c) => setModalState(() => selectedColor = c)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _sectionTitle('کالیبراسیون سرعت‌سنج GPS'),
                    Text(
                      'خطا: ${tempOffset > 0 ? "+$tempOffset" : tempOffset} km/h',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    Slider(
                      value: tempOffset,
                      min: -15,
                      max: 15,
                      divisions: 30,
                      activeColor: selectedColor,
                      onChanged: (val) =>
                          setModalState(() => tempOffset = val),
                    ),
                    _sectionTitle('حداکثر محدوده‌ی سرعت‌سنج'),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [120.0, 180.0, 240.0].map((v) {
                        final sel = tempMax == v;
                        return ChoiceChip(
                          label: Text('${v.round()}'),
                          selected: sel,
                          selectedColor: selectedColor,
                          labelStyle: TextStyle(
                              color: sel ? Colors.black : Colors.white),
                          onSelected: (_) => setModalState(() => tempMax = v),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    _sectionTitle('ساعت'),
                    SwitchListTile(
                      title: const Text('نمایش ۲۴ ساعته',
                          style: TextStyle(color: Colors.white, fontSize: 14)),
                      value: temp24h,
                      activeColor: selectedColor,
                      onChanged: (v) => setModalState(() => temp24h = v),
                    ),
                    _sectionTitle('صفحه‌نمایش'),
                    SwitchListTile(
                      title: const Text('روشن نگه‌داشتن صفحه',
                          style: TextStyle(color: Colors.white, fontSize: 14)),
                      value: tempAwake,
                      activeColor: selectedColor,
                      onChanged: (v) => setModalState(() => tempAwake = v),
                    ),
                    const SizedBox(height: 12),
                    _sectionTitle('بلندی صدا'),
                    Row(
                      children: [
                        const Icon(Icons.volume_down,
                            color: Colors.white54, size: 20),
                        Expanded(
                          child: Slider(
                            value: _volume,
                            activeColor: selectedColor,
                            onChanged: (v) {
                              setModalState(() => _volume = v);
                              VolumeController.instance.setVolume(v);
                            },
                          ),
                        ),
                        const Icon(Icons.volume_up,
                            color: Colors.white54, size: 20),
                      ],
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: selectedColor,
                        foregroundColor: Colors.black,
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () {
                        widget.onUpdateTheme(selectedColor, tempOffset);
                        widget.onSetMaxSpeed(tempMax);
                        widget.onSetUse24h(temp24h);
                        widget.onSetKeepAwake(tempAwake);
                        Navigator.pop(context);
                      },
                      child: const Text('ذخیره و اعمال',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text,
          style: TextStyle(
              color: widget.primaryNeon,
              fontWeight: FontWeight.bold,
              fontSize: 13)),
    );
  }

  Widget _colorPickerDot(
      Color color, Color currentSelected, Function(Color) onTap) {
    bool isSel = color.value == currentSelected.value;
    return GestureDetector(
      onTap: () => onTap(color),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: isSel ? Border.all(color: Colors.white, width: 3) : null,
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.6),
              blurRadius: 10,
              spreadRadius: 2,
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.primaryNeon;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -1.3),
            radius: 1.7,
            colors: [
              Color.lerp(const Color(0xFF16222E), accent, 0.12)!,
              const Color(0xFF07090D),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 18.0, vertical: 14.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: Icon(Icons.settings_outlined,
                          color: accent, size: 28),
                      onPressed: _openSettingsDialog,
                    ),
                    StreamBuilder(
                      stream: Stream.periodic(const Duration(seconds: 1)),
                      builder: (context, snapshot) {
                        final now = DateTime.now();
                        String timeStr;
                        if (widget.use24h) {
                          timeStr =
                              "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
                        } else {
                          final h = now.hour % 12 == 0 ? 12 : now.hour % 12;
                          final amPm = now.hour < 12 ? 'AM' : 'PM';
                          timeStr =
                              "$h:${now.minute.toString().padLeft(2, '0')} $amPm";
                        }
                        return Text(
                          timeStr,
                          style: TextStyle(
                            color: accent,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                            shadows: [
                              Shadow(
                                  color: accent.withOpacity(0.8),
                                  blurRadius: 12),
                            ],
                          ),
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
                              flex: 5,
                              child: GlassCard(
                                accent: accent,
                                child: _buildNavCardContent(accent),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Expanded(
                              flex: 6,
                              child: GlassCard(
                                accent: accent,
                                child: _buildMusicCardContent(accent),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 4,
                        child: GestureDetector(
                          onLongPress: _openSettingsDialog,
                          child: Center(
                            child: AspectRatio(
                              aspectRatio: 1,
                              child: LayoutBuilder(builder: (context, c) {
                                final size = math.min(c.maxWidth, c.maxHeight);
                                return CustomPaint(
                                  size: Size(size, size),
                                  painter: _SpeedometerPainter(
                                    speed: _displaySpeed,
                                    accent: accent,
                                    maxSpeed: widget.maxSpeed,
                                  ),
                                  child: Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '$_displaySpeed',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: size * 0.28,
                                            fontWeight: FontWeight.w300,
                                            letterSpacing: -2,
                                            shadows: [
                                              Shadow(
                                                color:
                                                    accent.withOpacity(0.85),
                                                blurRadius: 30,
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'KM/H',
                                          style: TextStyle(
                                            color: accent,
                                            fontSize: size * 0.06,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 4,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        const Text(
                                          'GPS LIVE',
                                          style: TextStyle(
                                            color: Colors.white38,
                                            fontSize: 10,
                                            letterSpacing: 2,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 3,
                        child: GlassCard(
                          accent: accent,
                          padding: const EdgeInsets.all(18),
                          child: _buildTibaCarCardContent(accent),
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
    );
  }

  Widget _buildNavCardContent(Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.near_me, color: accent, size: 18),
            const SizedBox(width: 8),
            Text(
              'NAVIGATION',
              style: TextStyle(
                color: accent,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
        const Spacer(),
        const Text(
          'انتخاب مسیریاب',
          style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 4),
        const Text(
          'مسیر خود را انتخاب کنید',
          style: TextStyle(fontSize: 13, color: Colors.white54),
        ),
        const Spacer(),
        Row(
          children: [
            _buildNavChip(
              accent: accent,
              title: 'نشان',
              icon: Icons.navigation_rounded,
              onTap: () => _launchApp('nshn://', 'https://neshan.org/maps'),
            ),
            const SizedBox(width: 10),
            _buildNavChip(
              accent: accent,
              title: 'بلد',
              icon: Icons.map_rounded,
              onTap: () => _launchApp('balad://', 'https://balad.ir'),
            ),
            const SizedBox(width: 10),
            _buildNavChip(
              accent: accent,
              title: 'گوگل',
              icon: Icons.explore_rounded,
              onTap: () =>
                  _launchApp('google.navigation:q=', 'https://maps.google.com'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNavChip({
    required Color accent,
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: accent),
              const SizedBox(width: 6),
              Text(title, style: const TextStyle(fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMusicCardContent(Color accent) {
    final hasSongs = _playlist.isNotEmpty;
    final position = _player.position;
    final duration = _player.duration ?? Duration.zero;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.music_note, color: accent, size: 16),
            const SizedBox(width: 6),
            Text('CAR AUDIO',
                style: TextStyle(
                    color: accent,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5)),
            const SizedBox(width: 8),
            _buildAnimatedEqualizer(),
            const Spacer(),
            GestureDetector(
              onTap: _pickSongs,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: accent.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.add, size: 14, color: accent),
                    const SizedBox(width: 4),
                    Text('آهنگ‌ها',
                        style: TextStyle(fontSize: 11, color: accent)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          hasSongs
              ? (_currentIndex >= 0 ? _songName(_currentIndex) : _songName(0))
              : 'آهنگی انتخاب نشده — دکمه «آهنگ‌ها» را بزن',
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: hasSongs ? Colors.white : Colors.white38),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Text(_fmt(position),
                style:
                    const TextStyle(fontSize: 10, color: Colors.white54)),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape:
                      const RoundOverlayShape(overlayRadius: 12),
                ),
                child: Slider(
                  value: duration.inMilliseconds > 0
                      ? position.inMilliseconds
                          .clamp(0, duration.inMilliseconds)
                          .toDouble()
                      : 0,
                  max: duration.inMilliseconds > 0
                      ? duration.inMilliseconds.toDouble()
                      : 1,
                  activeColor: accent,
                  inactiveColor: Colors.white.withOpacity(0.15),
                  onChanged: duration.inMilliseconds > 0
                      ? (v) => _player.seek(
                          Duration(milliseconds: v.round()))
                      : null,
                ),
              ),
            ),
            Text(_fmt(duration),
                style:
                    const TextStyle(fontSize: 10, color: Colors.white54)),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.skip_previous_rounded, size: 30),
              color: Colors.white70,
              onPressed: hasSongs ? _playPrev : null,
            ),
            GestureDetector(
              onTap: _togglePlay,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: accent.withOpacity(0.6),
                      blurRadius: 14,
                    ),
                  ],
                ),
                child: Icon(
                  _player.playing ? Icons.pause : Icons.play_arrow_rounded,
                  color: Colors.black,
                  size: 30,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.skip_next_rounded, size: 30),
              color: Colors.white70,
              onPressed: hasSongs ? _playNext : null,
            ),
            const SizedBox(width: 8),
            StreamBuilder<LoopMode>(
              stream: _player.loopModeStream,
              builder: (context, snap) {
                final loop = snap.data ?? LoopMode.off;
                return IconButton(
                  icon: Icon(
                    loop == LoopMode.one ? Icons.repeat_one : Icons.repeat,
                    size: 22,
                    color: loop == LoopMode.off ? Colors.white38 : accent,
                  ),
                  onPressed: () {
                    _player.setLoopMode(
                        loop == LoopMode.off ? LoopMode.one : LoopMode.off);
                  },
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAnimatedEqualizer() {
    return AnimatedBuilder(
      animation: _equalizerController,
      builder: (context, child) {
        return Row(
          children: List.generate(4, (index) {
            double height = _player.playing
                ? (5 + (9 * ((_equalizerController.value + index * 0.2) % 1)))
                : 4;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              width: 3,
              height: height,
              decoration: BoxDecoration(
                color: widget.primaryNeon,
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildTibaCarCardContent(Color accent) {
    return Column(
      children: [
        Row(
          children: [
            Icon(Icons.directions_car, color: accent, size: 18),
            const SizedBox(width: 8),
            Text(
              'CAR STATUS',
              style: TextStyle(
                color: accent,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
        const Spacer(),
        Text(
          'TIBA 2',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: 3,
            shadows: [Shadow(color: accent.withOpacity(0.7), blurRadius: 14)],
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'سواری شهری',
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Center(
            child: Image.asset(
              'tiba2.png',
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Image.asset(
                  'assets/tiba2.png',
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(
                      Icons.directions_car_filled_rounded,
                      color: accent,
                      size: 90,
                    );
                  },
                );
              },
            ),
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: accent.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: accent.withOpacity(0.4)),
          ),
          child: Text(
            'GPS LIVE',
            style: TextStyle(fontSize: 11, color: accent, letterSpacing: 1.5),
          ),
        ),
      ],
    );
  }
}

class _SpeedometerPainter extends CustomPainter {
  final int speed;
  final Color accent;
  final double maxSpeed;
  _SpeedometerPainter({
    required this.speed,
    required this.accent,
    required this.maxSpeed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 12;

    final glow = Paint()
      ..color = accent.withOpacity(0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 26);
    canvas.drawCircle(center, radius, glow);

    final track = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2, 2 * math.pi, false, track);

    final sweep = 2 * math.pi * (speed / maxSpeed).clamp(0.0, 1.0);
    final progress = Paint()
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: 3 * math.pi / 2,
        colors: [accent, accent.withOpacity(0.55)],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2, sweep, false, progress);

    final inner = Paint()
      ..color = accent.withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, radius - 24, inner);

    final tick = Paint()
      ..color = Colors.white.withOpacity(0.25)
      ..strokeWidth = 2;
    for (var i = 0; i < 24; i++) {
      final a = -math.pi / 2 + (2 * math.pi * i / 24);
      final p1 = Offset(center.dx + math.cos(a) * (radius - 20),
          center.dy + math.sin(a) * (radius - 20));
      final p2 = Offset(center.dx + math.cos(a) * (radius - 14),
          center.dy + math.sin(a) * (radius - 14));
      canvas.drawLine(p1, p2, tick);
    }
  }

  @override
  bool shouldRepaint(_SpeedometerPainter old) =>
      old.speed != speed ||
      old.accent != accent ||
      old.maxSpeed != maxSpeed;
}
