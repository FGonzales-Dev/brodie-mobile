import '../../../core/presentation/owned_rows_controller.dart';
import '../data/saved_place_repository.dart';

/// The rider's saved places, for the destination search screen.
final savedPlacesControllerProvider = ownedRowsControllerProvider(savedPlaceRepositoryProvider);
