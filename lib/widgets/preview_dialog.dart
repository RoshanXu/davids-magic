import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../models/media_file.dart';
import '../theme/app_theme.dart';

/// 预览对话框
class PreviewDialog extends StatefulWidget {
  final MediaFile file;
  final List<ClipRegion>? regions;

  const PreviewDialog({super.key, required this.file, this.regions});

  @override
  State<PreviewDialog> createState() => _PreviewDialogState();
}

class _PreviewDialogState extends State<PreviewDialog> {
  VideoPlayerController? _controller;
  bool _ready = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final file = File(widget.file.path);
      if (!await file.exists()) {
        setState(() => _error = '文件不存在');
        return;
      }
      _controller = VideoPlayerController.file(file);
      await _controller!.initialize();
      _controller!.addListener(() => mounted ? setState(() {}) : null);
      if (widget.regions?.isNotEmpty == true) {
        _controller!.seekTo(Duration(milliseconds: widget.regions!.first.startMs));
      }
      setState(() => _ready = true);
    } catch (e) {
      setState(() => _error = '预览失败');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLarge)),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingLarge),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            const Expanded(child: Text('预览', style: TextStyle(fontSize: AppTheme.fontSizeTitle, fontWeight: FontWeight.bold))),
            IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close)),
          ]),
          const SizedBox(height: AppTheme.spacingMedium),
          if (_error != null)
            SizedBox(height: 150, child: Center(child: Text(_error!, style: const TextStyle(fontSize: AppTheme.fontSizeLabel, color: AppTheme.warnColor))))
          else if (!_ready || _controller == null)
            const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()))
          else
            Column(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                child: AspectRatio(
                  aspectRatio: _controller!.value.aspectRatio,
                  child: VideoPlayer(_controller!),
                ),
              ),
              const SizedBox(height: AppTheme.spacingMedium),
              _buildProgressBar(),
              const SizedBox(height: 4),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                IconButton(
                  onPressed: () {
                    final pos = _controller!.value.position - const Duration(seconds: 5);
                    _controller!.seekTo(pos < Duration.zero ? Duration.zero : pos);
                  },
                  icon: const Icon(Icons.replay_5, size: 36),
                ),
                const SizedBox(width: 16),
                Container(
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: AppTheme.primaryColor),
                  child: IconButton(
                    onPressed: () => _controller!.value.isPlaying ? _controller!.pause() : _controller!.play(),
                    icon: Icon(_controller!.value.isPlaying ? Icons.pause : Icons.play_arrow, size: 36, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 16),
                IconButton(
                  onPressed: () {
                    final pos = _controller!.value.position + const Duration(seconds: 5);
                    final max = _controller!.value.duration;
                    _controller!.seekTo(pos > max ? max : pos);
                  },
                  icon: const Icon(Icons.forward_5, size: 36),
                ),
              ]),
            ]),
          const SizedBox(height: AppTheme.spacingMedium),
          ElevatedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('关闭')),
        ]),
      ),
    );
  }

  Widget _buildProgressBar() {
    final posMs = _controller!.value.position.inMilliseconds;
    final totalMs = _controller!.value.duration.inMilliseconds;
    return Row(children: [
      Text(ClipRegion.formatTimestamp(posMs), style: const TextStyle(fontSize: AppTheme.fontSizeSmall, fontFamily: 'monospace')),
      Expanded(
        child: SliderTheme(
          data: const SliderThemeData(trackHeight: 6, thumbShape: RoundSliderThumbShape(enabledThumbRadius: 8)),
          child: Slider(
            value: totalMs > 0 ? (posMs / totalMs).clamp(0.0, 1.0) : 0,
            onChanged: (v) => _controller!.seekTo(Duration(milliseconds: (v * totalMs).round())),
          ),
        ),
      ),
      Text(ClipRegion.formatTimestamp(totalMs), style: const TextStyle(fontSize: AppTheme.fontSizeSmall, fontFamily: 'monospace')),
    ]);
  }
}
