import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:lapinou/models/chat.dart';
import 'package:lapinou/providers/chat_provider.dart';
import 'package:lapinou/screens/chat_screen.dart';
import 'package:lapinou/services/voice_services.dart';
import 'package:lapinou/widgets/voice_message_player.dart';
import 'support/chat_fakes.dart';

/// Faux micro : écrit un petit fichier et note ce qui lui est demandé.
class FakeRecorder implements VoiceRecorder {
  FakeRecorder({this.granted = true});

  final bool granted;
  final calls = <String>[];
  String? path;

  @override
  Future<bool> requestPermission() async => granted;

  @override
  Future<void> start(String p) async {
    calls.add('start');
    path = p;
    // Écriture synchrone : les E/S asynchrones ne progressent pas dans le temps simulé des tests
    File(p).writeAsBytesSync('fake audio bytes'.codeUnits);
  }

  @override
  Future<String?> stop() async {
    calls.add('stop');
    return path;
  }

  @override
  Future<void> cancel() async {
    calls.add('cancel');
    if (path != null && File(path!).existsSync()) File(path!).deleteSync();
  }

  @override
  Future<void> dispose() async => calls.add('dispose');
}

class FakePlayback implements VoicePlayback {
  final position = StreamController<Duration>.broadcast();
  final duration = StreamController<Duration>.broadcast();
  final playing = StreamController<bool>.broadcast();
  final complete = StreamController<void>.broadcast();
  final calls = <String>[];
  double speed = 1.0;

  @override
  Stream<Duration> get positionStream => position.stream;
  @override
  Stream<Duration> get durationStream => duration.stream;
  @override
  Stream<bool> get playingStream => playing.stream;
  @override
  Stream<void> get completeStream => complete.stream;

  @override
  Future<void> play() async {
    calls.add('play');
    playing.add(true);
  }

  @override
  Future<void> pause() async {
    calls.add('pause');
    playing.add(false);
  }

  @override
  Future<void> seek(Duration p) async => calls.add('seek ${p.inMilliseconds}');

  @override
  Future<void> setSpeed(double s) async {
    speed = s;
    calls.add('speed $s');
  }

  @override
  Future<void> dispose() async => calls.add('dispose');
}

