import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/draft.dart';
import '../providers/draft/draft_notifier.dart';
import '../providers/reference_data/reference_data_providers.dart';

/// The name, subject and message of the email being written, with what the
/// server adds around them: shared by the three ways of starting an email
/// (issues, your own words, a campaign). Edits go straight into the draft; when
/// the draft's text is replaced from outside (issues ticked, a campaign chosen)
/// the fields are refilled.
///
/// With [showText] false only the name is shown: an issues email has no text
/// until a proposal is ticked for every issue, but the name can be typed at any
/// point.
class EmailEditor extends ConsumerStatefulWidget {
  const EmailEditor({super.key, this.showText = true});

  final bool showText;

  @override
  ConsumerState<EmailEditor> createState() => _EmailEditorState();
}

class _EmailEditorState extends ConsumerState<EmailEditor> {
  late final TextEditingController _nameController;
  late final TextEditingController _subjectController;
  late final TextEditingController _bodyController;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(draftNotifierProvider);
    _nameController = TextEditingController(text: draft.senderName);
    _subjectController = TextEditingController(text: draft.subject);
    _bodyController = TextEditingController(text: draft.body);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _subjectController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(draftNotifierProvider);
    final notifier = ref.read(draftNotifierProvider.notifier);
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final layout = ref.watch(topicCatalogueProvider).value?.emailLayout;

    // The text was replaced from outside the text fields: show it in them.
    ref.listen<int>(draftNotifierProvider.select((current) => current.revision), (_, _) {
      final current = ref.read(draftNotifierProvider);
      _subjectController.text = current.subject;
      _bodyController.text = current.body;
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(labelText: 'Your name', helperText: 'Signs off your email.'),
          maxLength: maxSenderNameLength,
          buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          onChanged: notifier.setSenderName,
        ),
        if (widget.showText) ...[
          const SizedBox(height: 16),
          TextField(
            controller: _subjectController,
            decoration: const InputDecoration(labelText: 'Subject'),
            onChanged: notifier.setSubject,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _bodyController,
            decoration: const InputDecoration(labelText: 'Message', alignLabelWithHint: true),
            minLines: 8,
            maxLines: 14, // taller drafts scroll inside the field, so the notes and Continue stay reachable
            keyboardType: TextInputType.multiline,
            onChanged: notifier.setBody,
          ),
          if (draft.hasUnfinishedText) ...[
            const SizedBox(height: 8),
            Text(
              'Your message still has text in double square brackets, like [[this]]. '
              'Replace it with your own words before you continue.',
              style: textTheme.bodySmall?.copyWith(color: colorScheme.error),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            layout == null
                ? 'We add a greeting for each councillor, and your name, around your message.'
                : 'We add "${layout.greetingFormat.replaceAll('{name}', '<name>')}" at the start, with each '
                      'councillor\'s own name, and "${layout.signOff}" and your name at the end.',
            style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
          if (draft.footer != null)
            Text(
              'Added under your name, and not editable: "${draft.footer}"',
              style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
        ],
      ],
    );
  }
}
