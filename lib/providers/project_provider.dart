import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../models/media_file.dart';
import '../models/export_settings.dart';
import '../services/ffmpeg_service.dart';
import '../services/draft_service.dart';

/// 处理状态
enum ProcessStatus { idle, processing, completed, cancelled, error }

/// 项目状态管理 — 文件、剪辑、导出
class ProjectProvider extends ChangeNotifier {
  List<MediaFile> _files = [];
  ExportSettings? _exportSettings;
  ProcessStatus _status = ProcessStatus.idle;
  double _progress = 0;
  String _statusMessage = '';
  String? _errorMessage;
  bool _initialized = false;

  // Getters
  List<MediaFile> get files => List.unmodifiable(_files);
  ExportSettings? get exportSettings => _exportSettings;
  ProcessStatus get status => _status;
  double get progress => _progress;
  String get statusMessage => _statusMessage;
  String? get errorMessage => _errorMessage;
  bool get hasFiles => _files.isNotEmpty;
  bool get isProcessing => _status == ProcessStatus.processing;
  bool get canExport => _files.isNotEmpty && _status != ProcessStatus.processing;

  /// 初始化（加载草稿、初始化 ffmpeg）
  Future<bool> initialize() async {
    if (_initialized) return false;
    _initialized = true;

    await FfmpegService.init();
    return await DraftService.hasDraft();
  }

  /// 恢复草稿
  Future<bool> restoreDraft() async {
    final draft = await DraftService.loadDraft();
    if (draft != null && draft.hasContent) {
      _files = draft.files;
      _exportSettings = draft.lastExportSettings;
      notifyListeners();
      return true;
    }
    return false;
  }

  /// 添加文件
  Future<void> addFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: [
        // 视频格式
        'mp4', 'mkv', 'mov', 'avi', 'webm', 'flv', 'wmv', 'm4v', '3gp', 'ts',
        // 音频格式
        'mp3', 'aac', 'wav', 'flac', 'ogg', 'wma', 'm4a', 'opus',
      ],
    );

    if (result == null || result.files.isEmpty) return;

    _status = ProcessStatus.processing;
    _statusMessage = '正在分析文件...';
    notifyListeners();

    for (final file in result.files) {
      if (file.path == null) continue;

      try {
        final info = await FfmpegService.probeFile(file.path!);
        final type = info['type'] == 'video' ? MediaType.video : MediaType.audio;

        _files.add(MediaFile(
          path: file.path!,
          name: file.name,
          durationMs: info['durationMs'] as int? ?? 0,
          type: type,
          width: info['width'] as int?,
          height: info['height'] as int?,
          bitrate: info['bitrate'] as int?,
        ));
      } catch (e) {
        // 跳过无法解析的文件，但添加基本信息
        _files.add(MediaFile(
          path: file.path!,
          name: file.name,
          durationMs: 0,
          type: MediaType.video,
        ));
      }
    }

    _status = ProcessStatus.idle;
    _statusMessage = '';
    _saveDraft();
    notifyListeners();
  }

  /// 移除单个文件
  void removeFile(int index) {
    if (index < 0 || index >= _files.length) return;
    _files.removeAt(index);
    _saveDraft();
    notifyListeners();
  }

  /// 清空全部文件
  void clearAll() {
    _files.clear();
    _exportSettings = null;
    DraftService.clearDraft();
    notifyListeners();
  }

  /// 重排文件顺序
  void reorderFiles(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    final item = _files.removeAt(oldIndex);
    _files.insert(newIndex, item);
    _saveDraft();
    notifyListeners();
  }

  /// 为指定文件设置剪辑区间
  void setClipRegions(int fileIndex, List<ClipRegion> regions) {
    if (fileIndex < 0 || fileIndex >= _files.length) return;
    _files[fileIndex] = _files[fileIndex].copyWith(keepRegions: regions);
    _saveDraft();
    notifyListeners();
  }

  /// 清除指定文件的剪辑
  void clearClip(int fileIndex) {
    if (fileIndex < 0 || fileIndex >= _files.length) return;
    _files[fileIndex] = _files[fileIndex].copyWith(keepRegions: null);
    _saveDraft();
    notifyListeners();
  }

  /// 设置导出参数
  void updateExportSettings(ExportSettings settings) {
    _exportSettings = settings;
    notifyListeners();
  }

  /// 开始导出
  Future<String?> startExport() async {
    if (!canExport) return null;

    _status = ProcessStatus.processing;
    _progress = 0;
    _errorMessage = null;
    _statusMessage = '正在导出...';
    notifyListeners();

    // 确保输出设置
    if (_exportSettings == null) {
      final dir = await getApplicationDocumentsDirectory();
      _exportSettings = ExportSettings.defaults(dir.path);
    }

    if (_exportSettings!.outputName.isEmpty) {
      // 用第一个文件名作为默认输出名
      final baseName = _files.first.name.replaceAll(RegExp(r'\.[^.]+$'), '');
      _exportSettings = _exportSettings!.copyWith(outputName: '${baseName}_output');
    }

    try {
      // 一步到位：-ss/-t 输入裁剪 + concat 滤镜合并 + 编码 → 只编码一次
      _statusMessage = '正在导出...';
      notifyListeners();

      final output = await FfmpegService.exportMultiple(
        _files,
        _exportSettings!,
        onProgress: (p, speed, remaining) {
          _progress = p;
          _statusMessage = '导出中... ${(p * 100).toStringAsFixed(0)}%';
          notifyListeners();
        },
      );

      _status = ProcessStatus.completed;
      _progress = 1;
      _statusMessage = '导出完成！';
      _saveDraft();
      notifyListeners();

      return output;
    } catch (e) {
      _status = ProcessStatus.error;
      _errorMessage = e.toString();
      _statusMessage = '导出失败';
      notifyListeners();
      return null;
    }
  }

  /// 取消处理
  Future<void> cancelProcess() async {
    await FfmpegService.cancel();
    _status = ProcessStatus.cancelled;
    _statusMessage = '已取消';
    notifyListeners();
  }

  /// 重置状态
  void resetStatus() {
    _status = ProcessStatus.idle;
    _progress = 0;
    _statusMessage = '';
    _errorMessage = null;
    notifyListeners();
  }

  /// 获取文件列表中最高参数
  int get maxSourceHeight {
    return _files
        .where((f) => f.type == MediaType.video && f.height != null)
        .fold<int>(0, (max, f) => f.height! > max ? f.height! : max);
  }

  int get maxSourceBitrate {
    return _files
        .where((f) => f.bitrate != null)
        .fold<int>(0, (max, f) => f.bitrate! > max ? f.bitrate! : max);
  }

  /// 预估输出文件大小
  String estimateOutputSize() {
    if (_files.isEmpty) return '未知';

    // 简单估算：总时长 × 码率
    int totalDurationMs = _files.fold(0, (sum, f) => sum + f.effectiveDurationMs);
    int bitrate = maxSourceBitrate > 0 ? maxSourceBitrate : 2000000; // 默认2Mbps

    if (_exportSettings?.quality.maxAudioBitrate != null) {
      final maxBr = (_exportSettings!.quality.maxAudioBitrate! * 1000);
      if (maxBr < bitrate) bitrate = maxBr;
    }

    final estimateBytes = (totalDurationMs / 1000) * (bitrate / 8);
    return _formatSize(estimateBytes.round());
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  /// 自动保存草稿
  void _saveDraft() {
    DraftService.saveDraft(
      files: _files,
      lastExportSettings: _exportSettings,
    );
  }

  @override
  void dispose() {
    _saveDraft();
    super.dispose();
  }
}
