/// Local model for a clip on the video timeline (S8-07).
class VideoClipInfo {
  final int clipId;
  final String sourcePath;
  final bool isVideo;
  final String displayName;
  final double durationSeconds;
  final double timelineIn;
  final double timelineOut;

  const VideoClipInfo({
    required this.clipId,
    required this.sourcePath,
    required this.isVideo,
    required this.displayName,
    required this.durationSeconds,
    required this.timelineIn,
    required this.timelineOut,
  });
}
