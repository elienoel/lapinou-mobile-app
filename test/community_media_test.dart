import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lapinou/models/community_post.dart';
import 'package:lapinou/widgets/post_media.dart';
import 'package:lapinou/widgets/reaction_picker.dart';

List<PostMedia> _images(int n) => List.generate(
  n,
  (i) => PostMedia(
    id: i,
    type: PostMediaType.image,
    url: 'http://localhost:8000/media/p$i.jpg',
  ),
);

Future<int?> _pumpGrid(WidgetTester tester, List<PostMedia> media) async {
  int? opened;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 400,
          child: PostMediaGrid(media: media, onOpen: (i) => opened = i),
        ),
      ),
    ),
  );
  await tester.pump();
  return opened;
}

void main() {
  reactionTests();
  test('CommunityPost parses media list, optional title and relative urls', () {
    final post = CommunityPost.fromJson({
      'id': 7,
      'author': 3,
      'author_name': 'Ferme du Lac',
      'content': 'Portée du jour',
      'media': [
        {'id': 1, 'media_type': 'image', 'url': '/media/a.jpg', 'position': 0},
        {
          'id': 2,
          'media_type': 'video',
          'url': 'http://h/media/b.mp4',
          'position': 1,
        },
      ],
      'created_at': '2026-09-25T10:00:00Z',
    });

    expect(post.title, isEmpty);
    expect(post.media.length, 2);
    expect(post.media[0].isVideo, isFalse);
    expect(post.media[0].url, endsWith('/media/a.jpg'));
    expect(post.media[0].url, startsWith('http'));
    expect(post.media[1].isVideo, isTrue);

    // Anciennes réponses sans champ media
    final legacy = CommunityPost.fromJson({
      'id': 1,
      'title': 'Vieux post',
      'content': 'x',
      'created_at': '2026-01-01T10:00:00Z',
    });
    expect(legacy.media, isEmpty);
  });

  testWidgets('media grid shows every tile up to 4 and a +N counter beyond', (
    tester,
  ) async {
    for (final n in [1, 2, 3, 4]) {
      await _pumpGrid(tester, _images(n));
      expect(find.byType(Image), findsNWidgets(n), reason: '$n médias');
      expect(find.textContaining('+'), findsNothing);
    }

    await _pumpGrid(tester, _images(7));
    expect(find.byType(Image), findsNWidgets(4));
    expect(find.text('+3'), findsOneWidget);
  });

  testWidgets('tapping a tile opens that media index', (tester) async {
    int? opened;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            child: PostMediaGrid(media: _images(3), onOpen: (i) => opened = i),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byType(Image).at(2));
    expect(opened, 2);
  });

  testWidgets('video tiles in a grid show a play icon without loading video', (
    tester,
  ) async {
    final media = [
      ..._images(1),
      const PostMedia(id: 9, type: PostMediaType.video, url: 'http://h/v.mp4'),
    ];
    await _pumpGrid(tester, media);
    expect(find.byType(Image), findsOneWidget);
    expect(find.byIcon(Icons.play_circle_fill_rounded), findsOneWidget);
  });
}

void reactionTests() {
  group('reactions', () {
    test('applyReactionChange adds, replaces and removes a reaction', () {
      var list = <ReactionCount>[];
      list = applyReactionChange(list, null, '❤️');
      expect(list.map((r) => '${r.emoji}${r.count}'), ['❤️1']);

      list = applyReactionChange(list, null, '👍');
      list = applyReactionChange(list, null, '👍');
      expect(list.first.emoji, '👍'); // le plus fréquent en premier
      expect(list.first.count, 2);

      // remplacement : ❤️ -> 😂
      list = applyReactionChange(list, '❤️', '😂');
      expect(list.any((r) => r.emoji == '❤️'), isFalse);
      expect(list.firstWhere((r) => r.emoji == '😂').count, 1);

      // retrait
      list = applyReactionChange(list, '😂', null);
      expect(list.map((r) => r.emoji), ['👍']);
    });

    test('post and comment parse reactions, replies and my reaction', () {
      final post = CommunityPost.fromJson({
        'id': 1,
        'content': 'x',
        'likes_count': 3,
        'my_reaction': '😮',
        'reactions': [
          {'emoji': '😮', 'count': 2},
          {'emoji': '❤️', 'count': 1},
        ],
        'created_at': '2026-09-25T10:00:00Z',
      });
      expect(post.isLiked, isTrue);
      expect(post.myReaction, '😮');
      expect(post.reactions.length, 2);

      final reply = PostComment.fromJson({
        'id': 5,
        'post': 1,
        'parent': 4,
        'author_name': 'Awa',
        'content': 'Merci',
        'likes_count': 1,
        'my_reaction': null,
        'reactions': [
          {'emoji': '👍', 'count': 1},
        ],
        'created_at': '2026-09-25T10:00:00Z',
      });
      expect(reply.isReply, isTrue);
      expect(reply.parentId, 4);
      expect(reply.myReaction, isNull);
      expect(reply.likesCount, 1);

      final root = PostComment.fromJson({
        'id': 4,
        'post': 1,
        'content': 'Bravo',
        'created_at': '2026-09-25T10:00:00Z',
      });
      expect(root.isReply, isFalse);
    });
  });

  testWidgets('long press opens the emoji bar and returns the choice', (
    tester,
  ) async {
    String? tapped;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ReactionTrigger(
              myReaction: null,
              onReact: (e) => tapped = e,
              child: const Padding(
                padding: EdgeInsets.all(20),
                child: Text("J'aime"),
              ),
            ),
          ),
        ),
      ),
    );

    // appui simple = réaction rapide ❤️
    await tester.tap(find.text("J'aime"));
    expect(tapped, kDefaultReaction);

    // appui long = barre d'emojis
    tapped = null;
    await tester.longPress(find.text("J'aime"));
    await tester.pumpAndSettle();
    for (final e in kReactionEmojis) {
      expect(find.text(e), findsOneWidget);
    }
    await tester.tap(find.text('😂'));
    await tester.pumpAndSettle();
    expect(tapped, '😂');
    expect(find.text('😂'), findsNothing); // barre refermée
  });
}
