String? validateEmail(String? rawEmail) {
  final email = rawEmail?.trim() ?? '';
  if (email.isEmpty) {
    return 'Email is required';
  }
  final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  if (!emailRegex.hasMatch(email)) {
    return 'Enter a valid email';
  }
  return null;
}

String? validateNewPassword(String? rawPassword) {
  final password = rawPassword ?? '';
  if (password.isEmpty) {
    return 'Password is required';
  }
  if (password.length < 8) {
    return 'Password must be at least 8 characters';
  }
  return null;
}

String? validateConfirmPassword(String password, String confirmPassword) {
  if (password != confirmPassword) {
    return 'Passwords do not match';
  }
  return null;
}

