import 'package:brodie/features/groups/domain/invite_links.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('builds the https invite link for a code', () {
    expect(InviteLinks.forCode('7A879D').toString(), 'https://${InviteLinks.host}/join/7A879D');
  });

  test('reads a typed code however it was written', () {
    expect(InviteLinks.codeFrom('7a879d'), '7A879D');
    expect(InviteLinks.codeFrom(' 7a8-79d '), '7A879D');
    expect(InviteLinks.codeFrom('7A8 79D'), '7A879D');
  });

  test('reads the code out of a pasted invite link', () {
    expect(InviteLinks.codeFrom('https://${InviteLinks.host}/join/7a879d'), '7A879D');
    expect(InviteLinks.codeFrom('Join us! https://${InviteLinks.host}/join/7A879D'), isNull,
        reason: 'only a bare link or code is accepted');
  });

  test('rejects things that are not invite codes or links', () {
    expect(InviteLinks.codeFrom(''), isNull);
    expect(InviteLinks.codeFrom('ab'), isNull);
    expect(InviteLinks.codeFrom('not a code!'), isNull);
    expect(InviteLinks.codeFrom('https://example.com/join/7A879D'), isNull, reason: 'someone else\'s site');
    expect(InviteLinks.codeFrom('https://${InviteLinks.host}/7A879D'), isNull, reason: 'not a join link');
  });
}
