import 'package:flutter/material.dart';

import '../models/style_summary.dart';
import '../models/topic_summary.dart';
import '../theme/app_theme.dart';

/// A tinted panel saying what an issues email is about: its topics, and (once
/// one is chosen) its letter style, each with a link to change it. Shown above
/// the choice of style and above the editor, so the resident always sees what
/// the text they are about to read is for.
class IssueChoiceSummary extends StatelessWidget {
  const IssueChoiceSummary({super.key, required this.topics, this.style, this.onChangeTopics, this.onChangeStyle});

  final List<TopicSummary> topics;

  /// Left out before a style is chosen.
  final StyleSummary? style;

  final VoidCallback? onChangeTopics;
  final VoidCallback? onChangeStyle;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.mist,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Row(
              text: 'Topics: ${topics.map((topic) => topic.title).join(', ')}',
              changeLabel: 'Change topics',
              onChange: onChangeTopics,
            ),
            if (style != null)
              _Row(text: 'Style: ${style!.title}', changeLabel: 'Change style', onChange: onChangeStyle),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.text, required this.changeLabel, required this.onChange});

  final String text;
  final String changeLabel;
  final VoidCallback? onChange;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
        ),
        if (onChange != null) TextButton(onPressed: onChange, child: Text(changeLabel)),
      ],
    );
  }
}
