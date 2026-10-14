import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:just_audio/just_audio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

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
      debugShowCheckedModeBanner: false,
      title: 'Tiba 2 Launcher',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF090D16),
        primaryColor: const Color(0xFF00E5FF),
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

class _DashboardScreenState extends State<DashboardScreen> {
  // Navigation Bar State
  int _selectedNavIndex = 0;

  // Car Sensors & HUD State
  double _speed = 0.0;
  double _rpm = 850.0;
  String _timeString = '';
  String _dateString = '';
  StreamSubscription<Position>? _positionStream;
  Timer? _timer;

  // Audio Player State
  late AudioPlayer _audioPlayer;
  String _currentTrackTitle = 'آهنگی انتخاب نشده است';
  String _currentArtist = 'سیستم صوتی تیبا';
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  // Car Status Mock Data
  final double _tirePressureFL = 32.0;
  final double _tirePressureFR = 32.5;
  final double _tirePressureRL = 31.8;
  final double _tirePressureRR = 32.0;
  final double _fuelLevel = 0.65;
  final int _batteryPercent = 94;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _initDateTime();
    _initGps();
    _initAudioPlayer();
  }

  void _initDateTime() {
    _updateClock();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateClock();
      // شبیه‌سازی ملایم دور موتور در هنگام درجا کار کردن
      if (_speed == 0 && mounted) {
        setState(() {
          _rpm = 820.0 + math.Random().nextInt(60);
        });
      }
    });
  }

  void _updateClock() {
    final now = DateTime.now();
    setState(() {
      _timeString =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      _dateString = '${now.year}/${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}';
    });
  }

  Future<void> _initGps() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        const locationSettings = LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 1,
        );
        _positionStream = Geolocator.getPositionStream(
          locationSettings: locationSettings,
        ).listen((Position position) {
          if (mounted) {
            setState(() {
              double speedKmh = (position.speed * 3.6);
              _speed = speedKmh < 0 ? 0 : speedKmh;
              if (_speed > 0) {
                _rpm = 1000 + (_speed * 35);
              }
            });
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _initAudioPlayer() async {
    _audioPlayer = AudioPlayer();
    _audioPlayer.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing;
        });
      }
    });

    _audioPlayer.durationStream.listen((d) {
      if (mounted) {
        setState(() {
          _duration = d ?? Duration.zero;
        });
      }
    });

    _audioPlayer.positionStream.listen((p) {
      if (mounted) {
        setState(() {
          _position = p;
        });
      }
    });
  }

  Future<void> _pickAudioFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
      );
      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;
        final fileName = result.files.single.name;
        await _audioPlayer.setFilePath(filePath);
        _audioPlayer.play();
        setState(() {
          _currentTrackTitle = fileName.replaceAll('.mp3', '');
          _currentArtist = 'پوشه محلی';
        });
      }
    } catch (_) {}
  }

  void _openMapIntent() {
    // باز کردن نقشه با ارسال اینتنت عمومی اندروید بدون نیاز به url_launcher
    const intentChannel = MethodChannel('plugins.flutter.io/url_launcher');
    intentChannel.invokeMethod('launch', {
      'url': 'geo:35.6892,51.3890?q=مسیریابی',
      'useSafariVC': false,
      'useWebView': false,
      'enableJavaScript': false,
      'enableDomStorage': false,
      'universalLinksOnly': false,
      'headers': <String, String>{},
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _timer?.cancel();
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
            center: Alignment.center,
            radius: 1.2,
            colors: [
              Color(0xFF0F172A),
              Color(0xFF050811),
            ],
          ),
        ),
        child: SafeArea(
          child: Row(
            children: [
              // نوار ابزار عمودی سمت چپ
              _buildModernSidebar(),

              // داشبورد اصلی
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                  child: Column(
                    children: [
                      // هدر بالای صفحه (زمان، وضعیت سیستم، باتری)
                      _buildTopHeader(),
                      const SizedBox(height: 10),

                      // پنل ۳ بخشی وسط (نقشه، کیلومترشمار نئونی، پلیر و خودرو)
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // بخش ناوبری چپ
                            Expanded(flex: 3, child: _buildNavCard()),
                            const SizedBox(width: 14),

                            // کیلومترشمار و دور موتور مرکزی
                            Expanded(flex: 4, child: _buildCenterGauges()),
                            const SizedBox(width: 14),

                            // پلیر و وضعیت ماشین در راست
                            Expanded(
                              flex: 3,
                              child: Column(
                                children: [
                                  Expanded(flex: 5, child: _buildMediaCard()),
                                  const SizedBox(height: 10),
                                  Expanded(flex: 4, child: _buildCarStatusCard()),
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
            ],
          ),
        ),
      ),
    );
  }

  // سایدبار مدرن و آیکون‌ها
  Widget _buildModernSidebar() {
    final icons = [
      Icons.speed_rounded,
      Icons.map_outlined,
      Icons.library_music_rounded,
      Icons.directions_car_filled_rounded,
      Icons.apps_rounded,
      Icons.settings_rounded,
    ];

    return Container(
      width: 72,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF111827).withOpacity(0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 14),
          const Icon(Icons.bolt, color: Color(0xFF00E5FF), size: 28),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.separated(
              itemCount: icons.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final isSelected = _selectedNavIndex == index;
                return Center(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      setState(() {
                        _selectedNavIndex = index;
                      });
                      if (index == 1) _openMapIntent();
                    },
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF00E5FF).withOpacity(0.18)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                        border: isSelected
                            ? Border.all(color: const Color(0xFF00E5FF), width: 1.5)
                            : null,
                      ),
                      child: Icon(
                        icons[index],
                        color: isSelected ? const Color(0xFF00E5FF) : Colors.white54,
                        size: 24,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          IconButton(
            onPressed: () {
              SystemNavigator.pop();
            },
            icon: const Icon(Icons.power_settings_new_rounded, color: Colors.redAccent),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  // هدر افقی بالای داشبورد
  Widget _buildTopHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF131B2E).withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on, color: Color(0xFF00E5FF), size: 18),
              const SizedBox(width: 6),
              const Text(
                'TIBA 2 HUD EDITION',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  letterSpacing: 2.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Text(
            _timeString,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              color: Colors.white,
            ),
          ),
          Row(
            children: [
              Text(_dateString, style: const TextStyle(color: Colors.white54, fontSize: 13)),
              const SizedBox(width: 16),
              const Icon(Icons.bluetooth_connected, color: Color(0xFF00E5FF), size: 18),
              const SizedBox(width: 12),
              const Icon(Icons.wifi, color: Colors.white70, size: 18),
              const SizedBox(width: 12),
              Row(
                children: [
                  const Icon(Icons.battery_charging_full_rounded, color: Colors.greenAccent, size: 20),
                  const SizedBox(width: 2),
                  Text('$_batteryPercent%', style: const TextStyle(color: Colors.white, fontSize: 12)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // کارت ناوبری و نقشه
  Widget _buildNavCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF101728),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.navigation_rounded, color: Color(0xFF00E5FF), size: 20),
                  SizedBox(width: 8),
                  Text('مسیریابی هوشمند', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              IconButton(
                onPressed: _openMapIntent,
                icon: const Icon(Icons.open_in_new, size: 18, color: Colors.white54),
              )
            ],
          ),
          const Spacer(),
          Center(
            child: Column(
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF00E5FF).withOpacity(0.12),
                    border: Border.all(color: const Color(0xFF00E5FF), width: 1.5),
                  ),
                  child: const Icon(Icons.turn_right_rounded, size: 40, color: Color(0xFF00E5FF)),
                ),
                const SizedBox(height: 12),
                const Text(
                  '۳۵۰ متر بعد، گردش به راست',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text(
                  'بلوار اصلی',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: _openMapIntent,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E5FF).withOpacity(0.15),
              foregroundColor: const Color(0xFF00E5FF),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: Color(0xFF00E5FF), width: 1),
              ),
              minimumSize: const Size(double.infinity, 44),
            ),
            child: const Text('باز کردن نقشه سخنگو', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // مرکز سنجشگر نئونی (سرعت و دور موتور HUD)
  Widget _buildCenterGauges() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF101728),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final dialSize = math.min(constraints.maxWidth, constraints.maxHeight);
          return Center(
            child: SizedBox(
              width: dialSize,
              height: dialSize,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: Size(dialSize, dialSize),
                    painter: DualHudGaugePainter(
                      speed: _speed,
                      rpm: _rpm,
                    ),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _speed.toStringAsFixed(0),
                        style: const TextStyle(
                          fontSize: 68,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1.0,
                        ),
                      ),
                      const Text(
                        'KM/H',
                        style: TextStyle(
                          color: Color(0xFF00E5FF),
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2.0,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black38,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Text(
                          'RPM ${_rpm.toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // پنل مدیا پلیر
  Widget _buildMediaCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF101728),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.music_note_rounded, color: Color(0xFF00E5FF), size: 18),
                  SizedBox(width: 6),
                  Text('پخش موسیقی', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                ],
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.folder_open, size: 20, color: Color(0xFF00E5FF)),
                onPressed: _pickAudioFile,
              ),
            ],
          ),
          const Spacer(),
          Text(
            _currentTrackTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          Text(
            _currentArtist,
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: _duration.inSeconds > 0
                ? (_position.inSeconds / _duration.inSeconds).clamp(0.0, 1.0)
                : 0.0,
            backgroundColor: Colors.white10,
            color: const Color(0xFF00E5FF),
            minHeight: 4,
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                iconSize: 22,
                icon: const Icon(Icons.skip_previous_rounded),
                onPressed: () {
                  _audioPlayer.seek(Duration.zero);
                },
              ),
              IconButton(
                iconSize: 32,
                color: const Color(0xFF00E5FF),
                icon: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill),
                onPressed: () {
                  if (_isPlaying) {
                    _audioPlayer.pause();
                  } else {
                    _audioPlayer.play();
                  }
                },
              ),
              IconButton(
                iconSize: 22,
                icon: const Icon(Icons.skip_next_rounded),
                onPressed: () {
                  _audioPlayer.seek(_duration);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // کارت اطلاعات و وضعیت خودرو
  Widget _buildCarStatusCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF101728),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('وضعیت باد تایرها (PSI)', style: TextStyle(fontSize: 11, color: Colors.white70)),
              Text('${(_fuelLevel * 100).toInt()}% بنزین', style: const TextStyle(fontSize: 11, color: Colors.amberAccent)),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildTireIndicator('جلو چ', _tirePressureFL),
              _buildTireIndicator('جلو ر', _tirePressureFR),
              _buildTireIndicator('عقب چ', _tirePressureRL),
              _buildTireIndicator('عقب ر', _tirePressureRR),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTireIndicator(String label, double psi) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 9, color: Colors.white38)),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.greenAccent.withOpacity(0.4)),
          ),
          child: Text(
            psi.toStringAsFixed(1),
            style: const TextStyle(fontSize: 10, color: Colors.greenAccent, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

// رسم‌کننده سرعت‌سنج و دور موتور دوگانه با افکت نئونی
class DualHudGaugePainter extends CustomPainter {
  final double speed;
  final double rpm;

  DualHudGaugePainter({required this.speed, required this.rpm});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 16;

    final bgPaint = Paint()
      ..color = Colors.white.withOpacity(0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    final speedPaint = Paint()
      ..shader = const SweepGradient(
        colors: [Color(0xFF0052D4), Color(0xFF4364F7), Color(0xFF00E5FF)],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    final rpmPaint = Paint()
      ..shader = const SweepGradient(
        colors: [Colors.tealAccent, Colors.orangeAccent, Colors.redAccent],
      ).createShader(Rect.fromCircle(center: center, radius: radius - 14))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    const startAngle = 135 * (math.pi / 180);
    const sweepTotalAngle = 270 * (math.pi / 180);

    // پس‌زمینه سرعت‌سنج
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepTotalAngle,
      false,
      bgPaint,
    );

    // پیشرفت سرعت‌سنج (ماکزیمم 220 کیلومتر بر ساعت)
    final speedPercent = (speed / 220.0).clamp(0.0, 1.0);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepTotalAngle * speedPercent,
      false,
      speedPaint,
    );

    // پیشرفت دور موتور داخلی (ماکزیمم 7000 دور)
    final rpmPercent = (rpm / 7000.0).clamp(0.0, 1.0);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 14),
      startAngle,
      sweepTotalAngle * rpmPercent,
      false,
      rpmPaint,
    );
  }

  @override
  bool shouldRepaint(covariant DualHudGaugePainter oldDelegate) {
    return oldDelegate.speed != speed || oldDelegate.rpm != rpm;
  }
}
