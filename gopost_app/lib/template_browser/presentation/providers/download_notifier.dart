import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gopost_app/core/error/failures.dart';
import 'package:gopost_app/rendering_bridge/engine_api.dart';
import 'package:gopost_app/rendering_bridge/template_bridge.dart';
import 'package:gopost_app/template_browser/domain/entities/template_access.dart';
import 'package:gopost_app/template_browser/domain/repositories/template_repository.dart';
import 'package:gopost_app/template_browser/domain/usecases/request_template_access_usecase.dart';

enum DownloadStatus { idle, requestingAccess, downloading, loadingInEngine, complete, error }

class DownloadState {
  final DownloadStatus status;
  final double progress;
  final String? error;
  final TemplateAccess? access;
  final String? localPath;
  final TemplateMetadata? loadedMetadata;

  const DownloadState({
    this.status = DownloadStatus.idle,
    this.progress = 0,
    this.error,
    this.access,
    this.localPath,
    this.loadedMetadata,
  });

  DownloadState copyWith({
    DownloadStatus? status,
    double? progress,
    String? error,
    TemplateAccess? access,
    String? localPath,
    TemplateMetadata? loadedMetadata,
    bool clearError = false,
  }) {
    return DownloadState(
      status: status ?? this.status,
      progress: progress ?? this.progress,
      error: clearError ? null : (error ?? this.error),
      access: access ?? this.access,
      localPath: localPath ?? this.localPath,
      loadedMetadata: loadedMetadata ?? this.loadedMetadata,
    );
  }
}

/// SRP: Manages the encrypted template download lifecycle:
/// request access -> download from CDN -> load in native engine (decrypt + parse).
class DownloadNotifier extends StateNotifier<DownloadState> {
  final RequestTemplateAccessUseCase _requestAccess;
  final TemplateAccessRepository _accessRepo;
  final TemplateBridge _templateBridge;

  DownloadNotifier({
    required RequestTemplateAccessUseCase requestAccess,
    required TemplateAccessRepository accessRepo,
    required TemplateBridge templateBridge,
  })  : _requestAccess = requestAccess,
        _accessRepo = accessRepo,
        _templateBridge = templateBridge,
        super(const DownloadState());

  Future<void> download(String templateId) async {
    state = state.copyWith(
      status: DownloadStatus.requestingAccess,
      progress: 0,
      clearError: true,
    );

    try {
      final access = await _requestAccess(templateId);
      state = state.copyWith(
        status: DownloadStatus.downloading,
        access: access,
      );

      final blob = await _accessRepo.downloadTemplateToBytes(
        url: access.signedUrl,
        onProgress: (received, total) {
          if (total > 0) {
            state = state.copyWith(progress: received / total);
          }
        },
      );

      state = state.copyWith(
        status: DownloadStatus.loadingInEngine,
        progress: 0.95,
      );

      final sessionKeyBytes = Uint8List.fromList(base64.decode(access.sessionKey));
      final metadata = await _templateBridge.loadEncryptedTemplate(
        encryptedBlob: blob,
        sessionKey: sessionKeyBytes,
      );

      state = state.copyWith(
        status: DownloadStatus.complete,
        progress: 1.0,
        loadedMetadata: metadata,
      );
    } on Failure catch (e) {
      state = state.copyWith(
        status: DownloadStatus.error,
        error: e.message,
      );
    } catch (e, st) {
      state = state.copyWith(
        status: DownloadStatus.error,
        error: e.toString(),
      );
    }
  }

  void reset() {
    state = const DownloadState();
  }
}
