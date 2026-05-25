import 'package:gains/features/ai/models/clarification.dart';
import 'package:gains/features/ai/models/coach_action.dart';
import 'package:gains/features/ai/models/coach_message.dart';

class ChatResponse {
  const ChatResponse({
    required this.conversationId,
    required this.assistant,
    this.proposedActions = const [],
    this.clarification,
  });

  final String conversationId;
  final CoachMessage assistant;
  final List<CoachAction> proposedActions;
  final AiClarification? clarification;

  factory ChatResponse.fromJson(Map<String, dynamic> json) {
    return ChatResponse(
      conversationId: json['conversation_id'] as String,
      assistant: CoachMessage.fromJson(json['assistant'] as Map<String, dynamic>),
      proposedActions: (json['proposed_actions'] as List<dynamic>? ?? [])
          .map((e) => CoachAction.fromJson(e as Map<String, dynamic>))
          .toList(),
      clarification: json['clarification'] != null
          ? AiClarification.fromJson(json['clarification'] as Map<String, dynamic>)
          : null,
    );
  }
}
