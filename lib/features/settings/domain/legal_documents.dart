/// The privacy policy and terms shown in the app. Written to match what the
/// app actually does; when a feature changes what's collected or shared,
/// update the matching section here and [LegalDocument.updated].
library;

/// A titled document made of headed sections.
class LegalDocument {
  const LegalDocument({required this.title, required this.updated, required this.intro, required this.sections});

  final String title;

  /// Shown as "Last updated ...".
  final String updated;
  final String intro;
  final List<LegalSection> sections;
}

/// A heading with paragraphs. A paragraph starting with "• " is shown as a
/// bullet point.
class LegalSection {
  const LegalSection(this.heading, this.paragraphs);

  final String heading;
  final List<String> paragraphs;
}

const privacyPolicy = LegalDocument(
  title: 'Privacy policy',
  updated: 'November 26, 2026',
  intro: 'Brodie is an app for riding with a group. This explains what it stores about you, who can see it, '
      'and how to delete it. In short: your location is only shared with the riders on a group ride while '
      "that ride is on, it isn't stored, and nothing about you is sold or used for ads.",
  sections: [
    LegalSection('What Brodie stores', [
      '• Your account: email address and password. The password is stored only as a secure hash by our '
          'login provider; nobody can read it.',
      '• Your profile: username and, if you add one, a profile picture.',
      '• Your vehicles: type, name and, if you add one, a photo.',
      '• Your emergency contacts: name, phone number and relationship, if you add them.',
      '• Your rides: for each ride you finish, the route you rode, distance, times, top speed, which '
          'vehicle you used, and which group ride it was part of.',
      '• Your groups: the groups you belong to, invites, and the group rides you joined.',
      '• Daily counters: how many route and place searches you used today (to keep within our limits), '
          'and how many wrong invite codes you entered today (to stop codes being guessed).',
    ]),
    LegalSection('Your location', [
      'Brodie uses your location only while you use it: to show you on the map, plan routes and follow '
          'your ride. It never asks for "always" access.',
      'During a group ride, your live position is sent to the other riders on that ride, also while your '
          'screen is locked, until the ride ends or you leave it. These live positions pass through our '
          "server but aren't saved.",
      'What is saved is your own ride when it ends (see above), so it can appear in your history.',
    ]),
    LegalSection('Who can see what', [
      '• Other riders can find you by your username, or by your exact email address. A search by email '
          'shows them your username, never your email.',
      '• Members of a group see each other\'s usernames and profile pictures.',
      '• Riders on a group ride see each other\'s live positions during the ride, and any SOS you send, '
          'with your location, until you say you\'re safe.',
      '• After a group ride, its members see each rider\'s totals: distance, moving time, top speed and '
          'whether they arrived. They never see your route.',
      '• Profile and vehicle photos are stored at a long, random web address. Anyone who has that exact '
          'address could open the photo, but it can\'t be guessed or searched for.',
      'Everything else (your email, rides, vehicles, emergency contacts) is visible only to you.',
    ]),
    LegalSection('Photos', [
      'Before a photo is uploaded, Brodie shrinks it and removes all the extra information phones store in '
          'photos, including the place it was taken.',
    ]),
    LegalSection('SOS', [
      "When you send an SOS, your phone's messages app opens with a text to your emergency contacts that "
          'includes your location. It is sent only if you tap Send, from your own phone. Brodie never '
          'contacts your emergency contacts by itself.',
    ]),
    LegalSection('Services Brodie relies on', [
      '• Supabase stores your account and data and runs Brodie\'s server, in its Tokyo (Japan) region.',
      '• Mapbox provides the maps, place search and routes. Searches and route requests go through '
          "Brodie's server, so Mapbox receives what you searched for and the route's points, but not who you "
          'are. The map itself loads directly from Mapbox, so Mapbox sees your phone\'s internet address and '
          "the area of the map you're viewing. Mapbox's map software may also send it anonymous usage data.",
      'Neither may use your data for anything but providing their service to Brodie.',
    ]),
    LegalSection('Kept on your phone only', [
      'Your settings, recently searched places, your last known position (to open the map quickly), and '
          'rides waiting to upload are stored on your phone and never leave it except as described above.',
    ]),
    LegalSection('Deleting your data', [
      'You can delete any ride, vehicle, emergency contact or photo yourself at any time.',
      'Profile → Delete account permanently deletes your account, profile, photos, vehicles, emergency '
          'contacts, rides and group memberships. Groups you lead are deleted too.',
    ]),
    LegalSection('What Brodie never does', [
      'Brodie shows no ads, doesn\'t sell or rent your data, and doesn\'t use third-party analytics or '
          'tracking.',
    ]),
    LegalSection('Children', [
      'Brodie is not meant for children under 13.',
    ]),
    LegalSection('Changes and questions', [
      'If this policy changes, the new version will appear here with a new date. For questions about your '
          'data, contact the person who runs Brodie for your group.',
    ]),
  ],
);

const termsOfUse = LegalDocument(
  title: 'Terms',
  updated: 'November 26, 2026',
  intro: 'These terms cover using Brodie. By using it, you agree to them.',
  sections: [
    LegalSection('Ride safely', [
      "Don't handle your phone while riding. Set your route before you set off, and stop somewhere safe if "
          'you need to use the app.',
      'Follow traffic laws and road signs. Brodie\'s routes and turn instructions can be wrong or out of '
          'date; the road in front of you always comes first.',
    ]),
    LegalSection('SOS and location are not guaranteed', [
      "Brodie's SOS is a convenience, not an emergency service. It depends on your phone, its battery, GPS "
          'and signal, and on you tapping Send in your messages app. In an emergency, call your local '
          'emergency number.',
      'Live positions, "fell behind" alerts and GPS readings can be late, inaccurate or missing. Don\'t rely '
          'on them to know that someone is safe.',
    ]),
    LegalSection('Your account', [
      'Keep your password to yourself; you are responsible for what happens on your account. Pick a '
          "username that isn't offensive and doesn't pretend to be someone else.",
    ]),
    LegalSection('Groups and rides', [
      'A group leader plans and ends rides for the group and can reset its invite code. Anyone with a '
          "group's invite code or link can join it, so share them only with people you want to ride with.",
      'Only invite people who agreed to be invited, and only add emergency contacts who are happy to be '
          'contacted.',
    ]),
    LegalSection('Fair use', [
      "Don't use Brodie to track people who haven't agreed to it, to harass anyone, or to break the law. "
          "Don't try to get around its limits or access other riders' data.",
      'Route and place searches have daily limits, because the services behind them charge per use.',
    ]),
    LegalSection('No warranty', [
      'Brodie is provided as it is, without any promise that it will always be available, accurate or free '
          'of errors. As far as the law allows, the people who run Brodie are not responsible for losses or '
          'injuries that come from using it.',
    ]),
    LegalSection('Ending', [
      'You can stop using Brodie and delete your account at any time from your profile. An account that '
          'breaks these terms may be removed.',
    ]),
    LegalSection('Changes', [
      'If these terms change, the new version will appear here with a new date.',
    ]),
  ],
);
