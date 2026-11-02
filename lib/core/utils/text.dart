/// "1 rider", "3 riders".
String countLabel(int count, String singular, [String? plural]) {
  return '$count ${count == 1 ? singular : plural ?? '${singular}s'}';
}
