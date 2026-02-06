abstract class DataState<T> {
  const DataState({this.data, this.error});

  final T? data;
  final String? error;
}

class DataSuccess<T> extends DataState<T> {
  const DataSuccess(T? data) : super(data: data);
}

class DataFailed<T> extends DataState<T> {
  const DataFailed(String? error, {int? code})
      : statusCode = code,
        super(error: error);
  final int? statusCode;
}

extension ExtendedList<DataState> on List<DataState> {
  bool get isSuccess {
    return every((DataState element) => element is DataSuccess);
  }
}

extension ExtendedDataState<DataState> on DataState {
  bool get isSuccess => this is DataSuccess;
}
