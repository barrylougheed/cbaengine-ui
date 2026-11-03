/// "1 councillor", "6 councillors". Pass [plural] where adding an "s" is wrong.
String countOf(int count, String singular, [String? plural]) =>
    '$count ${count == 1 ? singular : (plural ?? '${singular}s')}';
