import 'package:flutter/material.dart';

/// One submission at a time; a failed operation keeps the form and its values.
class AsyncEditor extends StatefulWidget {
  final String title;
  final GlobalKey<FormState> formKey;
  final Widget content;
  final Future<String> Function() onSave;
  final String Function(Object) errorMessage;
  const AsyncEditor({
    super.key,
    required this.title,
    required this.formKey,
    required this.content,
    required this.onSave,
    required this.errorMessage,
  });
  @override
  State<AsyncEditor> createState() => _AsyncEditorState();
}

class _AsyncEditorState extends State<AsyncEditor> {
  bool saving = false;
  String? error;
  Future<void> save() async {
    if (saving || !(widget.formKey.currentState?.validate() ?? false)) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final message = await widget.onSave();
      if (!mounted) return;
      setState(() => saving = false);
      Navigator.pop(context, message);
    } catch (failure) {
      if (mounted) {
        setState(() {
          saving = false;
          error = widget.errorMessage(failure);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Form(
            key: widget.formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AbsorbPointer(absorbing: saving, child: widget.content),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: saving ? null : save,
          icon: saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: Text(saving ? 'Guardando…' : 'Guardar'),
        ),
      ],
    ),
  );
}
