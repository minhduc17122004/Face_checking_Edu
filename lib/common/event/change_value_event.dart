class ChangeValueEvent<T> {
  late final T? value;

  void withValue(T? value) {
    this.value = value;
  }
}