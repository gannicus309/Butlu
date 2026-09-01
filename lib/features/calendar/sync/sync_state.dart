/// Per-source bookkeeping for incremental sync. Persisted (Milestone 2) so a
/// foreground sync can use Outlook's cheap delta query instead of a full
/// window re-pull; iOS has no delta concept so its bounds are just the pull
/// window.
class SyncState {
  final DateTime? outlookLastSyncedAt;
  final String? outlookDeltaLink;
  final DateTime? iosLastSyncedAt;

  const SyncState({
    this.outlookLastSyncedAt,
    this.outlookDeltaLink,
    this.iosLastSyncedAt,
  });

  SyncState copyWith({
    DateTime? outlookLastSyncedAt,
    String? outlookDeltaLink,
    DateTime? iosLastSyncedAt,
  }) {
    return SyncState(
      outlookLastSyncedAt: outlookLastSyncedAt ?? this.outlookLastSyncedAt,
      outlookDeltaLink: outlookDeltaLink ?? this.outlookDeltaLink,
      iosLastSyncedAt: iosLastSyncedAt ?? this.iosLastSyncedAt,
    );
  }
}
