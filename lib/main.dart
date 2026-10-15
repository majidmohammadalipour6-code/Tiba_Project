import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:just_audio/just_audio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const TibaCyberHudLauncher());
}

class TibaCyberHudLauncher extends StatelessWidget {
  const TibaCyberHudLauncher({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Tiba 2 Cyber HUD',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF030712),
      ),
      home: const CyberDashboardScreen(),
    );
  }
}

class CyberDashboardScreen extends StatefulWidget {
  const CyberDashboardScreen({super.key});

  @override
  State<CyberDashboardScreen> createState() => _CyberDashboardScreenState();
}

class _CyberDashboardScreenState extends State<CyberDashboardScreen> {
  int _selectedSidebarIndex = 0;
  double _currentSpeed = 0.0;
  StreamSubscription<Position>? _positionStream;

  // موزیک پلیر
  final AudioPlayer _audioPlayer = AudioPlayer();
  ConcatenatingAudioSource? _playlist;
  bool _isPlaying = false;
  String _currentSongTitle = "بدون آهنگ انتخابی";
  String _artistName = "Unknown Artist";
  Duration _duration = const Duration(minutes: 3, seconds: 56);
  Duration _position = const Duration(minutes: 1, seconds: 24);

  // نوار وضعیت
  late Timer _clockTimer;
  String _currentTime = "23:36";

  // دنده انتخابی
  String _selectedGear = 'D';

  // استایل نئونی
  final Color _neonCyan = const Color(0xFF00E5FF);
  final Color _neonBlue = const Color(0xFF0077FE);
  final Color _cardBg = const Color(0xFF081120).withOpacity(0.85);

