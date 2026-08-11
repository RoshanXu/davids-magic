import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/media_file.dart';
import '../models/export_settings.dart';
import '../providers/project_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/file_list_panel.dart';
import '../widgets/action_buttons.dart';
import '../widgets/clip_dialog.dart';
import '../widgets/export_dialog.dart';
import '../widgets/progress_dialog.dart';
/// 主题切换回调 InheritedWidget
class ThemeToggle extends InheritedWidget {
  final VoidCallback onToggle;

  const ThemeToggle({
    super.key,
    required this.onToggle,
    required super.child,
  });

  @override
  bool updateShouldNotify(ThemeToggle old) => false;

  static VoidCallback? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ThemeToggle>()?.onToggle;
  }
}

/// 主界面
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int? _selectedFileIndex;
  bool _processingInBackground = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<ProjectProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('大卫的魔法工具'),
            actions: [
              IconButton(
                onPressed: ThemeToggle.of(context),
                icon: Icon(
                  Theme.of(context).brightness == Brightness.light
                      ? Icons.dark_mode_outlined
                      : Icons.light_mode_outlined,
                ),
                tooltip: '切换深色/浅色模式',
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: Column(
            children: [
              // 后台运行的进度横幅
              if (_processingInBackground && provider.isProcessing)
                _BackgroundBanner(
                  message: provider.statusMessage,
                  progress: provider.progress,
                  onTap: () => _showProgressDialog(provider),
                  onCancel: () => provider.cancelProcess(),
                ),

              // 文件列表
              FileListPanel(
                files: provider.files,
                selectedIndex: _selectedFileIndex,
                onSelect: (index) {
                  setState(() {
                    _selectedFileIndex =
                        _selectedFileIndex == index ? null : index;
                  });
                },
                onRemove: (index) {
                  provider.removeFile(index);
                  if (_selectedFileIndex == index) {
                    _selectedFileIndex = null;
                  } else if (_selectedFileIndex != null &&
                      _selectedFileIndex! > index) {
                    _selectedFileIndex = _selectedFileIndex! - 1;
                  }
                },
                onReorder: provider.reorderFiles,
              ),

              // 底部操作栏：添加 + 清空
              _BottomBar(
                onAddFile: provider.addFiles,
                onClear: provider.hasFiles
                    ? () => _confirmClear(context, provider)
                    : null,
              ),

              // 三个操作按钮
              ActionButtons(
                hasFiles: provider.hasFiles,
                hasSelection: _selectedFileIndex != null,
                isProcessing: provider.isProcessing,
                onClip: _selectedFileIndex != null
                    ? () => _showClipDialog(
                        context, provider, _selectedFileIndex!)
                    : () {},
                onMerge: () {
                  if (provider.files.length < 2) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          '需要至少2个文件才能合并。\n拖拽文件可调整合并顺序。',
                          style:
                              TextStyle(fontSize: AppTheme.fontSizeLabel),
                        ),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text(
                          '文件已按列表顺序排列好\n点击"输出"按钮即可导出合并后的文件',
                          style: TextStyle(
                              fontSize: AppTheme.fontSizeLabel),
                        ),
                        duration: const Duration(seconds: 4),
                      ),
                    );
                  }
                },
                onExport: () => _showExportDialog(context, provider),
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmClear(BuildContext context, ProjectProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        ),
        title: const Text('清空全部文件？',
            style: TextStyle(fontSize: AppTheme.fontSizeTitle)),
        content: const Text(
          '将清除所有已添加的文件和剪辑设置',
          style: TextStyle(fontSize: AppTheme.fontSizeLabel),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              provider.clearAll();
              setState(() => _selectedFileIndex = null);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.dangerColor,
            ),
            child: const Text('确认清空'),
          ),
        ],
      ),
    );
  }

  void _showClipDialog(
      BuildContext context, ProjectProvider provider, int index) {
    final file = provider.files[index];
    showDialog(
      context: context,
      builder: (ctx) => ClipDialog(
        file: file,
        onConfirm: (regions) {
          provider.setClipRegions(index, regions ?? []);
        },
      ),
    );
  }

  void _showExportDialog(BuildContext context, ProjectProvider provider) {
    final initialSettings = provider.exportSettings ??
        ExportSettings.defaults('');

    showDialog(
      context: context,
      builder: (ctx) => ExportDialog(
        initialSettings: initialSettings,
        maxSourceHeight: provider.maxSourceHeight,
        maxSourceBitrate: provider.maxSourceBitrate,
        estimatedSize: provider.estimateOutputSize(),
        hasVideo: provider.files.any((f) => f.type == MediaType.video),
        onConfirm: (settings) {
          provider.updateExportSettings(settings);
          _startExport(provider);
        },
      ),
    );
  }

  Future<void> _startExport(ProjectProvider provider) async {
    _showProgressDialog(provider);

    final outputPath = await provider.startExport();

    if (!mounted) return;

    if (provider.status == ProcessStatus.completed) {
      if (!_processingInBackground) {
        ProgressDialog.showCompletedNotification(context, outputPath);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('导出完成！',
                style: TextStyle(fontSize: AppTheme.fontSizeLabel)),
            backgroundColor: AppTheme.accentColor,
            action: SnackBarAction(
              label: '查看',
              textColor: Colors.white,
              onPressed: () {
                ProgressDialog.showCompletedNotification(
                    context, outputPath);
              },
            ),
          ),
        );
      }
    } else if (provider.status == ProcessStatus.error) {
      if (!_processingInBackground) {
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(AppTheme.radiusLarge),
              ),
              title: const Row(
                children: [
                  Icon(Icons.error, color: AppTheme.dangerColor),
                  SizedBox(width: 8),
                  Text('处理失败',
                      style: TextStyle(
                          fontSize: AppTheme.fontSizeTitle)),
                ],
              ),
              content: Text(
                provider.errorMessage ?? '未知错误',
                style:
                    const TextStyle(fontSize: AppTheme.fontSizeLabel),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    provider.resetStatus();
                  },
                  child: const Text('好的'),
                ),
              ],
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '处理失败: ${provider.errorMessage ?? "未知错误"}',
              style: const TextStyle(fontSize: AppTheme.fontSizeLabel),
            ),
            backgroundColor: AppTheme.dangerColor,
          ),
        );
      }
    }
  }

  void _showProgressDialog(ProjectProvider provider) {
    setState(() => _processingInBackground = false);

    ProgressDialog.show(
      context,
      provider,
      onMinimize: () {
        setState(() => _processingInBackground = true);
      },
    );
  }
}

