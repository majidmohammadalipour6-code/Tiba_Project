import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
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
      title: 'Tiba 2 Cyber HUD',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF070B14),
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
  static const platform = MethodChannel('com.tiba2.launcher/actions');

  // GPS & Speed
  double _currentSpeed = 0.0;
  double _speedMultiplier = 1.0;
  StreamSubscription<Position>? _positionStream;
  bool _isGpsActive = false;

  // Selected Nav App
  String _selectedNavName = 'نشان (Neshan)';
  String _selectedNavPackage = 'org.neshan.maps.and.navi';

  // Gears & Time
  String _selectedGear = 'D';
  late Timer _clockTimer;
  String _currentTime = '';
  String _currentDate = '';

  // Music state
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _initTime();
    _initGps();
  }

  void _initTime() {
    _updateTime();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateTime();
    });
  }

  void _updateTime() {
    final now = DateTime.now();
    setState(() {
      _currentTime =
          "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
      _currentDate = "${now.year}/${now.month}/${now.day}";
    });
  }

  Future<void> _initGps() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => _isGpsActive = false);
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    setState(() => _isGpsActive = true);

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 1,
    );

    _positionStream =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
      (Position position) {
        double rawSpeed = position.speed; // m/s
        if (rawSpeed < 0.5) rawSpeed = 0.0;
        double kmh = rawSpeed * 3.6 * _speedMultiplier;
        setState(() {
          _currentSpeed = kmh;
        });
      },
      onError: (e) {
        setState(() => _isGpsActive = false);
      },
    );
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    _positionStream?.cancel();
    super.dispose();
  }

  // اجرای برنامه‌های خارجی با اینتنت مستقیم و امن
  Future<void> _openExternalApp(String actionType, {String? packageName}) async {
    try {
      await platform.invokeMethod('openApp', {
        'action': actionType,
        'package': packageName ?? '',
      });
    } catch (_) {
      // فال‌بک مستقیم با UrlLauncher در صورت نیاز
      if (packageName != null && packageName.isNotEmpty) {
        final uri = Uri.parse("android-app://$packageName");
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        }
      }
    }
  }

  void _showGpsCalibrationDialog() {
    double tempMultiplier = _speedMultiplier;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF0F172A),
              title: const Text(
                'تنظیم و کالیبراسیون GPS',
                style: TextStyle(color: Colors.cyanAccent),
                textAlign: TextAlign.center,
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'ضریب خطای کیلومترشمار: ${tempMultiplier.toStringAsFixed(2)}x',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  Slider(
                    value: tempMultiplier,
                    min: 0.8,
                    max: 1.2,
                    divisions: 40,
                    activeColor: Colors.cyanAccent,
                    onChanged: (val) {
                      setDialogState(() => tempMultiplier = val);
                    },
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueGrey.shade800,
                    ),
                    icon: const Icon(Icons.location_on, color: Colors.cyanAccent),
                    label: const Text('تنظیمات مکان اندروید'),
                    onPressed: () => _openExternalApp('location_settings'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('انصراف', style: TextStyle(color: Colors.white54)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.cyan),
                  onPressed: () {
                    setState(() => _speedMultiplier = tempMultiplier);
                    Navigator.pop(context);
                  },
                  child: const Text('ذخیره', style: TextStyle(color: Colors.black)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showNavAppSelector() {
    final navApps = [
      {'name': 'نشان (Neshan)', 'pkg': 'org.neshan.maps.and.navi'},
      {'name': 'بلد (Balad)', 'pkg': 'ir.balad.navigation'},
      {'name': 'Google Maps', 'pkg': 'com.google.android.apps.maps'},
      {'name': 'Waze', 'pkg': 'com.waze'},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D1527),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'انتخاب نرم‌افزار مسیریاب',
                style: TextStyle(
                  color: Colors.cyanAccent,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Divider(color: Colors.white24),
              ...navApps.map(
                (app) => ListTile(
                  leading: const Icon(Icons.navigation, color: Colors.cyanAccent),
                  title: Text(app['name']!, style: const TextStyle(color: Colors.white)),
                  trailing: _selectedNavPackage == app['pkg']
                      ? const Icon(Icons.check_circle, color: Colors.cyanAccent)
                      : null,
                  onTap: () {
                    setState(() {
                      _selectedNavName = app['name']!;
                      _selectedNavPackage = app['pkg']!;
                    });
                    Navigator.pop(context);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            // 1. سایدبار ناوبری عمودی (سمت چپ)
            _buildSidebar(),

            // 2. ستون ۱: کارت مسیریاب نئونی
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: _buildNavigationCard(),
              ),
            ),

            // 3. ستون ۲: سرعت‌سنج مرکزی HUD، آرم سایپا و نمای پشت تیبا ۲
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                child: _buildCenterHud(),
              ),
            ),

            // 4. ستون ۳: موزیک پلیر و کارت اصلی ماشین تیبا ۲
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: _buildRightPanel(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // نوار ابزار عمودی داک
  Widget _buildSidebar() {
    return Container(
      width: 72,
      margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withOpacity(0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.cyanAccent.withOpacity(0.2)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.cyanAccent, size: 28),
            onPressed: () => _openExternalApp('settings'),
          ),
          IconButton(
            icon: const Icon(Icons.map, color: Colors.cyanAccent, size: 28),
            onPressed: () => _openExternalApp('nav', packageName: _selectedNavPackage),
          ),
          IconButton(
            icon: const Icon(Icons.radio, color: Colors.cyanAccent, size: 28),
            onPressed: () => _openExternalApp('radio'),
          ),
          IconButton(
            icon: const Icon(Icons.phone, color: Colors.cyanAccent, size: 28),
            onPressed: () => _openExternalApp('phone'),
          ),
          IconButton(
            icon: const Icon(Icons.apps, color: Colors.cyanAccent, size: 28),
            onPressed: () => _openExternalApp('all_apps'),
          ),
        ],
      ),
    );
  }

  // کارت مسیریاب
  Widget _buildNavigationCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D1527),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.blueAccent.withOpacity(0.08),
            blurRadius: 15,
            spreadRadius: 2,
          )
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.tune, color: Colors.cyanAccent, size: 20),
                onPressed: _showNavAppSelector,
              ),
              Row(
                children: [
                  Text(
                    _selectedNavName,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.navigation, color: Colors.cyanAccent, size: 20),
                ],
              ),
            ],
          ),
          const Spacer(),
          Center(
            child: InkWell(
              onTap: () => _openExternalApp('nav', packageName: _selectedNavPackage),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.cyanAccent.withOpacity(0.1),
                      border: Border.all(color: Colors.cyanAccent, width: 2),
                    ),
                    child: const Icon(
                      Icons.near_me_outlined,
                      color: Colors.cyanAccent,
                      size: 42,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'شروع مسیریابی هوشمند',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          Text(
            _currentTime,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.cyanAccent,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }

  // پنل مرکزی HUD
  Widget _buildCenterHud() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // کالیبراسیون و دنده‌ها
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: Icon(
                Icons.satellite_alt,
                color: _isGpsActive ? Colors.greenAccent : Colors.redAccent,
                size: 22,
              ),
              onPressed: _showGpsCalibrationDialog,
            ),
            _buildGearSelector(),
            Text(
              _currentDate,
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ),

        // کیلومترشمار نئونی
        Column(
          children: [
            Text(
              _currentSpeed.toInt().toString(),
              style: const TextStyle(
                color: Colors.cyanAccent,
                fontSize: 78,
                fontWeight: FontWeight.w900,
                shadows: [
                  Shadow(
                    color: Colors.cyanAccent,
                    blurRadius: 28,
                  )
                ],
              ),
            ),
            const Text(
              'KM / H',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 13,
                letterSpacing: 3,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),

        // آرم نئونی سایپا
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.cyanAccent.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.cyanAccent.withOpacity(0.3)),
          ),
          child: const Text(
            'S A I P A',
            style: TextStyle(
              color: Colors.cyanAccent,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 4,
            ),
          ),
        ),

        // تصویر نمای پشت تیبا ۲ روی جاده نئونی
        Expanded(
          child: Image.asset(
            'tiba2_rear.png',
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.directions_car,
              color: Colors.cyanAccent,
              size: 54,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGearSelector() {
    final gears = ['P', 'R', 'N', 'D'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: gears.map((gear) {
          final isSelected = _selectedGear == gear;
          return GestureDetector(
            onTap: () => setState(() => _selectedGear = gear),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                gear,
                style: TextStyle(
                  color: isSelected ? Colors.cyanAccent : Colors.white24,
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // پنل سمت راست (موزیک + عکس تیبا ۲)
  Widget _buildRightPanel() {
    return Column(
      children: [
        // موزیک پلیر مستقیم فابریک
        Container(
          height: 120,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF0D1527),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.cyanAccent.withOpacity(0.2)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.launch, color: Colors.cyanAccent, size: 20),
                    onPressed: () => _openExternalApp('music'),
                  ),
                  const Text(
                    'پخش‌کننده خودرو',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.skip_previous, color: Colors.cyanAccent),
                    onPressed: () => _openExternalApp('media_prev'),
                  ),
                  IconButton(
                    icon: Icon(
                      _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                      color: Colors.cyanAccent,
                      size: 38,
                    ),
                    onPressed: () {
                      setState(() => _isPlaying = !_isPlaying);
                      _openExternalApp('media_play_pause');
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_next, color: Colors.cyanAccent),
                    onPressed: () => _openExternalApp('media_next'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // عکس نمایشی خودروی تیبا ۲
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0D1527),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white10),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.asset(
                'tiba2.png',
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Center(
                  child: Icon(Icons.directions_car, color: Colors.white24, size: 50),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
