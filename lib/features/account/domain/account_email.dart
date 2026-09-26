final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

String? normalizeAccountEmail(String input) {
  final email = input.trim();
  if (email.length > 254 || !_emailPattern.hasMatch(email)) return null;
  return email;
}
