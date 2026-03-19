enum AccountAvatarUpdateStatus {
  initial,
  success,
  failure,
}

class AccountState {
  final String displayName;
  final String displayEmail;
  final String avatarPath;
  final bool isUploadingAvatar;
  final AccountAvatarUpdateStatus avatarUpdateStatus;
  final bool backendSynced;

  const AccountState({
    this.displayName = 'Nguoi dung',
    this.displayEmail = 'user@example.com',
    this.avatarPath = '',
    this.isUploadingAvatar = false,
    this.avatarUpdateStatus = AccountAvatarUpdateStatus.initial,
    this.backendSynced = false,
  });

  AccountState copyWith({
    String? displayName,
    String? displayEmail,
    String? avatarPath,
    bool? isUploadingAvatar,
    AccountAvatarUpdateStatus? avatarUpdateStatus,
    bool? backendSynced,
  }) {
    return AccountState(
      displayName: displayName ?? this.displayName,
      displayEmail: displayEmail ?? this.displayEmail,
      avatarPath: avatarPath ?? this.avatarPath,
      isUploadingAvatar: isUploadingAvatar ?? this.isUploadingAvatar,
      avatarUpdateStatus: avatarUpdateStatus ?? this.avatarUpdateStatus,
      backendSynced: backendSynced ?? this.backendSynced,
    );
  }
}
