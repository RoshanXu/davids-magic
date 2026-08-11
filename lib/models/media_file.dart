/// 单个音视频文件的数据模型
class MediaFile {
  final String path;
  final String name;
  final int durationMs; // 总时长（毫秒）
  final MediaType type;
  final int? width;
  final int? height;
  final int? bitrate; // bps

  /// 剪辑保留区间列表，null 表示保留全部
  List<ClipRegion>? keepRegions;

  MediaFile({
    required this.path,
    required this.name,
    required this.durationMs,
    required this.type,
    this.width,
    this.height,
    this.bitrate,
    this.keepRegions,
  });

  /// 是否设置了剪辑
  bool get isClipped => keepRegions != null && keepRegions!.isNotEmpty;

  /// 实际有效时长（毫秒），考虑剪辑
  int get effectiveDurationMs {
    if (!isClipped) return durationMs;
    return keepRegions!.fold<int>(0, (sum, r) => sum + r.durationMs);
  }

  /// 格式化时长显示
  String get durationDisplay => _formatDuration(durationMs);

  String get effectiveDurationDisplay => _formatDuration(effectiveDurationMs);

  String _formatDuration(int ms) {
    final h = ms ~/ 3600000;
    final m = (ms % 3600000) ~/ 60000;
    final s = (ms % 60000) ~/ 1000;
    if (h > 0) return '$h时$m分$s秒';
    if (m > 0) return '$m分$s秒';
    return '$s秒';
  }

  /// 视频信息简介
  String get infoDisplay {
    final parts = <String>[];
    parts.add(type == MediaType.video ? '视频' : '音频');
    if (type == MediaType.video && width != null && height != null) {
      parts.add('${width}x$height');
    }
    if (bitrate != null) {
      parts.add(_formatBitrate(bitrate!));
    }
    return parts.join(' · ');
  }

  String _formatBitrate(int bps) {
    final kbps = bps ~/ 1000;
    if (kbps >= 1000) return '${(kbps / 1000).toStringAsFixed(0)}Mbps';
    return '${kbps}kbps';
  }

  MediaFile copyWith({
    List<ClipRegion>? keepRegions,
  }) {
    return MediaFile(
      path: path,
      name: name,
      durationMs: durationMs,
      type: type,
      width: width,
      height: height,
      bitrate: bitrate,
      keepRegions: keepRegions ?? this.keepRegions,
    );
  }

  Map<String, dynamic> toJson() => {
        'path': path,
        'name': name,
        'durationMs': durationMs,
        'type': type.index,
        'width': width,
        'height': height,
        'bitrate': bitrate,
        'keepRegions': keepRegions?.map((r) => r.toJson()).toList(),
      };

  factory MediaFile.fromJson(Map<String, dynamic> json) => MediaFile(
        path: json['path'] as String,
        name: json['name'] as String,
        durationMs: json['durationMs'] as int,
        type: MediaType.values[json['type'] as int],
        width: json['width'] as int?,
        height: json['height'] as int?,
        bitrate: json['bitrate'] as int?,
        keepRegions: (json['keepRegions'] as List<dynamic>?)
            ?.map((r) => ClipRegion.fromJson(r as Map<String, dynamic>))
            .toList(),
      );
}

enum MediaType { video, audio }

/// 剪辑时间区间
class ClipRegion {
  final int startMs; // 开始时间（毫秒）
  final int endMs; // 结束时间（毫秒）

  const ClipRegion({required this.startMs, required this.endMs});

  int get durationMs => endMs - startMs;

  /// 格式化显示 "02:15:30.500 ~ 05:45:00.000"
  String get display {
    return '${_formatMs(startMs)} ~ ${_formatMs(endMs)}';
  }

  /// 格式化单个时间戳
  static String formatTimestamp(int ms) => _formatMs(ms);

  static String _formatMs(int ms) {
    final h = ms ~/ 3600000;
    final m = (ms % 3600000) ~/ 60000;
    final s = (ms % 60000) ~/ 1000;
    final msPart = ms % 1000;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}.${msPart.toString().padLeft(3, '0')}';
  }

  /// 从时间戳字符串解析毫秒
  static int parseTimestamp(String text) {
    // 支持格式: HH:MM:SS.mmm 或 MM:SS.mmm 或 SS.mmm
    final parts = text.trim().split(':');
    int result = 0;
    if (parts.length == 3) {
      result += int.parse(parts[0]) * 3600000;
      result += int.parse(parts[1]) * 60000;
      final secParts = parts[2].split('.');
      result += int.parse(secParts[0]) * 1000;
      if (secParts.length > 1) {
        result += int.parse(secParts[1].padRight(3, '0').substring(0, 3));
      }
    } else if (parts.length == 2) {
      result += int.parse(parts[0]) * 60000;
      final secParts = parts[1].split('.');
      result += int.parse(secParts[0]) * 1000;
      if (secParts.length > 1) {
        result += int.parse(secParts[1].padRight(3, '0').substring(0, 3));
      }
    } else {
      final secParts = parts[0].split('.');
      result += int.parse(secParts[0]) * 1000;
      if (secParts.length > 1) {
        result += int.parse(secParts[1].padRight(3, '0').substring(0, 3));
      }
    }
    return result;
  }

  Map<String, dynamic> toJson() => {
        'startMs': startMs,
        'endMs': endMs,
      };

  factory ClipRegion.fromJson(Map<String, dynamic> json) => ClipRegion(
        startMs: json['startMs'] as int,
        endMs: json['endMs'] as int,
      );
}
