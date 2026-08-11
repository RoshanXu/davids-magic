import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/export_settings.dart';
import '../theme/app_theme.dart';

/// 导出设置面板对话框
class ExportDialog extends StatefulWidget {
  final ExportSettings initialSettings;
  final int maxSourceHeight;
  final int maxSourceBitrate;
  final String estimatedSize;
  final bool hasVideo;
  final void Function(ExportSettings settings) onConfirm;

  const ExportDialog({
    super.key,
    required this.initialSettings,
    required this.maxSourceHeight,
    required this.maxSourceBitrate,
    required this.estimatedSize,
    required this.hasVideo,
    required this.onConfirm,
  });

  @override
  State<ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<ExportDialog> {
  late ExportFormat _format;
  late QualityPreset _quality;
  late String _outputPath;
  late TextEditingController _nameCtrl;

  @override
  void initState() {
    super.initState();
    _format = widget.initialSettings.format;
    _quality = widget.initialSettings.quality;
    _outputPath = widget.initialSettings.outputPath;
    _nameCtrl =
        TextEditingController(text: widget.initialSettings.outputName);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickOutputDir() async {
    final dir = await FilePicker.platform.getDirectoryPath();
    if (dir != null) {
      setState(() => _outputPath = dir);
    }
  }

  void _onConfirm() {
    final settings = widget.initialSettings.copyWith(
      format: _format,
      quality: _quality,
      outputPath: _outputPath,
      outputName: _nameCtrl.text.trim().isEmpty
          ? 'output'
          : _nameCtrl.text.trim(),
    );
    widget.onConfirm(settings);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final formats = widget.hasVideo
        ? ExportFormat.values
        : ExportFormat.values.where((f) => f.isAudio).toList();

    // 过滤品质预设（不超过源文件上限）
    final qualities = QualityPreset.values.where((q) {
      if (q.maxHeight != null && widget.maxSourceHeight > 0) {
        if (q.maxHeight! > widget.maxSourceHeight) return false;
      }
      if (q.maxAudioBitrate != null && widget.maxSourceBitrate > 0) {
        if (q.maxAudioBitrate! * 1000 > widget.maxSourceBitrate) return false;
      }
      return true;
    }).toList();
    if (qualities.isEmpty) {
      qualities.clear();
      qualities.add(QualityPreset.original);
    }

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingLarge),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '导出设置',
                style: TextStyle(
                  fontSize: AppTheme.fontSizeTitle,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppTheme.spacingLarge),

              // 格式选择
              _SectionLabel('输出格式'),
              const SizedBox(height: AppTheme.spacingSmall),
              Wrap(
                spacing: AppTheme.spacingSmall,
                runSpacing: AppTheme.spacingSmall,
                children: formats.map((f) {
                  final selected = _format == f;
                  return ChoiceChip(
                    label: Text(
                      f.label,
                      style: TextStyle(
                        fontSize: AppTheme.fontSizeList,
                        fontWeight:
                            selected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    selected: selected,
                    onSelected: (_) => setState(() => _format = f),
                    selectedColor:
                        Theme.of(context).colorScheme.primaryContainer,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: AppTheme.spacingLarge),

              // 画质预设
              _SectionLabel('画质预设'),
              const SizedBox(height: AppTheme.spacingSmall),
              Text(
                '源文件上限: ${widget.maxSourceHeight > 0 ? '${widget.maxSourceHeight}p' : '无限制'}',
                style: TextStyle(
                  fontSize: AppTheme.fontSizeSmall,
                  color: Colors.grey.shade500,
                ),
              ),
              const SizedBox(height: AppTheme.spacingSmall),
              Wrap(
                spacing: AppTheme.spacingSmall,
                runSpacing: AppTheme.spacingSmall,
                children: qualities.map((q) {
                  final selected = _quality == q;
                  return ChoiceChip(
                    label: Text(
                      q.label,
                      style: TextStyle(
                        fontSize: AppTheme.fontSizeList,
                        fontWeight:
                            selected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    selected: selected,
                    onSelected: (_) => setState(() => _quality = q),
                    selectedColor:
                        Theme.of(context).colorScheme.primaryContainer,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: AppTheme.spacingLarge),

              // 保存路径
              _SectionLabel('保存位置'),
              const SizedBox(height: AppTheme.spacingSmall),
              InkWell(
                onTap: _pickOutputDir,
                borderRadius:
                    BorderRadius.circular(AppTheme.radiusSmall),
                child: Container(
                  padding: const EdgeInsets.all(AppTheme.spacingMedium),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .inputDecorationTheme
                        .fillColor,
                    borderRadius: BorderRadius.circular(
                        AppTheme.radiusSmall),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.folder_outlined, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _outputPath,
                          style: const TextStyle(
                              fontSize: AppTheme.fontSizeLabel),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '浏览',
                        style: TextStyle(
                          fontSize: AppTheme.fontSizeLabel,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spacingLarge),

              // 文件名
              _SectionLabel('文件名'),
              const SizedBox(height: AppTheme.spacingSmall),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _nameCtrl,
                      style:
                          const TextStyle(fontSize: AppTheme.fontSizeList),
                      decoration: const InputDecoration(
                        hintText: '输入文件名',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '.${_format.extension}',
                    style: const TextStyle(
                      fontSize: AppTheme.fontSizeList,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingLarge),

              // 预估大小
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingMedium),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withAlpha(20),
                  borderRadius:
                      BorderRadius.circular(AppTheme.radiusMedium),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.storage_outlined,
                      size: 20,
                      color: AppTheme.primaryColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '预估文件大小: ${widget.estimatedSize}',
                      style: const TextStyle(
                        fontSize: AppTheme.fontSizeLabel,
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.spacingLarge),

              // 按钮
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: AppTheme.spacingMedium),
                  ElevatedButton(
                    onPressed: _onConfirm,
                    child: const Text('开始导出'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: AppTheme.fontSizeButton,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
