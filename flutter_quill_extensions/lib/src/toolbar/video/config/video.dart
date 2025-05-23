import 'package:flutter/widgets.dart' show BuildContext;
import 'package:flutter_quill/flutter_quill.dart';
import 'package:meta/meta.dart' show immutable;

/// When request picking an video, for example when the video button toolbar
/// clicked, it should be null in case the user didn't choose any video or
/// any other reasons, and it should be the video file path as string that is
/// exists in case the user picked the video successfully
///
/// by default we already have a default implementation that show a dialog
/// request the source for picking the video, from gallery, link or camera
typedef OnRequestPickVideo = Future<String?> Function(
  BuildContext context,
);

/// A callback will called when inserting a video in the editor
/// it have the logic that will insert the video block using the controller
typedef OnVideoInsertCallback = Future<void> Function(
  String video,
  QuillController controller,
);

/// When a new video picked this callback will called and you might want to
/// do some logic depending on your use case
typedef OnVideoInsertedCallback = Future<void> Function(
  String video,
);

enum InsertVideoSource {
  gallery,
  camera,
  link,
}

/// Configurations for dealing with videos, on insert a video
/// on request picking a video
@immutable
class QuillToolbarVideoConfig {
  const QuillToolbarVideoConfig({
    this.onRequestPickVideo,
    this.onVideoInsertedCallback,
    this.onVideoInsertCallback,
  });

  final OnRequestPickVideo? onRequestPickVideo;

  final OnVideoInsertedCallback? onVideoInsertedCallback;

  final OnVideoInsertCallback? onVideoInsertCallback;
}
