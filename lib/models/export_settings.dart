/// 导出设置数据模型
class ExportSettings {
  final ExportFormat format;
  final QualityPreset quality;
  final String outputPath;
  final String outputName;

  const ExportSettings({
    required this.format,
    required this.quality,
    required this.outputPath,
    required this.outputName,
  });

  /// 默认设置
  factory ExportSettings.defaults(String outputDir) => ExportSettings(
        format: ExportFormat.mp4,
        quality: QualityPreset.original,
        outputPath: outputDir,
        outputName: '',
      );

  String get fullOutputPath {
    final separator = outputPath.endsWith('/') || outputPath.endsWith('\\') ? '' : '/';
    return '$outputPath$separator$outputName.${format.extension}';
  }

  ExportSettings copyWith({
    ExportFormat? format,
    QualityPreset? quality,
    String? outputPath,
    String? outputName,
  }) {
    return ExportSettings(
      format: format ?? this.format,
      quality: quality ?? this.quality,
      outputPath: outputPath ?? this.outputPath,
      outputName: outputName ?? this.outputName,
    );
  }

  Map<String, dynamic> toJson() => {
        'format': format.index,
        'quality': quality.index,
        'outputPath': outputPath,
        'outputName': outputName,
      };

  factory ExportSettings.fromJson(Map<String, dynamic> json) => ExportSettings(
        format: ExportFormat.values[json['format'] as int],
        quality: QualityPreset.values[json['quality'] as int],
        outputPath: json['outputPath'] as String,
        outputName: json['outputName'] as String,
      );
}

enum ExportFormat {
  mp4,
  mkv,
  mov,
  avi,
  webm,
  gif,
  mp3,
  aac,
  m4a,
  wav,
  flac,
  ogg;

  String get label {
    switch (this) {
      case ExportFormat.mp4: return 'MP4';
      case ExportFormat.mkv: return 'MKV';
      case ExportFormat.mov: return 'MOV';
      case ExportFormat.avi: return 'AVI';
      case ExportFormat.webm: return 'WebM';
      case ExportFormat.gif: return 'GIF';
      case ExportFormat.mp3: return 'MP3';
      case ExportFormat.aac: return 'AAC';
      case ExportFormat.m4a: return 'M4A';
      case ExportFormat.wav: return 'WAV';
      case ExportFormat.flac: return 'FLAC';
      case ExportFormat.ogg: return 'OGG';
    }
  }

  String get extension {
    switch (this) {
      case ExportFormat.mp4: return 'mp4';
      case ExportFormat.mkv: return 'mkv';
      case ExportFormat.mov: return 'mov';
      case ExportFormat.avi: return 'avi';
      case ExportFormat.webm: return 'webm';
      case ExportFormat.gif: return 'gif';
      case ExportFormat.mp3: return 'mp3';
      case ExportFormat.aac: return 'aac';
      case ExportFormat.m4a: return 'm4a';
      case ExportFormat.wav: return 'wav';
      case ExportFormat.flac: return 'flac';
      case ExportFormat.ogg: return 'ogg';
    }
  }

  bool get isAudio {
    switch (this) {
      case ExportFormat.mp3:
      case ExportFormat.aac:
      case ExportFormat.m4a:
      case ExportFormat.wav:
      case ExportFormat.flac:
      case ExportFormat.ogg:
        return true;
      default:
        return false;
    }
  }

  bool get isVideo => !isAudio;
}

enum QualityPreset {
  original,
  high,
  standard,
  small;

  String get label {
    switch (this) {
      case QualityPreset.original: return '原画';
      case QualityPreset.high: return '高清';
      case QualityPreset.standard: return '标清';
      case QualityPreset.small: return '小文件';
    }
  }

  /// 视频分辨率上限（以源文件最高参数为准）
  int? get maxHeight {
    switch (this) {
      case QualityPreset.original: return null; // 不限制
      case QualityPreset.high: return 1080;
      case QualityPreset.standard: return 720;
      case QualityPreset.small: return 480;
    }
  }

  /// 音频比特率上限（kbps）
  int? get maxAudioBitrate {
    switch (this) {
      case QualityPreset.original: return null;
      case QualityPreset.high: return 320;
      case QualityPreset.standard: return 192;
      case QualityPreset.small: return 128;
    }
  }
}
