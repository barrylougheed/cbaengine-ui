import 'package:equatable/equatable.dart';

import 'campaign_summary.dart';
import 'council.dart';
import 'lea.dart';
import 'message_intent.dart';
import 'topic_summary.dart';

/// The text the server marks as still to be filled in. The API refuses any
/// message containing it, so the app does not let the resident continue.
const unfinishedTextMarker = '[[';

/// The longest name the API accepts for the sign-off.
const maxSenderNameLength = 100;

/// Where the subject's wording is kept among the wording the server chose
/// ({issue id: opener id, "_subject": subject id}). Starts with an underscore,
/// which no id can, so it can never be mistaken for an issue.
const subjectVariantKey = '_subject';

/// The in-progress message the user is building — held in
/// draftNotifierProvider as the user moves through the email (issues and
/// proposals, their own words, or a campaign) -> council -> LEA -> review.
/// Nothing here is sent to the backend until /connect's auto-chain (create ->
/// confirm -> send) runs, so this is pure client-side state (apart from asking
/// the server for the text of issues and campaigns).
class Draft extends Equatable {
  const Draft({
    this.council,
    this.lea,
    this.intent = MessageIntent.issues,
    this.issues = const [],
    this.ticked = const {},
    this.campaign,
    this.templateVariants = const {},
    this.footer,
    this.senderName = '',
    this.subject = '',
    this.body = '',
    this.composedSubject = '',
    this.composedBody = '',
    this.revision = 0,
  });

  final Council? council;
  final Lea? lea;

  /// What kind of email this is: about issues, the resident's own words, or a campaign.
  final MessageIntent intent;

  /// The issues chosen (issues email), in the issue list's order.
  final List<TopicSummary> issues;

  /// Issue id -> ids of the proposals ticked for it. An issue that is chosen
  /// but has nothing ticked yet has an empty list.
  final Map<String, List<String>> ticked;

  /// The campaign chosen (campaign email).
  final CampaignSummary? campaign;

  /// The wording the server chose: issue id -> opener id and "_subject" ->
  /// subject id (issues), or campaign id -> variant id (campaign). Includes
  /// ones for issues since un-ticked, so ticking one again does not re-roll it.
  final Map<String, String> templateVariants;

  /// Added by the server under the sign-off; only for issue and campaign emails.
  final String? footer;

  /// Signs off the email; typed by the resident.
  final String senderName;

  final String subject;
  final String body;

  /// The subject and body exactly as the server composed them, to tell
  /// whether the resident has since edited them.
  final String composedSubject;
  final String composedBody;

  /// Goes up whenever the text is replaced from outside the text fields
  /// (issues or campaign composed, kind of email changed), so the screen knows
  /// to refill them.
  final int revision;

  Draft copyWith({
    Council? council,
    bool clearLea = false,
    Lea? lea,
    MessageIntent? intent,
    List<TopicSummary>? issues,
    Map<String, List<String>>? ticked,
    CampaignSummary? campaign,
    bool clearCampaign = false,
    Map<String, String>? templateVariants,
    String? footer,
    bool clearFooter = false,
    String? senderName,
    String? subject,
    String? body,
    String? composedSubject,
    String? composedBody,
    int? revision,
  }) {
    return Draft(
      council: council ?? this.council,
      lea: clearLea ? null : (lea ?? this.lea),
      intent: intent ?? this.intent,
      issues: issues ?? this.issues,
      ticked: ticked ?? this.ticked,
      campaign: clearCampaign ? null : (campaign ?? this.campaign),
      templateVariants: templateVariants ?? this.templateVariants,
      footer: clearFooter ? null : (footer ?? this.footer),
      senderName: senderName ?? this.senderName,
      subject: subject ?? this.subject,
      body: body ?? this.body,
      composedSubject: composedSubject ?? this.composedSubject,
      composedBody: composedBody ?? this.composedBody,
      revision: revision ?? this.revision,
    );
  }

  /// The topic ids the API expects: the chosen issues, the campaign's id, or
  /// "custom" for an email the resident writes themselves.
  List<String> get apiTopics => switch (intent) {
    MessageIntent.own => const [customTopicId],
    MessageIntent.issues => [for (final issue in issues) issue.id],
    MessageIntent.campaign => [if (campaign != null) campaign!.id],
  };

  /// The ticked proposals of the chosen issues only: the API rejects any others.
  Map<String, List<String>> get proposalsInUse {
    if (intent != MessageIntent.issues) return const {};
    return {for (final issue in issues) issue.id: ticked[issue.id] ?? const <String>[]};
  }

  /// The wording of what is being sent only: the API rejects any other.
  Map<String, String> get variantsInUse {
    switch (intent) {
      case MessageIntent.own:
        return const {};
      case MessageIntent.issues:
        return {
          for (final issue in issues)
            if (templateVariants.containsKey(issue.id)) issue.id: templateVariants[issue.id]!,
          if (templateVariants.containsKey(subjectVariantKey)) subjectVariantKey: templateVariants[subjectVariantKey]!,
        };
      case MessageIntent.campaign:
        final chosen = campaign;
        if (chosen == null || !templateVariants.containsKey(chosen.id)) return const {};
        return {chosen.id: templateVariants[chosen.id]!};
    }
  }

  /// Issues chosen and at least one proposal ticked for each of them: only then
  /// is there text to show.
  bool get selectionComplete => issues.isNotEmpty && issues.every((issue) => (ticked[issue.id] ?? const []).isNotEmpty);

  /// True when the resident has typed or changed text that would be lost if
  /// the issues, the campaign or the kind of email changed.
  bool get hasEditedText {
    if (intent == MessageIntent.own) return subject.trim().isNotEmpty || body.trim().isNotEmpty;
    return subject != composedSubject || body != composedBody;
  }

  bool get hasUnfinishedText => subject.contains(unfinishedTextMarker) || body.contains(unfinishedTextMarker);

  /// One line, 1 to [maxSenderNameLength] characters (the API's rule).
  bool get hasValidSenderName {
    final name = senderName.trim();
    return name.isNotEmpty && name.length <= maxSenderNameLength && !_lineBreakOrControl.hasMatch(name);
  }

  /// What the email is about has been chosen: nothing to choose for the
  /// resident's own words, proposals ticked for every issue, or a campaign.
  bool get hasChosenContent => switch (intent) {
    MessageIntent.own => true,
    MessageIntent.issues => selectionComplete,
    MessageIntent.campaign => campaign != null,
  };

  /// Everything the first step has to produce: what the email is about, its
  /// text, and the name. The area comes next.
  bool get isContentReady =>
      hasChosenContent &&
      hasValidSenderName &&
      subject.trim().isNotEmpty &&
      body.trim().isNotEmpty &&
      !hasUnfinishedText;

  bool get isReadyToReview => lea != null && isContentReady;

  @override
  List<Object?> get props => [
    council,
    lea,
    intent,
    issues,
    ticked,
    campaign,
    templateVariants,
    footer,
    senderName,
    subject,
    body,
    composedSubject,
    composedBody,
    revision,
  ];
}

// Control characters, and the two Unicode line/paragraph separators, which
// would let a name break out of its single line in the sign-off.
final _lineBreakOrControl = RegExp(r'[\u0000-\u001F\u007F  ]');
