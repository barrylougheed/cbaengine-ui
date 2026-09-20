import 'package:app/models/council.dart';
import 'package:app/models/councillor_preview.dart';
import 'package:app/models/draft.dart';
import 'package:app/models/lea.dart';
import 'package:app/providers/draft/draft_notifier.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const council = Council(id: 'fingal-county-council', name: 'Fingal County Council');
  const lea = Lea(
    id: 'fingal-balbriggan',
    name: 'Balbriggan',
    council: 'Fingal County Council',
    councillors: [CouncillorPreview(name: 'A Councillor', party: 'Independent')],
  );

  test('starts empty', () {
    final notifier = DraftNotifier();

    expect(notifier.state, const Draft());
    expect(notifier.state.isReadyToReview, isFalse);
  });

  test('selectCouncil sets the council', () {
    final notifier = DraftNotifier();

    notifier.selectCouncil(council);

    expect(notifier.state.council, council);
  });

  test('selecting a different council clears any already-selected LEA', () {
    final notifier = DraftNotifier();
    notifier.selectCouncil(council);
    notifier.selectLea(lea);

    notifier.selectCouncil(const Council(id: 'dublin-city-council', name: 'Dublin City Council'));

    expect(notifier.state.lea, isNull);
  });

  test('selectLea sets the LEA', () {
    final notifier = DraftNotifier();
    notifier.selectCouncil(council);

    notifier.selectLea(lea);

    expect(notifier.state.lea, lea);
  });

  test('setTopic/setSubject/setBody update their fields independently', () {
    final notifier = DraftNotifier();

    notifier.setTopic('housing');
    notifier.setSubject('Subject');
    notifier.setBody('Body');

    expect(notifier.state.topic, 'housing');
    expect(notifier.state.subject, 'Subject');
    expect(notifier.state.body, 'Body');
  });

  test('isReadyToReview is false until LEA, topic, subject and body are all set', () {
    final notifier = DraftNotifier();
    notifier.selectCouncil(council);
    expect(notifier.state.isReadyToReview, isFalse);

    notifier.selectLea(lea);
    expect(notifier.state.isReadyToReview, isFalse);

    notifier.setTopic('housing');
    expect(notifier.state.isReadyToReview, isFalse);

    notifier.setSubject('Subject');
    expect(notifier.state.isReadyToReview, isFalse);

    notifier.setBody('Body');
    expect(notifier.state.isReadyToReview, isTrue);
  });

  test('isReadyToReview is false for whitespace-only subject/body', () {
    final notifier = DraftNotifier();
    notifier.selectCouncil(council);
    notifier.selectLea(lea);
    notifier.setTopic('housing');
    notifier.setSubject('   ');
    notifier.setBody('   ');

    expect(notifier.state.isReadyToReview, isFalse);
  });

  test('clear resets to an empty draft', () {
    final notifier = DraftNotifier();
    notifier.selectCouncil(council);
    notifier.selectLea(lea);
    notifier.setTopic('housing');
    notifier.setSubject('Subject');
    notifier.setBody('Body');

    notifier.clear();

    expect(notifier.state, const Draft());
  });
}
