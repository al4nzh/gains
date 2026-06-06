import 'package:dio/dio.dart';
import 'package:gains/core/api/api_client.dart';
import 'package:gains/features/ai/models/chat_response.dart';
import 'package:gains/features/ai/models/coach_action.dart';
import 'package:gains/features/ai/models/coach_conversation.dart';
import 'package:gains/features/ai/models/coach_message.dart';
import 'package:gains/features/ai/models/routine_draft.dart';
import 'package:gains/features/ai/models/workout_insight.dart';
import 'package:gains/features/routines/models/routine.dart';

class AiApi {
  AiApi(this._client);

  final ApiClient _client;

  Future<WorkoutAnalysisInsight> analyzeWorkout(
    String workoutId, {
    String unitSystem = 'metric',
  }) async {
    try {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/ai/analyze-workout/$workoutId',
        data: {'unit_system': unitSystem},
      );
      return WorkoutAnalysisInsight.fromJson(response.data!);
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<GenerateRoutinesResult> generateRoutines(String message) async {
    try {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/ai/generate-routines',
        data: {'message': message},
      );
      return GenerateRoutinesResult.fromJson(response.data!);
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<List<Routine>> confirmRoutineDraft(String draftId) async {
    try {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/ai/generated-routines/$draftId/confirm',
      );
      final routines = response.data!['routines'] as List<dynamic>? ?? [];
      return routines.map((r) => Routine.fromJson(r as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<ChatResponse> sendChatMessage({
    required String message,
    String? conversationId,
    String unitSystem = 'metric',
  }) async {
    try {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/ai/chat',
        data: {
          'message': message,
          'conversation_id': ?conversationId,
          'unit_system': unitSystem,
        },
      );
      return ChatResponse.fromJson(response.data!);
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<List<CoachConversation>> listConversations({int limit = 30}) async {
    try {
      final response = await _client.dio.get<Map<String, dynamic>>(
        '/ai/chat/conversations',
        queryParameters: {'limit': limit},
      );
      final list = response.data!['conversations'] as List<dynamic>? ?? [];
      return list
          .map((e) => CoachConversation.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<List<CoachMessage>> getConversationMessages(String conversationId) async {
    try {
      final response = await _client.dio.get<Map<String, dynamic>>(
        '/ai/chat/conversations/$conversationId/messages',
      );
      final list = response.data!['messages'] as List<dynamic>? ?? [];
      return list.map((e) => CoachMessage.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<void> deleteConversation(String conversationId) async {
    try {
      await _client.dio.delete<void>('/ai/chat/conversations/$conversationId');
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<List<CoachAction>> listPendingActions({int limit = 50}) async {
    try {
      final response = await _client.dio.get<Map<String, dynamic>>(
        '/ai/actions/pending',
        queryParameters: {'limit': limit},
      );
      final list = response.data!['actions'] as List<dynamic>? ?? [];
      return list.map((e) => CoachAction.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<CoachAction> acceptAction(String actionId) async {
    try {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/ai/actions/$actionId/accept',
      );
      return CoachAction.fromJson(response.data!);
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<CoachAction> rejectAction(String actionId) async {
    try {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/ai/actions/$actionId/reject',
      );
      return CoachAction.fromJson(response.data!);
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }
}
