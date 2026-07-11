import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main.dart';

class SettingsPage extends StatefulWidget {
  final UiTheme currentTheme;

  const SettingsPage({super.key, required this.currentTheme});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late UiTheme _selectedTheme;

  @override
  void initState() {
    super.initState();
    _selectedTheme = widget.currentTheme;
  }

  Future<void> _saveTheme(UiTheme theme) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ui_theme', theme.name);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D2B),
      appBar: AppBar(
        title: const Text(
          '设置',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white70),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0D0D2B),
              Color(0xFF1A0A2E),
              Color(0xFF0F3460),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
                Text(
                  'UI 主题',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.4),
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 14),
                _buildThemeOption(
                  theme: UiTheme.glassmorphism,
                  title: '液态玻璃',
                  subtitle: '深色渐变背景 + 毛玻璃面板 + 粒子动效',
                  icon: Icons.gradient_rounded,
                ),
                const SizedBox(height: 10),
                _buildThemeOption(
                  theme: UiTheme.material,
                  title: 'Flutter 原生',
                  subtitle: 'Material Design 风格，浅色/深色自适应',
                  icon: Icons.auto_awesome_rounded,
                ),
                const SizedBox(height: 10),
                _buildThemeOption(
                  theme: UiTheme.minimal,
                  title: '极简',
                  subtitle: '纯黑背景，仅显示核心控件',
                  icon: Icons.dark_mode_rounded,
                ),
                const Spacer(),
                Center(
                  child: Text(
                    '滑动返回即可保存',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.25),
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThemeOption({
    required UiTheme theme,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final isSelected = _selectedTheme == theme;
    return GestureDetector(
      onTap: () async {
        setState(() => _selectedTheme = theme);
        await _saveTheme(theme);
        if (mounted) Navigator.pop(context, theme);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isSelected
              ? Colors.amber.withValues(alpha: 0.1)
              : Colors.white.withValues(alpha: 0.04),
          border: Border.all(
            color: isSelected
                ? Colors.amber.withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.08),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 28,
              color: isSelected ? Colors.amber : Colors.white.withValues(alpha: 0.5),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Colors.amber
                          : Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.35),
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle_rounded,
                color: Colors.amber.withValues(alpha: 0.7),
                size: 22,
              ),
          ],
        ),
      ),
    );
  }
}
