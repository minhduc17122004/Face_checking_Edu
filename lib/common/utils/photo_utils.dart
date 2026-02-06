String? getPhotoName(String? url) {
  if (url != null && url.contains('http')) {
    return url.split('/').last.replaceAll('sm_', '');
  }
  return url;
}
