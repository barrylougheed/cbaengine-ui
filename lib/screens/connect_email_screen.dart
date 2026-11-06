import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/message_intent.dart';
import '../models/oauth_result.dart';
import '../models/persisted_draft.dart';
import '../providers/auth/auth_notifier.dart';
import '../providers/core_providers.dart';
import '../providers/draft/draft_notifier.dart';
import '../providers/message_flow/message_flow_notifier.dart';
import '../services/oauth_fragment_parser.dart';
import '../widgets/app_banner.dart';
import '../widgets/error_banner.dart';
import '../widgets/loading_view.dart';
import '../widgets/step_progress_indicator.dart';

/// Step 5: triggers OAuth and hosts the post-connect auto-chain
/// (create -> confirm -> send). Reached both from a fresh "Connect email and send" tap
/// on Review, and — on web only — from the app's own reboot after the
/// OAuth provider redirects back here with a token in the URL fragment;
/// on mobile the app process survives the round-trip, so that second
/// path never triggers there.
///
/// The draft is always read from persisted storage when continuing
/// after connect, on both platforms, rather than from draftNotifier's
/// in-memory state — draftNotifier is guaranteed to be empty after a
/// web reload, so using the same source for both platforms keeps this
/// one code path instead of branching by platform here too.
class ConnectEmailScreen extends ConsumerStatefulWidget {
  const ConnectEmailScreen({super.key});

  @override
  ConsumerState<ConnectEmailScreen> createState() => _ConnectEmailScreenState();
}

class _ConnectEmailScreenState extends ConsumerState<ConnectEmailScreen> {
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleWebReturnIfAny());
  }

  Future<void> _handleWebReturnIfAny() async {
    if (!kIsWeb) return;
    // Read from the fragment captured in main() before runApp(), not
    // Uri.base.fragment directly — go_router's own startup can strip it
    // from the live URL before this widget ever gets a chance to look.
    final fragment = ref.read(initialOauthFragmentProvider);
    if (fragment == null) return; // a plain visit to /connect, not a return trip
    ref.read(initialOauthFragmentProvider.notifier).consume(); // handled once only

    final result = OauthFragmentParser.parse(fragment);
    if (result == null) return;

    await _handleOAuthResult(result);
  }

  Future<void> _connect(String provider) async {
    setState(() {
      _busy = true;
      _error = null;
    });

    final draft = ref.read(draftNotifierProvider);
    await ref
        .read(draftStorageServiceProvider)
        .write(
          PersistedDraft(
            councilId: draft.council?.id,
            councilName: draft.council?.name,
            leaId: draft.lea?.id,
            leaName: draft.lea?.name,
            intent: draft.intent,
            // The issues chosen, or the campaign's id: the same list the API is sent.
            topicIds: draft.intent == MessageIntent.own ? const [] : draft.apiTopics,
            proposals: draft.proposalsInUse,
            // Only the wording of what is being sent: the API rejects any other.
            templateVariants: draft.variantsInUse,
            senderName: draft.senderName.trim(),
            subject: draft.subject,
            body: draft.body,
            savedAt: DateTime.now().toUtc(),
          ),
        );

    try {
      final result = await ref.read(oauthServiceProvider).connect(provider: provider);
      // Only ever reached on mobile — web navigates away before
      // connect()'s future would resolve.
      await _handleOAuthResult(result);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Could not connect. Please try again.';
      });
    }
  }

  Future<void> _handleOAuthResult(OAuthResult returned) async {
    // Both the web return (fragment) and mobile return (app link) pass
    // through here: only accept a connection this app started — see
    // OAuthClientStateStore.
    final result = await ref.read(oauthClientStateStoreProvider).verify(returned);
    switch (result) {
      case OAuthSuccess(:final token, :final email, :final provider):
        if (!mounted) return;
        setState(() => _busy = true);
        ref.read(authNotifierProvider.notifier).setSession(token: token, email: email, provider: provider);
        await _runMessageFlowFromPersistedDraft();
      case OAuthFailure(:final errorDescription):
        if (!mounted) return;
        setState(() {
          _busy = false;
          _error = errorDescription.isNotEmpty ? errorDescription : 'Could not connect. Please try again.';
        });
    }
  }

  Future<void> _runMessageFlowFromPersistedDraft() async {
    final storage = ref.read(draftStorageServiceProvider);
    final persisted = await storage.read();
    if (persisted == null || persisted.leaId == null || persisted.apiTopics.isEmpty || persisted.senderName.isEmpty) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Something went wrong restoring your draft. Please start again.';
      });
      return;
    }

    await ref
        .read(messageFlowNotifierProvider.notifier)
        .startFlow(
          localElectoralArea: persisted.leaId!,
          intent: persisted.intent,
          topics: persisted.apiTopics,
          proposals: persisted.proposals,
          subject: persisted.subject,
          body: persisted.body,
          senderName: persisted.senderName,
          templateVariants: persisted.templateVariants,
        );
    await storage.clear();

    if (!mounted) return;
    context.go('/result');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const AppBanner()),
      body: Column(
        children: [
          const StepProgressIndicator(currentStep: 5, totalSteps: 5, label: 'Connect your email'),
          Expanded(
            child: Center(
              child: _busy
                  ? const LoadingView()
                  : SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_error != null) ...[ErrorBanner(message: _error!), const SizedBox(height: 16)],
                            const Text('Connect the email account you want to send from.'),
                            const SizedBox(height: 16),
                            const _WhatYouAreAgreeingTo(),
                            const SizedBox(height: 24),
                            FilledButton(
                              onPressed: () => _pickProviderAndConnect(context),
                              child: const Text('Connect email'),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickProviderAndConnect(BuildContext context) async {
    final provider = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.mail_outline),
              title: const Text('Google'),
              onTap: () => Navigator.of(sheetContext).pop('google'),
            ),
            ListTile(
              leading: const Icon(Icons.mail_outline),
              title: const Text('Microsoft'),
              onTap: () => Navigator.of(sheetContext).pop('microsoft'),
            ),
          ],
        ),
      ),
    );
    if (provider == null || !mounted) return; // sheet dismissed without a choice
    await _connect(provider);
  }
}

/// What connecting means, in plain words, before the resident is sent off to
/// Google or Microsoft: the permission asked for is send-only, the message
/// goes straight away (the Review step's "Connect email and send" was their go-ahead), and
/// where the copy and any replies end up.
class _WhatYouAreAgreeingTo extends StatelessWidget {
  const _WhatYouAreAgreeingTo();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _point(
              context,
              Icons.lock_outline,
              "We ask for permission to send email from your account, and nothing else. We can't read your messages or see your contacts.",
            ),
            _point(context, Icons.send_outlined, 'Your message is sent as soon as you connect.'),
            _point(context, Icons.mark_email_read_outlined, 'You get a copy, and any replies come to your inbox.'),
            _point(
              context,
              Icons.info_outline,
              'Works with Google (Gmail) and Microsoft (Outlook, Hotmail) accounts.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _point(BuildContext context, IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
