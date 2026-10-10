import 'package:flutter_test/flutter_test.dart';
import 'package:lapinou/services/validators.dart';

void main() {
  test(
    'phone needs at least 8 digits once spaces and separators are removed',
    () {
      expect(Validators.phone('06 12 34'), isNotNull);
      expect(Validators.phone('+33 6 12 34 56 78'), isNull);
    },
  );

  test('a finance amount must be positive and at most 99 999 999,99', () {
    expect(Validators.amount(0), isNotNull);
    expect(Validators.amount(-5), isNotNull);
    expect(Validators.amount(99999999.99), isNull);
    expect(Validators.amount(100000000), isNotNull);
  });

  test(
    'a chat message needs text, a photo or an audio, and not both photo and audio',
    () {
      expect(Validators.chatMessage(text: '   '), isNotNull);
      expect(Validators.chatMessage(text: 'Bonjour'), isNull);
      expect(Validators.chatMessage(text: 'x' * 4001), isNotNull);
    },
  );

  test('a cage is 1-12 rows and 1-6 columns', () {
    expect(Validators.cageSize(rows: 0, columns: 1), isNotNull);
    expect(Validators.cageSize(rows: 13, columns: 1), isNotNull);
    expect(Validators.cageSize(rows: 3, columns: 7), isNotNull);
    expect(Validators.cageSize(rows: 12, columns: 6), isNull);
  });

  test('a post needs text or at least one media, and at most 10 media', () {
    expect(Validators.postContent(content: '  ', mediaCount: 0), isNotNull);
    expect(Validators.postContent(content: '', mediaCount: 1), isNull);
    expect(Validators.postMediaCount(11), isNotNull);
    expect(Validators.postMediaCount(10), isNull);
  });

  test('only the six known reactions are accepted', () {
    expect(Validators.reactionEmojis, hasLength(6));
    expect(Validators.reactionEmojis, contains('❤️'));
    expect(Validators.reactionEmojis, isNot(contains('🔥')));
  });
}
