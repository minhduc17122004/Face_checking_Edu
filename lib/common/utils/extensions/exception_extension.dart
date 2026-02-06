extension ExceptionX on Exception {
  String getMessage() {
    if (toString().contains('Exception: ')) {
      return toString().substring('Exception: '.length);
    }
    return toString();
  }
}
