import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// 三个主操作按钮：剪辑、合并、输出
class ActionButtons extends StatelessWidget {
  final bool hasFiles;
  final bool hasSelection;
  final bool isProcessing;
  final VoidCallback onClip;
  final VoidCallback onMerge;
  final VoidCallback onExport;

  const ActionButtons({
    super.key,
    required this.hasFiles,
    required this.hasSelection,
    required this.isProcessing,
    required this.onClip,
    required this.onMerge,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingMedium,
        vertical: AppTheme.spacingMedium,
      ),
      child: Row(
        children: [
          Expanded(
            child: _ActionButton(
              icon: Icons.content_cut,
              label: '剪辑',
              enabled: hasSelection && !isProcessing,
              onTap: onClip,
            ),
          ),
          const SizedBox(width: AppTheme.spacingMedium),
          Expanded(
            child: _ActionButton(
              icon: Icons.merge,
              label: '合并',
              enabled: hasFiles && !isProcessing,
              onTap: onMerge,
            ),
          ),
          const SizedBox(width: AppTheme.spacingMedium),
          Expanded(
            child: _ActionButton(
              icon: Icons.file_download_outlined,
              label: '输出',
              enabled: hasFiles && !isProcessing,
              onTap: onExport,
              highlight: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;
  final bool highlight;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: ElevatedButton(
        onPressed: enabled ? onTap : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: highlight
              ? (enabled ? AppTheme.accentColor : Colors.grey.shade400)
              : null,
          foregroundColor: highlight ? Colors.white : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24),
            const SizedBox(width: 8),
            Text(label),
          ],
        ),
      ),
    );
  }
}
