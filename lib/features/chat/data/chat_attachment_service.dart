import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

/// What kind of thing is hanging off a message.
enum AttachmentKind { image, file }

/// A file the builder picked, already reduced and ready to upload.
class PickedAttachment {
  final File file;
  final String name;
  final AttachmentKind kind;

  /// Bytes on disk after any downscaling, used to reject oversized documents
  /// before a slow upload starts rather than after.
  final int sizeBytes;

  const PickedAttachment({
    required this.file,
    required this.name,
    required this.kind,
    required this.sizeBytes,
  });
}

/// An uploaded attachment, as stored on the message document.
class UploadedAttachment {
  final String url;
  final String name;
  final AttachmentKind kind;
  final int sizeBytes;

  const UploadedAttachment({
    required this.url,
    required this.name,
    required this.kind,
    required this.sizeBytes,
  });

  Map<String, dynamic> toMap() => {
        'url': url,
        'name': name,
        'kind': kind == AttachmentKind.image ? 'image' : 'file',
        'sizeBytes': sizeBytes,
      };
}

/// Picks and uploads chat attachments.
///
/// Photos are the common case on a site: a builder shows the shop a wall, a
/// delivery, a damaged bag. A phone camera image is several megabytes, which is
/// slow to send on mobile data and slow to load for the shop every time the
/// thread opens. So images are downscaled and re-encoded at pick time rather
/// than uploaded raw, and displayed through a disk cache so each one is
/// fetched once per device.
///
/// Documents are uploaded as they are, since a receipt or a plan cannot be
/// re-encoded without losing the thing that made it worth sending.
class ChatAttachmentService {
  ChatAttachmentService({
    FirebaseStorage? storage,
    FirebaseAuth? auth,
    ImagePicker? picker,
  })  : _storage = storage ?? FirebaseStorage.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _picker = picker ?? ImagePicker();

  final FirebaseStorage _storage;
  final FirebaseAuth _auth;
  final ImagePicker _picker;

  /// Longest edge kept on an uploaded photo. Comfortably past what a phone
  /// screen shows, and far below what a modern camera produces.
  static const double maxImageEdge = 1600;

  /// JPEG quality. 80 is the usual point where further loss starts showing on
  /// photographs of materials.
  static const int imageQuality = 80;

  /// Hard ceiling on any single attachment, so one file cannot stall a thread
  /// or run up someone's data.
  static const int maxBytes = 10 * 1024 * 1024;

  /// Documents the shop can actually open. Anything else is refused at pick
  /// time with a reason, rather than uploaded and left unopenable.
  static const List<String> allowedFileExtensions = [
    'pdf', 'doc', 'docx', 'xls', 'xlsx', 'csv', 'txt',
  ];

  /// Takes a photo or picks one from the gallery, downscaled on the way in.
  ///
  /// The resizing happens inside image_picker, so the large original is never
  /// loaded into memory here.
  Future<PickedAttachment?> pickImage({required bool fromCamera}) async {
    final shot = await _picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: maxImageEdge,
      maxHeight: maxImageEdge,
      imageQuality: imageQuality,
    );
    if (shot == null) return null;

