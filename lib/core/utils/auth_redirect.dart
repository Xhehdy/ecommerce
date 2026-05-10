String? normalizeAuthRedirectUrl(String? rawUrl) {
  final value = rawUrl?.trim() ?? '';
  if (value.isEmpty) {
    return null;
  }
  return value;
}

