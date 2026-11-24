/// Every route path in one place, so screens never hard-code strings.
abstract final class Routes {
  static const splash = '/';
  static const signIn = '/sign-in';
  static const signUp = '/sign-up';
  static const chooseUsername = '/choose-username';

  static const map = '/map';
  static const destinationSearch = '/map/search';
  static const soloRide = '/ride/solo';
  static const rideSummaryPattern = '/ride/summary/:rideId';
  static String rideSummary(String rideId) => '/ride/summary/$rideId';

  static const groups = '/groups';
  static const createGroup = '/groups/create';
  static const pendingInvites = '/groups/invites';
  static const joinWithCode = '/groups/join';

  /// Invite links (`https://<site>/join/<code>`) arrive on this path.
  static const joinPattern = '/join/:code';
  static String join(String code) => '/join/$code';
  static bool isJoinLink(String location) => location.startsWith('/join/');

  static const groupPattern = '/groups/:groupId';
  static String group(String groupId) => '/groups/$groupId';
  static const groupInvitePattern = '/groups/:groupId/invite';
  static String groupInvite(String groupId) => '/groups/$groupId/invite';
  static const groupRidePattern = '/groups/:groupId/ride';
  static String groupRide(String groupId) => '/groups/$groupId/ride';

  static const history = '/history';
  static const rideDetailPattern = '/history/:rideId';
  static String rideDetail(String rideId) => '/history/$rideId';

  static const profile = '/profile';
  static const vehicles = '/profile/vehicles';
  static const emergencyContacts = '/profile/emergency-contacts';
  static const settings = '/profile/settings';
  static const privacy = '/profile/privacy';
  static const terms = '/profile/terms';
  static const about = '/profile/about';
  static const usage = '/profile/usage';

  /// Reachable without a session.
  static const signedOut = {signIn, signUp};
}
