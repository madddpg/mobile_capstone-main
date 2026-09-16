import 'package:cloud_firestore/cloud_firestore.dart';

/// What happened when a screen tried to open a posted estimate.
///
/// The estimate screens used to show one message for every failure, which hid
/// the difference that decides what the builder can do about it. Being offline
/// is fixed by trying again. A post that was deleted, or rewritten so it no
/// longer belongs to this account, will never load, and retrying only repeats
/// the error; the builder needs a way to detach it from their saved project.
///
/// A builder cannot tell those last two apart. Reading a post that no longer
/// exists fails the ownership rule rather than coming back empty, because the
/// rule checks the owner on a document that is not there. So a deleted post
/// and someone else's post both arrive as permission-denied.
enum PostLoadOutcome { loaded, offline, unavailable, failed }

/// The Firestore error code carried by a stream or read error, if any.
String? firestoreErrorCode(Object? error) =>
    error is FirebaseException ? error.code : null;

/// Sorts a post read into the outcome that decides what the screen offers.
///
/// Anything not recognised is [PostLoadOutcome.failed], which offers a retry
/// rather than an unlink. Unlinking changes the builder's saved project, so it
/// is only offered when the post is known to be unreadable.
PostLoadOutcome classifyPostLoad({
  required bool hasError,
  String? errorCode,
  required bool exists,
}) {
  if (hasError) {
    switch (errorCode) {
      case 'unavailable':
      case 'deadline-exceeded':
      case 'network-request-failed':
        return PostLoadOutcome.offline;
      case 'permission-denied':
      case 'not-found':
        return PostLoadOutcome.unavailable;
      default:
        return PostLoadOutcome.failed;
    }
  }
  return exists ? PostLoadOutcome.loaded : PostLoadOutcome.unavailable;
}
