import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/project_provider.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final isDark = prefs.getBool('dark_mode') ?? false;

  runApp(DavidMagicApp(isDarkMode: isDark));
}

class DavidMagicApp extends StatefulWidget {
  final bool isDarkMode;

  const DavidMagicApp({super.key, required this.isDarkMode});

  @override
  State<DavidMagicApp> createState() => _DavidMagicAppState();
}

class _DavidMagicAppState extends State<DavidMagicApp> {
  late bool _isDarkMode;

  @override
  void initState() {
    super.initState();
    _isDarkMode = widget.isDarkMode;
  }

  Future<void> _toggleTheme() async {
    setState(() => _isDarkMode = !_isDarkMode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', _isDarkMode);
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ProjectProvider(),
      child: MaterialApp(
        title: 'DavidMagic',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
        home: ThemeToggle(
          onToggle: _toggleTheme,
          child: const HomeScreenShell(),
        ),
      ),
    );
  }
}

/// 主页面外壳：处理草稿恢复
class HomeScreenShell extends StatefulWidget {
  const HomeScreenShell({super.key});

  @override
  State<HomeScreenShell> createState() => _HomeScreenShellState();
}

class _HomeScreenShellState extends State<HomeScreenShell> {
  bool _checkedDraft = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_checkedDraft) {
      _checkedDraft = true;
      Future.microtask(() => _checkDraft());
    }
  }

  Future<void> _checkDraft() async {
    if (!mounted) return;
    final provider = context.read<ProjectProvider>();
    final hasDraft = await provider.initialize();

    if (hasDraft && mounted) {
      final restore = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          ),
          title: const Text(
            '恢复上次任务？',
            style: TextStyle(fontSize: AppTheme.fontSizeTitle),
          ),
          content: const Text(
            '检测到上次未完成的任务，是否恢复？',
            style: TextStyle(fontSize: AppTheme.fontSizeLabel),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              style: TextButton.styleFrom(
                textStyle:
                    const TextStyle(fontSize: AppTheme.fontSizeButton),
              ),
              child: const Text('不用了'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('恢复'),
            ),
          ],
        ),
      );

      if (restore == true) {
        await provider.restoreDraft();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const HomeScreen();
  }
}
