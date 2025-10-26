// Password strength, input validation

bool isStrongPassword(String pw) {
  if (pw.length < 8) return false;
  final hasDigit = pw.contains(RegExp(r'\d'));
  final hasLetter = pw.contains(RegExp(r'[A-Za-z]'));
  return hasDigit && hasLetter;
}
