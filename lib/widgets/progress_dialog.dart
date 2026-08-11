import 'package:flutter/material.dart';
import '../providers/project_provider.dart';
import '../theme/app_theme.dart';

/// 处理进度弹窗 — 支持最小化后台运行
class ProgressDialog extends StatelessWidget {
  final ProjectProvider provider;
  final VoidCallback onMinimize;
  final VoidCallback onCancel;

  const ProgressDialog({
    super.key,
    required this.provider,
    required this.onMinimize,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingLarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 状态图标
            _buildStatusIcon(),
            const SizedBox(height: AppTheme.spacingMedium),

            // 状态文字
            Text(
              provider.statusMessage.isEmpty
                  ? '处理中...'
                  : provider.statusMessage,
              style: const TextStyle(
                fontSize: AppTheme.fontSizeButton,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spacingMedium),

            // 进度条
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: provider.progress > 0 ? provider.progress : null,
                minHeight: 8,
                backgroundColor:
                    Theme.of(context).colorScheme.primary.withAlpha(38),
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spacingSmall),

            // 百分比
            if (provider.progress > 0)
              Text(
                '${(provider.progress * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: AppTheme.fontSizeLabel,
                  color: Colors.grey.shade600,
                ),
              ),
            const SizedBox(height: AppTheme.spacingLarge),

            // 按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: onMinimize,
                  icon: const Icon(Icons.minimize, size: 20),
                  label: const Text('后台运行'),
                ),
                const SizedBox(width: AppTheme.spacingMedium),
                OutlinedButton.icon(
                  onPressed: onCancel,
                  icon: const Icon(Icons.close, size: 20),
                  label: const Text('取消'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.dangerColor,
                    side: const BorderSide(color: AppTheme.dangerColor),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon() {
    switch (provider.status) {
      case ProcessStatus.processing:
        return const SizedBox(
          width: 48,
          height: 48,
          child: CircularProgressIndicator(strokeWidth: 4),
        );
      case ProcessStatus.completed:
        return const Icon(
          Icons.check_circle_outline,
          size: 48,
          color: AppTheme.accentColor,
        );
      case ProcessStatus.error:
        return const Icon(
          Icons.error_outline,
          size: 48,
          color: AppTheme.dangerColor,
        );
      case ProcessStatus.cancelled:
        return const Icon(
          Icons.cancel_outlined,
          size: 48,
          color: AppTheme.warnColor,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  /// 显示进度弹窗，返回是否完成
  static Future<bool> show(
    BuildContext context,
    ProjectProvider provider, {
    VoidCallback? onMinimize,
    VoidCallback? onCancel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ProgressDialog(
        provider: provider,
        onMinimize: () {
          Navigator.of(ctx).pop(false); // false = minimized
          onMinimize?.call();
        },
        onCancel: () {
          provider.cancelProcess();
          onCancel?.call();
        },
      ),
    );
    return result ?? false;
  }

  /// 完成后弹出通知
  static void showCompletedNotification(
      BuildContext context, String? outputPath) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        ),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: AppTheme.accentColor, size: 28),
            SizedBox(width: 8),
            Text('导出完成', style: TextStyle(fontSize: AppTheme.fontSizeTitle)),
          ],
        ),
        content: Text(
          outputPath != null ? '文件已保存到:\n$outputPath' : '文件已成功导出',
          style: const TextStyle(fontSize: AppTheme.fontSizeLabel),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('好的'),
          ),
        ],
      ),
    );
  }
}
