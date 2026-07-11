import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:torch_light/torch_light.dart';
import 'settings_page.dart';

enum UiTheme { glassmorphism, material, minimal }

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const SSGYApp());
}

class SSGYApp extends StatefulWidget {
  const SSGYApp({super.key});

  @override
  State<SSGYApp> createState() => _SSGYAppState();
}

class _SSGYAppState extends State<SSGYApp> {
  ThemeMode _themeMode = ThemeMode.dark;

  void _onThemeChanged(UiTheme uiTheme) {
    setState(() {
      _themeMode = uiTheme == UiTheme.material ? ThemeMode.system : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '爆闪狗眼',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorSchemeSeed: Colors.amber,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.amber,
      ),
      home: FlashScreen(onThemeChanged: _onThemeChanged),
    );
  }
}

class FlashScreen extends StatefulWidget {
  final void Function(UiTheme)? onThemeChanged;

  const FlashScreen({super.key, this.onThemeChanged});

  @override
  State<FlashScreen> createState() => _FlashScreenState();
}

class _FlashScreenState extends State<FlashScreen> with TickerProviderStateMixin {
  static const String _kIntervalKey = 'flash_interval';
  static const String _kThemeKey = 'ui_theme';

  double _interval = 0.5;
  bool _isRunning = false;
  bool _isFlashing = false;
  bool _loaded = false;
  Timer? _flashTimer;
  Timer? _nextToggle;
  UiTheme _uiTheme = UiTheme.glassmorphism;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _bgController;

  final List<_Particle> _particles = [];
  Timer? _particleTimer;

