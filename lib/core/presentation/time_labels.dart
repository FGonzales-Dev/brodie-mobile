import 'package:flutter/material.dart';

/// "8:04 AM" (or "08:04"), in the rider's time zone and clock format.
String clockLabel(BuildContext context, DateTime time) =>
    MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(time.toLocal()));

/// "Sat, Nov 2 · 8:04 AM", e.g. when a ride started.
String dateTimeLabel(BuildContext context, DateTime time) {
  final local = time.toLocal();
  return '${MaterialLocalizations.of(context).formatMediumDate(local)} · ${clockLabel(context, local)}';
}
