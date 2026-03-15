import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gopost_app/video_editor/domain/models/video_project.dart';
import 'package:gopost_app/video_editor/presentation/providers/timeline_notifier.dart';

const _markerColors = <(MarkerType, String, Color, IconData)>[
  (MarkerType.chapter, 'Chapter', Color(0xFF6C63FF), Icons.bookmark_rounded),
  (MarkerType.comment, 'Comment', Color(0xFF26C6DA), Icons.comment_rounded),
  (MarkerType.todo, 'To-Do', Color(0xFFFF7043), Icons.check_circle_outline_rounded),
  (MarkerType.sync, 'Sync', Color(0xFF66BB6A), Icons.sync_rounded),
];

class MarkersPanel extends ConsumerStatefulWidget {
  const MarkersPanel({super.key});

  @override
  ConsumerState<MarkersPanel> createState() => _MarkersPanelState();
}

class _MarkersPanelState extends ConsumerState<MarkersPanel> {
  MarkerType _selectedType = MarkerType.chapter;
  final _labelCtrl = TextEditingController();

  @override
  void dispose() {
    _labelCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(timelineNotifierProvider);
    final markers = state.project?.markers ?? [];
    final sortedMarkers = List<TimelineMarker>.from(markers)
      ..sort((a, b) => a.positionSeconds.compareTo(b.positionSeconds));

    return Column(
      children: [
        _buildAddSection(state),
        _buildNavigationBar(),
        const Divider(height: 1, color: Color(0xFF252540)),
        Expanded(child: _buildMarkersList(sortedMarkers)),
      ],
    );
  }

  Widget _buildAddSection(TimelineState state) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _SectionLabel('Add Marker'),
              const Spacer(),
              Text(
                _formatTime(state.playback.positionSeconds),
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: Color(0xFF6B6B88)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: _markerColors.map((m) {
              final isActive = _selectedType == m.$1;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedType = m.$1),
                  child: Container(
                    height: 32,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: isActive ? m.$3.withValues(alpha: 0.2) : const Color(0xFF1A1A34),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isActive ? m.$3 : const Color(0xFF303050),
                      ),
                    ),
                    child: Tooltip(
                      message: m.$2,
                      child: Icon(m.$4, size: 16, color: isActive ? m.$3 : const Color(0xFF6B6B88)),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _labelCtrl,
                  style: const TextStyle(fontSize: 14, color: Color(0xFFE0E0F0)),
                  decoration: InputDecoration(
                    hintText: 'Marker label (optional)',
                    hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF6B6B88)),
                    filled: true,
                    fillColor: const Color(0xFF1A1A34),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: Color(0xFF303050)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                height: 34,
                child: FilledButton.icon(
                  onPressed: _addMarker,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add', style: TextStyle(fontSize: 13)),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationBar() {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF14142B),
        border: Border(
          top: BorderSide(color: Color(0xFF252540)),
          bottom: BorderSide(color: Color(0xFF252540)),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.skip_previous_rounded, size: 18),
            color: const Color(0xFFB0B0C8),
            onPressed: () => ref.read(timelineNotifierProvider.notifier).navigateToPreviousMarker(),
            tooltip: 'Previous marker',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
          IconButton(
            icon: const Icon(Icons.skip_next_rounded, size: 18),
            color: const Color(0xFFB0B0C8),
            onPressed: () => ref.read(timelineNotifierProvider.notifier).navigateToNextMarker(),
            tooltip: 'Next marker',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
          const Spacer(),
          Text(
            '${ref.watch(timelineNotifierProvider).project?.markers.length ?? 0} markers',
            style: const TextStyle(fontSize: 12, color: Color(0xFF6B6B88)),
          ),
        ],
      ),
    );
  }

  Widget _buildMarkersList(List<TimelineMarker> markers) {
    if (markers.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bookmark_border_rounded, size: 38, color: Color(0xFF404060)),
              SizedBox(height: 8),
              Text('No markers yet', style: TextStyle(fontSize: 14, color: Color(0xFF6B6B88))),
              SizedBox(height: 4),
              Text('Add markers to annotate your timeline',
                style: TextStyle(fontSize: 12, color: Color(0xFF505070)),
                textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: markers.length,
      itemBuilder: (context, index) => _buildMarkerTile(markers[index]),
    );
  }

  Widget _buildMarkerTile(TimelineMarker marker) {
    final markerInfo = _markerColors.firstWhere((m) => m.$1 == marker.type);
    final color = markerInfo.$3;
    final icon = markerInfo.$4;
    final typeName = markerInfo.$2;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => ref.read(timelineNotifierProvider.notifier).navigateToMarker(marker.id),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFF1E1E38), width: 0.5)),
          ),
          child: Row(
            children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      marker.label.isNotEmpty ? marker.label : typeName,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFFE0E0F0)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${_formatTime(marker.positionSeconds)}  •  $typeName',
                      style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.7)),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 16),
                color: const Color(0xFF6B6B88),
                onPressed: () => _editMarker(marker),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 16),
                color: const Color(0xFF6B6B88),
                onPressed: () => ref.read(timelineNotifierProvider.notifier).removeMarker(marker.id),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _addMarker() {
    ref.read(timelineNotifierProvider.notifier).addMarker(
      type: _selectedType,
      label: _labelCtrl.text.trim(),
    );
    _labelCtrl.clear();
  }

  void _editMarker(TimelineMarker marker) {
    final editCtrl = TextEditingController(text: marker.label);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A34),
        title: const Text('Edit Marker', style: TextStyle(fontSize: 15, color: Color(0xFFE0E0F0))),
        content: TextField(
          controller: editCtrl,
          style: const TextStyle(fontSize: 15, color: Color(0xFFE0E0F0)),
          decoration: InputDecoration(
            hintText: 'Marker label',
            filled: true,
            fillColor: const Color(0xFF12122A),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: Color(0xFF303050)),
            ),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () { editCtrl.dispose(); Navigator.pop(ctx); },
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(timelineNotifierProvider.notifier).updateMarker(marker.id, label: editCtrl.text.trim());
              editCtrl.dispose();
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  String _formatTime(double s) {
    final m = (s / 60).floor();
    final sec = (s % 60).floor();
    final ms = ((s % 1) * 100).floor();
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}.${ms.toString().padLeft(2, '0')}';
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(
      fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF8888A0), letterSpacing: 0.8,
    ));
  }
}
