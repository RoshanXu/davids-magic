import 'dart:convert';
import 'dart:io';
import 'package:ffmpeg_kit_flutter_full/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_full/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter_full/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_full/return_code.dart';
import 'package:ffmpeg_kit_flutter_full/statistics.dart';
import '../models/media_file.dart';
import '../models/export_settings.dart';

typedef ProgressCallback = void Function(double progress, int speed, double remainingSeconds);

/// FFmpeg 服务 — 封装所有音视频处理操作
class FfmpegService {
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    await FFmpegKitConfig.init();
    _initialized = true;
  }

  /// 获取文件信息
  static Future<Map<String, dynamic>> probeFile(String filePath) async {
    if (Platform.isAndroid) {
      try {
        final session = await FFprobeKit.getMediaInformation(filePath);
        final info = session.getMediaInformation();
        if (info != null) {
          final allProperties = info.getAllProperties();
          final streams = info.getStreams();
          int? width, height;
          String? codecType;
          for (final s in streams) {
            final type = s.getType();
            if (type == 'video') {
              codecType = 'video';
              width = s.getWidth();
              height = s.getHeight();
              break;
            } else if (type == 'audio' && codecType == null) {
              codecType = 'audio';
            }
          }
          final bitrateStr = allProperties?['bit_rate'] as String?;
          final bitrate = bitrateStr != null ? int.tryParse(bitrateStr) : null;
          final durationStr = allProperties?['duration'] as String?;
          final durationMs = durationStr != null
              ? (double.parse(durationStr) * 1000).round()
              : 0;
          return {
            'durationMs': durationMs,
            'type': codecType ?? 'unknown',
            'width': width,
            'height': height,
            'bitrate': bitrate,
          };
        }
      } catch (_) {}
    }

    // Windows：使用应用同目录下的 ffprobe.exe
    final exeDir = File(Platform.resolvedExecutable).parent.path.replaceAll('\\', '/');
    final ffprobePath = '$exeDir/ffprobe.exe';
    final result = await Process.run(ffprobePath, [
      '-v', 'quiet', '-print_format', 'json',
      '-show_format', '-show_streams', filePath,
    ]);
    final output = result.stdout as String;
    if (output.isEmpty) return {'durationMs': 0, 'type': 'unknown'};

    final info = jsonDecode(output) as Map<String, dynamic>;
    final format = info['format'] as Map<String, dynamic>? ?? {};
    final streams = (info['streams'] as List<dynamic>?) ?? [];

    int durationMs = 0;
    final durationStr = format['duration'] as String?;
    if (durationStr != null) {
      durationMs = (double.parse(durationStr) * 1000).round();
    }

    int? width, height, bitrate;
    String? codecType;
    for (final s in streams) {
      final stream = s as Map<String, dynamic>;
      if (stream['codec_type'] == 'video') {
        codecType = 'video';
        width = (stream['width'] as num?)?.toInt();
        height = (stream['height'] as num?)?.toInt();
        break;
      } else if (stream['codec_type'] == 'audio' && codecType == null) {
        codecType = 'audio';
      }
    }
    final bitrateStr = format['bit_rate'] as String?;
    if (bitrateStr != null) bitrate = int.tryParse(bitrateStr);

    return {
      'durationMs': durationMs,
      'type': codecType ?? 'unknown',
      'width': width,
      'height': height,
      'bitrate': bitrate,
    };
  }

  /// 生成 H.264 预览片段（最长 30 秒），用于 Windows 上 video_player 兼容
  static Future<String?> generatePreview(
    String inputPath,
    int startMs,
    int endMs, {
    String? outputDir,
  }) async {
    const maxPreviewMs = 30000; // 最长 30 秒
    final previewStart = (startMs - 3000).clamp(0, startMs);
    var previewEnd = endMs + 3000;
    // 限制预览时长
    if (previewEnd - previewStart > maxPreviewMs) {
      previewEnd = previewStart + maxPreviewMs;
    }
    if (previewEnd <= previewStart) return null;

    final tempDir = outputDir ??
        '${Platform.environment['TEMP'] ?? '.'}/david_magic_previews';
    await Directory(tempDir).create(recursive: true);
    final outputPath =
        '$tempDir/preview_${DateTime.now().millisecondsSinceEpoch}.mp4';

    final args = [
      '-y',
      '-ss', (previewStart / 1000).toStringAsFixed(3),
      '-i', inputPath,
      '-t', ((previewEnd - previewStart) / 1000).toStringAsFixed(3),
      '-c:v', 'libx264', '-preset', 'ultrafast', '-crf', '23',
      '-c:a', 'aac', '-b:a', '128k',
      '-pix_fmt', 'yuv420p',
      outputPath,
    ];
    await _execute(args);
    return outputPath;
  }

  /// 导出：裁剪 + 合并 + 转码一步完成，只编码一次
  /// 通过 -ss/-t 输入选项做帧精确裁剪，concat 滤镜合并多段
  static Future<String> exportMultiple(
    List<MediaFile> files, ExportSettings settings,
    {ProgressCallback? onProgress}) async {

    // 展开所有片段：未裁剪的整个文件，裁剪的每个区间作为独立片段
    final segments = <_Segment>[];
    for (final file in files) {
      if (file.isClipped) {
        for (final region in file.keepRegions!) {
          segments.add(_Segment(file.path, startMs: region.startMs, endMs: region.endMs,
              type: file.type));
        }
      } else {
        segments.add(_Segment(file.path, type: file.type));
      }
    }

    final hasVideoSource = segments.any((s) => s.type == MediaType.video);
    final n = segments.length;

    final maxSourceHeight = files
        .where((f) => f.type == MediaType.video)
        .fold<int?>(null, (max, f) {
      if (f.height == null) return max;
      if (max == null) return f.height;
      return f.height! > max ? f.height : max;
    });

    final maxSourceBitrate = files
        .where((f) => f.bitrate != null && f.bitrate! > 0)
        .fold<int?>(null, (max, f) {
      if (max == null) return f.bitrate;
      return f.bitrate! > max ? f.bitrate : max;
    });

    final args = <String>['-y'];

    // 输入所有片段，带 -ss/-t 做帧精确裁剪
    for (final seg in segments) {
      if (seg.isClipped) {
        args.addAll([
          '-ss', (seg.startMs! / 1000).toStringAsFixed(3),
          '-t', ((seg.endMs! - seg.startMs!) / 1000).toStringAsFixed(3),
        ]);
      }
      args.addAll(['-i', seg.path]);
    }

    final audioBitrate = _buildAudioBitrate(settings, maxSourceBitrate);

    if (n == 1) {
      // 单片段：直接转码，无需 concat（-ss/-t 输入选项已处理裁剪）
      if (hasVideoSource && settings.format.isVideo) {
        if (settings.quality.maxHeight != null && maxSourceHeight != null) {
          final h = settings.quality.maxHeight!.clamp(2, maxSourceHeight);
          args.addAll(['-vf', 'scale=-2:$h']);
        }
        args.addAll(['-map', '0:v?', '-map', '0:a?']);
        args.addAll(['-c:v', 'libx264', '-preset', 'medium', '-crf', '23', '-pix_fmt', 'yuv420p']);
        args.addAll(['-c:a', 'aac', '-b:a', audioBitrate]);
      } else if (hasVideoSource && settings.format.isAudio) {
        args.addAll(['-map', '0:a?', '-vn']);
        args.addAll(['-c:a', _audioCodecForFormat(settings.format), '-b:a', audioBitrate]);
      } else {
        args.addAll(['-map', '0:a?', '-vn']);
        args.addAll(['-c:a', _audioCodecForFormat(settings.format), '-b:a', audioBitrate]);
      }
    } else {
      // 多片段：使用 concat 滤镜合并 + 转码
      if (hasVideoSource && settings.format.isVideo) {
        final filterParts = <String>[];
        for (int i = 0; i < n; i++) {
          filterParts.add('[$i:v][$i:a]');
        }
        final scaleNeeded = settings.quality.maxHeight != null && maxSourceHeight != null;
        if (scaleNeeded) {
          final h = settings.quality.maxHeight!.clamp(2, maxSourceHeight);
          final filter = '${filterParts.join('')}concat=n=$n:v=1:a=1[v][a];[v]scale=-2:$h[v2]';
          args.addAll(['-filter_complex', filter]);
          args.addAll(['-map', '[v2]', '-map', '[a]']);
        } else {
          final filter = '${filterParts.join('')}concat=n=$n:v=1:a=1';
          args.addAll(['-filter_complex', filter]);
        }
        args.addAll(['-c:v', 'libx264', '-preset', 'medium', '-crf', '23', '-pix_fmt', 'yuv420p']);
        args.addAll(['-c:a', 'aac', '-b:a', audioBitrate]);
      } else {
        final filterParts = <String>[];
        for (int i = 0; i < n; i++) {
          filterParts.add('[$i:a]');
        }
        final filter = '${filterParts.join('')}concat=n=$n:v=0:a=1';
        args.addAll(['-filter_complex', filter]);
        args.addAll(['-c:a', _audioCodecForFormat(settings.format), '-b:a', audioBitrate]);
      }
    }

    // 确保输出目录存在
    final outFile = File(settings.fullOutputPath);
    if (!outFile.parent.existsSync()) {
      outFile.parent.createSync(recursive: true);
    }

    args.add(settings.fullOutputPath);
    await _execute(args, onProgress: onProgress);
    return settings.fullOutputPath;
  }

  /// 构建音频比特率参数，如 "192k"
  static String _buildAudioBitrate(ExportSettings settings, int? maxSourceBitrate) {
    int br = 192; // 默认 192kbps
    if (settings.quality.maxAudioBitrate != null) {
      br = settings.quality.maxAudioBitrate!;
    }
    if (maxSourceBitrate != null && maxSourceBitrate > 0) {
      final maxKbps = maxSourceBitrate ~/ 1000;
      if (br > maxKbps) br = maxKbps;
    }
    return '${br}k';
  }

  /// 根据音频格式返回对应的编码器
  static String _audioCodecForFormat(ExportFormat format) {
    switch (format) {
      case ExportFormat.mp3:
        return 'libmp3lame';
      case ExportFormat.aac:
      case ExportFormat.m4a:
        return 'aac';
      case ExportFormat.wav:
        return 'pcm_s16le';
      case ExportFormat.flac:
        return 'flac';
      case ExportFormat.ogg:
        return 'libvorbis';
      default:
        // 视频容器中的音频默认用 AAC
        return 'aac';
    }
  }

  /// 执行 ffmpeg 命令
  static Future<void> _execute(
    List<String> args, {ProgressCallback? onProgress}) async {
    if (Platform.isAndroid) {
      final session = await FFmpegKit.executeAsync(
        args.join(' '),
        null, null,
        onProgress != null
            ? (Statistics stats) {
                final time = stats.getTime() / 1000.0;
                final speed = stats.getSpeed().round();
                onProgress(time, speed, 0);
              }
            : null,
      );
      final returnCode = await session.getReturnCode();
      if (!ReturnCode.isSuccess(returnCode)) {
        final output = await session.getOutput();
        final failStack = await session.getFailStackTrace();
        throw Exception('FFmpeg 执行失败:\n${failStack ?? output}');
      }
    } else {
      // 桌面端：Windows 用应用目录下 ffmpeg.exe，Linux/macOS 用系统 ffmpeg
      final isWindows = Platform.isWindows;
      final exeDir = File(Platform.resolvedExecutable).parent.path.replaceAll('\\', '/');
      final ffmpegPath = isWindows ? '$exeDir/ffmpeg.exe' : 'ffmpeg';
      final safeArgs = args.map((a) => a.replaceAll('\\', '/')).toList();

      // 保存复现命令
      if (isWindows) {
        final cmdLine = '"$ffmpegPath" ${safeArgs.map((a) => a.contains(' ') ? '"$a"' : a).join(' ')}';
        final batFile = File('${Directory.systemTemp.path}/_dm_cmd.bat');
        await batFile.writeAsString('@echo off\r\n$cmdLine\r\n');
      }
      print('[FFmpeg] $ffmpegPath ${safeArgs.join(' ')}');

      final result = await Process.run(ffmpegPath, safeArgs);
      if (result.exitCode != 0) {
        final raw = result.stderr.toString();
        final errorStart = raw.indexOf('Input #');
        final useful = errorStart >= 0
            ? raw.substring(errorStart)
            : (raw.length > 2000 ? '...(头2000字符为版本banner，已省略)\n${raw.substring(raw.length - 2000)}' : raw);
        throw Exception(
            'FFmpeg 执行失败 (exit ${result.exitCode})\n---\n$useful');
      }
    }
  }

  /// 取消
  static Future<void> cancel() async {
    await FFmpegKit.cancel();
  }
}

/// 内部使用的片段描述
class _Segment {
  final String path;
  final int? startMs;
  final int? endMs;
  final MediaType type;
  _Segment(this.path, {this.startMs, this.endMs, required this.type});
  bool get isClipped => startMs != null && endMs != null;
}
