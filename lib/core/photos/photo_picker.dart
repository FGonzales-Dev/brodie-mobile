import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../design_system/design_system.dart';
import 'photo_storage.dart';

/// What the rider chose in [pickPhoto].
sealed class PhotoChoice {
  const PhotoChoice();
}

/// A photo ready to upload (see [preparePhoto]).
class PhotoPicked extends PhotoChoice {
  const PhotoPicked(this.jpeg);

  final Uint8List jpeg;
}

class PhotoRemoved extends PhotoChoice {
  const PhotoRemoved();
}

/// Asks where the photo comes from (camera or library, plus Remove when
/// there is one), then returns it prepared for upload. Null when the rider
/// backs out.
Future<PhotoChoice?> pickPhoto(
  BuildContext context, {
  required String title,
  required PhotoBucket bucket,
  required bool canRemove,
}) async {
  final source = await showModalBottomSheet<_Source>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(BrodieSpace.md, 0, BrodieSpace.md, BrodieSpace.xs),
            child: Text(title.toUpperCase(), style: BrodieType.headline.copyWith(color: context.colors.textPrimary)),
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Take a photo'),
            onTap: () => Navigator.pop(context, _Source.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose from library'),
            onTap: () => Navigator.pop(context, _Source.library),
          ),
          if (canRemove)
            ListTile(
              leading: Icon(Icons.delete_outline, color: context.colors.danger),
              title: Text('Remove photo', style: TextStyle(color: context.colors.danger)),
              onTap: () => Navigator.pop(context, _Source.remove),
            ),
          const SizedBox(height: BrodieSpace.sm),
        ],
      ),
    ),
  );
  switch (source) {
    case null:
      return null;
    case _Source.remove:
      return const PhotoRemoved();
    case _Source.camera || _Source.library:
      final file = await ImagePicker().pickImage(
        source: source == _Source.camera ? ImageSource.camera : ImageSource.gallery,
        // A first pass on the device keeps huge camera files out of memory;
        // preparePhoto does the final size and strips the metadata.
        maxWidth: bucket.maxSide * 2,
        maxHeight: bucket.maxSide * 2,
        imageQuality: 90,
        // The system photo picker needs no library permission this way.
        requestFullMetadata: false,
      );
      if (file == null) return null;
      return PhotoPicked(await preparePhoto(await file.readAsBytes(), maxSide: bucket.maxSide));
  }
}

enum _Source { camera, library, remove }
