import 'package:flutter/material.dart';
import 'package:gains/core/api/api_client.dart';
import 'package:gains/core/api/api_exception.dart';
import 'package:gains/core/theme/app_colors.dart';
import 'package:gains/features/ai/data/ai_api.dart';
import 'package:gains/features/ai/models/clarification.dart';
import 'package:gains/features/ai/models/coach_action.dart';
import 'package:gains/features/ai/models/coach_conversation.dart';
import 'package:gains/features/ai/models/coach_message.dart';
import 'package:gains/features/ai/presentation/widgets/coach_action_card.dart';
import 'package:gains/features/ai/presentation/widgets/coach_clarification_banner.dart';
import 'package:gains/features/ai/presentation/widgets/coach_message_bubble.dart';
import 'package:gains/features/ai/presentation/widgets/coach_no_actions_hint.dart';
import 'package:gains/features/home/presentation/widgets/home_formatters.dart';
import 'package:gains/features/shell/shell_tab_auto_refresh.dart';
import 'package:gains/features/shell/shell_tab_refresh.dart';
import 'package:provider/provider.dart';

class _DisplayMessage {
  const _DisplayMessage({
    required this.message,
    this.proposedActions,
    this.clarification,
    this.showNoActionsHint = false,
  });

  final CoachMessage message;
  final List<CoachAction>? proposedActions;
  final AiClarification? clarification;
  final bool showNoActionsHint;
}

class CoachScreen extends StatefulWidget {
  const CoachScreen({super.key});

