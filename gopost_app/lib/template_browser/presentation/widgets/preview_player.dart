import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gopost_app/core/cache/image_cache_manager.dart';
import 'package:gopost_app/core/theme/app_spacing.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

class PreviewPlayer extends StatefulWidget {
  final String? previewUrl;
  final String? thumbnailUrl;
  final bool isVideo;
  final int width;
  final int height;
  final bool autoPlay;
  final bool looping;

  const PreviewPlayer({
    super.key,
    this.previewUrl,
    this.thumbnailUrl,
    required this.isVideo,
    required this.width,
    required this.height,
    this.autoPlay = true,
    this.looping = true,
  });

  @override
  State<PreviewPlayer> createState() => _PreviewPlayerState();
}

class _PreviewPlayerState extends State<PreviewPlayer>
    with WidgetsBindingObserver {
  Player? _player;
  VideoController? _videoController;
  bool _initialized = false;
  bool _showControls = true;
  StreamSubscription? _playingSub;
  StreamSubscription? _positionSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.isVideo && widget.previewUrl != null) {
      _initVideoPlayer();
    }
  }

  Future<void> _initVideoPlayer() async {
    final player = Player();
    final controller = VideoController(player);
    _player = player;
    _videoController = controller;

    _playingSub = player.stream.playing.listen((_) {
      if (mounted) setState(() {});
    });
    _positionSub = player.stream.position.listen((_) {
      if (mounted) setState(() {});
    });

    try {
      await player.open(Media(widget.previewUrl!), play: false);
      await player.setPlaylistMode(
        widget.looping ? PlaylistMode.single : PlaylistMode.none,
      );
      await player.setVolume(0.0);

      if (mounted) {
        setState(() => _initialized = true);
        if (widget.autoPlay) {
          player.play();
          setState(() => _showControls = false);
        }
      }
    } catch (_) {
      // Initialization failed — fall back to thumbnail
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_player == null) return;
    if (state == AppLifecycleState.paused) {
      _player!.pause();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _playingSub?.cancel();
    _positionSub?.cancel();
    _player?.dispose();
    super.dispose();
  }

  bool get _isPlaying => _player?.state.playing ?? false;
  bool get _isMuted => (_player?.state.volume ?? 0) == 0;

  void _togglePlayPause() {
    if (_player == null || !_initialized) return;
    if (_isPlaying) {
      _player!.pause();
      setState(() => _showControls = true);
    } else {
      _player!.play();
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && _isPlaying) setState(() => _showControls = false);
      });
    }
  }

  void _toggleMute() {
    if (_player == null) return;
    _player!.setVolume(_isMuted ? 100.0 : 0.0);
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: widget.width / widget.height,
      child: widget.isVideo ? _buildVideoPlayer() : _buildImagePreview(),
    );
  }

  Widget _buildImagePreview() {
    final theme = Theme.of(context);

    if (widget.thumbnailUrl != null) {
      return AppCachedImage(
        imageUrl: widget.thumbnailUrl!,
        fit: BoxFit.cover,
      );
    }

    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.image_outlined,
        size: 48,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }

  Widget _buildVideoPlayer() {
    return GestureDetector(
      onTap: () {
        if (_initialized) {
          setState(() => _showControls = !_showControls);
          if (_showControls) {
            Future.delayed(const Duration(seconds: 3), () {
              if (mounted && _isPlaying) setState(() => _showControls = false);
            });
          }
        }
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          _buildVideoSurface(),
          _buildPlayPauseOverlay(),
          _buildMuteButton(),
          if (_initialized) _buildProgressBar(),
        ],
      ),
    );
  }

  Widget _buildVideoSurface() {
    if (_initialized && _videoController != null) {
      return Video(controller: _videoController!, controls: NoVideoControls);
    }

    if (widget.thumbnailUrl != null) {
      return AppCachedImage(
        imageUrl: widget.thumbnailUrl!,
        fit: BoxFit.cover,
      );
    }

    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }

  Widget _buildPlayPauseOverlay() {
    return AnimatedOpacity(
      opacity: _showControls ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      child: GestureDetector(
        onTap: _togglePlayPause,
        child: Container(
          color: Colors.black.withValues(alpha: 0.3),
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                _isPlaying
                    ? Icons.pause_circle_filled
                    : Icons.play_circle_filled,
                key: ValueKey(_isPlaying),
                color: Colors.white,
                size: 64,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMuteButton() {
    return Positioned(
      bottom: AppSpacing.md + (_initialized ? 12 : 0),
      right: AppSpacing.md,
      child: AnimatedOpacity(
        opacity: _showControls || !_isPlaying ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: GestureDetector(
          onTap: _toggleMute,
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isMuted ? Icons.volume_off : Icons.volume_up,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    final position = _player!.state.position;
    final duration = _player!.state.duration;
    final progress =
        duration.inMilliseconds > 0
            ? position.inMilliseconds / duration.inMilliseconds
            : 0.0;

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: AnimatedOpacity(
        opacity: _showControls || !_isPlaying ? 1.0 : 0.3,
        duration: const Duration(milliseconds: 200),
        child: LinearProgressIndicator(
          value: progress,
          minHeight: 3,
          backgroundColor: Colors.white.withValues(alpha: 0.3),
          valueColor: AlwaysStoppedAnimation<Color>(
            Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }
}
