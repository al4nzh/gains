import 'package:flutter/material.dart';

Future<String?> promptRoutineName(BuildContext context, {String? initial}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _RoutineNameDialog(initial: initial),
  );
}

class _RoutineNameDialog extends StatefulWidget {
  const _RoutineNameDialog({this.initial});

  final String? initial;

  @override
  State<_RoutineNameDialog> createState() => _RoutineNameDialogState();
}

class _RoutineNameDialogState extends State<_RoutineNameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() => Navigator.pop(context, _controller.text.trim());

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Routine name'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'e.g. Push Day'),
        textCapitalization: TextCapitalization.words,
        onSubmitted: (_) => _save(),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

Future<({String name, String description})?> promptEditRoutine(
  BuildContext context, {
  required String initialName,
  String? initialDescription,
}) {
  return showDialog<({String name, String description})>(
    context: context,
    builder: (context) => _EditRoutineDialog(
      initialName: initialName,
      initialDescription: initialDescription,
    ),
  );
}

class _EditRoutineDialog extends StatefulWidget {
  const _EditRoutineDialog({
    required this.initialName,
    this.initialDescription,
  });

  final String initialName;
  final String? initialDescription;

  @override
  State<_EditRoutineDialog> createState() => _EditRoutineDialogState();
}

class _EditRoutineDialogState extends State<_EditRoutineDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialName);
    _descCtrl = TextEditingController(text: widget.initialDescription ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _save() {
    Navigator.pop(
      context,
      (name: _nameCtrl.text.trim(), description: _descCtrl.text.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit routine'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descCtrl,
              decoration: const InputDecoration(labelText: 'Description (optional)'),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

Future<bool> confirmDelete(
  BuildContext context,
  String message, {
  String title = 'Remove exercise?',
  String confirmLabel = 'Remove',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}