  @override
  State<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends State<CoachScreen> with ShellTabAutoRefresh {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();

  AiApi? _api;
  String? _conversationId;
  List<_DisplayMessage> _messages = [];
  List<CoachAction> _pendingActions = [];
  List<CoachConversation> _conversations = [];
  bool _chatLoading = false;
  bool _initialLoading = true;
  String? _coachUnavailable;
  String? _resolvingActionId;

  @override
  int get shellTabIndex => ShellTab.coach;

  @override
  void onShellTabRefresh() => _refresh(silent: true);

  AiApi get api => _api ??= AiApi(context.read<ApiClient>());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _aiErrorMessage(ApiException e) {
    if (e.statusCode == 503) return 'Coach unavailable';
    return e.message;
  }

  Future<void> _refresh({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _initialLoading = true;
        _coachUnavailable = null;
      });
    }
    try {
      final pending = await api.listPendingActions();
      final conversations = await api.listConversations();
      if (!mounted) return;
      setState(() {
        _pendingActions = pending;
        _conversations = conversations;
        _initialLoading = false;
        _coachUnavailable = null;
        _syncPendingIntoChat();
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _initialLoading = false;
        if (e.statusCode == 503) {
          _coachUnavailable = 'Coach unavailable';
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _initialLoading = false);
    }
  }

  /// Keeps action cards only on assistant messages; drops resolved actions.
  void _syncPendingIntoChat() {
    final pendingIds = _pendingActions.map((a) => a.id).toSet();
    final pendingById = {for (final a in _pendingActions) a.id: a};

    var messages = _messages.map((m) {
      final raw = m.proposedActions;
      if (raw == null) return m;
      final kept = raw.where((a) => pendingIds.contains(a.id)).map((a) => pendingById[a.id]!).toList();
      return _DisplayMessage(
        message: m.message,
        proposedActions: kept.isEmpty ? null : kept,
        clarification: m.clarification,
        showNoActionsHint: m.showNoActionsHint,
      );
    }).toList();

    final attachedIds = messages
        .expand((m) => m.proposedActions ?? const <CoachAction>[])
        .map((a) => a.id)
        .toSet();
    final orphans = _pendingActions.where((a) => !attachedIds.contains(a.id)).toList();

    if (orphans.isNotEmpty) {
      final idx = messages.lastIndexWhere((m) => m.message.isAssistant);
      if (idx >= 0) {
        final m = messages[idx];
        final byId = <String, CoachAction>{
          for (final a in [...?m.proposedActions, ...orphans]) a.id: a,
        };
        messages[idx] = _DisplayMessage(
          message: m.message,
          proposedActions: byId.values.toList(),
          clarification: m.clarification,
          showNoActionsHint: m.showNoActionsHint,
        );
      }
    }

    _messages = messages;
    _applyNoActionsHints();
  }

  void _applyNoActionsHints() {
    final pendingIds = _pendingActions.map((a) => a.id).toSet();
    _messages = _messages.map((m) {
      if (!m.message.isAssistant) {
        return _DisplayMessage(
          message: m.message,
          proposedActions: m.proposedActions,
          clarification: m.clarification,
          showNoActionsHint: false,
        );
      }
      final hasActions = (m.proposedActions?.any((a) => pendingIds.contains(a.id)) ?? false);
      final showHint = !hasActions &&
          m.clarification == null &&
          coachMessageImpliesActions(m.message.content);
      return _DisplayMessage(
        message: m.message,
        proposedActions: m.proposedActions,
        clarification: m.clarification,
        showNoActionsHint: showHint,
      );
    }).toList();
  }

  void _removeActionFromChat(String actionId) {
    setState(() {
      _pendingActions = _pendingActions.where((a) => a.id != actionId).toList();
      _messages = _messages.map((m) {
        if (m.proposedActions == null) return m;
        final kept = m.proposedActions!.where((a) => a.id != actionId).toList();
        return _DisplayMessage(
          message: m.message,
          proposedActions: kept.isEmpty ? null : kept,
          clarification: m.clarification,
        );
      }).toList();
    });
  }

  Future<void> _loadConversation(String conversationId) async {
    setState(() {
      _chatLoading = true;
      _conversationId = conversationId;
      _messages = [];
    });
    try {
      final messages = await api.getConversationMessages(conversationId);
      if (!mounted) return;
      setState(() {
        _messages = messages.map((m) => _DisplayMessage(message: m)).toList();
        _chatLoading = false;
      });
      _scrollToBottom();
      await _refresh(silent: true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _chatLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_aiErrorMessage(e))),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _chatLoading = false);
    }
  }

  void _startNewChat() {
    setState(() {
      _conversationId = null;
      _messages = [];
    });
  }

  Future<bool> _confirmDeleteConversation(CoachConversation conversation) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete conversation?'),
        content: Text(
          'Delete “${conversation.title}”? Pending suggestions from this chat will be dismissed.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _deleteConversation(CoachConversation conversation, {VoidCallback? onDeleted}) async {
    final ok = await _confirmDeleteConversation(conversation);
    if (!ok || !mounted) return;

    try {
      await api.deleteConversation(conversation.id);
      if (!mounted) return;

      if (_conversationId == conversation.id) {
        _startNewChat();
      }
      setState(() {
        _conversations = _conversations.where((c) => c.id != conversation.id).toList();
      });
      onDeleted?.call();
      await _refresh(silent: true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Conversation deleted')),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_aiErrorMessage(e))),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not delete conversation')),
        );
      }
    }
  }

  Future<void> _deleteCurrentConversation() async {
    final id = _conversationId;
    if (id == null) return;

    CoachConversation? match;
    for (final c in _conversations) {
      if (c.id == id) {
        match = c;
        break;
      }
    }
    await _deleteConversation(
      match ??
          CoachConversation(
            id: id,
            title: 'This chat',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
    );
  }

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _chatLoading) return;

    final userMsg = CoachMessage(
      id: 'local-${DateTime.now().millisecondsSinceEpoch}',
      role: 'user',
      content: text,
      createdAt: DateTime.now(),
    );

    setState(() {
      _chatLoading = true;
      _messages = [..._messages, _DisplayMessage(message: userMsg)];
    });
    _inputController.clear();
    _scrollToBottom();

    try {
      final response = await api.sendChatMessage(
        message: text,
        conversationId: _conversationId,
      );
      if (!mounted) return;

      setState(() {
        _conversationId = response.conversationId;
        _messages = [
          ..._messages,
          _DisplayMessage(
            message: response.assistant,
            proposedActions: response.proposedActions.isNotEmpty ? response.proposedActions : null,
            clarification: response.clarification,
            showNoActionsHint: response.proposedActions.isEmpty &&
                response.clarification == null &&
                coachMessageImpliesActions(response.assistant.content),
          ),
        ];
        _chatLoading = false;
      });
      _scrollToBottom();
      await _refresh(silent: true);
      if (mounted) {
        setState(() {
          _syncPendingIntoChat();
          _applyNoActionsHints();
        });
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _chatLoading = false;
        if (_messages.isNotEmpty && _messages.last.message.id.startsWith('local-')) {
          // keep user message
        }
      });
      final msg = _aiErrorMessage(e);
      if (e.statusCode == 503) {
        setState(() => _coachUnavailable = msg);
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _chatLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not send message')),
      );
    }
  }

  Future<void> _resolveAction(CoachAction action, {required bool accept}) async {
    setState(() => _resolvingActionId = action.id);
    try {
      if (accept) {
        await api.acceptAction(action.id);
      } else {
        await api.rejectAction(action.id);
      }
      if (!mounted) return;
      _removeActionFromChat(action.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(accept ? 'Change applied' : 'Change rejected')),
      );
      context.read<ShellTabRefresh>().bumpMany([
        ShellTab.home,
        ShellTab.routines,
      ]);
      await _refresh(silent: true);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_aiErrorMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _resolvingActionId = null);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _showThreads() async {
    try {
      final list = await api.listConversations();
      if (!mounted) return;
      setState(() => _conversations = list);
    } catch (_) {
      // use cached list
    }

    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Conversations', style: Theme.of(sheetCtx).textTheme.titleMedium),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(sheetCtx);
                            _startNewChat();
                          },
                          child: const Text('New chat'),
                        ),
                      ],
                    ),
                  ),
                  if (_conversations.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('No conversations yet'),
                    )
                  else
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _conversations.length,
                        itemBuilder: (context, i) {
                          final c = _conversations[i];
                          return ListTile(
                            title: Text(c.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text(formatRelativeDate(c.updatedAt)),
                            trailing: IconButton(
                              tooltip: 'Delete',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _deleteConversation(
                                c,
                                onDeleted: () => setSheetState(() {}),
                              ),
                            ),
                            onTap: () {
                              Navigator.pop(sheetCtx);
                              _loadConversation(c.id);
                            },
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final unavailable = _coachUnavailable;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Coach'),
        actions: [
          if (_conversationId != null)
            IconButton(
              tooltip: 'Delete conversation',
              icon: const Icon(Icons.delete_outline),
              onPressed: _deleteCurrentConversation,
            ),
          IconButton(
            tooltip: 'Conversations',
            icon: const Icon(Icons.history),
            onPressed: _showThreads,
          ),
          IconButton(
            tooltip: 'New chat',
            icon: const Icon(Icons.add_comment_outlined),
            onPressed: _startNewChat,
          ),
        ],
      ),
      body: Column(
        children: [
          if (unavailable != null)
            MaterialBanner(
              content: Text(unavailable),
              backgroundColor: AppColors.surfaceElevated,
              actions: [
                TextButton(onPressed: () => _refresh(), child: const Text('Retry')),
              ],
            ),
          Expanded(
            child: _initialLoading && _messages.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.chat_bubble_outline, size: 48, color: AppColors.textMuted),
                              const SizedBox(height: 16),
                              Text(
                                'Ask your coach',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Training advice, routine tweaks, recovery — changes are only applied when you accept them.',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        itemCount: _messages.length,
                        itemBuilder: (context, i) {
                          final item = _messages[i];
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              CoachMessageBubble(message: item.message),
                              if (item.proposedActions != null &&
                                  item.proposedActions!.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Suggested changes (review to apply)',
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                        color: AppColors.textMuted,
                                      ),
                                ),
                                const SizedBox(height: 6),
                                ...item.proposedActions!.map(
                                  (a) => CoachActionCard(
                                    action: a,
                                    busy: _resolvingActionId == a.id,
                                    onAccept: () => _resolveAction(a, accept: true),
                                    onReject: () => _resolveAction(a, accept: false),
                                  ),
                                ),
                              ],
                              if (item.clarification != null) ...[
                                const SizedBox(height: 8),
                                CoachClarificationBanner(clarification: item.clarification!),
                              ],
                              if (item.showNoActionsHint) ...[
                                const SizedBox(height: 8),
                                const CoachNoActionsHint(),
                              ],
                            ],
                          );
                        },
                      ),
          ),
          if (_chatLoading)
            const LinearProgressIndicator(minHeight: 2, color: AppColors.primary),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: unavailable != null ? null : (_) => _sendMessage(),
                      enabled: !_chatLoading && unavailable == null,
                      decoration: const InputDecoration(
                        hintText: 'Message your coach…',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _chatLoading || unavailable != null ? null : _sendMessage,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