    final file = File(shot.path);
    final size = await file.length();
    return PickedAttachment(
      file: file,
      name: shot.name,
      kind: AttachmentKind.image,
      sizeBytes: size,
    );
  }

  /// Picks a document.
  ///
  /// Returns null when the builder backs out. Throws with a readable reason
  /// when the file is too large, so the caller can show it directly.
  Future<PickedAttachment?> pickFile() async {
    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: allowedFileExtensions,
    );
    if (picked == null) return null;

    // On some platforms a picked file is content-backed rather than a real
    // path, so there is nothing to hand to putFile.
    final path = picked.path;
    if (path == null) {
      throw const ChatAttachmentException(
        'That file could not be read from its location. '
        'Copy it into your device storage and try again.',
      );
    }

    final size = await picked.length();
    if (size > maxBytes) {
      throw ChatAttachmentException(
        'That file is ${_readableSize(size)}. '
        'Attachments have to be under ${_readableSize(maxBytes)}.',
      );
    }

    return PickedAttachment(
      file: File(path),
      name: picked.name,
      kind: AttachmentKind.file,
      sizeBytes: size,
    );
  }

  /// Uploads under the conversation so Storage rules can scope access to its
  /// two participants.
  Future<UploadedAttachment> upload({
    required String conversationId,
    required PickedAttachment picked,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw ChatAttachmentException('You have been signed out. Sign in again.');
    }
    if (picked.sizeBytes > maxBytes) {
      throw ChatAttachmentException(
        'That file is ${_readableSize(picked.sizeBytes)}. '
        'Attachments have to be under ${_readableSize(maxBytes)}.',
      );
    }

    final stamp = DateTime.now().millisecondsSinceEpoch;
    final safeName = _safeName(picked.name);
    final ref = _storage
        .ref()
        .child('chat_attachments')
        .child(conversationId)
        .child('${stamp}_$safeName');

    try {
      await ref.putFile(
        picked.file,
        SettableMetadata(
          contentType: _contentTypeFor(safeName, picked.kind),
          // Attachments never change once written, so both the app's disk
          // cache and any CDN in front of Storage can hold them indefinitely.
          cacheControl: 'public, max-age=31536000, immutable',
          customMetadata: {'uploadedBy': uid},
        ),
      );
      final url = await ref.getDownloadURL();
      return UploadedAttachment(
        url: url,
        name: picked.name,
        kind: picked.kind,
        sizeBytes: picked.sizeBytes,
      );
    } on FirebaseException catch (e) {
      debugPrint('Attachment upload failed: ${e.code} — ${e.message}');
      throw ChatAttachmentException(uploadFailureMessage(e.code));
    }
  }


  /// Turns a Cloud Storage error code into something worth reading.
  ///
  /// These are separated out because the failures have completely different
  /// fixes and lumping them together as "check your connection" sent people
  /// looking in the wrong place. `unauthorized` in particular means the
  /// Storage rules are missing or not deployed, which no amount of retrying
  /// will solve.
  static String uploadFailureMessage(String code) {
    return switch (code) {
      'unauthorized' || 'permission-denied' =>
        'The app is not allowed to upload attachments yet. Storage rules need '
            'to be deployed: run firebase deploy --only storage.',
      'unauthenticated' =>
        'You have been signed out. Sign in again and resend.',
      'object-not-found' || 'bucket-not-found' || 'project-not-found' =>
        'Cloud Storage is not set up for this project yet. Open Storage in the '
            'Firebase console once to create the bucket.',
      'quota-exceeded' =>
        'This project has run out of storage. Contact whoever manages the '
            'Firebase project.',
      'retry-limit-exceeded' =>
        'The upload kept timing out. Check your connection and try again.',
      'canceled' => 'That upload was cancelled.',
      _ => 'That attachment did not upload ($code). Try again, and send this '
          'code on if it keeps happening.',
    };
  }

  /// Storage object names travel in URLs, so anything awkward is flattened.
  static String _safeName(String name) {
    final cleaned = name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return cleaned.length <= 80 ? cleaned : cleaned.substring(cleaned.length - 80);
  }

  static String _contentTypeFor(String name, AttachmentKind kind) {
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    return switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      'heic' => 'image/heic',
      'pdf' => 'application/pdf',
      'csv' => 'text/csv',
      'txt' => 'text/plain',
      'doc' => 'application/msword',
      'docx' =>
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'xls' => 'application/vnd.ms-excel',
      'xlsx' =>
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      _ => kind == AttachmentKind.image ? 'image/jpeg' : 'application/octet-stream',
    };
  }

  static String _readableSize(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) return '${(bytes / 1024).round()} KB';
    return '$bytes B';
  }

  /// Public so the message bubble can label a file without duplicating this.
  static String readableSize(int bytes) => _readableSize(bytes);
}

/// An attachment problem worth showing the builder verbatim.
class ChatAttachmentException implements Exception {
  final String message;
  const ChatAttachmentException(this.message);

  @override
  String toString() => message;
}
