enum SignUpOutcome {
  /// The account is active and a session started.
  signedIn,

  /// The project requires email confirmation; no session until the user
  /// follows the emailed link and signs in.
  needsEmailConfirmation,
}
