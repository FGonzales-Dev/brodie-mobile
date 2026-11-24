import '../../../core/presentation/owned_rows_controller.dart';
import '../data/vehicle_repository.dart';

/// The rider's vehicles; shared by the Vehicles screen, ride history and
/// onboarding.
final vehiclesControllerProvider = ownedRowsControllerProvider(vehicleRepositoryProvider);
