bool isValidEmail(String email) {
  if (email.isEmpty) return false;
  final RegExp pattern = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );
  return pattern.hasMatch(email.trim());
}

bool isValidPassword(String password) {
  if (password.length < 8 || password.length > 15) return false;
  final bool hasUpper = password.contains(RegExp(r'[A-Z]'));
  final bool hasLower = password.contains(RegExp(r'[a-z]'));
  final bool hasDigit = password.contains(RegExp(r'[0-9]'));
  return hasUpper && hasLower && hasDigit;
}

bool isValidBudget(String input) {
  if (input.isEmpty) return false;
  final double? value = double.tryParse(input);
  if (value == null) return false;
  return value > 0;
}

bool isValidRadius(double km) {
  return km >= 1.0 && km <= 50.0;
}
