import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../config/env.dart';
import '../di/core_providers.dart';
import '../errors/app_failure.dart';
import '../errors/guard_remote.dart';

part 'photo_storage.g.dart';

/// The Storage buckets photos go in (see the photos migration in
/// brodie-supabase). Both are public: a photo's random file name is what
/// keeps it from being found.
enum PhotoBucket {
  avatars('avatars', maxSide: 512),
  vehicles('vehicle-photos', maxSide: 1280);

  const PhotoBucket(this.id, {required this.maxSide});

  final String id;

  /// Photos are scaled down so their longest side is at most this.
  final int maxSide;
}

/// Turns a photo picked from the camera or library into what gets uploaded:
/// upright, no larger than [maxSide], a JPEG, and with all metadata removed.
/// Phone photos usually carry the GPS position they were taken at, which
/// would otherwise publish where a rider lives. Runs off the UI thread.
Future<Uint8List> preparePhoto(Uint8List original, {required int maxSide}) => compute(_prepare, (original, maxSide));

Uint8List _prepare((Uint8List, int) args) {
  final (original, maxSide) = args;
  final decoded = img.decodeImage(original);
  if (decoded == null) throw const ValidationFailure("That photo couldn't be read. Try a different one.");
  var image = img.bakeOrientation(decoded);
  if (image.width > maxSide || image.height > maxSide) {
    image = image.width >= image.height
        ? img.copyResize(image, width: maxSide, interpolation: img.Interpolation.average)
        : img.copyResize(image, height: maxSide, interpolation: img.Interpolation.average);
  }
  // The encoder writes out whatever metadata the image still carries.
  image.exif = img.ExifData();
  return img.encodeJpg(image, quality: 82);
}

/// Uploads, links to and deletes the signed-in rider's photos. Files go in
/// the rider's own folder, `<user id>/<random id>.jpg`; the database keeps
/// that path, and [PhotoUrls] turns it into a link.
class PhotoStorage {
  PhotoStorage(this._client);

  final SupabaseClient _client;

  String get _userId => _client.auth.currentUser?.id ?? (throw const UnauthenticatedFailure());

  /// Returns the new file's path. A new name every time, so a replaced photo
  /// never shows stale from a cache.
  Future<String> upload(PhotoBucket bucket, Uint8List jpeg) => guardRemote(() async {
    final path = '$_userId/${const Uuid().v4()}.jpg';
    await _client.storage
        .from(bucket.id)
        .uploadBinary(
          path,
          jpeg,
          fileOptions: const FileOptions(contentType: 'image/jpeg', cacheControl: '31536000'),
        );
    return path;
  });

  /// Uploads [jpeg], points its owner at it with [save], then deletes the
  /// photo it [replaces]. If saving fails, the new upload is deleted again,
  /// so nothing is left pointing at a missing file or orphaned.
  Future<void> replace(
    PhotoBucket bucket,
    Uint8List jpeg, {
    required Future<void> Function(String path) save,
    String? replaces,
  }) async {
    final path = await upload(bucket, jpeg);
    try {
      await save(path);
    } catch (_) {
      await delete(bucket, path);
      rethrow;
    }
    if (replaces != null) await delete(bucket, replaces);
  }

  /// Unlinks the photo at [path] with [clear], then deletes the file.
  Future<void> remove(PhotoBucket bucket, String path, {required Future<void> Function() clear}) async {
    await clear();
    await delete(bucket, path);
  }

  /// Best effort: a file left behind costs a little storage, nothing more.
  Future<void> delete(PhotoBucket bucket, String path) async {
    try {
      await _client.storage.from(bucket.id).remove([path]);
    } catch (_) {}
  }

  /// Every photo the rider has uploaded, e.g. before deleting their account.
  Future<void> deleteAllMine() async {
    final userId = _userId;
    for (final bucket in PhotoBucket.values) {
      try {
        final files = await _client.storage.from(bucket.id).list(path: userId);
        if (files.isEmpty) continue;
        await _client.storage.from(bucket.id).remove([for (final file in files) '$userId/${file.name}']);
      } catch (_) {}
    }
  }
}

@Riverpod(keepAlive: true)
PhotoStorage photoStorage(Ref ref) => PhotoStorage(ref.watch(supabaseClientProvider));

/// Public links for stored photos. Building one needs no network call.
class PhotoUrls {
  const PhotoUrls(this._baseUrl);

  final String _baseUrl;

  String? avatar(String? path) => _url(PhotoBucket.avatars, path);

  String? vehicle(String? path) => _url(PhotoBucket.vehicles, path);

  String? _url(PhotoBucket bucket, String? path) {
    if (path == null || path.isEmpty) return null;
    final encoded = path.split('/').map(Uri.encodeComponent).join('/');
    return '$_baseUrl/storage/v1/object/public/${bucket.id}/$encoded';
  }
}

@Riverpod(keepAlive: true)
PhotoUrls photoUrls(Ref ref) => PhotoUrls(Env.supabaseUrl);
