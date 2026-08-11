import 'package:flutter/material.dart';
import '../models/media_file.dart';
import '../theme/app_theme.dart';

/// 文件列表面板 — 可拖拽排序、可删除、可选中
class FileListPanel extends StatelessWidget {
  final List<MediaFile> files;
  final int? selectedIndex;
  final ValueChanged<int> onSelect;
  final ValueChanged<int> onRemove;
  final void Function(int oldIndex, int newIndex) onReorder;

  const FileListPanel({
    super.key,
    required this.files,
    this.selectedIndex,
    required this.onSelect,
    required this.onRemove,
    required this.onReorder,
  });

  @override
  Widget build(BuildContext context) {
    if (files.isEmpty) {
      return _EmptyState();
    }

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacingMedium,
              vertical: AppTheme.spacingSmall,
            ),
            child: Text(
              '已添加 ${files.length} 个文件',
              style: TextStyle(
                fontSize: AppTheme.fontSizeLabel,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingMedium,
              ),
              itemCount: files.length,
              onReorderItem: onReorder,
              proxyDecorator: (child, index, animation) {
                return AnimatedBuilder(
                  animation: animation,
                  builder: (context, child) =>
                      Material(elevation: 4, child: child),
                  child: child,
                );
              },
              itemBuilder: (context, index) {
                final file = files[index];
                final isSelected = selectedIndex == index;
                return _FileItem(
                  key: ValueKey('${file.path}_$index'),
                  file: file,
                  index: index,
                  isSelected: isSelected,
                  onTap: () => onSelect(index),
                  onRemove: () => onRemove(index),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.video_library_outlined,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: AppTheme.spacingMedium),
            Text(
              '点击下方「+ 添加文件」开始',
              style: TextStyle(
                fontSize: AppTheme.fontSizeList,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: AppTheme.spacingSmall),
            Text(
              '支持音视频文件导入、剪辑和合并',
              style: TextStyle(
                fontSize: AppTheme.fontSizeLabel,
                color: Colors.grey.shade400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FileItem extends StatelessWidget {
  final MediaFile file;
  final int index;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _FileItem({
    super.key,
    required this.file,
    required this.index,
    required this.isSelected,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingSmall),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        side: isSelected
            ? BorderSide(color: Theme.of(context).colorScheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingMedium),
          child: Row(
            children: [
              // 排序手柄
              ReorderableDragStartListener(
                index: index,
                child: Icon(
                  Icons.drag_handle,
                  size: 28,
                  color: Colors.grey.shade400,
                ),
              ),
              const SizedBox(width: 12),

              // 文件图标
              Icon(
                file.type == MediaType.video
                    ? Icons.videocam_rounded
                    : Icons.audiotrack_rounded,
                size: 32,
                color: file.type == MediaType.video
                    ? AppTheme.primaryColor
                    : AppTheme.accentColor,
              ),
              const SizedBox(width: 12),

              // 文件信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      file.name,
                      style: TextStyle(
                        fontSize: AppTheme.fontSizeList,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${file.durationDisplay} · ${file.infoDisplay}',
                      style: TextStyle(
                        fontSize: AppTheme.fontSizeSmall,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    if (file.isClipped)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withAlpha(25),
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusSmall),
                          ),
                          child: Text(
                            '已剪辑 · ${file.effectiveDurationDisplay}',
                            style: TextStyle(
                              fontSize: AppTheme.fontSizeSmall,
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // 删除按钮
              IconButton(
                onPressed: onRemove,
                icon: Icon(
                  Icons.close,
                  size: 22,
                  color: Colors.grey.shade400,
                ),
                tooltip: '移除',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
