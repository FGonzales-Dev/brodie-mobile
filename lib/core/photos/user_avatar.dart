import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design_system/design_system.dart';
import 'photo_storage.dart';

/// [BrodieAvatar] for a rider, showing their profile picture when they
/// have one.
class UserAvatar extends ConsumerWidget {
  const UserAvatar({super.key, required this.name, this.avatarPath, this.size = 36, this.highlighted = false});

  final String name;
  final String? avatarPath;
  final double size;
  final bool highlighted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BrodieAvatar(
      name: name,
      size: size,
      highlighted: highlighted,
      imageUrl: ref.watch(photoUrlsProvider).avatar(avatarPath),
    );
  }
}
