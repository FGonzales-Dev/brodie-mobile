import '../../../core/presentation/owned_rows_controller.dart';
import '../data/emergency_contact_repository.dart';

/// The rider's emergency contacts; shared by their screen, SOS and
/// onboarding.
final emergencyContactsControllerProvider = ownedRowsControllerProvider(emergencyContactRepositoryProvider);
