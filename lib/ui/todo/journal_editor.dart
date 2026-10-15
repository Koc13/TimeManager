import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/period.dart';
import '../../providers/data_providers.dart';
import 'done_section.dart';
import '../../providers/actions/task_actions.dart';

/// The period file's Markdown body: the nightly journal for a day, review
/// notes for a week or month. Saves itself shortly after typing stops and
/// when it goes away, so there is no Save button to forget.
class JournalEditor extends ConsumerStatefulWidget {
  const JournalEditor({super.key, required this.period});

  final Period period;

  @override
  ConsumerState<JournalEditor> createState() => _JournalEditorState();
}

class _JournalEditorState extends ConsumerState<JournalEditor> {
  late final _text = TextEditingController(text: _stored);

  final _focus = FocusNode();
  Timer? _debounce;
  bool _preview = false;

  // Captured up front because the last save runs in dispose(), where
  // looking up ancestors or using ref is no longer allowed.
  late final TaskActions _data;
  ScaffoldMessengerState? _messenger;

  @override
  void initState() {
    super.initState();
    _data = ref.read(taskActionsProvider);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _messenger = ScaffoldMessenger.maybeOf(context);
  }

  String get _stored => ref.read(appDataProvider).period(widget.period).journal;

  @override
  void didUpdateWidget(JournalEditor old) {
    super.didUpdateWidget(old);
    // The pager reuses this widget when the arrows change the period.
    if (old.period != widget.period) {
      _flush(old.period);
      _text.text = _stored;
    }
  }

  @override
  void dispose() {
    _flush(widget.period);
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _changed(String _) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 800),
      () => _flush(widget.period),
    );
  }

  void _flush(Period period) {
    if (_debounce == null) return;
    _debounce!.cancel();
    _debounce = null;
    _data.setJournal(period, _text.text).catchError((Object e) {
      _messenger?.showSnackBar(SnackBar(content: Text('$e')));
    });
  }

  @override
  Widget build(BuildContext context) {
    final stored = ref.watch(
      appDataProvider.select((d) => d.period(widget.period).journal),
    );
    // A file edited elsewhere (Obsidian, Syncthing) wins, unless the user
    // is typing here right now.
    if (stored != _text.text && _debounce == null && !_focus.hasFocus) {
      _text.text = stored;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          widget.period.kind == PeriodKind.day ? 'Journal' : 'Review',
          trailing: IconButton(
            tooltip: _preview ? 'Edit' : 'Preview',
            icon: Icon(
              _preview ? Icons.edit_outlined : Icons.visibility_outlined,
            ),
            onPressed: () {
              _flush(widget.period);
              setState(() => _preview = !_preview);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _preview
              ? MarkdownBody(data: _text.text.isEmpty ? '*Empty*' : _text.text)
              : TextField(
                  controller: _text,
                  focusNode: _focus,
                  onChanged: _changed,
                  minLines: 4,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Markdown…',
                    border: OutlineInputBorder(),
                  ),
                ),
        ),
      ],
    );
  }
}
