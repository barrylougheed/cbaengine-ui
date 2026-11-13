import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/reference_data/reference_data_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/app_footer.dart';
import '../widgets/app_header.dart';
import '../widgets/choice_card.dart';
import '../widgets/content_width.dart';

/// The app's true root: reached before any specific flow starts.
///
/// From the top it is a deep olive hero (the headline, the tagline and the
/// three things you can do), a thin clay rule, the size of the service in large
/// numbers (councillors, councils and areas), "How it works" in three steps, a
/// tinted note saying what you need before you start, and the footer.
///
/// "Craft an email" (issues, or your own words) and "Campaigns" are the live
/// entry points (feature 1). The third card is a placeholder for feature 3
/// (URLGeneration, see AGENTS.md) so the layout already has room for it once
/// that feature is specified and built, rather than needing another
/// restructure then.
///
/// The notes say, before anyone starts, that one email can be sent a day and
/// which email accounts can send (so an iCloud or Yahoo user does not find out
/// at the last step).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  /// The width at which things that sit side by side (the three options, the
  /// three steps) stop being stacked one under another, as on a phone.
  static const double _sideBySideFrom = 760;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    // Loading or failing to load the councils only costs the numbers below.
    final councils = ref.watch(councilsProvider).value ?? const [];
    final councillors = councils.fold<int>(0, (sum, council) => sum + council.councillorCount);
    final areas = councils.fold<int>(0, (sum, council) => sum + council.areaCount);

    return Scaffold(
      appBar: const AppHeader(),
      // The page scrolls. Its content is at least as tall as the window, and
      // the footer is spread to the bottom of that, so on a tall screen the
      // footer sits at the foot of the window and on a short one it simply
      // follows the content. (SliverFillRemaining would do this too, but it
      // measures its child's intrinsic height, which ContentWidth's
      // LayoutBuilder cannot give.)
      body: LayoutBuilder(
        builder: (context, viewport) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: viewport.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Hero(textTheme: textTheme),
                    // The one warm accent: a thin clay rule under the hero.
                    const SizedBox(height: 4, child: ColoredBox(color: AppColors.clay)),
                    if (councillors > 0) _Stats(councillors: councillors, councils: councils.length, areas: areas),
                    _HowItWorks(textTheme: textTheme),
                    const _Notes(),
                    const SizedBox(height: 48),
                  ],
                ),
                const AppFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Lays [children] out in a row of equal columns where there is room, and one
/// under another where there is not (a phone). Used for the options and the steps.
class _Responsive extends StatelessWidget {
  const _Responsive({required this.children});

  final List<Widget> children;

  static const double _gap = 16;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < HomeScreen._sideBySideFrom) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(height: _gap), children[i]],
            ],
          );
        }
        // IntrinsicHeight makes the cards equally tall, whatever their text.
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(width: _gap),
                Expanded(child: children[i]),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// The deep olive band at the top: headline, tagline, and the three options.
class _Hero extends StatelessWidget {
  const _Hero({required this.textTheme});

  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    // The headline is a little smaller on a phone so a long word never has to
    // be wider than the screen.
    final isPhone = MediaQuery.sizeOf(context).width < 600;

