// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'Flutter Riverpod クリーンアーキテクチャ';

  @override
  String get welcomeMessage => 'Flutter Riverpod クリーンアーキテクチャへようこそ';

  @override
  String get home => 'ホーム';

  @override
  String get settings => '設定';

  @override
  String get profile => 'プロフィール';

  @override
  String get darkMode => 'ダークモード';

  @override
  String get lightMode => 'ライトモード';

  @override
  String get systemMode => 'システムモード';

  @override
  String get language => '言語';

  @override
  String get change_language => '言語を変更';

  @override
  String get theme => 'テーマ';

  @override
  String get change_theme => 'テーマを変更';

  @override
  String get notifications => '通知';

  @override
  String get notification_settings => 'Configure notification preferences';

  @override
  String get localization_demo => 'Localization Demo';

  @override
  String get localization_demo_description =>
      'View localization features in action';

  @override
  String get language_settings => 'Language Settings';

  @override
  String get select_your_language => 'Select your preferred language';

  @override
  String get language_explanation =>
      'The selected language will be applied across the entire application';

  @override
  String get localization_assets_demo => 'Localization & Assets Demo';

  @override
  String get current_language => 'Current Language';

  @override
  String get language_code => 'Language code';

  @override
  String get language_name => 'Language name';

  @override
  String get formatting_examples => 'Formatting Examples';

  @override
  String get date_full => 'Date (full)';

  @override
  String get date_short => 'Date (short)';

  @override
  String get time => 'Time';

  @override
  String get currency => 'Currency';

  @override
  String get percent => 'Percent';

  @override
  String get localized_assets => 'Localized Assets';

  @override
  String get localized_assets_explanation =>
      'This section demonstrates how to load different assets based on the selected language. Images, audio, and other resources can be language-specific.';

  @override
  String get image_example => 'Localized Image Example';

  @override
  String get welcome_image_caption =>
      'This image is loaded based on your selected language';

  @override
  String get common_image_example => 'Common Image Example';

  @override
  String get common_image_caption =>
      'This image is the same across all languages';

  @override
  String get logout => 'ログアウト';

  @override
  String get login => 'ログイン';

  @override
  String get email => 'メール';

  @override
  String get password => 'パスワード';

  @override
  String get signIn => 'サインイン';

  @override
  String get register => '登録';

  @override
  String get forgotPassword => 'パスワードをお忘れですか？';

  @override
  String get errorOccurred => 'エラーが発生しました';

  @override
  String get tryAgain => '再試行';

  @override
  String greeting(String name) {
    return 'こんにちは、$nameさん！';
  }

  @override
  String itemCount(num count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.compact(
      locale: localeName,
    );
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countStringアイテム',
      one: '1アイテム',
      zero: 'アイテムなし',
    );
    return '$_temp0';
  }

  @override
  String lastUpdated(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return '最終更新: $dateString';
  }

  @override
  String get browsePeople => 'ユーザー';

  @override
  String get chatDirect => '個人チャット';

  @override
  String get chatGroup => 'グループ';

  @override
  String get chatSupergroup => 'スーパーグループ';

  @override
  String get chatChannel => 'チャンネル';

  @override
  String get chatFallbackTitle => 'チャット';

  @override
  String membersCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 人のメンバー',
    );
    return '$_temp0';
  }

  @override
  String get attachmentProcessing => '処理中…';

  @override
  String get attachmentFailed => 'アップロード失敗';

  @override
  String get attachmentOpenFailed => 'このファイルを開けませんでした';

  @override
  String get imageLoadFailed => '画像を表示できません';

  @override
  String get close => '閉じる';

  @override
  String get addReaction => 'リアクションを追加';

  @override
  String get reactionsDisabled => 'このチャットではリアクションが無効です';

  @override
  String reactionLimitReached(Object limit) {
    return '1 メッセージにつき最大 $limit 件のリアクションを追加できます';
  }

  @override
  String get messageNotFound => 'そのメッセージは利用できません';

  @override
  String get chatInfo => 'チャット情報';

  @override
  String get chatName => '名前';

  @override
  String get chatDescription => '説明';

  @override
  String get chatPublic => '公開チャット';

  @override
  String get chatPublicHint => 'リンクを知っている人は誰でも参加できます';

  @override
  String get chatAdminOnly => '管理者のみ';

  @override
  String get chatAdminOnlyHint => '管理者のみ投稿できます';

  @override
  String get chatSlowMode => '低速モード';

  @override
  String get chatSlowModeOff => 'オフ';

  @override
  String chatSlowModeSeconds(Object seconds) {
    return 'メッセージ間隔 $seconds 秒';
  }

  @override
  String get chatReactionsMode => 'リアクション';

  @override
  String get chatReactionsAll => '全員・すべての絵文字';

  @override
  String get chatReactionsSome => '選択した絵文字のみ';

  @override
  String get chatReactionsNone => 'オフ';

  @override
  String get leaveChat => 'チャットを退出';

  @override
  String get leaveChatConfirm => 'このチャットを退出しますか？メッセージは届かなくなります。';

  @override
  String get leaveChatOwnerBlocked => '作成者は退出できません。チャットを削除してください。';

  @override
  String get deleteChat => 'チャットを削除';

  @override
  String get deleteChatConfirm => '全員のためにこのチャットを削除しますか？取り消せません。';

  @override
  String get saveChanges => '保存';

  @override
  String get cancel => 'キャンセル';

  @override
  String get chatSettingsSaved => 'チャットを更新しました';

  @override
  String get viewMembers => 'メンバー';

  @override
  String get messageEdited => '編集済み';

  @override
  String get messageReply => '返信';

  @override
  String get messageForward => '転送';

  @override
  String get messageEdit => '編集';

  @override
  String get messageDelete => '削除';

  @override
  String get messageSelect => '選択';

  @override
  String get messageReact => 'React';

  @override
  String get messageCopy => 'Copy text';

  @override
  String get messageCopied => 'Copied';

  @override
  String get linkOpenFailed => 'Nothing here can open that link';

  @override
  String get messageDetails => 'Details';

  @override
  String replyingTo(String author) {
    return 'Replying to $author';
  }

  @override
  String forwardedFrom(String author) {
    return 'Forwarded from $author';
  }

  @override
  String get forwardedMessage => 'Forwarded message';

  @override
  String get detailsSentAt => 'Sent';

  @override
  String get detailsAuthor => 'From';

  @override
  String get detailsSequence => 'Number in chat';

  @override
  String get detailsEdited => 'Edited';

  @override
  String get detailsEditedYes => 'Yes';

  @override
  String get detailsDelivery => 'Delivery';

  @override
  String get detailsAttachments => 'Attachments';

  @override
  String get backToLatest => '最新のメッセージに戻る';

  @override
  String get messageRead => '既読';

  @override
  String get messageSent => '送信済み';

  @override
  String get dateToday => '今日';

  @override
  String get dateYesterday => '昨日';

  @override
  String get unreadMessages => '未読メッセージ';

  @override
  String get noMessagesYet => 'メッセージはまだありません';

  @override
  String get editingMessage => 'メッセージを編集中';

  @override
  String get scrollToBottom => '最新のメッセージへ移動';

  @override
  String newMessagesBelow(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count new messages below',
      one: '1 new message below',
      zero: 'No new messages',
    );
    return '$_temp0';
  }

  @override
  String get connectionReconnecting => 'Reconnecting…';

  @override
  String get connectionOffline => 'Offline — pull to refresh';

  @override
  String get attachmentFallbackLabel => 'Attachment';

  @override
  String get composerJoinToSend => 'Join this chat to send messages';

  @override
  String get composerBanned => 'You are banned from this chat';

  @override
  String get composerMuted => 'You are muted in this chat';

  @override
  String get composerAdminsOnly => 'Only admins can post in this chat';

  @override
  String get composerNoPermission =>
      'You do not have permission to send messages here';

  @override
  String attachmentSelection(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files',
      one: '1 file',
    );
    return '$_temp0, $size';
  }

  @override
  String get attachmentReady => 'Ready to send';

  @override
  String attachMediaLimits(int count, String size) {
    return 'Up to $count, $size each';
  }

  @override
  String attachDocumentLimits(String size) {
    return 'One file, up to $size';
  }

  @override
  String get messageDensity => 'メッセージの余白';

  @override
  String get densityCompact => 'コンパクト';

  @override
  String get densityCozy => '標準';

  @override
  String get densityComfortable => 'ゆったり';

  @override
  String get voiceSlideToCancel => '左にスワイプで取消、上で固定';

  @override
  String get voiceReleaseToCancel => '離すと取り消し';

  @override
  String get voiceRecordingLocked => '録音中 — 完了したら送信をタップ';

  @override
  String get voiceLimitReached => '最大の長さに達しました';

  @override
  String get voicePermissionDenied => 'マイクへのアクセスが無効です';

  @override
  String get voiceMessage => 'ボイスメッセージ';

  @override
  String get voicePlay => 'ボイスメッセージを再生';

  @override
  String get voicePause => 'ボイスメッセージを一時停止';

  @override
  String get voiceUnavailable => '利用できません';

  @override
  String get voiceNotListened => '未再生';

  @override
  String voiceSpeedLabel(String speed) {
    return '再生速度 $speed';
  }

  @override
  String get voiceRecording => '録音中';

  @override
  String voiceTimeLeft(String time) {
    return '残り $time';
  }

  @override
  String get voiceCancelRecording => 'キャンセル';

  @override
  String get voiceSendRecording => 'ボイスメッセージを送信';

  @override
  String get attach => '添付';

  @override
  String get messageHint => 'メッセージ';

  @override
  String get unknownChat => '不明なチャット';

  @override
  String get unknownProfile => '不明なプロフィール';

  @override
  String get goToChats => 'チャットへ';

  @override
  String get pageNotFound => 'ページが見つかりません';

  @override
  String pathDoesNotExist(String path) {
    return '$path は存在しません';
  }

  @override
  String get retry => '再試行';

  @override
  String get clear => 'クリア';

  @override
  String get add => '追加';

  @override
  String get save => '保存';

  @override
  String get readAll => 'すべて既読';

  @override
  String get filter => '絞り込み';

  @override
  String get filterAll => 'すべて';

  @override
  String get filterUnread => '未読のみ';

  @override
  String get filterRead => '既読のみ';

  @override
  String get showAll => 'すべて表示';

  @override
  String get notificationsLoadFailed => '通知を読み込めませんでした。';

  @override
  String get profiles => 'ユーザー';

  @override
  String get searchByName => '名前で検索';

  @override
  String get searchByUsername => 'ユーザー名で検索';

  @override
  String get searchPeopleHint => '名前または@ユーザー名で検索';

  @override
  String get profilesLoadFailed => 'プロフィールを読み込めませんでした。';

  @override
  String get signInToViewProfile => 'プロフィールを見るにはサインイン';

  @override
  String get signInToEditProfile => 'プロフィールを編集するにはサインイン';

  @override
  String get profileAbout => '紹介';

  @override
  String get profileSkills => 'スキル';

  @override
  String get profileContacts => '連絡先';

  @override
  String get sendMessageAction => 'メッセージ';

  @override
  String get editProfile => 'プロフィールを編集';

  @override
  String get displayName => '表示名';

  @override
  String get specialization => '専門分野';

  @override
  String get bio => '自己紹介';

  @override
  String get dateOfBirth => '生年月日';

  @override
  String get addContact => '連絡先を追加';

  @override
  String get contactProvider => 'プロバイダー（例: telegram）';

  @override
  String get contactHandle => '連絡先（例: @handle）';

  @override
  String get skillsHint => 'スキルを入力して Enter';

  @override
  String get photoLibraryFailed => 'フォトライブラリを開けませんでした';

  @override
  String get chats => 'チャット';

  @override
  String get searchChatsAndPeople => 'チャットと人を検索';

  @override
  String get chatsLoadFailed => 'チャットを読み込めませんでした。';

  @override
  String get noChatsYet => 'チャットはまだありません';

  @override
  String get noChatsYetHint => '会話を始めるとここに表示されます。';

  @override
  String get newChat => '新しいチャット';

  @override
  String get chatTypeDirect => '個人';

  @override
  String get chatTypeGroup => 'グループ';

  @override
  String get chatTypeSuper => 'スーパー';

  @override
  String get chatTypeChannel => 'チャンネル';

  @override
  String get chatPublicHintCreate => '誰でもこのチャットを見つけて参加できます';

  @override
  String get chatSlowModeSecondsField => '低速モード（秒）';

  @override
  String get createChat => 'チャットを作成';

  @override
  String get membersTitle => 'メンバー';

  @override
  String get membersLoadFailed => 'メンバーを読み込めませんでした';

  @override
  String get addMember => 'メンバーを追加';

  @override
  String get changeRole => '役割を変更';

  @override
  String get banMember => 'ブロック';

  @override
  String get banMemberTitle => 'メンバーをブロック';

  @override
  String get kickMember => '退出させる';

  @override
  String get banReason => '理由（任意）';

  @override
  String get banUntil => '日付を設定';

  @override
  String get searchPeople => 'ユーザー';

  @override
  String get noPeopleFound => '該当するユーザーがいません';

  @override
  String get callConnecting => '接続中…';

  @override
  String get callJoin => '通話に参加';

  @override
  String get callEnded => '通話終了';

  @override
  String get callRejoin => '再参加';

  @override
  String get callLeave => '退出';

  @override
  String get callTitle => '通話';

  @override
  String selectedCount(int count) {
    return '$count 件選択';
  }

  @override
  String deleteMessagesTitle(int count) {
    return '$count 件のメッセージを削除しますか？';
  }

  @override
  String get cannotBeUndone => 'この操作は取り消せません。';

  @override
  String get chatLoadFailed => 'チャットを読み込めませんでした';

  @override
  String get attachMedia => '写真と動画';

  @override
  String get attachDocument => 'ドキュメント';

  @override
  String get messageForwarded => 'メッセージを転送しました';

  @override
  String get forwardTo => '転送先';

  @override
  String get noOtherChats => '他のチャットはありません';

  @override
  String get chatsLoadFailedShort => 'チャットを読み込めませんでした';

  @override
  String get messageWaitingToSend => '送信待ち';

  @override
  String get messageNotSent => '未送信';

  @override
  String get connectionBusy => '接続中…';

  @override
  String get connectionWaitingForNetwork => 'ネットワーク待機中';

  @override
  String get wsDiagnostics => '接続診断';

  @override
  String wsDiagnosticsFrames(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count件のフレームを記録',
      zero: 'フレームの記録なし',
    );
    return '$_temp0';
  }

  @override
  String get wsDiagnosticsCopied => '診断をコピーしました';

  @override
  String get discard => '破棄';

  @override
  String get reactedTitle => 'リアクション';

  @override
  String get noReactionsYet => 'まだ誰もこのリアクションをしていません';

  @override
  String get showMore => 'もっと見る';

  @override
  String get bulkForwarding => '転送中';

  @override
  String get bulkDeleting => '削除中';

  @override
  String bulkProgress(String label, int done, int total) {
    return '$label $done/$total…';
  }

  @override
  String bulkComplete(String label, int total) {
    return '$label 完了（$total）';
  }

  @override
  String bulkPartial(int done, int total, int failed, String reason) {
    return '$total 件中 $done 件成功 — $failed 件失敗: $reason';
  }

  @override
  String get callTokenUnavailable => '通話を開始できませんでした';

  @override
  String get loginTitle => 'ログイン';

  @override
  String get emailOrUsername => 'メールまたはユーザー名';

  @override
  String get emailOrUsernameHint => 'you@example.com またはユーザー名';

  @override
  String get passwordHint => 'パスワードを入力';

  @override
  String get logIn => 'ログイン';

  @override
  String get username => 'ユーザー名';

  @override
  String get usernameHint => '4〜100 文字';

  @override
  String get emailHint => 'メールアドレスを入力';

  @override
  String get passwordRule => '8文字以上・大小英字・数字・記号';

  @override
  String get confirmPassword => 'パスワードの確認';

  @override
  String get confirmPasswordHint => 'パスワードを再入力';

  @override
  String get signInTitle => 'サインイン';

  @override
  String get backToSignIn => 'サインインに戻る';

  @override
  String get setNewPassword => '新しいパスワードを設定';

  @override
  String get resetCode => 'リセットコード';

  @override
  String get newPassword => '新しいパスワード';

  @override
  String get confirmNewPassword => '新しいパスワードの確認';

  @override
  String get resetPassword => 'パスワードをリセット';

  @override
  String get passwordUpdated => 'パスワードを更新しました。ログインしてください。';

  @override
  String get sendCode => 'コードを送信';

  @override
  String get haveCodeAlready => 'コードを持っています';

  @override
  String get resetCodeSent => 'メールでコードを確認してください。';

  @override
  String get verifyEmailTitle => 'メールを確認';

  @override
  String get verifyEmailHint => '送信したメールのトークンを貼り付けてください。';

  @override
  String get verificationToken => '確認トークン';

  @override
  String get verify => '確認';

  @override
  String get resendLimitHint => '再送できます（1時間に3回まで）。';

  @override
  String get resendVerification => '確認メールを再送';

  @override
  String get emailVerified => 'メールを確認しました';

  @override
  String get verificationSent => '確認メールを送信しました。受信箱をご確認ください。';

  @override
  String get browserOpenFailed => 'ブラウザを開けませんでした';

  @override
  String continueWith(String provider) {
    return '$provider で続行';
  }

  @override
  String get peopleSearchFailed => 'ユーザーを検索できませんでした';

  @override
  String get startChatFailed => 'この人とのチャットを開始できませんでした';

  @override
  String get profileLoadFailed => 'このプロフィールを読み込めませんでした';

  @override
  String get myProfileLoadFailed => 'プロフィールを読み込めませんでした';

  @override
  String get saveChangesFailed => '変更を保存できませんでした';

  @override
  String get avatarUpdateFailed => 'アバターを更新できませんでした';

  @override
  String get oauthCancelled => 'サインインがキャンセルされました';

  @override
  String get oauthCancelledHint => '変更はありません。もう一度試すか、ユーザー名とパスワードをお使いください。';

  @override
  String get oauthFailed => 'サインインを完了できませんでした';

  @override
  String get oauthFailedHint => 'ユーザー名とパスワードでサインインしてください。';

  @override
  String get realtimeRejected => 'このチャットのライブ更新は無効です';

  @override
  String get forwardComment => 'コメントを追加（任意）';

  @override
  String get forwardAction => '転送';

  @override
  String get banDuration => '期間';

  @override
  String get banForever => '無期限';

  @override
  String get banUntilDate => '指定日まで';

  @override
  String get banLift => 'ブロックを解除';

  @override
  String get banLiftHint => '過去の日付を送信し、サーバーはこれを解除として扱います';

  @override
  String get banPickDate => '日付を選択';

  @override
  String get myDevices => 'マイデバイス';

  @override
  String get devicesLoadFailed => 'デバイスを読み込めませんでした。';

  @override
  String get noDevices => 'アクティブなセッションはありません';

  @override
  String get deviceActive => '有効';

  @override
  String get deviceInactive => 'サインアウト済み';

  @override
  String deviceLastActive(String date) {
    return '最終利用: $date';
  }

  @override
  String get designSystem => 'デザインシステム';

  @override
  String get accentColor => 'アクセントカラー';

  @override
  String get chatWallpaper => 'チャットの背景';

  @override
  String get wallpaperAurora => 'オーロラ';

  @override
  String get wallpaperMesh => 'メッシュ';

  @override
  String get wallpaperPlain => 'プレーン';

  @override
  String get textSize => '文字サイズ';

  @override
  String get textSizeSmall => '小';

  @override
  String get textSizeDefault => '標準';

  @override
  String get textSizeLarge => '大';

  @override
  String get textSizeExtraLarge => '特大';

  @override
  String get resetAppearance => '外観をリセット';

  @override
  String get showcaseAccents => 'アクセント';

  @override
  String get showcaseNeutrals => 'ニュートラル';

  @override
  String get showcaseNeutralsLight => 'ライトの階調';

  @override
  String get showcaseNeutralsDark => 'ダークの階調';

  @override
  String get showcaseRadii => '角丸';

  @override
  String get showcaseSpacing => '余白';

  @override
  String get showcaseElevation => '高さ';

  @override
  String get showcaseMotion => 'モーション';

  @override
  String get showcaseMotionFast => '速い';

  @override
  String get showcaseMotionBase => '標準';

  @override
  String get showcaseMotionSlow => '遅い';

  @override
  String get showcaseMotionReplay => '再生';

  @override
  String get showcaseTypography => 'タイポグラフィ';

  @override
  String get showcaseTabularFigures => '等幅数字';

  @override
  String get showcaseBubbles => 'メッセージバブル';

  @override
  String get showcaseReactions => 'リアクション';

  @override
  String get showcaseAuthors => '送信者の色';

  @override
  String get showcaseComponents => 'コンポーネント';

  @override
  String get showcaseIncomingSample => '受信：温かみのある面と細い枠線。';

  @override
  String get showcaseStackedSample => '同じ連続の2通目。';

  @override
  String get showcaseOutgoingSample => '送信：アクセントのグラデーション。';

  @override
  String get messageSending => '送信中';

  @override
  String get onlineNow => 'オンライン';

  @override
  String userTyping(String name) {
    return '$name が入力中…';
  }

  @override
  String severalTyping(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 人が入力中…',
    );
    return '$_temp0';
  }

  @override
  String attachmentsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '添付ファイル $count 件',
    );
    return '$_temp0';
  }

  @override
  String get contacts => '連絡先';

  @override
  String get profileSettingsHint => '名前、アイコン、連絡先情報';

  @override
  String get noChatSelected => 'チャットが選択されていません';

  @override
  String get noChatSelectedHint => '一覧から会話を選んでください。';

  @override
  String get newDirectChat => '新しい個人チャット';

  @override
  String get newGroup => '新しいグループ';

  @override
  String get newChannel => '新しいチャンネル';

  @override
  String get quickActionsHint => '新しく作成';

  @override
  String unreadMessagesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '未読メッセージ$count件',
      zero: '未読メッセージはありません',
    );
    return '$_temp0';
  }

  @override
  String unreadNotificationsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '新しい通知$count件',
      zero: '新しい通知はありません',
    );
    return '$_temp0';
  }

  @override
  String get noContactsFound => 'その名前に一致する人はいません';

  @override
  String get noContactsFoundHint => 'より短い名前や別の綴りでお試しください。';

  @override
  String get noContactsYet => '表示できる人はまだいません';

  @override
  String get previewYou => '自分';

  @override
  String get previewPhoto => '写真';

  @override
  String get previewVideo => '動画';

  @override
  String get previewVoice => 'ボイスメッセージ';

  @override
  String get previewVideoNote => 'ビデオメッセージ';

  @override
  String get previewFile => 'ファイル';

  @override
  String get previewNoText => 'メッセージ';

  @override
  String get draftLabel => '下書き:';

  @override
  String get markAsRead => '既読にする';

  @override
  String get archiveChat => 'アーカイブ';

  @override
  String get unarchiveChat => 'アーカイブ解除';

  @override
  String get pinChat => 'ピン留め';

  @override
  String get unpinChat => 'ピン留めを外す';

  @override
  String get muteChat => '通知オフ';

  @override
  String get unmuteChat => '通知オン';

  @override
  String get archivedChats => 'アーカイブ済み';

  @override
  String get chatPinnedLabel => 'ピン留め済み';

  @override
  String get chatMutedLabel => '通知オフ';

  @override
  String get chatArchivedToast => 'チャットをアーカイブしました';

  @override
  String get chatDeletedToast => 'チャットを削除しました';

  @override
  String get undo => '元に戻す';

  @override
  String get allChatsArchived => 'すべてアーカイブ済みです';

  @override
  String previewVoiceWithDuration(String duration) {
    return 'ボイスメッセージ $duration';
  }

  @override
  String archivedChatsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 件のチャット',
    );
    return '$_temp0';
  }

  @override
  String get chatFolders => 'フォルダ';

  @override
  String get chatFoldersAll => 'すべてのチャット';

  @override
  String get folderPresetUnread => '未読';

  @override
  String get folderPresetPersonal => '個人';

  @override
  String get folderPresetGroups => 'グループ';

  @override
  String get folderPresetChannels => 'チャンネル';

  @override
  String get folderPresetNoReply => '返信待ち';

  @override
  String get newFolder => '新しいフォルダ';

  @override
  String get editFolder => 'フォルダを編集';

  @override
  String get folderName => 'フォルダ名';

  @override
  String get folderIcon => 'アイコン';

  @override
  String get folderRules => 'ルール';

  @override
  String get folderMatchModeTitle => 'チャットがここに入る条件';

  @override
  String get folderMatchAll => 'すべてのルールを満たす';

  @override
  String get folderMatchAny => 'いずれかのルールを満たす';

  @override
  String get addFolderRule => 'ルールを追加';

  @override
  String get removeFolderRule => 'ルールを削除';

  @override
  String get folderRuleChatType => 'チャットの種類';

  @override
  String folderRuleChatTypeIn(String types) {
    return '種類が $types';
  }

  @override
  String get folderRuleUnread => '未読メッセージがある';

  @override
  String get folderRuleRead => '未読がない';

  @override
  String get folderRulePinned => 'ピン留めしている';

  @override
  String get folderRuleNotPinned => 'ピン留めしていない';

  @override
  String get folderRuleNoReply => '自分の返信待ち';

  @override
  String folderRuleNoReplyDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days 日以上返信していない',
      zero: '自分の返信待ち',
    );
    return '$_temp0';
  }

  @override
  String get folderRuleDaysLabel => '返信しないまま経った日数';

  @override
  String get folderRuleDaysAny => '指定なし';

  @override
  String get folderRuleMember => '特定の人がいる';

  @override
  String folderRuleMemberNamed(String name) {
    return '$name がいる';
  }

  @override
  String get folderRulePickPerson => '人を選ぶ';

  @override
  String get folderRuleNoPeople => 'チャットのある相手がここに表示されます';

  @override
  String get folderRuleMemberLocalNote =>
      'チャット一覧がすでに知っている範囲で判定します。自分、読み込み済みのメンバー、最後の送信者、チャットの作成者です。';

  @override
  String get deleteFolder => 'フォルダを削除';

  @override
  String get deleteFolderConfirm => 'このフォルダを削除しますか？中のチャットはそのまま残ります。';

  @override
  String get folderNameRequired => 'フォルダ名を入力してください';

  @override
  String folderNameTooLong(int count) {
    return 'フォルダ名は $count 文字までです';
  }

  @override
  String get folderRulesRequired => 'ルールを1つ以上追加してください';

  @override
  String folderLimitReached(int count) {
    return 'フォルダは $count 個まで作れます';
  }

  @override
  String pinLimitReached(int count) {
    return 'ピン留めできるのは $count 件までです。先に1件外してください。';
  }

  @override
  String get foldersEmpty => 'フォルダはまだありません';

  @override
  String get foldersEmptyHint => 'フォルダは一覧ではなくルールの集まりです。チャットは自動で出入りします。';

  @override
  String get folderReadyMade => 'すぐ使える';

  @override
  String get folderYours => '自分のフォルダ';

  @override
  String folderRuleCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ルール $count 件',
    );
    return '$_temp0';
  }

  @override
  String get folderEmptyChats => 'このフォルダには何もありません';

  @override
  String get folderEmptyChatsHint => 'ルールを満たしたチャットがここに表示されます。';

  @override
  String get hideFolderTabs => 'フォルダのタブを隠す';

  @override
  String get hideFolderTabsHint => 'フォルダは残したまま、一覧の上のタブを表示しません';

  @override
  String get unarchiveOnNewMessage => '新着で戻す';

  @override
  String get unarchiveOnNewMessageHint => 'アーカイブしたチャットは、誰かが書き込むと一覧に戻ります';

  @override
  String get organizerDeviceOnly =>
      'フォルダはこの端末にだけ保存され、アカウントには付いていきません。ピン留め・アーカイブ・通知オフは付いていきます。';

  @override
  String get chatPinnedZone => 'ピン留め';

  @override
  String get chatUnarchivedToast => '一覧に戻しました';

  @override
  String get searchTabMessages => 'メッセージ';

  @override
  String get searchEverything => 'チャット・人・メッセージを検索';

  @override
  String get searchRecentQueries => '最近の検索';

  @override
  String get searchRecentChats => '最近開いたチャット';

  @override
  String get searchClearHistory => '消去';

  @override
  String get searchRemoveFromHistory => '最近の検索から削除';

  @override
  String get searchStartTitle => 'チャット・人・メッセージを探す';

  @override
  String get searchStartHint => 'チャットは名前、人はユーザー名、メッセージは本文で探します。';

  @override
  String get searchLoadedHistoryOnly => 'この端末にあるものを検索しました';

  @override
  String get searchLoadedHistoryExplained =>
      'サーバーに接続できなかったため、この端末にあるメッセージだけを検索しました。';

  @override
  String get noChatsFound => 'チャットが見つかりません';

  @override
  String get noChatsFoundHint => '読み込み済みのチャットの中から、名前と説明で探します。';

  @override
  String get noPeopleFoundHint => '綴りを変えるか、ユーザー名で探してみてください。';

  @override
  String get noMessagesFound => 'メッセージが見つかりません';

  @override
  String get messageSearchFailed => 'メッセージを検索できませんでした';

  @override
  String get searchInChat => 'このチャット内を検索';

  @override
  String searchMatchPosition(int current, int total) {
    return '$total 件中 $current 件目';
  }

  @override
  String get searchNoMatches => '該当なし';

  @override
  String get searchOlderMatch => '前の該当箇所';

  @override
  String get searchNewerMatch => '次の該当箇所';

  @override
  String get searchInChatHint => 'このチャット内を検索';

  @override
  String get searchChatDescriptionMatch => '説明に一致';

  @override
  String get searchOpenChat => 'チャットを開く';

  @override
  String get reactionSectionRecent => '最近使った絵文字';

  @override
  String get reactionSectionFaces => 'スマイリー';

  @override
  String get reactionSectionPeople => '人';

  @override
  String get reactionSectionHearts => 'ハート';

  @override
  String get reactionSectionCelebration => 'お祝い';

  @override
  String get reactionSectionFood => '食べ物';

  @override
  String get reactionSectionNature => '自然';

  @override
  String get reactionSectionSymbols => '記号';

  @override
  String get reactionsNoneAllowed => 'このチャットで使えるリアクションはありません';

  @override
  String reactionsUsed(int used, int limit) {
    return '$used/$limit';
  }

  @override
  String reactionMessageLimitReached(Object limit) {
    return 'このメッセージにはすでに$limit種類のリアクションがあります';
  }

  @override
  String get moreReactions => 'その他のリアクション';

  @override
  String get reactionFailed => 'リアクションを保存できませんでした';

  @override
  String get reactionTooFast => 'リアクションが多すぎます';

  @override
  String get reactionNotAllowed => 'このリアクションはここでは使えません';

  @override
  String get reactionsNobody => 'まだ誰もいません';

  @override
  String reactionUserFallback(Object id) {
    return 'ユーザー $id';
  }

  @override
  String composerCharactersLeft(int count) {
    return '残り$count';
  }

  @override
  String get composerSendLabel => '送信';

  @override
  String get composerSaveEditLabel => '変更を保存';

  @override
  String get composerRecordLabel => '長押しで音声メッセージを録音';

  @override
  String composerReplyingTo(Object name) {
    return '$nameに返信';
  }

  @override
  String composerSlowModeWait(int seconds) {
    return '低速モード：あと$seconds秒';
  }

  @override
  String composerSlowModeHint(int seconds) {
    return 'このチャットでは$seconds秒に1通まで送信できます';
  }

  @override
  String get attachSheetTitle => '添付';

  @override
  String get attachRecent => '最近';

  @override
  String get attachCamera => 'カメラ';

  @override
  String get attachVoice => '音声メッセージ';

  @override
  String get attachVideoNote => 'ビデオメッセージ';

  @override
  String attachVoiceHint(int seconds) {
    return '単独で送信、最大$seconds秒';
  }

  @override
  String attachVideoNoteHint(int seconds, int pixels) {
    return '単独で送信、最大$seconds秒・${pixels}px';
  }

  @override
  String get attachGalleryDenied => 'ここから選ぶには写真へのアクセスを許可してください';

  @override
  String get attachGalleryAllow => '許可';

  @override
  String attachMediaFull(int count) {
    return '1通につき写真・動画は$count件までです';
  }

  @override
  String attachSendCount(int count) {
    return '$count件を添付';
  }

  @override
  String get attachUnavailable => 'このファイルを読み込めませんでした';

  @override
  String videoNoteTooLarge(int pixels) {
    return 'このカメラは${pixels}pxを超えて録画するため、ビデオメッセージとして受け付けられません';
  }

  @override
  String composerTooLongBy(int count) {
    return '上限を$count超過';
  }

  @override
  String get videoNoteTapToRecord => 'タップして録画';

  @override
  String get videoNoteNoCamera => 'この端末には録画できるカメラがありません';

  @override
  String get videoNoteCameraDenied => 'ビデオメッセージの録画にはカメラとマイクへのアクセスを許可してください';

  @override
  String get videoNoteCameraFailed => 'カメラを起動できませんでした';

  @override
  String get videoNoteDiscarded => '録画されませんでした';

  @override
  String get attachmentOpen => '開く';

  @override
  String attachmentSavedTo(String path) {
    return '$path に保存しました';
  }

  @override
  String get attachmentSaveFailed => 'このファイルを保存できませんでした';

  @override
  String get attachmentUploading => 'アップロード中';

  @override
  String mediaViewerCounter(int index, int count) {
    return '$count 件中 $index 件目';
  }

  @override
  String get mediaViewerUnavailable => 'このメディアは利用できません';

  @override
  String get mediaPreviewHint => '送りたくないものは削除できます';

  @override
  String get mediaPreviewCaptionHint => 'キャプションを追加';

  @override
  String get mediaPreviewRemove => '削除';

  @override
  String get composerRecordVideoNoteLabel => '長押しでビデオメッセージを録画';

  @override
  String get composerSwitchToVideoNote => 'ビデオメッセージに切り替え';

  @override
  String get composerSwitchToVoice => 'ボイスメッセージに切り替え';

  @override
  String get videoNoteSwitchCamera => 'カメラを切り替え';

  @override
  String get videoNoteDoubleTapToSwitch => 'ダブルタップでカメラを切り替え';

  @override
  String get videoNoteOpeningCamera => 'カメラを起動しています…';

  @override
  String get videoNoteHoldToRecord => '長押しで録画';

  @override
  String get videoNoteSend => 'ビデオメッセージを送信';

  @override
  String get videoNoteRecordingLabel => 'ビデオメッセージを録画中';

  @override
  String get videoNoteTapForSound => 'タップで音声をオン';

  @override
  String get videoNoteTapToMute => 'タップでミュート';

  @override
  String get videoNoteHoldForFullScreen => '長押しで全画面表示';

  @override
  String videoNotePlayerLabel(String duration) {
    return 'ビデオメッセージ、$duration';
  }

  @override
  String get videoNoteAutoplayOff => 'タップで再生';

  @override
  String get mediaAutoplay => 'ビデオメッセージの自動再生';

  @override
  String get mediaAutoplayHint => '画面に入るとビデオメッセージが無音で再生されます。タップすると音声が出ます。';

  @override
  String get mediaAutoplayAlways => '常に';

  @override
  String get mediaAutoplayWifi => 'Wi-Fi のときのみ';

  @override
  String get mediaAutoplayNever => 'しない';

  @override
  String get videoNotePreview => 'カメラのプレビュー';

  @override
  String searchTypeMore(int count) {
    return '$count 文字以上を入力してください';
  }

  @override
  String get noMessagesFoundHint => '検索の対象は本文だけで、ファイル名やチャット名は含まれません。';

  @override
  String get chatSettings => 'Chat settings';

  @override
  String get chatSettingsNoPermission =>
      'Only an owner or admin can change this chat';

  @override
  String get chatNameCannotBeCleared =>
      'A name cannot be removed once the chat has one';

  @override
  String chatSlowModeRange(int max) {
    return '0 to $max seconds';
  }

  @override
  String get chatReactionsPickHint => 'Pick the emoji people may react with';

  @override
  String get chatNotMutedLabel => 'Notifications on';

  @override
  String get chatMutedToast => 'Notifications off for this chat';

  @override
  String get chatUnmutedToast => 'Notifications back on for this chat';

  @override
  String get muteForHour => 'Mute for 1 hour';

  @override
  String get muteForEightHours => 'Mute for 8 hours';

  @override
  String get muteForever => 'Mute until I turn it back on';

  @override
  String get leaveChatOwnerStuck =>
      'The chat creator cannot leave, and you no longer have permission to delete this chat.';

  @override
  String get chatInviteLink => 'Invite link';

  @override
  String get chatInviteLinkHint =>
      'Anyone signed in to ChatiX can open this link and join. It only opens in the app.';

  @override
  String get chatInviteLinkCopied => 'Invite link copied';

  @override
  String get sharedMedia => 'Media';

  @override
  String get sharedFiles => 'Files';

  @override
  String get sharedLinks => 'Links';

  @override
  String get sharedVoice => 'Voice';

  @override
  String get sharedMediaEmpty => 'No photos or videos here yet';

  @override
  String get sharedFilesEmpty => 'No files here yet';

  @override
  String get sharedLinksEmpty => 'No links here yet';

  @override
  String get sharedVoiceEmpty => 'No voice messages here yet';

  @override
  String get sharedContentLocalOnly =>
      'Shows what this device has loaded from the chat — the server has no shared-media index.';

  @override
  String get chatSettingsUnchanged => 'Nothing has changed yet';

  @override
  String get membersSearchHint => 'Search members';

  @override
  String get membersSearchLoadedOnly =>
      'Only the members loaded so far are searched.';

  @override
  String membersSearchEmpty(String query) {
    return 'No one here matches “$query”';
  }

  @override
  String get membersLoadMore => 'Load more people';

  @override
  String get membersSectionAdmins => 'Administration';

  @override
  String get membersSectionMembers => 'Members';

  @override
  String get membersSectionBanned => 'Banned members';

  @override
  String get membersBannedHint =>
      'Banned people cannot read or write here until the ban is lifted.';

  @override
  String get membersEmptyTitle => 'No members to show';

  @override
  String get membersEmptyInvite => 'Add someone to get this chat started.';

  @override
  String get membersEmptyNoInvite =>
      'Only members with the invite permission can add people here.';

  @override
  String get chatRoleOwner => 'Owner';

  @override
  String get chatRoleAdmin => 'Admin';

  @override
  String get chatRoleEditor => 'Editor';

  @override
  String get chatRoleDirect => 'Direct';

  @override
  String get chatRoleMember => 'Member';

  @override
  String get chatRoleViewer => 'Viewer';

  @override
  String get chatRoleUnknown => 'Unknown role';

  @override
  String get memberMutedBadge => 'Muted';

  @override
  String get memberBannedBadge => 'Banned';

  @override
  String get memberOpenProfile => 'Open profile';

  @override
  String get memberMessagePrivately => 'Message privately';

  @override
  String memberKickConfirmTitle(String name) {
    return 'Remove $name?';
  }

  @override
  String get memberKickConfirmBody =>
      'They lose access to this chat, but can be added again later.';

  @override
  String memberRoleChanged(String name, String role) {
    return '$name is now $role';
  }

  @override
  String memberKicked(String name) {
    return '$name was removed';
  }

  @override
  String memberBannedToast(String name) {
    return '$name was banned';
  }

  @override
  String memberUnbanned(String name) {
    return 'The ban on $name was lifted';
  }

  @override
  String get memberActionFailed => 'That did not go through. Please try again.';

  @override
  String get roleAssignHint => 'You can only assign roles below your own.';

  @override
  String get roleOwnerTransferHint =>
      'Owner is not in the list: the API has no way to hand a chat over.';

  @override
  String get banForHour => 'For an hour';

  @override
  String get banForDay => 'For a day';

  @override
  String get banForWeek => 'For a week';

  @override
  String get inviteMembersTitle => 'Add people';

  @override
  String get inviteRoleLabel => 'They join as';

  @override
  String inviteRoomLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Room for $count more people',
      one: 'Room for 1 more person',
      zero: 'This chat is full',
    );
    return '$_temp0';
  }

  @override
  String inviteChatFull(int limit) {
    return 'This chat holds $limit members, and it is full.';
  }

  @override
  String inviteAddSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Add $count people',
      one: 'Add 1 person',
    );
    return '$_temp0';
  }

  @override
  String inviteAddedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people added',
      one: '1 person added',
    );
    return '$_temp0';
  }

  @override
  String inviteFailedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people could not be added',
      one: '1 person could not be added',
    );
    return '$_temp0';
  }

  @override
  String get inviteSearchStart =>
      'Find people by name or @username, then add them all at once.';

  @override
  String get inviteSelectionFull => 'That is everyone this chat has room for.';

  @override
  String peopleSearchNoneFound(String query) {
    return 'No one found for “$query”';
  }

  @override
  String get peopleSearchHint =>
      'Search matches any part of a name or @username.';

  @override
  String get profileShareAction => 'Share';

  @override
  String get profileShareCopied => 'Profile link copied';

  @override
  String get profileBirthday => 'Birthday';

  @override
  String get profileEmptyTitle => 'Nothing here yet';

  @override
  String get profileEmptyHintSelf =>
      'Add a few words about yourself so people know who they are talking to.';

  @override
  String get profileEmptyHintOther =>
      'This person has not filled in their profile.';

  @override
  String get profileAccount => 'Account';

  @override
  String get profileAccountNoEmail => 'Signed in';

  @override
  String get profilePhoto => 'Photo';

  @override
  String get profileNoPhoto => 'No photo yet';

  @override
  String get profileOpenLinkFailed => 'Could not open this link';

  @override
  String get profileContactCopied => 'Copied to clipboard';

  @override
  String get profileCopyAction => 'Copy';

  @override
  String devicesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count devices',
      one: '1 device',
      zero: 'No devices',
    );
    return '$_temp0';
  }

  @override
  String get changePhoto => 'Change photo';

  @override
  String get choosePhoto => 'Choose a photo';

  @override
  String get avatarCropTitle => 'Move and scale';

  @override
  String get avatarCropHint => 'Drag to move, pinch to zoom.';

  @override
  String get avatarCropConfirm => 'Use photo';

  @override
  String get avatarStagePreparing => 'Preparing…';

  @override
  String get avatarStageUploading => 'Uploading…';

  @override
  String get avatarStageConfirming => 'Almost done…';

  @override
  String get avatarStageProcessing => 'Processing the photo…';

  @override
  String get avatarStageDone => 'Photo updated';

  @override
  String get avatarProcessingFailed => 'Could not update the photo';

  @override
  String get avatarProcessingFailedHint =>
      'The server did not accept that picture. Try another one.';

  @override
  String get avatarNotAnImage => 'That file is not an image';

  @override
  String get avatarTooLarge => 'That picture is too large. Pick a smaller one.';

  @override
  String get avatarUnreadable => 'That picture could not be opened';

  @override
  String get profileEditDetails => 'Details';

  @override
  String get profileEditLinks => 'Links';

  @override
  String get profileEditLinksHint =>
      'Links are saved the moment you add or remove one, separately from the form below.';

  @override
  String get profileNoLinks => 'No links yet';

  @override
  String get removeLink => 'Remove link';

  @override
  String get clearDateOfBirth => 'Clear date of birth';

  @override
  String get specializationHint => 'What you do, in a few words';

  @override
  String bioCounter(int count, int max) {
    return '$count/$max';
  }

  @override
  String get profileSkillsHint => 'Up to 30 characters each';

  @override
  String get profileSaved => 'Profile saved';

  @override
  String get discardChangesTitle => 'Discard changes?';

  @override
  String get discardChangesMessage =>
      'Your edits to this profile will be lost.';

  @override
  String get discardAction => 'Discard';

  @override
  String get keepEditingAction => 'Keep editing';

  @override
  String get camera => 'Camera';

  @override
  String get loading => 'Loading…';

  @override
  String fieldTooLong(int max) {
    return 'At most $max characters';
  }

  @override
  String skillTooLong(String skill, int max) {
    return '“$skill” is longer than $max characters';
  }

  @override
  String callRoomName(String slug) {
    return 'Room $slug';
  }

  @override
  String get callJoinExplanation =>
      'A call here is a room: join it, and anyone else in this chat can join you.';

  @override
  String get callNoIncomingNotice =>
      'Ringing for incoming calls is not available yet — the server does not announce them.';

  @override
  String get callWaitingForOthers => 'Waiting for someone else to join…';

  @override
  String get callReconnecting => 'Reconnecting…';

  @override
  String get callYou => 'You';

  @override
  String callParticipantsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count participants',
      one: '1 participant',
      zero: 'No one here yet',
    );
    return '$_temp0';
  }

  @override
  String get callMicrophoneMute => 'Mute';

  @override
  String get callMicrophoneUnmute => 'Unmute';

  @override
  String get callCameraStart => 'Start video';

  @override
  String get callCameraStop => 'Stop video';

  @override
  String get callSpeakerOn => 'Speaker';

  @override
  String get callSpeakerOff => 'Earpiece';

  @override
  String get callLayoutGrid => 'Grid';

  @override
  String get callLayoutSpeaker => 'Speaker view';

  @override
  String callPinParticipant(String name) {
    return 'Pin $name';
  }

  @override
  String callUnpinParticipant(String name) {
    return 'Unpin $name';
  }

  @override
  String get callMuteForEveryone => 'Mute for everyone';

  @override
  String get callUnmuteForEveryone => 'Let them speak';

  @override
  String get callQualityExcellent => 'Excellent connection';

  @override
  String get callQualityGood => 'Good connection';

  @override
  String get callQualityPoor => 'Weak connection';

  @override
  String get callQualityLost => 'Connection lost';

  @override
  String get callMicrophonePermissionTitle => 'Let ChatiX use the microphone';

  @override
  String get callMicrophonePermissionBody =>
      'The others can only hear you if ChatiX may use the microphone. You can mute yourself again at any time.';

  @override
  String get callCameraPermissionTitle => 'Let ChatiX use the camera';

  @override
  String get callCameraPermissionBody =>
      'Your video is only sent while the camera is on, and you can turn it off at any time.';

  @override
  String get callPermissionContinue => 'Continue';

  @override
  String get callPermissionNotNow => 'Not now';

  @override
  String get callPermissionOpenSettings => 'Open settings';

  @override
  String get callMicrophoneBlocked =>
      'Microphone is off: ChatiX has no permission for it.';

  @override
  String get callCameraBlocked =>
      'Camera is off: ChatiX has no permission for it.';

  @override
  String get callSelfPreview => 'Your camera';

  @override
  String get callSelfPreviewHint => 'Drag to move';

  @override
  String get callShowControls => 'Show call controls';

  @override
  String get callOngoingInChat => 'You are in a call in this chat';

  @override
  String get callReturn => 'Return';

  @override
  String callMiniPlayerLabel(String name) {
    return 'Call with $name';
  }

  @override
  String get callMinimize => 'Minimize call';

  @override
  String get callDismiss => 'Dismiss';
}
