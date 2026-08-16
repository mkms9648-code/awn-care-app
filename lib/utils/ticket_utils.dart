/// The app shows doctors a single "ticket" number everywhere — never a raw
/// internal handle. Handles are stored server-side as `t:<n>` (ticket) or
/// `b:<n>` (internal routing marker for the ED→Round handoff, never shown to
/// a doctor). This strips whichever prefix is present so nothing leaks into
/// the UI. See PatientDetailScreen/EncounterCard/report_formatter.
String cleanTicket(String raw) {
  return raw.replaceFirst(RegExp(r'^[tb]:', caseSensitive: false), '');
}
