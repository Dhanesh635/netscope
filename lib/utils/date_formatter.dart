import 'package:intl/intl.dart';

String formatSessionDateTime(DateTime dt) {
  // e.g. "Jun 03, 2026 - 15:05"
  final format = DateFormat("MMM dd, yyyy - HH:mm");
  return format.format(dt);
}
