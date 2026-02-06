extension ExtendedIterable<E> on Iterable<E> {
  /// Like Iterable<T>.map but callback have index as second argument
  Iterable<T> mapIndexed<T>(T Function(E e, int i) f) {
    int i = 0;
    return map((e) => f(e, i++));
  }

  void forEachIndexed(void Function(E e, int i) f) {
    int i = 0;
    forEach((e) => f(e, i++));
  }

  num sum(num Function(E item) element) {
    num total = 0;
    forEach((E e) {
      total += element(e);
    });
    return total;
  }

  num sumWhere(bool Function(E item) where) {
    num total = 0;
    forEach((E e) {
      if (where((e))) {
        total += 1;
      }
    });
    return total;
  }
}

extension MapX<K, V> on Map<K, V> {
  Map<K, V> removeNull() {
    removeWhere((K key, V value) => key == null || value == null);
    return this;
  }

  Map<K, V> removeNullAndEmpty() {
    removeWhere(
        (K key, V value) => key == null || value == null || (value is String && value.isEmpty) || (value is Map && value.isEmpty));
    return this;
  }
}

extension Unique<E, Id> on List<E> {
  List<E> uniqueBy(Id Function(E element) id) {
    final Set ids = <Id>{};
    List<E> list = this;
    list.retainWhere((x) => ids.add(id(x)));
    return list;
  }
}