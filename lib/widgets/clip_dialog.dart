import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../models/media_file.dart';
import '../services/ffmpeg_service.dart';
import '../theme/app_theme.dart';

/// 剪辑面板 — 带播放器
class ClipDialog extends StatefulWidget {
  final MediaFile file;
  final void Function(List<ClipRegion>? regions) onConfirm;

  const ClipDialog({super.key, required this.file, required this.onConfirm});

  @override
  State<ClipDialog> createState() => _ClipDialogState();
}

class _ClipDialogState extends State<ClipDialog> {
  // 视频播放
  VideoPlayerController? _videoCtrl;
  // 音频播放
  AudioPlayer? _audioPlayer;

  bool _ready = false;
  String? _error;

  // 当前播放位置和时长（毫秒）
  int _posMs = 0;
  int _totalMs = 0;
  bool _playing = false;

  StreamSubscription? _audioPosSub;
  StreamSubscription? _audioStateSub;
  StreamSubscription? _audioDurSub;

  final _keepStartCtrl = TextEditingController();
  final _keepEndCtrl = TextEditingController();
  final _deleteControllers =
      <({TextEditingController start, TextEditingController end})>[];

  bool get _isAudio => widget.file.type == MediaType.audio;

  @override
  void initState() {
    super.initState();
    _totalMs = widget.file.durationMs;

    if (widget.file.keepRegions != null && widget.file.keepRegions!.isNotEmpty) {
      final r = widget.file.keepRegions!.first;
      _keepStartCtrl.text = ClipRegion.formatTimestamp(r.startMs);
      _keepEndCtrl.text = ClipRegion.formatTimestamp(r.endMs);
    } else {
      _keepStartCtrl.text = ClipRegion.formatTimestamp(0);
      _keepEndCtrl.text = ClipRegion.formatTimestamp(widget.file.durationMs);
    }
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      final file = File(widget.file.path);
      if (!await file.exists()) {
        setState(() => _error = '文件不存在');
        return;
      }

      if (_isAudio) {
        await _initAudio(file);
      } else {
        await _initVideo(file);
      }
    } catch (e) {
      setState(() => _error = '加载失败: $e');
    }
  }

  Future<void> _initAudio(File file) async {
    _audioPlayer = AudioPlayer();

    _audioDurSub = _audioPlayer!.onDurationChanged.listen((dur) {
      if (dur.inMilliseconds > 0) {
        _totalMs = dur.inMilliseconds;
        if (mounted) setState(() {});
      }
    });

    _audioPosSub = _audioPlayer!.onPositionChanged.listen((pos) {
      _posMs = pos.inMilliseconds;
      if (mounted) setState(() {});
    });

    _audioStateSub = _audioPlayer!.onPlayerStateChanged.listen((s) {
      _playing = s == PlayerState.playing;
      if (mounted) setState(() {});
    });

    try {
      await _audioPlayer!.play(DeviceFileSource(file.path));
      await _audioPlayer!.pause(); // 加载后立即暂停
      setState(() => _ready = true);
    } catch (e) {
      // audioplayers 失败时，仍显示可用于手动输入
      setState(() {
        _ready = true;
        _error = null;
      });
    }
  }

  Future<void> _initVideo(File file) async {
    try {
      // 生成 H.264 兼容预览（最长30秒），解决 Windows video_player 解码问题
      final previewStart = _keepStartMs > 0 ? _keepStartMs : 0;
      final previewEnd = (_keepEndMs > previewStart && _keepEndMs <= widget.file.durationMs)
          ? _keepEndMs
          : (previewStart + 30000).clamp(0, widget.file.durationMs);
      final previewPath = await FfmpegService.generatePreview(
        file.path, previewStart, previewEnd,
      );
      if (previewPath != null) {
        _videoCtrl = VideoPlayerController.file(File(previewPath));
        await _videoCtrl!.initialize();
        _videoCtrl!.addListener(_onVideoUpdate);
        _totalMs = _videoCtrl!.value.duration.inMilliseconds;
        setState(() => _ready = true);
        return;
      }
    } catch (e) {
      setState(() => _error = '预览生成失败（可能是视频编码不支持）');
      setState(() => _ready = true);
      return;
    }
    // Fallback：尝试直接播放原文件
    try {
      _videoCtrl = VideoPlayerController.file(file);
      await _videoCtrl!.initialize();
      _videoCtrl!.addListener(_onVideoUpdate);
      _totalMs = _videoCtrl!.value.duration.inMilliseconds;
    } catch (_) {}
    setState(() => _ready = true);
  }

  int get _keepStartMs {
    try { return ClipRegion.parseTimestamp(_keepStartCtrl.text); }
    catch (_) { return 0; }
  }

  int get _keepEndMs {
    try { return ClipRegion.parseTimestamp(_keepEndCtrl.text); }
    catch (_) { return 0; }
  }

  void _onVideoUpdate() {
    if (_videoCtrl == null) return;
    _posMs = _videoCtrl!.value.position.inMilliseconds;
    _playing = _videoCtrl!.value.isPlaying;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _videoCtrl?.removeListener(_onVideoUpdate);
    _videoCtrl?.dispose();
    _audioPosSub?.cancel();
    _audioStateSub?.cancel();
    _audioDurSub?.cancel();
    _audioPlayer?.dispose();
    _keepStartCtrl.dispose();
    _keepEndCtrl.dispose();
    for (final c in _deleteControllers) {
      c.start.dispose();
      c.end.dispose();
    }
    super.dispose();
  }

  // ---- 播放控制 ----

  void _togglePlay() {
    if (_isAudio && _audioPlayer != null) {
      if (_playing) {
        _audioPlayer!.pause();
      } else {
        _audioPlayer!.resume();
      }
    } else if (_videoCtrl != null) {
      if (_playing) {
        _videoCtrl!.pause();
      } else {
        _videoCtrl!.play();
      }
    }
  }

  void _seekRelative(int ms) {
    final target = (_posMs + ms).clamp(0, _totalMs);
    if (_isAudio && _audioPlayer != null) {
      _audioPlayer!.seek(Duration(milliseconds: target));
    } else if (_videoCtrl != null) {
      _videoCtrl!.seekTo(Duration(milliseconds: target));
    }
    _posMs = target;
    setState(() {});
  }

  void _seekTo(int ms) {
    if (_isAudio && _audioPlayer != null) {
      _audioPlayer!.seek(Duration(milliseconds: ms));
    } else if (_videoCtrl != null) {
      _videoCtrl!.seekTo(Duration(milliseconds: ms));
    }
    _posMs = ms;
    setState(() {});
  }

  void _setStartFromCurrent() {
    _keepStartCtrl.text = ClipRegion.formatTimestamp(_posMs);
    setState(() {});
  }

  void _setEndFromCurrent() {
    _keepEndCtrl.text = ClipRegion.formatTimestamp(_posMs);
    setState(() {});
  }

  void _playRegionPreview() {
    final startMs = ClipRegion.parseTimestamp(_keepStartCtrl.text);
    _seekTo(startMs);
    Future.delayed(const Duration(milliseconds: 100), _togglePlay);
  }

  // ---- 删除区间 ----

  void _addDeleteRegion() {
    setState(() {
      _deleteControllers.add((
        start: TextEditingController(text: '00:00:00.000'),
        end: TextEditingController(text: '00:00:00.000'),
      ));
    });
  }

  void _removeDeleteRegion(int index) {
    setState(() {
      _deleteControllers[index].start.dispose();
      _deleteControllers[index].end.dispose();
      _deleteControllers.removeAt(index);
    });
  }

  // ---- 确认 ----

  void _onConfirm() {
    final keepStart = ClipRegion.parseTimestamp(_keepStartCtrl.text);
    final keepEnd = ClipRegion.parseTimestamp(_keepEndCtrl.text);
    if (keepEnd <= keepStart) {
      _showError('结束时间必须大于开始时间');
      return;
    }
    if (keepStart < 0) {
      _showError('开始时间不能小于0');
      return;
    }
    if (keepEnd > widget.file.durationMs) {
      _showError('结束时间不能超过视频时长（${ClipRegion.formatTimestamp(widget.file.durationMs)}）');
      return;
    }

    final deletes = <ClipRegion>[];
    for (final c in _deleteControllers) {
      final s = ClipRegion.parseTimestamp(c.start.text);
      final e = ClipRegion.parseTimestamp(c.end.text);
      if (e > s) deletes.add(ClipRegion(startMs: s, endMs: e));
    }

    final result = <ClipRegion>[];
    if (deletes.isEmpty) {
      result.add(ClipRegion(startMs: keepStart, endMs: keepEnd));
    } else {
      var cur = keepStart;
      deletes.sort((a, b) => a.startMs.compareTo(b.startMs));
      for (final d in deletes) {
        if (d.startMs > cur) {
          result.add(ClipRegion(startMs: cur, endMs: d.startMs.clamp(cur, keepEnd)));
        }
        if (d.endMs > cur) cur = d.endMs.clamp(cur, keepEnd);
      }
      if (cur < keepEnd) result.add(ClipRegion(startMs: cur, endMs: keepEnd));
      if (result.isEmpty) {
        _showError('删除区间覆盖了整个保留范围，请调整');
        return;
      }
    }
    widget.onConfirm(result.isNotEmpty ? result : null);
    Navigator.of(context).pop();
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontSize: AppTheme.fontSizeLabel)),
      backgroundColor: AppTheme.dangerColor,
    ));
  }

  // ---- UI ----

  @override
  Widget build(BuildContext context) {
    final maxTime = ClipRegion.formatTimestamp(widget.file.durationMs);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLarge)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: SizedBox(
        width: 600,
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingLarge),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 12),
                _buildPlayer(),
                const SizedBox(height: 8),
                _buildControls(),
                const SizedBox(height: 20),
                _buildKeepRegion(maxTime),
                const SizedBox(height: 20),
                _buildDeleteRegions(),
                const SizedBox(height: 20),
                _buildActions(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(children: [
      Icon(
        _isAudio ? Icons.audiotrack_rounded : Icons.videocam_rounded,
        size: 28, color: AppTheme.primaryColor,
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(widget.file.name,
          style: const TextStyle(fontSize: AppTheme.fontSizeTitle, fontWeight: FontWeight.bold),
          maxLines: 1, overflow: TextOverflow.ellipsis,
        ),
      ),
    ]);
  }

  Widget _buildPlayer() {
    if (_error != null) {
      return Container(
        height: 180,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(_error!, textAlign: TextAlign.center,
              style: const TextStyle(fontSize: AppTheme.fontSizeLabel, color: AppTheme.warnColor),
            ),
          ),
        ),
      );
    }

    if (!_ready) {
      return Container(
        height: 180,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        ),
        child: const Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('加载中...', style: TextStyle(fontSize: AppTheme.fontSizeLabel)),
          ]),
        ),
      );
    }

    // 音频：显示音频图标
    if (_isAudio) {
      return Container(
        height: 140,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1D23),
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        ),
        child: Stack(alignment: Alignment.center, children: [
          Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(
              _playing ? Icons.graphic_eq : Icons.audiotrack_rounded,
              size: 56,
              color: _playing
                  ? AppTheme.accentColor
                  : AppTheme.accentColor.withAlpha(140),
            ),
            const SizedBox(height: 8),
            Text(
              _playing ? '正在播放...' : '音频预览',
              style: TextStyle(
                fontSize: AppTheme.fontSizeLabel,
                color: _playing ? Colors.white : Colors.white54,
              ),
            ),
          ]),
          if (!_playing)
            GestureDetector(
              onTap: _togglePlay,
              child: Container(
                color: Colors.black38,
                child: const Center(
                  child: Icon(Icons.play_circle_filled, size: 52, color: Colors.white70),
                ),
              ),
            ),
        ]),
      );
    }

    // 视频：显示 video_player
    if (_videoCtrl != null && _videoCtrl!.value.isInitialized) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        child: AspectRatio(
          aspectRatio: _videoCtrl!.value.aspectRatio,
          child: Stack(alignment: Alignment.center, children: [
            VideoPlayer(_videoCtrl!),
            if (!_playing)
              GestureDetector(
                onTap: _togglePlay,
                child: Container(
                  color: Colors.black26,
                  child: const Icon(Icons.play_circle_filled, size: 64, color: Colors.white70),
                ),
              ),
          ]),
        ),
      );
    }

    // 视频播放器不可用（Windows fallback）
    return Container(
      height: 140,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D23),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      child: const Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.videocam_rounded, size: 48, color: Colors.white54),
          SizedBox(height: 8),
          Text('使用下方进度条定位', style: TextStyle(fontSize: AppTheme.fontSizeLabel, color: Colors.white54)),
        ]),
      ),
    );
  }

  Widget _buildControls() {
    final posText = ClipRegion.formatTimestamp(_posMs);
    final totalText = ClipRegion.formatTimestamp(_totalMs);
    final progress = _totalMs > 0 ? (_posMs / _totalMs).clamp(0.0, 1.0) : 0.0;

    return Column(children: [
      Row(children: [
        Text(posText, style: const TextStyle(fontSize: 13, fontFamily: 'monospace')),
        Expanded(
          child: SliderTheme(
            data: const SliderThemeData(
              trackHeight: 6,
              thumbShape: RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape: RoundSliderOverlayShape(overlayRadius: 16),
            ),
            child: Slider(
              value: progress,
              onChanged: (v) => _seekTo((v * _totalMs).round()),
            ),
          ),
        ),
        Text(totalText, style: const TextStyle(fontSize: 13, fontFamily: 'monospace')),
      ]),
      const SizedBox(height: 4),

      // 播放按钮
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _CtrlBtn(icon: Icons.replay_5, label: '后退5秒', onTap: () => _seekRelative(-5000)),
        const SizedBox(width: 4),
        Container(
          decoration: const BoxDecoration(shape: BoxShape.circle, color: AppTheme.primaryColor),
          child: IconButton(
            onPressed: _togglePlay,
            icon: Icon(_playing ? Icons.pause : Icons.play_arrow, size: 36, color: Colors.white),
          ),
        ),
        const SizedBox(width: 4),
        _CtrlBtn(icon: Icons.forward_5, label: '前进5秒', onTap: () => _seekRelative(5000)),
      ]),
      const SizedBox(height: 10),

      // 设为开始/结束/试播
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        OutlinedButton.icon(
          onPressed: _setStartFromCurrent,
          icon: const Icon(Icons.skip_previous, size: 18),
          label: const Text('设为开始'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 40),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            side: const BorderSide(color: AppTheme.primaryColor),
            foregroundColor: AppTheme.primaryColor,
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: _setEndFromCurrent,
          icon: const Icon(Icons.skip_next, size: 18),
          label: const Text('设为结束'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 40),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            side: const BorderSide(color: AppTheme.accentColor),
            foregroundColor: AppTheme.accentColor,
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: _playRegionPreview,
          icon: const Icon(Icons.play_circle_outline, size: 18),
          label: const Text('试播区间'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 40),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          ),
        ),
      ]),
    ]);
  }

  Widget _buildKeepRegion(String maxTime) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('保留区间', style: TextStyle(fontSize: AppTheme.fontSizeButton, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: _TimeInput(controller: _keepStartCtrl, label: '开始')),
        const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('~', style: TextStyle(fontSize: AppTheme.fontSizeButton))),
        Expanded(child: _TimeInput(controller: _keepEndCtrl, label: '结束')),
      ]),
      const SizedBox(height: 4),
      Text('格式: 时:分:秒.毫秒  范围: 00:00:00.000 ~ $maxTime',
          style: TextStyle(fontSize: AppTheme.fontSizeSmall, color: Colors.grey.shade500)),
      const SizedBox(height: 2),
      const Text('播放时点「设为开始/结束」自动填入',
          style: TextStyle(fontSize: AppTheme.fontSizeSmall, color: AppTheme.primaryColor)),
    ]);
  }

  Widget _buildDeleteRegions() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('删除区间（可选）', style: TextStyle(fontSize: AppTheme.fontSizeButton, fontWeight: FontWeight.w600)),
        TextButton.icon(onPressed: _addDeleteRegion, icon: const Icon(Icons.add, size: 20), label: const Text('添加')),
      ]),
      const SizedBox(height: 8),
      ...List.generate(_deleteControllers.length, (i) {
        final c = _deleteControllers[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            Expanded(child: _TimeInput(controller: c.start, label: '开始')),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('~', style: TextStyle(fontSize: AppTheme.fontSizeButton))),
            Expanded(child: _TimeInput(controller: c.end, label: '结束')),
            IconButton(onPressed: () => _removeDeleteRegion(i), icon: const Icon(Icons.delete_outline, color: AppTheme.dangerColor)),
          ]),
        );
      }),
    ]);
  }

  Widget _buildActions() {
    return Row(mainAxisAlignment: MainAxisAlignment.end, children: [
      TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('取消')),
      const SizedBox(width: 16),
      ElevatedButton(onPressed: _onConfirm, child: const Text('确认')),
    ]);
  }
}

class _CtrlBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _CtrlBtn({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      IconButton(onPressed: onTap, icon: Icon(icon, size: 30)),
      Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
    ]);
  }
}

class _TimeInput extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  const _TimeInput({required this.controller, required this.label});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.text,
      style: const TextStyle(fontSize: 16, fontFamily: 'monospace', letterSpacing: 1),
      decoration: InputDecoration(
        labelText: label,
        hintText: '00:00:00.000',
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
    );
  }
}
