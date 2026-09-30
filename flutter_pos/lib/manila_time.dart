class ManilaTime {
  static const Duration _utcOffset = Duration(hours: 8);

  static DateTime now() {
    final local = DateTime.now();
    return DateTime.utc(
      local.year,
      local.month,
      local.day,
      local.hour,
      local.minute,
      local.second,
      local.millisecond,
      local.microsecond,
    );
  }

  static DateTime today() {
    final current = now();
    return DateTime.utc(current.year, current.month, current.day);
  }

  static DateTime? parse(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return null;

    final hasTimezone = RegExp(r'(?:Z|[+-]\d{2}:?\d{2})$', caseSensitive: false)
        .hasMatch(value.trim());
    if (hasTimezone) return parsed.toUtc().add(_utcOffset);

    return DateTime.utc(
      parsed.year,
      parsed.month,
      parsed.day,
      parsed.hour,
      parsed.minute,
      parsed.second,
      parsed.millisecond,
      parsed.microsecond,
    );
  }

  static bool matchesRange(String value, String range, DateTime anchor) {
    final parsed = parse(value);
    if (parsed == null) return true;

    final itemDay = DateTime.utc(parsed.year, parsed.month, parsed.day);
    final anchorDay = DateTime.utc(anchor.year, anchor.month, anchor.day);

    switch (range) {
      case 'Date':
      case 'Today':
        return itemDay == anchorDay;
      case 'This Week':
        final startOfWeek = anchorDay.subtract(Duration(days: anchorDay.weekday - 1));
        return !itemDay.isBefore(startOfWeek) && !itemDay.isAfter(anchorDay);
      case 'Last Week':
        final startOfThisWeek = anchorDay.subtract(Duration(days: anchorDay.weekday - 1));
        final startOfLastWeek = startOfThisWeek.subtract(const Duration(days: 7));
        final endOfLastWeek = startOfThisWeek.subtract(const Duration(days: 1));
        return !itemDay.isBefore(startOfLastWeek) && !itemDay.isAfter(endOfLastWeek);
      case 'This Month':
        return itemDay.year == anchorDay.year && itemDay.month == anchorDay.month;
      case 'Last Month':
        final lastMonth = DateTime.utc(anchorDay.year, anchorDay.month - 1, 1);
        return itemDay.year == lastMonth.year && itemDay.month == lastMonth.month;
      case 'This Year':
        return itemDay.year == anchorDay.year;
      case 'Last Year':
        return itemDay.year == anchorDay.year - 1;
      default:
        return true;
    }
  }

  static String utcIsoFromManilaWallTime(DateTime value) => DateTime.utc(
        value.year,
        value.month,
        value.day,
        value.hour - _utcOffset.inHours,
        value.minute,
        value.second,
        value.millisecond,
        value.microsecond,
      ).toIso8601String();

  static String utcNowIso8601() => utcIsoFromManilaWallTime(DateTime.now());
}