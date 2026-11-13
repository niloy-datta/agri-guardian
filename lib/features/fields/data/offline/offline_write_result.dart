/// Represents the outcome of creating or updating a field or crop cycle.
///
/// When online, [synced] carries the server-confirmed domain object returned
/// by FastAPI.
///
/// When offline or when network failure occurs, [queued] carries the durable
/// mutation ID stored in the local outbox. Unsynced local submissions MUST NOT
/// synthesize fake server IDs, fake areas, or fake centroids.
sealed class OfflineWriteResult<T> {
  const OfflineWriteResult();

  factory OfflineWriteResult.synced(T value, {String? message}) =
      SyncedResult<T>;
  factory OfflineWriteResult.queued({required String tempId, String? message}) =
      QueuedResult<T>;

  bool get isSynced => this is SyncedResult<T>;
  bool get isQueued => this is QueuedResult<T>;

  T? get syncedValue => isSynced ? (this as SyncedResult<T>).value : null;
  T? get data => syncedValue;

  String? get mutationId =>
      isQueued ? (this as QueuedResult<T>).tempId : null;
  String? get tempId => mutationId;

  String? get message => isSynced
      ? (this as SyncedResult<T>).message
      : (this as QueuedResult<T>).message;
}

class SyncedResult<T> extends OfflineWriteResult<T> {
  final T value;
  final String? message;
  const SyncedResult(this.value, {this.message});
}

class QueuedResult<T> extends OfflineWriteResult<T> {
  final String tempId;
  final String? message;
  const QueuedResult({required this.tempId, this.message});
}