  @override
  void initState() {
    super.initState();
    _loadPrefs();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutSine),
    );

    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    _initParticles();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _interval = prefs.getDouble(_kIntervalKey) ?? 0.5;
      final themeName = prefs.getString(_kThemeKey) ?? 'glassmorphism';
      _uiTheme = UiTheme.values.firstWhere(
        (e) => e.name == themeName,
        orElse: () => UiTheme.glassmorphism,
      );
      _loaded = true;
    });
  }

  Future<void> _saveInterval() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kIntervalKey, _interval);
  }

  Future<void> _saveTheme(UiTheme theme) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemeKey, theme.name);
  }

  void _initParticles() {
    final rng = Random(42);
    for (int i = 0; i < 30; i++) {
      _particles.add(_Particle(
        x: rng.nextDouble(),
        y: rng.nextDouble(),
        size: rng.nextDouble() * 3 + 1,
        speedX: (rng.nextDouble() - 0.5) * 0.002,
        speedY: (rng.nextDouble() - 0.5) * 0.002 - 0.001,
        opacity: rng.nextDouble() * 0.3 + 0.05,
      ));
    }

    _particleTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!mounted) return;
      setState(() {
        for (final p in _particles) {
          p.x += p.speedX;
          p.y += p.speedY;
          if (p.x < 0 || p.x > 1) p.speedX *= -1;
          if (p.y < 0 || p.y > 1) p.speedY *= -1;
        }
      });
    });
  }

  @override
  void dispose() {
    _stopFlashing();
    _pulseController.dispose();
    _bgController.dispose();
    _particleTimer?.cancel();
    super.dispose();
  }

  void _startFlashing() async {
    try {
      await TorchLight.enableTorch();
    } catch (_) {}

    setState(() {
      _isRunning = true;
      _isFlashing = true;
    });
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);

    _doFlashCycle();
  }

  void _doFlashCycle() async {
    if (!mounted || !_isRunning) return;

    final ms = (_interval * 1000).round();

    setState(() => _isFlashing = true);
    try {
      await TorchLight.enableTorch();
    } catch (_) {}

    _nextToggle = Timer(Duration(milliseconds: ms), () async {
      if (!mounted || !_isRunning) return;
      setState(() => _isFlashing = false);
      try {
        await TorchLight.disableTorch();
      } catch (_) {}

      _flashTimer = Timer(Duration(milliseconds: ms), _doFlashCycle);
    });
  }

  void _stopFlashing() {
    _isRunning = false;
    _flashTimer?.cancel();
    _nextToggle?.cancel();
    _flashTimer = null;
    _nextToggle = null;

    try {
      TorchLight.disableTorch();
    } catch (_) {}

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    if (mounted) setState(() => _isFlashing = false);
  }

  String _formatInterval(double val) {
    if (val >= 1.0) return '1s';
    final s = val.toStringAsFixed(2);
    return '${s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '')}s';
  }

  void _openSettings() async {
    final result = await Navigator.push<UiTheme>(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => SettingsPage(currentTheme: _uiTheme),
        transitionsBuilder: (_, anim, __, child) =>
            SlideTransition(position: Tween<Offset>(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
            child: child),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );

    if (result != null && result != _uiTheme && mounted) {
      setState(() => _uiTheme = result);
      await _saveTheme(result);
      widget.onThemeChanged?.call(result);
    }
  }

  // ══════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    switch (_uiTheme) {
      case UiTheme.glassmorphism:
        return _buildGlassmorphism();
      case UiTheme.material:
        return _buildMaterial();
      case UiTheme.minimal:
        return _buildMinimal();
    }
  }

  // ══════════════════════════════════════════════════════════
  //  THEME: 液态玻璃
  // ══════════════════════════════════════════════════════════

  Widget _buildGlassmorphism() {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _bgController,
        builder: (context, _) {
          return Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.lerp(
                    const Color(0xFF0D0D2B),
                    const Color(0xFF1A0A2E),
                    (sin(_bgController.value * pi * 2) * 0.5 + 0.5).clamp(0.0, 1.0),
                  ) ?? const Color(0xFF0D0D2B),
                  Color.lerp(
                    const Color(0xFF1A0A2E),
                    const Color(0xFF0D0D2B),
                    (sin(_bgController.value * pi * 2) * 0.5 + 0.5).clamp(0.0, 1.0),
                  ) ?? const Color(0xFF1A0A2E),
                  Color.lerp(
                    const Color(0xFF16213E),
                    const Color(0xFF0F3460),
                    (sin(_bgController.value * pi * 2 + 1) * 0.5 + 0.5).clamp(0.0, 1.0),
                  ) ?? const Color(0xFF16213E),
                ],
              ),
            ),
            child: Stack(
              children: [
                // Particles
                ..._particles.map((p) => Positioned(
                      left: p.x * MediaQuery.of(context).size.width,
                      top: p.y * MediaQuery.of(context).size.height,
                      child: Container(
                        width: p.size,
                        height: p.size,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: p.opacity),
                          shape: BoxShape.circle,
                        ),
                      ),
                    )),

                // Main content (no flash overlay!)
                SafeArea(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 20),
                          _buildGlassHeader(),
                          const SizedBox(height: 32),
                          _buildControlPanel(glassPanel: true),
                          const SizedBox(height: 40),
                          _buildStatusText(),
                          const SizedBox(height: 60),
                        ],
                      ),
                    ),
                  ),
                ),

                // Settings button
                Positioned(
                  top: MediaQuery.of(context).padding.top + 8,
                  right: 16,
                  child: _buildSettingsIcon(Colors.white70),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildGlassHeader() {
    return Column(
      children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.amber.withValues(alpha: 0.3), Colors.orange.withValues(alpha: 0.15)],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1.5),
            boxShadow: [BoxShadow(color: Colors.amber.withValues(alpha: 0.15), blurRadius: 25, spreadRadius: 5)],
          ),
          child: const Icon(Icons.bolt_rounded, size: 42, color: Colors.amber),
        ),
        const SizedBox(height: 14),
        Text('爆闪狗眼', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.9), letterSpacing: 4)),
        const SizedBox(height: 6),
        Text('STROBE LIGHT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w300, color: Colors.white.withValues(alpha: 0.35), letterSpacing: 8)),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════
  //  THEME: Flutter 原生 (Material)
  // ══════════════════════════════════════════════════════════

  Widget _buildMaterial() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('爆闪狗眼', style: TextStyle(letterSpacing: 2, fontWeight: FontWeight.w600)),
        centerTitle: true,
        actions: [_buildSettingsIcon(Theme.of(context).iconTheme.color ?? Colors.white70)],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.bolt_rounded, size: 64, color: Colors.amber),
              const SizedBox(height: 24),
              _buildControlPanel(glassPanel: false),
              const SizedBox(height: 32),
              _buildStatusText(),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  THEME: 极简
  // ══════════════════════════════════════════════════════════

  Widget _buildMinimal() {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 40),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(width: 44),
                      Text(
                        '爆闪狗眼',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w300,
                          color: Colors.white.withValues(alpha: 0.6),
                          letterSpacing: 6,
                        ),
                      ),
                      _buildSettingsIcon(Colors.white38),
                    ],
                  ),
                ),
                _buildControlPanel(glassPanel: false),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  SETTINGS ICON
  // ══════════════════════════════════════════════════════════

  Widget _buildSettingsIcon(Color color) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: _openSettings,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(Icons.settings_rounded, size: 24, color: color),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  CONTROL PANEL (shared by all themes)
  // ══════════════════════════════════════════════════════════

  Widget _buildControlPanel({required bool glassPanel}) {
    final panel = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Interval row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '间隔',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: glassPanel
                    ? Colors.white.withValues(alpha: 0.5)
                    : (_uiTheme == UiTheme.minimal
                        ? Colors.white.withValues(alpha: 0.3)
                        : Colors.white70),
              ),
            ),
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, _) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: _isRunning
                        ? (_isFlashing
                            ? Colors.amber.withValues(alpha: 0.2)
                            : Colors.white.withValues(alpha: 0.05))
                        : Colors.white.withValues(alpha: glassPanel ? 0.05 : 0.08),
                    border: Border.all(
                      color: _isRunning
                          ? Colors.amber.withValues(alpha: 0.3)
                          : Colors.white.withValues(alpha: glassPanel ? 0.1 : 0.15),
                    ),
                  ),
                  child: Text(
                    _formatInterval(_interval),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: _isRunning ? Colors.amber : Colors.white.withValues(alpha: 0.8),
                      letterSpacing: 1,
                    ),
                  ),
                );
              },
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Slider
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: Colors.amber.withValues(alpha: 0.7),
            inactiveTrackColor: Colors.white.withValues(alpha: glassPanel ? 0.1 : 0.15),
            thumbColor: Colors.amber,
            overlayColor: Colors.amber.withValues(alpha: 0.1),
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 24),
          ),
          child: Column(
            children: [
              Slider(
                value: _interval,
                min: 0.05,
                max: 1.0,
                divisions: 19,
                label: _formatInterval(_interval),
                onChanged: _isRunning
                    ? null
                    : (v) {
                        setState(() => _interval = v);
                        _saveInterval();
                      },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('0.05s',
                        style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.4))),
                    Text('0.1s',
                        style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.25))),
                    Text('0.2s',
                        style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.25))),
                    Text('0.5s',
                        style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.25))),
                    Text('1s',
                        style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.4))),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 28),

        // Start/Stop buttons
        Row(
          children: [
            Expanded(child: _buildBtn(
              label: '开始', icon: Icons.play_arrow_rounded,
              active: !_isRunning, color: const Color(0xFF00E676),
              glassPanel: glassPanel,
            )),
            const SizedBox(width: 16),
            Expanded(child: _buildBtn(
              label: '停止', icon: Icons.stop_rounded,
              active: _isRunning, color: const Color(0xFFFF5252),
              glassPanel: glassPanel,
            )),
          ],
        ),
      ],
    );

    if (!glassPanel) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: panel,
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Colors.white.withValues(alpha: 0.08), Colors.white.withValues(alpha: 0.03)],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 1),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 40, spreadRadius: 5, offset: const Offset(0, 10)),
          BoxShadow(color: Colors.blue.withValues(alpha: 0.05), blurRadius: 60, spreadRadius: -10),
        ],
      ),
      child: panel,
    );
  }

  Widget _buildBtn({
    required String label,
    required IconData icon,
    required bool active,
    required Color color,
    required bool glassPanel,
  }) {
    return GestureDetector(
      onTap: active ? (_isRunning ? _stopFlashing : _startFlashing) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: active
              ? LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [color.withValues(alpha: glassPanel ? 0.3 : 0.35), color.withValues(alpha: glassPanel ? 0.1 : 0.15)],
                )
              : (_uiTheme == UiTheme.minimal
                  ? LinearGradient(colors: [Colors.white.withValues(alpha: 0.03), Colors.white.withValues(alpha: 0.01)])
                  : LinearGradient(colors: [Colors.white.withValues(alpha: glassPanel ? 0.03 : 0.08), Colors.white.withValues(alpha: glassPanel ? 0.01 : 0.04)])),
          border: Border.all(
            color: active ? color.withValues(alpha: glassPanel ? 0.4 : 0.5) : Colors.white.withValues(alpha: glassPanel ? 0.05 : 0.1),
            width: 1.5,
          ),
          boxShadow: active
              ? [BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 20)]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24, color: active ? color : Colors.white.withValues(alpha: 0.15)),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(
              fontSize: 17, fontWeight: FontWeight.w600,
              color: active ? color : Colors.white.withValues(alpha: 0.15),
              letterSpacing: 2,
            )),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  STATUS TEXT
  // ══════════════════════════════════════════════════════════

  Widget _buildStatusText() {
    final iconColor = _uiTheme == UiTheme.glassmorphism
        ? Colors.white
        : (_uiTheme == UiTheme.minimal ? Colors.white : Colors.white70);

    if (!_isRunning) {
      return Text(
        '点击开始启动爆闪',
        style: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w300,
          color: iconColor.withValues(alpha: 0.3),
          letterSpacing: 2,
        ),
      );
    }

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, _) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _isFlashing
              ? Text('⚡ 闪击中 ...', key: const ValueKey('on'),
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500,
                    color: Colors.amber.withValues(alpha: _pulseAnimation.value),
                    letterSpacing: 2))
              : Text('⏸ 停顿中 ...', key: const ValueKey('off'),
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500,
                    color: iconColor.withValues(alpha: 0.4),
                    letterSpacing: 2)),
        );
      },
    );
  }
}

class _Particle {
  double x, y, size, speedX, speedY, opacity;
  _Particle({
    required this.x, required this.y, required this.size,
    required this.speedX, required this.speedY, required this.opacity,
  });
}
