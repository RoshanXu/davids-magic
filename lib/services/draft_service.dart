import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/media_file.dart';
import '../models/export_settings.dart';

/// 草稿自动保存和恢复服务
class DraftService {
  static const String _draftFileName = 'draft.json';

  /// 获取草稿文件路径
  static Future<String> _draftFilePath() async {
    final dir = await getApplicationDocumentsDirectory();
    final draftDir = Directory('${dir.path}/david_magic');
    if (!await draftDir.exists()) {
      await draftDir.create(recursive: true);
    }
    return '${draftDir.path}/$_draftFileName';
  }

  /// 保存草稿
  static Future<void> saveDraft({
    required List<MediaFile> files,
    required ExportSettings? lastExportSettings,
  }) async {
    try {
      final path = await _draftFilePath();
      final data = {
        'files': files.map((f) => f.toJson()).toList(),
        'lastExportSettings': lastExportSettings?.toJson(),
        'savedAt': DateTime.now().toIso8601String(),
      };
      await File(path).writeAsString(jsonEncode(data));
    } catch (e) {
      // 静默失败，不影响主流程
    }
  }

  /// 读取草稿
  static Future<DraftData?> loadDraft() async {
    try {
      final path = await _draftFilePath();
      final file = File(path);
      if (!await file.exists()) return null;

      final content = await file.readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;

      final files = (data['files'] as List<dynamic>?)
              ?.map((f) {
                try {
                  return MediaFile.fromJson(f as Map<String, dynamic>);
                } catch (e) {
                  return null;
                }
              })
              .whereType<MediaFile>()
              .toList() ??
          [];

      // 验证文件是否还存在
      final validFiles = <MediaFile>[];
      for (final f in files) {
        if (await File(f.path).exists()) {
          validFiles.add(f);
        }
      }

      final settingsJson = data['lastExportSettings'] as Map<String, dynamic>?;
      final settings = settingsJson != null
          ? ExportSettings.fromJson(settingsJson)
          : null;

      return DraftData(
        files: validFiles,
        lastExportSettings: settings,
        savedAt: DateTime.tryParse(data['savedAt'] as String? ?? '') ?? DateTime.now(),
      );
    } catch (e) {
      return null;
    }
  }

  /// 检查是否有未完成的草稿
  static Future<bool> hasDraft() async {
    try {
      final path = await _draftFilePath();
      return await File(path).exists();
    } catch (e) {
      return false;
    }
  }

  /// 清除草稿
  static Future<void> clearDraft() async {
    try {
      final path = await _draftFilePath();
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      // 静默失败
    }
  }
}

class DraftData {
  final List<MediaFile> files;
  final ExportSettings? lastExportSettings;
  final DateTime savedAt;

  const DraftData({
    required this.files,
    this.lastExportSettings,
    required this.savedAt,
  });

  bool get hasContent => files.isNotEmpty;
}
