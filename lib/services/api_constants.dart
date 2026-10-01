import 'dart:io';
import 'package:flutter/foundation.dart';

class ApiConstants {
  // Détection intelligente de l'adresse selon la plateforme
  static String get baseUrl {
    if (kReleaseMode) {
      return 'https://api.lapinou.elienoel.dev/api';
    }
    if (kIsWeb) {
      return 'http://localhost:8000/api';
    }
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:8000/api';
    }
    // iOS simulateur ou macOS desktop
    return 'http://localhost:8000/api';
  }

  static String get requestOtpUrl => '$baseUrl/auth/request-otp/';
  static String get verifyOtpUrl => '$baseUrl/auth/verify-otp/';
  static String get currentUserUrl => '$baseUrl/auth/users/me/';

  static String get postsUrl => '$baseUrl/community/posts/';
  static String postDetailUrl(int postId) =>
      '$baseUrl/community/posts/$postId/';
  static String postCommentsUrl(int postId) =>
      '$baseUrl/community/posts/$postId/comments/';
  static String commentReactUrl(int commentId) =>
      '$baseUrl/community/comments/$commentId/react/';
  static String postLikeUrl(int postId) =>
      '$baseUrl/community/posts/$postId/like/';

  // Messagerie privée
  static String get chatConversationsUrl => '$baseUrl/chat/conversations/';
  static String get chatUnreadUrl => '$baseUrl/chat/conversations/unread-count/';
  static String get chatUsersUrl => '$baseUrl/chat/conversations/users/';
  static String chatMessagesUrl(int conversationId) => '$baseUrl/chat/conversations/$conversationId/messages/';

  // Documentation Swagger
  static String get swaggerDocsUrl => '$baseUrl/docs/';

  // Module Farm (Élevage)
  static String get breedsUrl => '$baseUrl/farm/breeds/';
  static String get cagesUrl => '$baseUrl/farm/cages/';
  static String cageDetailUrl(String id) => '$baseUrl/farm/cages/$id/';
  static String get rabbitsUrl => '$baseUrl/farm/rabbits/';
  static String rabbitDetailUrl(String id) => '$baseUrl/farm/rabbits/$id/';
  static String rabbitGenealogyUrl(String id) =>
      '$baseUrl/farm/rabbits/$id/genealogy/';
  static String rabbitUploadPhotoUrl(String id) =>
      '$baseUrl/farm/rabbits/$id/upload_photo/';
  static String rabbitSetPrimaryPhotoUrl(String id, int imageId) =>
      '$baseUrl/farm/rabbits/$id/images/$imageId/set-primary/';
  static String rabbitDeletePhotoUrl(String id, int imageId) =>
      '$baseUrl/farm/rabbits/$id/images/$imageId/';

  static String formatMediaUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    final root = baseUrl.replaceAll(RegExp(r'/api/?$'), '');
    if (path.startsWith('/')) {
      return '$root$path';
    }
    return '$root/$path';
  }

  static String get matingsUrl => '$baseUrl/farm/matings/';
  static String matingDetailUrl(String id) => '$baseUrl/farm/matings/$id/';
  static String matingPalpationUrl(String id) => '$baseUrl/farm/matings/$id/palpation/';
  static String matingCancelUrl(String id) => '$baseUrl/farm/matings/$id/cancel/';

  static String get littersUrl => '$baseUrl/farm/litters/';
  static String litterDetailUrl(String id) => '$baseUrl/farm/litters/$id/';
  static String litterWeanUrl(String id) => '$baseUrl/farm/litters/$id/wean/';

  // Soins & entretien : types de soins, soins effectués et rappels
  static String get careTreatmentsUrl => '$baseUrl/farm/care-treatments/';
  static String careTreatmentDetailUrl(String id) =>
      '$baseUrl/farm/care-treatments/$id/';
  static String get careRecordsUrl => '$baseUrl/farm/care-records/';
  static String careRecordDetailUrl(String id) =>
      '$baseUrl/farm/care-records/$id/';
  static String get careUpcomingUrl => '$baseUrl/farm/care-records/upcoming/';

  static String get careEventsUrl => '$baseUrl/farm/care-events/';
  static String careEventDetailUrl(String id) =>
      '$baseUrl/farm/care-events/$id/';
  static String get upcomingRemindersUrl =>
      '$baseUrl/farm/care-events/upcoming_reminders/';

  static String get financesUrl => '$baseUrl/farm/finances/';
  static String financeDetailUrl(String id) => '$baseUrl/farm/finances/$id/';
  static String get financeSummaryUrl => '$baseUrl/farm/finances/summary/';
}
