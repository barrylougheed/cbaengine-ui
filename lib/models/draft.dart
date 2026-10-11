import 'package:equatable/equatable.dart';

import 'council.dart';
import 'lea.dart';
import 'topic_summary.dart';

/// How the resident is writing their email.
enum ComposeMode {
  /// Starting from one or more pre-defined topics.
  topics,

  /// Writing everything themselves.
  ownWords,
}

/// The text the server marks as still to be filled in. The API refuses any
/// message containing it, so the app does not let the resident continue.
const unfinishedTextMarker = '[[';

/// The longest name the API accepts for the sign-off.
const maxSenderNameLength = 100;

/// The in-progress message the user is building — held in
/// draftNotifierProvider as the user moves through council -> LEA ->
/// compose -> review. Nothing here is sent to the backend until
/// /connect's auto-chain (create -> confirm -> send) runs, so this is
/// pure client-side state (apart from asking the server for topic text).
class Draft extends Equatable {
  const Draft({
    this.council,
    this.lea,
    this.mode = ComposeMode.topics,
    this.topics = const [],
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
  final ComposeMode mode;

  /// The topics chosen (topics mode), in the topic list's order.
  final List<TopicSummary> topics;

  /// Topic id -> variant id for every topic composed this session, including
  /// ones since un-ticked, so ticking a topic again does not re-roll it.
  final Map<String, String> templateVariants;

  /// Added by the server under the sign-off; only for topic-based emails.
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
  /// (topics composed, mode changed), so the screen knows to refill them.
  final int revision;

  Draft copyWith({
    Council? council,
    bool clearLea = false,
    Lea? lea,
    ComposeMode? mode,
    List<TopicSummary>? topics,
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
      mode: mode ?? this.mode,
      topics: topics ?? this.topics,
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

  /// The topic ids the API expects: the chosen topics, or "custom" for an
  /// email the resident writes themselves.
  List<String> get apiTopics => mode == ComposeMode.ownWords ? const [customTopicId] : [for (final t in topics) t.id];

  /// The variants of the chosen topics only: the API rejects any others.
  Map<String, String> get variantsInUse {
    if (mode == ComposeMode.ownWords) return const {};
    return {
      for (final topic in topics)
        if (templateVariants.containsKey(topic.id)) topic.id: templateVariants[topic.id]!,
    };
  }

  /// True when the resident has typed or changed text that would be lost if
  /// the topics or the mode changed.
  bool get hasEditedText {
    if (mode == ComposeMode.ownWords) return subject.trim().isNotEmpty || body.trim().isNotEmpty;
    return subject != composedSubject || body != composedBody;
  }

  bool get hasUnfinishedText => subject.contains(unfinishedTextMarker) || body.contains(unfinishedTextMarker);

  /// One line, 1 to [maxSenderNameLength] characters (the API's rule).
  bool get hasValidSenderName {
    final name = senderName.trim();
    return name.isNotEmpty && name.length <= maxSenderNameLength && !_lineBreakOrControl.hasMatch(name);
  }

  bool get isReadyToReview =>
      lea != null &&
      hasValidSenderName &&
      subject.trim().isNotEmpty &&
      body.trim().isNotEmpty &&
      !hasUnfinishedText &&
      (mode == ComposeMode.ownWords || topics.isNotEmpty);

  @override
  List<Object?> get props => [
    council,
    lea,
    mode,
    topics,
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

final _lineBreakOrControl = RegExp(r'[\u0000-\u001F\u007F  ]');
