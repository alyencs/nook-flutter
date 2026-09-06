/// Date formatting, in the one shape the mockup draws: "July 15, 2025".
///
/// Small enough not to be worth a package.
String formatLongDate(DateTime date) {
  const months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}
