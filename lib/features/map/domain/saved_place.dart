import 'package:freezed_annotation/freezed_annotation.dart';

import 'map_models.dart';

part 'saved_place.freezed.dart';

/// A place the rider saved to pick again without searching.
@freezed
abstract class SavedPlace with _$SavedPlace {
  const factory SavedPlace({required String id, required Place place}) = _SavedPlace;
}
