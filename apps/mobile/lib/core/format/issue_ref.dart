/// Human issue reference (TASK-05 §5.6): `SA-` + the first 8 hex characters
/// of the issue UUID, upper-cased (`SA-3F9A2C1B`). A label only, never a
/// lookup key; TASK-07 reuses it on the issue detail screen.
String issueRef(String issueId) {
  final hex = issueId.replaceAll('-', '').toUpperCase();
  final head = hex.length >= 8 ? hex.substring(0, 8) : hex.padRight(8, '0');
  return 'SA-$head';
}