  @override
  void initState() {
    super.initState();
    _updateClock();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (timer) => _updateClock());
    _initGps();
    _initAudioPlayer();
  }

  void _updateClock() {
    final now = DateTime.now();
    if (mounted) {
      setState(() {
        _currentTime = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
      });
    }
  }

  Future<void> _initGps() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 1,
      );
      _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings).listen(
        (pos) {
          if (mounted) {
            setState(() {
              _currentSpeed = pos.speed >= 0 ? (pos.speed * 3.6) : 0.0;
            });
          }
        },
      );
    } catch (e) {
      debugPrint("GPS Error: $e");
    }
  }

  void _initAudioPlayer() {
    _audioPlayer.playerStateStream.listen((state) {
      if (mounted) setState(() => _isPlaying = state.playing);
    });
    _audioPlayer.positionStream.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _audioPlayer.durationStream.listen((d) {
      if (mounted && d != null) setState(() => _duration = d);
    });
  }

  Future<void> _pickAndPlayMusic() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: true,
      );
      if (result != null && result.files.isNotEmpty) {
        List<AudioSource> sources = [];
        for (var f in result.files) {
          if (f.path != null) sources.add(AudioSource.file(f.path!));
        }
        _playlist = ConcatenatingAudioSource(children: sources);
        await _audioPlayer.setAudioSource(_playlist!);
        await _audioPlayer.play();
        setState(() {
          _currentSongTitle = result.files.first.name;
          _artistName = "پخش از حافظه خودرو";
        });
      }
    } catch (e) {
      debugPrint("Audio Error: $e");
    }
  }

  Future<void> _launchIntent(String action, {String? data}) async {
    final intent = AndroidIntent(
      action: action,
      data: data,
      flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
    );
    try {
      await intent.launch();
    } catch (e) {
      debugPrint("Intent Error: $e");
    }
  }

  String _formatDuration(Duration d) {
    String minutes = d.inMinutes.remainder(60).toString();
    String seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    _positionStream?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.0, -0.2),
            radius: 1.3,
            colors: [
              Color(0xFF0D1E38),
              Color(0xFF040915),
              Color(0xFF02040A),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // نوار بالایی کامپکت مطابق عکس
              _buildTopBar(),

              // بدنه اصلی لانچر
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 14, 10),
                  child: Row(
                    children: [
                      // ۱. سایدبار آیکون‌ها
                      _buildSidebar(),
                      const SizedBox(width: 12),

                      // ۲. کارت ناوبری (چپ)
                      Expanded(flex: 32, child: _buildNavigationCard()),
                      const SizedBox(width: 12),

                      // ۳. کیلومتر شمار و HUD پرسپکتیو (مرکز)
                      Expanded(flex: 36, child: _buildCenterHudCard()),
                      const SizedBox(width: 12),

                      // ۴. ستون سمت راست: مدیا پلیر + وضعیت خودرو
                      Expanded(
                        flex: 32,
                        child: Column(
                          children: [
                            Expanded(flex: 48, child: _buildNowPlayingCard()),
                            const SizedBox(height: 12),
                            Expanded(flex: 52, child: _buildCarStatusCard()),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================= نوار بالایی (Status Bar) =================
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: _neonCyan.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(Icons.flash_on_rounded, color: _neonCyan, size: 16),
              ),
              const SizedBox(width: 12),
              Text(
                _currentTime,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1),
              ),
              const SizedBox(width: 10),
              const Icon(Icons.signal_cellular_alt_rounded, color: Colors.white70, size: 15),
              const SizedBox(width: 4),
              const Text("LTE", style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
          Row(
            children: [
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(Icons.wifi, color: _neonCyan, size: 17),
                onPressed: () => _launchIntent('android.settings.WIFI_SETTINGS'),
              ),
              const SizedBox(width: 14),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(Icons.bluetooth, color: _neonCyan, size: 17),
                onPressed: () => _launchIntent('android.settings.BLUETOOTH_SETTINGS'),
              ),
              const SizedBox(width: 14),
              const Icon(Icons.mail_outline_rounded, color: Colors.white70, size: 17),
              const SizedBox(width: 14),
              const Icon(Icons.battery_charging_full_rounded, color: Colors.greenAccent, size: 18),
              const SizedBox(width: 4),
              const Text("100%", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  // ================= سایدبار مدرن عمودی =================
  Widget _buildSidebar() {
    return Container(
      width: 52,
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _neonBlue.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(color: _neonBlue.withOpacity(0.08), blurRadius: 10, spreadRadius: 1),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _dockItem(Icons.grid_view_rounded, 0, () => setState(() => _selectedSidebarIndex = 0)),
          _dockItem(Icons.explore_rounded, 1, () => _launchIntent('android.intent.action.VIEW', data: 'geo:0,0?q=navigation')),
          _dockItem(Icons.music_note_rounded, 2, () => setState(() => _selectedSidebarIndex = 2), hasIndicator: true),
          _dockItem(Icons.apps_rounded, 3, () => _launchIntent('android.settings.SETTINGS')),
          _dockItem(Icons.settings_rounded, 4, _showQuickSettings),
        ],
      ),
    );
  }

  Widget _dockItem(IconData icon, int index, VoidCallback onTap, {bool hasIndicator = false}) {
    bool isSel = _selectedSidebarIndex == index;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        alignment: Alignment.center,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (hasIndicator)
              Positioned(
                left: 0,
                child: Container(
                  width: 3.5,
                  height: 22,
                  decoration: BoxDecoration(
                    color: _neonCyan,
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [BoxShadow(color: _neonCyan, blurRadius: 6)],
                  ),
                ),
              ),
            Icon(
              icon,
              color: isSel ? _neonCyan : (hasIndicator ? _neonCyan : Colors.white60),
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  // ================= کارت ناوبری (سمت چپ) =================
  Widget _buildNavigationCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _neonCyan.withOpacity(0.35)),
        boxShadow: [
          BoxShadow(color: _neonCyan.withOpacity(0.08), blurRadius: 12),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // هدر ناوبری
          Row(
            children: [
              Icon(Icons.navigation, color: _neonCyan, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text("0.5 mi - Route 101", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                    Text("Continue on Route 101", style: TextStyle(color: Colors.white54, fontSize: 10)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24),
                ),
                child: const Text("N", style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // نقشه با خط سیر درخشان نئونی
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFF0A1322), Color(0xFF03070E)],
                      ),
                    ),
                  ),
                  CustomPaint(painter: NavigationRoadPainter(color: _neonCyan)),
                  // دکمه‌های زوم نقشه
                  Positioned(
                    left: 10,
                    bottom: 12,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Column(
                        children: const [
                          Padding(padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4), child: Icon(Icons.add, size: 14, color: Colors.white70)),
                          Divider(height: 1, color: Colors.white12),
                          Padding(padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4), child: Icon(Icons.remove, size: 14, color: Colors.white70)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // اطلاعات سفر
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _tripInfoCol("8 min", "ETA"),
              _tripInfoCol("3.2 mi", "Distance"),
              _tripInfoCol("23:44", "Arrival"),
            ],
          ),
          const SizedBox(height: 10),

          // دکمه شروع ناوبری نئونی
          GestureDetector(
            onTap: () => _launchIntent('android.intent.action.VIEW', data: 'geo:0,0?q=navigation'),
            child: Container(
              height: 38,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_neonBlue.withOpacity(0.8), _neonCyan.withOpacity(0.8)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: _neonCyan.withOpacity(0.4), blurRadius: 10),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.near_me_rounded, color: Colors.white, size: 16),
                  SizedBox(width: 8),
                  Text("Start Navigation", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tripInfoCol(String value, String label) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
      ],
    );
  }

  // ================= مرکز: کیلومترشمار Cyber HUD =================
  Widget _buildCenterHudCard() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _neonCyan.withOpacity(0.4)),
        boxShadow: [
          BoxShadow(color: _neonBlue.withOpacity(0.15), blurRadius: 14),
        ],
      ),
      child: Column(
        children: [
          // گیج قوسی کیلومتر و سرعت دیجیتال
          Expanded(
            flex: 65,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(260, 260),
                  painter: CyberSpeedometerPainter(speed: _currentSpeed, neonColor: _neonCyan),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _currentSpeed.toInt().toString(),
                      style: const TextStyle(fontSize: 54, fontWeight: FontWeight.w900, color: Colors.white),
                    ),
                    Text(
                      "KM / H",
                      style: TextStyle(color: _neonCyan, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                    ),
                    const SizedBox(height: 6),
                    Icon(Icons.shield_outlined, color: _neonCyan.withOpacity(0.8), size: 18),
                  ],
                ),
              ],
            ),
          ),

          // جاده پرسپکتیو و خودروی مرکزی
          Expanded(
            flex: 25,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(200, 70),
                  painter: RoadPerspectivePainter(color: _neonCyan),
                ),
                const Icon(Icons.directions_car_rounded, color: Colors.white, size: 36),
              ],
            ),
          ),

          // وضعیت دنده انتخابی (D, P, R, N)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: ['D', 'P', 'R', 'N'].map((gear) {
              bool isSelected = _selectedGear == gear;
              return GestureDetector(
                onTap: () => setState(() => _selectedGear = gear),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: isSelected ? _neonCyan.withOpacity(0.15) : Colors.transparent,
                    border: Border.all(color: isSelected ? _neonCyan : Colors.transparent, width: 1.5),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: isSelected ? [BoxShadow(color: _neonCyan.withOpacity(0.4), blurRadius: 8)] : null,
                  ),
                  child: Text(
                    gear,
                    style: TextStyle(
                      color: isSelected ? _neonCyan : Colors.white54,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ================= مدیا پلیر نئونی (بالا سمت راست) =================
  Widget _buildNowPlayingCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _neonCyan.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Now Playing", style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(Icons.folder_open_rounded, color: _neonCyan, size: 18),
                onPressed: _pickAndPlayMusic,
              ),
            ],
          ),
          const SizedBox(height: 8),

          // کاور و نام آهنگ
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8A2387), Color(0xFFE94057), Color(0xFFF27121)],
                  ),
                ),
                child: const Icon(Icons.music_note_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currentSongTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _artistName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),

          // نوار زمان پیشرفت پخش
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_formatDuration(_position), style: const TextStyle(color: Colors.white54, fontSize: 10)),
              Text(_formatDuration(_duration), style: const TextStyle(color: Colors.white54, fontSize: 10)),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2.5,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4.5),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 8),
              activeTrackColor: _neonCyan,
              inactiveTrackColor: Colors.white12,
              thumbColor: _neonCyan,
            ),
            child: Slider(
              value: _position.inSeconds.toDouble().clamp(0.0, _duration.inSeconds.toDouble()),
              max: _duration.inSeconds > 0 ? _duration.inSeconds.toDouble() : 1.0,
              onChanged: (val) => _audioPlayer.seek(Duration(seconds: val.toInt())),
            ),
          ),

          // دکمه‌های کنترل موسیقی
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              const Icon(Icons.shuffle_rounded, size: 18, color: Colors.white60),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 22),
                onPressed: () {
                  if (_audioPlayer.hasPrevious) _audioPlayer.seekToPrevious();
                },
              ),
              // دکمه دایره‌ای شیک پخش/توقف
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _neonCyan, width: 2),
                  boxShadow: [BoxShadow(color: _neonCyan.withOpacity(0.4), blurRadius: 10)],
                ),
                child: CircleAvatar(
                  backgroundColor: Colors.transparent,
                  radius: 17,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow_rounded, color: Colors.white, size: 20),
                    onPressed: () {
                      if (_isPlaying) {
                        _audioPlayer.pause();
                      } else {
                        _audioPlayer.play();
                      }
                    },
                  ),
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 22),
                onPressed: () {
                  if (_audioPlayer.hasNext) _audioPlayer.seekToNext();
                },
              ),
              const Icon(Icons.repeat_rounded, size: 18, color: Colors.white60),
            ],
          ),
        ],
      ),
    );
  }

  // ================= وضعیت خودرو تیبا ۲ (پایین سمت راست) =================
  Widget _buildCarStatusCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _neonCyan.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text("Car Status", style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
              Text("See More >", style: TextStyle(color: Colors.white38, fontSize: 10)),
            ],
          ),

          // نمایش تصویر تیبا ۲
          Expanded(
            child: Center(
              child: Image.asset(
                'tiba2.png',
                width: double.infinity,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(Icons.directions_car_rounded, size: 60, color: _neonCyan);
                },
              ),
            ),
          ),

          // ۴ پارامتر وضعیت فنی مطابق تصویر
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _carStatItem(Icons.local_gas_station_rounded, "85%", "Fuel", _neonCyan),
              _carStatItem(Icons.tire_repair_rounded, "32 PSI", "Tires", _neonCyan),
              _carStatItem(Icons.check_circle_outline_rounded, "Normal", "Engine", Colors.greenAccent),
              _carStatItem(Icons.thermostat_rounded, "22°C", "Temp", _neonCyan),
            ],
          ),
        ],
      ),
    );
  }

  Widget _carStatItem(IconData icon, String val, String label, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 3),
        Text(val, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 9)),
      ],
    );
  }

  void _showQuickSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0A1224),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("تنظیمات سیستم مانیتور", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
              const SizedBox(height: 16),
              ListTile(
                leading: Icon(Icons.wifi, color: _neonCyan),
                title: const Text("وای‌فای"),
                onTap: () => _launchIntent('android.settings.WIFI_SETTINGS'),
              ),
              ListTile(
                leading: Icon(Icons.bluetooth, color: _neonCyan),
                title: const Text("بلوتوث"),
                onTap: () => _launchIntent('android.settings.BLUETOOTH_SETTINGS'),
              ),
              ListTile(
                leading: Icon(Icons.settings, color: _neonCyan),
                title: const Text("تنظیمات اصلی اندروید"),
                onTap: () => _launchIntent('android.settings.SETTINGS'),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ================= نقاش خطوط مسیر ناوبری =================
class NavigationRoadPainter extends CustomPainter {
  final Color color;
  NavigationRoadPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4);

    final path = Path()
      ..moveTo(size.width * 0.45, size.height)
      ..cubicTo(size.width * 0.45, size.height * 0.6, size.width * 0.6, size.height * 0.4, size.width * 0.35, 0);

    canvas.drawPath(path, paint);

    // فلش نشانگر خودرو در نقشه
    final arrowPaint = Paint()..color = Colors.white;
    final arrowPath = Path()
      ..moveTo(size.width * 0.45, size.height * 0.7)
      ..lineTo(size.width * 0.40, size.height * 0.78)
      ..lineTo(size.width * 0.45, size.height * 0.75)
      ..lineTo(size.width * 0.50, size.height * 0.78)
      ..close();
    canvas.drawPath(arrowPath, arrowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ================= نقاش کیلومتر شمار نئونی HUD =================
class CyberSpeedometerPainter extends CustomPainter {
  final double speed;
  final Color neonColor;

  CyberSpeedometerPainter({required this.speed, required this.neonColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.44;

    const startAngle = 135 * (math.pi / 180);
    const sweepAngle = 270 * (math.pi / 180);

    // دایره زمینه تیره
    final bgPaint = Paint()
      ..color = Colors.white10
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, sweepAngle, false, bgPaint);

    // خط درخشان پر شده بر اساس سرعت جی‌پی‌اس
    final progress = (speed / 240).clamp(0.0, 1.0);
    final activePaint = Paint()
      ..shader = SweepGradient(
        startAngle: startAngle,
        endAngle: startAngle + sweepAngle,
        colors: [neonColor.withOpacity(0.4), neonColor],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..strokeWidth = 7
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4);

    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, sweepAngle * progress, false, activePaint);

    // کشیدن تیک‌های سرعت (Tick Marks)
    final tickPaint = Paint()
      ..color = Colors.white30
      ..strokeWidth = 1.5;

    for (int i = 0; i <= 24; i++) {
      final angle = startAngle + (sweepAngle * (i / 24));
      final isMajor = i % 4 == 0;
      final outerR = radius - 8;
      final innerR = radius - (isMajor ? 18 : 12);

      final p1 = Offset(center.dx + outerR * math.cos(angle), center.dy + outerR * math.sin(angle));
      final p2 = Offset(center.dx + innerR * math.cos(angle), center.dy + innerR * math.sin(angle));

      tickPaint.color = isMajor ? neonColor : Colors.white24;
      canvas.drawLine(p1, p2, tickPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CyberSpeedometerPainter oldDelegate) => oldDelegate.speed != speed;
}

// ================= نقاش پرسپکتیو جاده مرکزی =================
class RoadPerspectivePainter extends CustomPainter {
  final Color color;
  RoadPerspectivePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.5)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // خطوط کناری جاده
    canvas.drawLine(Offset(size.width * 0.35, 0), Offset(0, size.height), paint);
    canvas.drawLine(Offset(size.width * 0.65, 0), Offset(size.width, size.height), paint);

    // خط‌چین وسط
    final centerPaint = Paint()
      ..color = color.withOpacity(0.3)
      ..strokeWidth = 1.5;
    for (double y = 0; y < size.height; y += 12) {
      canvas.drawLine(Offset(size.width * 0.5, y), Offset(size.width * 0.5, y + 6), centerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
