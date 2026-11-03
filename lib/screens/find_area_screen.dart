import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/council.dart';
import '../models/place_match.dart';
import '../providers/draft/draft_notifier.dart';
import '../providers/reference_data/reference_data_providers.dart';
import '../utils/counts.dart';
import '../widgets/app_banner.dart';
import '../widgets/error_banner.dart';
import '../widgets/loading_view.dart';

/// "Find your area": for a resident who does not know their council or Local
/// Electoral Area. They type the town, village or suburb they live in, we show
/// the area(s) it is in, and picking one carries straight on to writing the
/// message (it chooses the council and the area, as the two list screens do).
///
/// A town split between two areas (Athlone, either side of the Shannon) shows
/// both, so they pick the one their address is in. What they type goes to the
/// API in a POST body, never the URL, since someone may type their address.
class FindAreaScreen extends ConsumerStatefulWidget {
  const FindAreaScreen({super.key});

  @override
  ConsumerState<FindAreaScreen> createState() => _FindAreaScreenState();
}

class _FindAreaScreenState extends ConsumerState<FindAreaScreen> {
  /// How long to wait after the last key press before searching, so typing a
  /// word does not search once per letter.
  static const _pause = Duration(milliseconds: 350);
  static const _minLength = 2;

  final _controller = TextEditingController();
  Timer? _timer;
  String _query = '';

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    _timer?.cancel();
    _timer = Timer(_pause, () {
      if (mounted) setState(() => _query = text.trim());
    });
    // Clearing the box clears the results straight away.
    if (text.trim().isEmpty) setState(() => _query = '');
  }

  void _clear() {
    _timer?.cancel();
    _controller.clear();
    setState(() => _query = '');
  }

  void _choose(PlaceMatch match) {
    final draft = ref.read(draftNotifierProvider.notifier);
    draft.selectCouncil(Council(id: match.councilId, name: match.lea.council));
    draft.selectLea(match.lea);
    context.push('/compose');
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    return Scaffold(
      appBar: AppBar(title: const AppBanner()),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Align(alignment: Alignment.centerLeft, child: Text('Find your area', style: textTheme.titleLarge)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              controller: _controller,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Your town, village or suburb',
                prefixIcon: const Icon(Icons.place_outlined),
                suffixIcon: _controller.text.isEmpty
                    ? null
                    : IconButton(icon: const Icon(Icons.clear), tooltip: 'Clear', onPressed: _clear),
              ),
              textInputAction: TextInputAction.search,
              onChanged: (text) {
                _onChanged(text);
                setState(() {}); // shows or hides the clear button
              },
            ),
          ),
          Expanded(child: _results(context)),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Text(
              'Place names and area boundaries © Tailte Éireann (CC BY 4.0).',
              style: textTheme.bodySmall?.copyWith(color: muted),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _results(BuildContext context) {
    if (_query.length < _minLength) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Type the town, village or suburb where you live, for example Swords, Rathmines or Athlone. '
          'Just the place name, not your full address.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      );
    }

    return ref
        .watch(placeSearchProvider(_query))
        .when(
          loading: () => const LoadingView(),
          error: (error, _) => ErrorBanner(
            message: 'Could not search. Please check your connection and try again.',
            onRetry: () => ref.invalidate(placeSearchProvider(_query)),
          ),
          data: (found) => found.results.isEmpty ? _noMatch(context) : _matches(context, found),
        );
  }

  Widget _noMatch(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('We could not find "$_query". Try the nearest bigger town, or choose your council from the list.'),
          const SizedBox(height: 16),
          FilledButton.tonal(
            onPressed: () => context.go('/council'),
            child: const Text('Choose from the list of councils'),
          ),
        ],
      ),
    );
  }

  Widget _matches(BuildContext context, PlaceSearchResults found) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(color: muted);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      children: [
        if (found.results.length > 1 && !found.isCutShort)
          Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('Pick the area your address is in.', style: style)),
        if (found.isCutShort)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Showing ${found.results.length} of ${found.total} matches. Type more of the name to narrow it down.',
              style: style,
            ),
          ),
        for (final match in found.results)
          Card(
            child: ListTile(
              title: Text(match.place),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${match.lea.name}, ${match.lea.council}'),
                  Text(countOf(match.lea.councillors.length, 'councillor')),
                  Text(
                    match.lea.councillors.map((councillor) => councillor.name).join(', '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _choose(match),
            ),
          ),
      ],
    );
  }
}
