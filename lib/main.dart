import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:torch_light/torch_light.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const SSGYApp());
}

class SSGYApp extends StatelessWidget {
  const SSGYApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: '爆闪狗眼',
      debugShowCheckedModeBanner: false,
      home: FlashScreen(),
    );
  }
}

class FlashScreen extends StatefulWidget {
  const FlashScreen({super.key});

  @override
  State<FlashScreen> createState() => _FlashScreenState();
}

class _FlashScreenState extends State<FlashScreen> with TickerProviderStateMixin {
  double _interval = 0.5; // seconds
  bool _isRunning = false;
  bool _isFlashing = false;
  Timer? _flashTimer;
  Timer? _nextToggle;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _bgController;

  final List<_Particle> _particles = [];
  Timer? _particleTimer;

  @override
  void initState() {
    super.initState();

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

    // Initialize particles
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

    // Keep screen on
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);

    _doFlashCycle();
  }

  void _doFlashCycle() async {
    if (!mounted || !_isRunning) return;

    final ms = (_interval * 1000).round();
    setState(() => _isFlashing = true);

    // Turn on
    try {
      await TorchLight.enableTorch();
    } catch (_) {}

    // Schedule turn off
    _nextToggle = Timer(Duration(milliseconds: ms), () async {
      if (!mounted || !_isRunning) return;
      setState(() => _isFlashing = false);
      try {
        await TorchLight.disableTorch();
      } catch (_) {}

      // Schedule next cycle
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

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    if (mounted) {
      setState(() => _isFlashing = false);
    }
  }

  String _formatInterval(double val) {
    if (val >= 1.0) return '1s';
    return '${val.toStringAsFixed(1)}s';
  }

  @override
  Widget build(BuildContext context) {
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
                // Animated particles
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

                // Flash overlay
                if (_isFlashing)
                  AnimatedOpacity(
                    opacity: _isFlashing ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 50),
                    child: Container(
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),

                // Main content
                SafeArea(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 20),

                          // App icon + title
                          _buildHeader(),

                          const SizedBox(height: 32),

                          // Glass panel
                          _buildGlassPanel(),

                          const SizedBox(height: 40),

                          // Status text
                          _buildStatusText(),

                          const SizedBox(height: 60),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        // Lightning icon in a glass circle
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.amber.withValues(alpha: 0.3),
                Colors.orange.withValues(alpha: 0.15),
              ],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.15),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.amber.withValues(alpha: 0.15),
                blurRadius: 25,
                spreadRadius: 5,
              ),
            ],
          ),
          child: const Icon(
            Icons.bolt_rounded,
            size: 42,
            color: Colors.amber,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          '爆闪狗眼',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: Colors.white.withValues(alpha: 0.9),
            letterSpacing: 4,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'STROBE LIGHT',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w300,
            color: Colors.white.withValues(alpha: 0.35),
            letterSpacing: 8,
          ),
        ),
      ],
    );
  }

  Widget _buildGlassPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.08),
            Colors.white.withValues(alpha: 0.03),
          ],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 40,
            spreadRadius: 5,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.05),
            blurRadius: 60,
            spreadRadius: -10,
          ),
        ],
      ),
      child: Column(
        children: [
          // Interval label
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '间隔',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.5),
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
                          : Colors.white.withValues(alpha: 0.05),
                      border: Border.all(
                        color: _isRunning
                            ? Colors.amber.withValues(alpha: 0.3)
                            : Colors.white.withValues(alpha: 0.1),
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

          // Custom slider
          StatefulBuilder(
            builder: (context, setLocalState) {
              return Column(
                children: [
                  SliderTheme(
                    data: SliderThemeData(
                      activeTrackColor: Colors.amber.withValues(alpha: 0.7),
                      inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
                      thumbColor: Colors.amber,
                      overlayColor: Colors.amber.withValues(alpha: 0.1),
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 24),
                    ),
                    child: Slider(
                      value: _interval,
                      min: 0.1,
                      max: 1.0,
                      divisions: 9,
                      label: _formatInterval(_interval),
                      onChanged: _isRunning
                          ? null
                          : (v) {
                              setState(() => _interval = v);
                            },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildTickLabel('0.1s', true),
                        _buildTickLabel('0.3s', false),
                        _buildTickLabel('0.5s', false),
                        _buildTickLabel('0.7s', false),
                        _buildTickLabel('1s', true),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 28),

          // Control buttons
          Row(
            children: [
              // Start button
              Expanded(
                child: _buildActionButton(
                  label: '开始',
                  icon: Icons.play_arrow_rounded,
                  active: !_isRunning,
                  color: const Color(0xFF00E676),
                  onPressed: _startFlashing,
                ),
              ),
              const SizedBox(width: 16),
              // Stop button
              Expanded(
                child: _buildActionButton(
                  label: '停止',
                  icon: Icons.stop_rounded,
                  active: _isRunning,
                  color: const Color(0xFFFF5252),
                  onPressed: _stopFlashing,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTickLabel(String text, bool edge) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 10,
        fontWeight: edge ? FontWeight.w500 : FontWeight.w400,
        color: Colors.white.withValues(alpha: edge ? 0.4 : 0.2),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required bool active,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: active ? onPressed : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: active
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color.withValues(alpha: 0.3),
                    color.withValues(alpha: 0.1),
                  ],
                )
              : LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.03),
                    Colors.white.withValues(alpha: 0.01),
                  ],
                ),
          border: Border.all(
            color: active ? color.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.05),
            width: 1.5,
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.2),
                    blurRadius: 20,
                    spreadRadius: 0,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 24,
              color: active ? color : Colors.white.withValues(alpha: 0.15),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: active ? color : Colors.white.withValues(alpha: 0.15),
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusText() {
    if (!_isRunning) {
      return Text(
        '点击开始启动爆闪',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w300,
          color: Colors.white.withValues(alpha: 0.3),
          letterSpacing: 2,
        ),
      );
    }

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, _) {
        return Text(
          _isFlashing ? '⚡ 闪击中 ...' : '⏸ 停顿中 ...',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: _isFlashing
                ? Colors.amber.withValues(alpha: _pulseAnimation.value)
                : Colors.white.withValues(alpha: 0.4),
            letterSpacing: 2,
          ),
        );
      },
    );
  }
}

class _Particle {
  double x, y, size, speedX, speedY, opacity;
  _Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speedX,
    required this.speedY,
    required this.opacity,
  });
}
