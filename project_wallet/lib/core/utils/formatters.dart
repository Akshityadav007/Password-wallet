String hidePassword(String pw, {int visible = 0}) {
  if (pw.isEmpty) return '';
  if (visible <= 0) return '*' * pw.length;
  return pw.substring(0, visible) + '*' * (pw.length - visible);
}
