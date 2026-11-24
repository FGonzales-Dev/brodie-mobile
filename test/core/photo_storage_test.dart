import 'package:brodie/core/design_system/design_system.dart';
import 'package:brodie/core/errors/app_failure.dart';
import 'package:brodie/core/photos/photo_storage.dart';
import 'package:brodie/features/profile/data/profile_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';

/// A camera-style JPEG: landscape pixels, an "rotate 90°" orientation tag,
/// and the GPS position it was taken at.
Uint8List _cameraPhoto() {
  final image = img.Image(width: 3000, height: 2000);
  img.fill(image, color: img.ColorRgb8(200, 90, 30));
  image.exif.imageIfd.orientation = 6;
  image.exif.gpsIfd.setGpsLocation(latitude: 14.1153, longitude: 120.9621);
  return img.encodeJpg(image, quality: 90);
}

/// Storage without a server: uploads get numbered paths, deletes are recorded.
class _FakeStorage extends PhotoStorage {
  _FakeStorage() : super(SupabaseClient('http://localhost', 'test-key'));

  final deleted = <String>[];
  var uploads = 0;

  @override
  Future<String> upload(PhotoBucket bucket, Uint8List jpeg) async => 'user-1/new-${++uploads}.jpg';

  @override
  Future<void> delete(PhotoBucket bucket, String path) async => deleted.add(path);
}

void main() {
  test('the sample photo really carries GPS, so the next test means something', () {
    final raw = img.decodeJpgExif(_cameraPhoto())!;
    expect(raw.gpsIfd.gpsLatitude, closeTo(14.1153, 1e-3));
    expect(raw.imageIfd.orientation, 6);
  });

  test('uploaded photos are upright, scaled down, and carry no location', () async {
    final prepared = await preparePhoto(_cameraPhoto(), maxSide: 512);
    final photo = img.decodeJpg(prepared)!;

    // Read straight from the file: decoding would hide an orientation tag.
    final metadata = img.decodeJpgExif(prepared);
    expect(metadata == null || metadata.isEmpty, isTrue, reason: 'no GPS or any other metadata');
    // Portrait after the rotation, longest side 512.
    expect(photo.height, 512);
    expect(photo.width, closeTo(341, 1));
  });

  test('small photos keep their size', () async {
    final small = img.encodeJpg(img.Image(width: 300, height: 200));
    final photo = img.decodeJpg(await preparePhoto(small, maxSide: 512))!;
    expect((photo.width, photo.height), (300, 200));
  });

  test("a file that isn't an image is refused with a clear message", () async {
    await expectLater(
      preparePhoto(Uint8List.fromList([1, 2, 3, 4]), maxSide: 512),
      throwsA(isA<ValidationFailure>()),
    );
  });

  test('links point at the public bucket, and nothing without a photo', () {
    const urls = PhotoUrls('https://abc.supabase.co');
    expect(urls.avatar('user-1/pic.jpg'), 'https://abc.supabase.co/storage/v1/object/public/avatars/user-1/pic.jpg');
    expect(urls.vehicle('user-1/bike.jpg'), 'https://abc.supabase.co/storage/v1/object/public/vehicle-photos/user-1/bike.jpg');
    expect(urls.avatar(null), isNull);
    expect(urls.avatar(''), isNull);
  });

  test('profiles read their picture path', () {
    final profile = ProfileRepository.profileFromRow({'id': 'u1', 'username': 'lea', 'avatar_path': 'u1/pic.jpg'});
    expect(profile.avatarPath, 'u1/pic.jpg');
  });

  testWidgets("an avatar whose picture can't load shows the initial", (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(body: BrodieAvatar(name: 'lea', imageUrl: 'https://example.invalid/pic.jpg')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('L'), findsOneWidget);
  });

  group('replacing and removing a photo', () {
    final jpeg = Uint8List.fromList([1, 2, 3]);

    test('the owner points at the new file, then the old one is deleted', () async {
      final storage = _FakeStorage();
      String? saved;
      await storage.replace(PhotoBucket.avatars, jpeg, save: (path) async => saved = path, replaces: 'user-1/old.jpg');
      expect(saved, 'user-1/new-1.jpg');
      expect(storage.deleted, ['user-1/old.jpg']);
    });

    test('if saving fails, the new upload is deleted and the old photo kept', () async {
      final storage = _FakeStorage();
      await expectLater(
        storage.replace(PhotoBucket.avatars, jpeg, save: (_) => Future.error(Exception('offline')), replaces: 'user-1/old.jpg'),
        throwsException,
      );
      expect(storage.deleted, ['user-1/new-1.jpg']);
    });

    test('removing unlinks first, then deletes the file', () async {
      final storage = _FakeStorage();
      final order = <String>[];
      await storage.remove(PhotoBucket.vehicles, 'user-1/bike.jpg', clear: () async => order.add('cleared'));
      order.addAll(storage.deleted);
      expect(order, ['cleared', 'user-1/bike.jpg']);
    });
  });
}
