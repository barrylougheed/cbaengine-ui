import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/style_summary.dart';
import '../providers/draft/draft_notifier.dart';
import '../providers/reference_data/reference_data_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header.dart';
import '../widgets/confirm_discard.dart';
import '../widgets/error_banner.dart';
import '../widgets/issue_choice_summary.dart';
import '../widgets/loading_view.dart';
import '../widgets/step_page.dart';

/// The third screen of an email about issues: choose a letter style, the tone
/// the whole email is written in. The server writes the text when Continue is
/// pressed, in the style chosen, for the topics chosen; nothing here needs an
/// area. Choosing is local to this screen until then, so trying styles out
/// costs nothing and loses nothing.
///
/// Coming back to this screen shows the style the text is in as chosen.
/// Carrying on with it, and the same topics, goes straight to the editor and
/// keeps any edits; changing the style (or the topics) writes the text again,
/// after asking when the resident has edited it.
class StyleScreen extends ConsumerStatefulWidget {
  const StyleScreen({super.key});

  @override
  ConsumerState<StyleScreen> createState() => _StyleScreenState();
}

class _StyleScreenState extends ConsumerState<StyleScreen> {
  /// The style marked on screen; becomes the draft's only on Continue.
  StyleSummary? _selected;

  /// True while the text is being written.
  bool _composing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selected = ref.read(draftNotifierProvider).style;
  }

  Future<void> _continue() async {
    final style = _selected;
    if (style == null) return;
    final draft = ref.read(draftNotifierProvider);

    // The same style, and the text is still there for these topics: nothing to
    // write again, and any edits stay.
    if (draft.style == style && draft.composedBody.isNotEmpty) {
      context.push('/craft/issues/email');
      return;
    }
    if (draft.hasEditedText && !await confirmDiscard(context, 'This replaces your edits. Continue?')) return;
    if (!mounted) return;

    setState(() {
      _composing = true;
      _error = null;
    });
    final error = await ref.read(draftNotifierProvider.notifier).chooseStyle(style);
    if (!mounted) return;
    setState(() {
      _composing = false;
      _error = error;
    });
    if (error == null) context.push('/craft/issues/email');
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(draftNotifierProvider);
    // "Start over" (the header's dialog) empties the draft while this screen is
    // still animating away: show just the header for those few frames.
    if (draft.issues.isEmpty) return const Scaffold(appBar: AppHeader());
    final catalogueAsync = ref.watch(topicCatalogueProvider);
    final textTheme = Theme.of(context).textTheme;

    return StepPage(
      step: 1,
      label: 'Choose a letter style',
      action: FilledButton(
        onPressed: _selected != null && !_composing ? _continue : null,
        child: const Text('Continue'),
      ),
      children: [
        Text('Choose a letter style', style: textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          'This sets the tone of your email. You can still edit the text afterwards.',
          style: textTheme.bodyMedium?.copyWith(color: AppColors.mutedText),
        ),
        const SizedBox(height: 16),
        IssueChoiceSummary(topics: draft.issues, onChangeTopics: () => context.push('/craft/issues')),
        const SizedBox(height: 16),
        catalogueAsync.when(
          loading: () => const LoadingView(),
          error: (error, _) => ErrorBanner(
            message: 'Could not load the letter styles. Please check your connection and try again.',
            onRetry: () => ref.invalidate(topicCatalogueProvider),
          ),
          data: (catalogue) => RadioGroup<String>(
            groupValue: _selected?.id,
            onChanged: _composing
                ? (_) {}
                : (id) => setState(() {
                    _selected = catalogue.styles.where((style) => style.id == id).firstOrNull;
                    _error = null;
                  }),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [for (final style in catalogue.styles) _StyleCard(style: style, enabled: !_composing)],
            ),
          ),
        ),
        if (_composing) ...[const SizedBox(height: 8), const LinearProgressIndicator()],
        if (_error != null) ...[const SizedBox(height: 8), ErrorBanner(message: _error!)],
        const SizedBox(height: 16),
      ],
    );
  }
}

/// One style: a radio button, its name and what it sounds like. The whole card
/// can be pressed, and the chosen one is outlined in deep olive.
class _StyleCard extends StatelessWidget {
  const _StyleCard({required this.style, required this.enabled});

  final StyleSummary style;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final registry = RadioGroup.maybeOf<String>(context);
    final selected = registry?.groupValue == style.id;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      color: selected ? AppColors.softOlive : AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: selected ? AppColors.deepOlive : AppColors.hairline, width: selected ? 2 : 1),
      ),
      child: InkWell(
        onTap: enabled ? () => registry?.onChanged(style.id) : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 16, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Radio<String>(value: style.id),
              const SizedBox(width: 4),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(style.title, style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(style.description, style: textTheme.bodyMedium?.copyWith(color: AppColors.mutedText)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