    return ColoredBox(
      key: const Key('home-hero'),
      color: AppColors.deepOlive,
      child: ContentWidth(
        maxWidth: ContentWidth.wide,
        child: Padding(
          padding: EdgeInsets.fromLTRB(0, isPhone ? 32 : 56, 0, isPhone ? 32 : 56),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Email your local councillors in minutes',
                style: textTheme.headlineLarge?.copyWith(color: AppColors.white, fontSize: isPhone ? 30 : 40),
              ),
              const SizedBox(height: 12),
              Text(
                'Hold yourself accountable for holding power accountable.',
                style: textTheme.titleMedium?.copyWith(color: AppColors.softOlive, fontStyle: FontStyle.italic),
              ),
              SizedBox(height: isPhone ? 28 : 40),
              Text('What would you like to do?', style: textTheme.titleLarge?.copyWith(color: AppColors.white)),
              const SizedBox(height: 4),
              Text(
                'Pick an option below to get started.',
                style: textTheme.bodyMedium?.copyWith(color: AppColors.softOlive),
              ),
              const SizedBox(height: 20),
              _Responsive(
                children: [
                  ChoiceCard(
                    icon: Icons.edit_outlined,
                    title: 'Craft an email',
                    subtitle: 'Raise issues with your local councillors, or write your own message.',
                    onTap: () => context.push('/craft'),
                  ),
                  ChoiceCard(
                    icon: Icons.campaign_outlined,
                    title: 'Campaigns',
                    subtitle: 'Back a campaign by emailing your local councillors.',
                    onTap: () => context.push('/campaigns'),
                  ),
                  const ChoiceCard(
                    icon: Icons.link_outlined,
                    title: 'Create a campaign link',
                    subtitle: 'Share a pre-filled message for others to send.',
                    badge: 'Coming soon',
                    onTap: null,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// How big the service is, in large numerals: councillors, councils and areas
/// you can write to. Only built when the councils loaded.
class _Stats extends StatelessWidget {
  const _Stats({required this.councillors, required this.councils, required this.areas});

  final int councillors;
  final int councils;
  final int areas;

  @override
  Widget build(BuildContext context) {
    return ContentWidth(
      maxWidth: ContentWidth.wide,
      child: Padding(
        padding: const EdgeInsets.only(top: 40),
        child: DecoratedBox(
          key: const Key('home-stats'),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.hairline),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
            child: Row(
              children: [
                Expanded(
                  child: _Stat(value: councillors, singular: 'councillor', plural: 'councillors'),
                ),
                const _StatDivider(),
                Expanded(
                  child: _Stat(value: councils, singular: 'council', plural: 'councils'),
                ),
                const _StatDivider(),
                Expanded(
                  child: _Stat(value: areas, singular: 'local area', plural: 'local areas'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.singular, required this.plural});

  final int value;
  final String singular;
  final String plural;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$value',
          style: textTheme.displaySmall?.copyWith(color: AppColors.deepOlive, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          value == 1 ? singular : plural,
          textAlign: TextAlign.center,
          style: textTheme.bodyMedium?.copyWith(color: AppColors.mutedText),
        ),
      ],
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) =>
      const SizedBox(width: 1, height: 48, child: ColoredBox(color: AppColors.hairline));
}

/// "How it works": three numbered cards, in the order the flow runs.
class _HowItWorks extends StatelessWidget {
  const _HowItWorks({required this.textTheme});

  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return ContentWidth(
      maxWidth: ContentWidth.wide,
      child: Padding(
        padding: const EdgeInsets.only(top: 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('How it works', style: textTheme.headlineSmall),
            const SizedBox(height: 20),
            const _Responsive(
              children: [
                _Step(number: 1, title: 'Write', text: 'Craft an email, or back a campaign.'),
                _Step(
                  number: 2,
                  title: 'Choose and review',
                  text: 'Choose your council and area, then review your message and who it goes to.',
                ),
                _Step(
                  number: 3,
                  title: 'Connect and send',
                  text: 'Connect your Gmail or Outlook account. Your message is sent straight away, from your own account, with a copy to you.',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.title, required this.text});

  final int number;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The number sits in a deep olive disc so it reads as a step marker.
            DecoratedBox(
              decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.deepOlive),
              child: SizedBox(
                width: 32,
                height: 32,
                child: Center(
                  child: Text(
                    '$number',
                    style: textTheme.labelLarge?.copyWith(color: AppColors.white, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(title, style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(text, style: textTheme.bodyMedium?.copyWith(color: AppColors.mutedText)),
          ],
        ),
      ),
    );
  }
}

/// What to know before you start: a tinted panel with the two limits.
class _Notes extends StatelessWidget {
  const _Notes();

  @override
  Widget build(BuildContext context) {
    return ContentWidth(
      maxWidth: ContentWidth.wide,
      child: Padding(
        padding: const EdgeInsets.only(top: 32),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.mist,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.hairline),
          ),
          child: const Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Note('You can send one email a day.'),
                SizedBox(height: 12),
                _Note("You'll need a Gmail, Outlook or Hotmail account to send."),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: Icon(Icons.info_outline, size: 20, color: AppColors.linkOlive),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(text)),
      ],
    );
  }
}