/// La lecture du fichier à envoyer passe par de vraies E/S : on alterne temps réel et temps simulé.
Future<void> _letUploadFinish(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Finder get _mic => find.byIcon(Icons.mic_rounded);
Finder get _sendRecording => find.byTooltip('Envoyer la note vocale');

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr_FR', null);
  });

  final originalRecorder = VoiceServices.recorder;
  final originalPlayback = VoiceServices.playback;
  tearDown(() {
    VoiceServices.recorder = originalRecorder;
    VoiceServices.playback = originalPlayback;
  });

  group('models', () {
    test('voice message parses audio url and duration', () {
      final m = ChatMessage.fromJson({
        ...msgJson(5, 2, ''),
        'audio': '/media/chat/audio/a.m4a',
        'audio_duration_ms': 12500,
      });
      expect(m.hasAudio, isTrue);
      expect(m.audioUrl, startsWith('http'));
      expect(m.audioDurationMs, 12500);
      expect(m.hasImage, isFalse);
    });

    test('conversation preview shows a voice note label', () {
      final c = ChatConversation.fromJson(convJson(last: {
        'id': 1, 'sender': 2, 'content': '', 'has_image': false,
        'has_audio': true, 'audio_duration_ms': 4000,
        'created_at': '2026-09-26T10:00:00Z',
      }));
      expect(c.last!.hasAudio, isTrue);
      expect(c.last!.text, '🎤 Message vocal');
    });
  });

  group('recording in the chat', () {
    late FakeServer server;
    late ChatProvider chat;

    Future<void> openChat(WidgetTester tester, {FakeRecorder? recorder}) async {
      VoiceServices.recorder = () => recorder ?? FakeRecorder();
      VoiceServices.playback = ({url, filePath}) => FakePlayback();
      final auth = await loggedInAuth(tester);
      server = FakeServer();
      chat = ChatProvider(client: server.client())..setToken('tok');
      await tester.pumpWidget(chatApp(
        auth,
        chat,
        ChatScreen(conversation: ChatConversation.fromJson(convJson())),
      ));
      await tester.pumpAndSettle();
    }

    Future<void> closeChat(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      chat.setToken(null);
      chat.dispose();
    }

    testWidgets('the button is a mic when empty and a send arrow once there is text',
        (tester) async {
      await openChat(tester);
      expect(_mic, findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Salut');
      await tester.pump();
      expect(_mic, findsNothing);
      expect(find.byIcon(Icons.send_rounded), findsOneWidget);

      await tester.enterText(find.byType(TextField), '');
      await tester.pump();
      expect(_mic, findsOneWidget);
      await closeChat(tester);
    });

    testWidgets('record, send and see the voice note in the conversation', (tester) async {
      final recorder = FakeRecorder();
      await openChat(tester, recorder: recorder);

      await tester.tap(_mic);
      await tester.pump();
      expect(find.text('Enregistrement…'), findsOneWidget);
      expect(recorder.calls, ['start']);

      await tester.pump(const Duration(seconds: 2));
      expect(find.text('0:02'), findsOneWidget); // minuteur d'enregistrement

      await tester.tap(_sendRecording);
      await tester.pump();
      await _letUploadFinish(tester);

      expect(recorder.calls, containsAllInOrder(['start', 'stop', 'dispose']));
      expect(server.audioUploads, 1);
      expect(find.byType(VoiceMessagePlayer), findsOneWidget);
      expect(find.text('Enregistrement…'), findsNothing);
      expect(_mic, findsOneWidget, reason: 'retour à la saisie normale');
      // la durée envoyée au serveur est celle enregistrée (~2 s)
      expect(server.messages.last['audio_duration_ms'], inInclusiveRange(1800, 2600));
      await closeChat(tester);
    });

    testWidgets('a note shorter than one second is discarded', (tester) async {
      await openChat(tester);
      await tester.tap(_mic);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(_sendRecording);
      await tester.pumpAndSettle();

      expect(find.text('Message vocal trop court'), findsOneWidget);
      expect(server.audioUploads, 0);
      expect(find.byType(VoiceMessagePlayer), findsNothing);
      await closeChat(tester);
    });

    testWidgets('cancelling a recording sends nothing and deletes the file', (tester) async {
      final recorder = FakeRecorder();
      await openChat(tester, recorder: recorder);
      await tester.tap(_mic);
      await tester.pump(const Duration(seconds: 3));
      final path = recorder.path!;
      expect(File(path).existsSync(), isTrue);

      await tester.tap(find.byTooltip('Annuler'));
      await tester.pumpAndSettle();

      expect(recorder.calls, containsAllInOrder(['start', 'cancel']));
      expect(server.audioUploads, 0);
      expect(File(path).existsSync(), isFalse);
      expect(_mic, findsOneWidget);
      await closeChat(tester);
    });

    testWidgets('denied microphone permission shows a hint and never records',
        (tester) async {
      final recorder = FakeRecorder(granted: false);
      await openChat(tester, recorder: recorder);
      await tester.tap(_mic);
      await tester.pumpAndSettle();

      expect(find.textContaining("Autorisez l'accès au micro"), findsOneWidget);
      expect(find.text('Enregistrement…'), findsNothing);
      expect(recorder.calls, isNot(contains('start')));
      await closeChat(tester);
    });

    testWidgets('recording stops and sends by itself at the 5 minute limit', (tester) async {
      await openChat(tester);
      await tester.tap(_mic);
      await tester.pump();
      await tester.pump(const Duration(minutes: 5, seconds: 1));
      await _letUploadFinish(tester);

      expect(server.audioUploads, 1);
      expect(find.textContaining('Durée maximale de 5 minutes'), findsOneWidget);
      await closeChat(tester);
    });
  });

  group('VoiceMessagePlayer', () {
    Widget host(List<Widget> children) => MaterialApp(
          home: Scaffold(body: Column(children: children)),
        );

    testWidgets('play, progress, speed and end of playback', (tester) async {
      final fake = FakePlayback();
      VoiceServices.playback = ({url, filePath}) => fake;

      await tester.pumpWidget(host([
        const VoiceMessagePlayer(
            url: 'http://x/a.m4a', durationMs: 5000, isMine: false),
      ]));
      expect(find.text('0:05'), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pump();
      await tester.pump();
      expect(fake.calls, containsAllInOrder(['speed 1.0', 'play']));
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);

      fake.position.add(const Duration(milliseconds: 2500));
      await tester.pump();
      expect(find.text('0:02'), findsOneWidget);

      await tester.tap(find.text('1x'));
      await tester.pump();
      expect(fake.speed, 1.5);
      expect(find.text('1.5x'), findsOneWidget);

      fake.complete.add(null);
      await tester.pump();
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      expect(find.text('0:05'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      expect(fake.calls, contains('dispose'));
    });

    testWidgets('starting a second note pauses the first', (tester) async {
      final players = <FakePlayback>[];
      VoiceServices.playback = ({url, filePath}) {
        final p = FakePlayback();
        players.add(p);
        return p;
      };

      await tester.pumpWidget(host(const [
        VoiceMessagePlayer(url: 'http://x/1.m4a', durationMs: 3000, isMine: false),
        VoiceMessagePlayer(url: 'http://x/2.m4a', durationMs: 4000, isMine: true),
      ]));

      await tester.tap(find.byIcon(Icons.play_arrow_rounded).first);
      await tester.pump();
      await tester.pump();
      await tester.tap(find.byIcon(Icons.play_arrow_rounded).last);
      await tester.pump();
      await tester.pump();

      expect(players.length, 2);
      expect(players[0].calls, contains('pause'));
      expect(players[1].calls, contains('play'));

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('no native player is created before the first tap', (tester) async {
      var created = 0;
      VoiceServices.playback = ({url, filePath}) {
        created++;
        return FakePlayback();
      };
      await tester.pumpWidget(host(const [
        VoiceMessagePlayer(url: 'http://x/1.m4a', durationMs: 3000, isMine: false),
        VoiceMessagePlayer(url: 'http://x/2.m4a', durationMs: 4000, isMine: false),
      ]));
      expect(created, 0);
    });
  });
}
