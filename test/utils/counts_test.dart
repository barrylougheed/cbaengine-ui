import 'package:app/utils/counts.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('one is singular, everything else (including none) is plural', () {
    expect(countOf(1, 'councillor'), '1 councillor');
    expect(countOf(6, 'councillor'), '6 councillors');
    expect(countOf(0, 'area'), '0 areas');
  });

  test('an irregular plural can be given', () {
    expect(countOf(2, 'person', 'people'), '2 people');
    expect(countOf(1, 'person', 'people'), '1 person');
  });
}