/// 后台运行横幅
class _BackgroundBanner extends StatelessWidget {
  final String message;
  final double progress;
  final VoidCallback onTap;
  final VoidCallback onCancel;

  const _BackgroundBanner({
    required this.message,
    required this.progress,
    required this.onTap,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingMedium,
          vertical: AppTheme.spacingSmall,
        ),
        color: AppTheme.primaryColor.withAlpha(25),
        child: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: AppTheme.fontSizeLabel,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
            Text(
              '${(progress * 100).toStringAsFixed(0)}%',
              style: const TextStyle(
                fontSize: AppTheme.fontSizeLabel,
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            IconButton(
              onPressed: onCancel,
              icon: const Icon(Icons.close, size: 18),
              color: AppTheme.primaryColor,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: 32,
                minHeight: 32,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 底部操作栏：添加文件 + 清空
class _BottomBar extends StatelessWidget {
  final VoidCallback onAddFile;
  final VoidCallback? onClear;

  const _BottomBar({
    required this.onAddFile,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingMedium,
        vertical: AppTheme.spacingSmall,
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onAddFile,
              icon: const Icon(Icons.add, size: 24),
              label: const Text('添加文件'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 48),
                side: BorderSide(
                  color: Colors.grey.shade300,
                  width: 1.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppTheme.radiusMedium),
                ),
              ),
            ),
          ),
          if (onClear != null) ...[
            const SizedBox(width: AppTheme.spacingMedium),
            TextButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.delete_outline,
                  size: 20, color: AppTheme.dangerColor),
              label: const Text('清空',
                  style: TextStyle(color: AppTheme.dangerColor)),
            ),
          ],
        ],
      ),
    );
  }
}
