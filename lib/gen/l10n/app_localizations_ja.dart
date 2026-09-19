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
  String get notification_settings => '通知の設定';

  @override
  String get localization_demo => 'ローカライズのデモ';

  @override
  String get localization_demo_description => 'ローカライズの動きを見る';

  @override
  String get language_settings => '言語設定';

  @override
  String get select_your_language => '言語を選んでください';

  @override
  String get language_explanation => '選んだ言語はアプリ全体に適用されます';

  @override
  String get localization_assets_demo => 'ローカライズとアセット';

  @override
  String get current_language => '現在の言語';

  @override
  String get language_code => '言語コード';

  @override
  String get language_name => '言語名';

  @override
  String get formatting_examples => '書式の例';

  @override
  String get date_full => '日付（完全）';

  @override
  String get date_short => '日付（短縮）';

  @override
  String get time => '時刻';

  @override
  String get currency => '通貨';

  @override
  String get percent => 'パーセント';

  @override
  String get localized_assets => 'ローカライズされたアセット';

  @override
  String get localized_assets_explanation =>
      'このセクションでは、選んだ言語に応じて別のアセットを読み込む方法を示します。画像や音声などのファイルは言語ごとに用意できます。';

  @override
  String get image_example => 'ローカライズされた画像の例';

  @override
  String get welcome_image_caption => 'この画像は選んだ言語に合わせて読み込まれます';

  @override
  String get common_image_example => '共通画像の例';

  @override
  String get common_image_caption => 'この画像はすべての言語で同じです';

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
  String get messageReact => 'リアクション';

  @override
  String get messageCopy => 'テキストをコピー';

  @override
  String get messageCopied => 'コピーしました';

  @override
  String get linkOpenFailed => 'このリンクを開けるものがありません';

  @override
  String get messageDetails => '詳細';

  @override
  String replyingTo(String author) {
    return '$authorさんへの返信';
  }

  @override
  String forwardedFrom(String author) {
    return '$authorさんから転送';
  }

  @override
  String get forwardedMessage => '転送されたメッセージ';

  @override
  String get detailsSentAt => '送信';

  @override
  String get detailsAuthor => '差出人';

  @override
  String get detailsSequence => 'チャット内の番号';

  @override
  String get detailsEdited => '編集済み';

  @override
  String get detailsEditedYes => 'はい';

  @override
  String get detailsDelivery => '配信';

  @override
  String get detailsAttachments => '添付ファイル';

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
      other: '下に新着メッセージ$count件',
      zero: '新着メッセージはありません',
    );
    return '$_temp0';
  }

  @override
  String get connectionReconnecting => '再接続中…';

  @override
  String get connectionOffline => 'オフライン — 引っ張って更新';

  @override
  String get attachmentFallbackLabel => '添付ファイル';

  @override
  String get composerJoinToSend => 'メッセージを送るにはこのチャットに参加してください';

  @override
  String get composerBanned => 'このチャットではブロックされています';

  @override
  String get composerMuted => 'このチャットでは発言できません';

  @override
  String get composerAdminsOnly => 'このチャットでは管理者のみ投稿できます';

  @override
  String get composerNoPermission => 'ここにメッセージを送る権限がありません';

  @override
  String attachmentSelection(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ファイル$count件',
    );
    return '$_temp0、$size';
  }

  @override
  String get attachmentReady => '送信の準備ができました';

  @override
  String attachMediaLimits(int count, String size) {
    return '最大$count件、各$sizeまで';
  }

  @override
  String attachDocumentLimits(String size) {
    return '1ファイル、$sizeまで';
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
  String get chatSettings => 'チャットの設定';

  @override
  String get chatSettingsNoPermission => 'このチャットを変更できるのはオーナーと管理者だけです';

  @override
  String get chatNameCannotBeCleared => '一度付いた名前は削除できません';

  @override
  String chatSlowModeRange(int max) {
    return '0〜$max秒';
  }

  @override
  String get chatReactionsPickHint => 'リアクションに使える絵文字を選んでください';

  @override
  String get chatNotMutedLabel => '通知オン';

  @override
  String get chatMutedToast => 'このチャットの通知をオフにしました';

  @override
  String get chatUnmutedToast => 'このチャットの通知をオンに戻しました';

  @override
  String get muteForHour => '1時間ミュート';

  @override
  String get muteForEightHours => '8時間ミュート';

  @override
  String get muteForever => '自分で戻すまでミュート';

  @override
  String get leaveChatOwnerStuck =>
      'チャットの作成者は退出できず、あなたにはもうこのチャットを削除する権限がありません。';

  @override
  String get chatInviteLink => '招待リンク';

  @override
  String get chatInviteLinkHint =>
      'ChatiX にサインインしている人なら誰でもこのリンクを開いて参加できます。アプリ内でのみ開きます。';

  @override
  String get chatInviteLinkCopied => '招待リンクをコピーしました';

  @override
  String get sharedMedia => 'メディア';

  @override
  String get sharedFiles => 'ファイル';

  @override
  String get sharedLinks => 'リンク';

  @override
  String get sharedVoice => 'ボイス';

  @override
  String get sharedMediaEmpty => '写真や動画はまだありません';

  @override
  String get sharedFilesEmpty => 'ファイルはまだありません';

  @override
  String get sharedLinksEmpty => 'リンクはまだありません';

  @override
  String get sharedVoiceEmpty => 'ボイスメッセージはまだありません';

  @override
  String get sharedContentLocalOnly =>
      'この端末がチャットから読み込んだものを表示します。サーバーには共有メディアの索引がありません。';

  @override
  String get chatSettingsUnchanged => 'まだ何も変更されていません';

  @override
  String get membersSearchHint => 'メンバーを検索';

  @override
  String get membersSearchLoadedOnly => '読み込み済みのメンバーの中だけを検索します。';

  @override
  String membersSearchEmpty(String query) {
    return '「$query」に一致する人はいません';
  }

  @override
  String get membersLoadMore => 'さらに読み込む';

  @override
  String get membersSectionAdmins => '管理';

  @override
  String get membersSectionMembers => 'メンバー';

  @override
  String get membersSectionBanned => 'ブロック中のメンバー';

  @override
  String get membersBannedHint => 'ブロックされた人は、解除されるまでここを読むことも書くこともできません。';

  @override
  String get membersEmptyTitle => '表示できるメンバーがいません';

  @override
  String get membersEmptyInvite => '誰かを追加してチャットを始めましょう。';

  @override
  String get membersEmptyNoInvite => 'ここに人を追加できるのは招待権限のあるメンバーだけです。';

  @override
  String get chatRoleOwner => 'オーナー';

  @override
  String get chatRoleAdmin => '管理者';

  @override
  String get chatRoleEditor => '編集者';

  @override
  String get chatRoleDirect => 'ダイレクト';

  @override
  String get chatRoleMember => 'メンバー';

  @override
  String get chatRoleViewer => '閲覧者';

  @override
  String get chatRoleUnknown => '不明なロール';

  @override
  String get memberMutedBadge => '発言不可';

  @override
  String get memberBannedBadge => 'ブロック中';

  @override
  String get memberOpenProfile => 'プロフィールを開く';

  @override
  String get memberMessagePrivately => '個別に送る';

  @override
  String memberKickConfirmTitle(String name) {
    return '$nameさんを削除しますか？';
  }

  @override
  String get memberKickConfirmBody => 'このチャットへのアクセスは失われますが、あとで追加し直せます。';

  @override
  String memberRoleChanged(String name, String role) {
    return '$nameさんは$roleになりました';
  }

  @override
  String memberKicked(String name) {
    return '$nameさんを削除しました';
  }

  @override
  String memberBannedToast(String name) {
    return '$nameさんをブロックしました';
  }

  @override
  String memberUnbanned(String name) {
    return '$nameさんのブロックを解除しました';
  }

  @override
  String get memberActionFailed => 'うまくいきませんでした。もう一度お試しください。';

  @override
  String get roleAssignHint => '自分より下のロールしか割り当てられません。';

  @override
  String get roleOwnerTransferHint => 'オーナーは一覧にありません。API にチャットを譲る手段がないためです。';

  @override
  String get banForHour => '1時間';

  @override
  String get banForDay => '1日';

  @override
  String get banForWeek => '1週間';

  @override
  String get inviteMembersTitle => 'メンバーを追加';

  @override
  String get inviteRoleLabel => '参加時のロール';

  @override
  String inviteRoomLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'あと$count人まで参加できます',
      zero: 'このチャットは満員です',
    );
    return '$_temp0';
  }

  @override
  String inviteChatFull(int limit) {
    return 'このチャットの定員は$limit人で、すでに満員です。';
  }

  @override
  String inviteAddSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count人を追加',
    );
    return '$_temp0';
  }

  @override
  String inviteAddedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count人を追加しました',
    );
    return '$_temp0';
  }

  @override
  String inviteFailedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count人を追加できませんでした',
    );
    return '$_temp0';
  }

  @override
  String get inviteSearchStart => '名前や @username で人を探し、まとめて追加できます。';

  @override
  String get inviteSelectionFull => 'このチャットに入れるのはここまでです。';

  @override
  String peopleSearchNoneFound(String query) {
    return '「$query」に該当する人は見つかりません';
  }

  @override
  String get peopleSearchHint => '名前や @username の一部でも検索できます。';

  @override
  String get profileShareAction => '共有';

  @override
  String get profileShareCopied => 'プロフィールのリンクをコピーしました';

  @override
  String get profileBirthday => '誕生日';

  @override
  String get profileEmptyTitle => 'まだ何もありません';

  @override
  String get profileEmptyHintSelf => '自己紹介を少し書いておくと、相手が誰と話しているか分かります。';

  @override
  String get profileEmptyHintOther => 'この人はプロフィールを入力していません。';

  @override
  String get profileAccount => 'アカウント';

  @override
  String get profileAccountNoEmail => 'サインイン済み';

  @override
  String get profilePhoto => '写真';

  @override
  String get profileNoPhoto => '写真はまだありません';

  @override
  String get profileOpenLinkFailed => 'このリンクを開けませんでした';

  @override
  String get profileContactCopied => 'クリップボードにコピーしました';

  @override
  String get profileCopyAction => 'コピー';

  @override
  String devicesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'デバイス$count台',
      zero: 'デバイスはありません',
    );
    return '$_temp0';
  }

  @override
  String get changePhoto => '写真を変更';

  @override
  String get choosePhoto => '写真を選ぶ';

  @override
  String get avatarCropTitle => '移動と拡大';

  @override
  String get avatarCropHint => 'ドラッグで移動、ピンチで拡大縮小します。';

  @override
  String get avatarCropConfirm => 'この写真を使う';

  @override
  String get avatarStagePreparing => '準備中…';

  @override
  String get avatarStageUploading => 'アップロード中…';

  @override
  String get avatarStageConfirming => 'もう少しです…';

  @override
  String get avatarStageProcessing => '写真を処理しています…';

  @override
  String get avatarStageDone => '写真を更新しました';

  @override
  String get avatarProcessingFailed => '写真を更新できませんでした';

  @override
  String get avatarProcessingFailedHint => 'サーバーがこの画像を受け付けませんでした。別のものをお試しください。';

  @override
  String get avatarNotAnImage => 'このファイルは画像ではありません';

  @override
  String get avatarTooLarge => 'この画像は大きすぎます。小さいものを選んでください。';

  @override
  String get avatarUnreadable => 'この画像を開けませんでした';

  @override
  String get profileEditDetails => '詳細';

  @override
  String get profileEditLinks => 'リンク';

  @override
  String get profileEditLinksHint => 'リンクは追加・削除した時点で、下のフォームとは別に保存されます。';

  @override
  String get profileNoLinks => 'リンクはまだありません';

  @override
  String get removeLink => 'リンクを削除';

  @override
  String get clearDateOfBirth => '誕生日を消す';

  @override
  String get specializationHint => '何をしている人か、短い言葉で';

  @override
  String bioCounter(int count, int max) {
    return '$count/$max';
  }

  @override
  String get profileSkillsHint => 'それぞれ30文字まで';

  @override
  String get profileSaved => 'プロフィールを保存しました';

  @override
  String get discardChangesTitle => '変更を破棄しますか？';

  @override
  String get discardChangesMessage => 'このプロフィールへの編集は失われます。';

  @override
  String get discardAction => '破棄';

  @override
  String get keepEditingAction => '編集を続ける';

  @override
  String get camera => 'カメラ';

  @override
  String get loading => '読み込み中…';

  @override
  String fieldTooLong(int max) {
    return '$max文字までです';
  }

  @override
  String skillTooLong(String skill, int max) {
    return '「$skill」は$max文字を超えています';
  }

  @override
  String callRoomName(String slug) {
    return 'ルーム $slug';
  }

  @override
  String get callJoinExplanation => 'ここでの通話はルームです。参加すれば、このチャットの誰でも入ってこられます。';

  @override
  String get callNoIncomingNotice => '着信の呼び出し音はまだありません。サーバーが着信を通知しないためです。';

  @override
  String get callWaitingForOthers => '他の人の参加を待っています…';

  @override
  String get callReconnecting => '再接続中…';

  @override
  String get callYou => '自分';

  @override
  String callParticipantsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '参加者$count人',
      zero: 'まだ誰もいません',
    );
    return '$_temp0';
  }

  @override
  String get callMicrophoneMute => 'ミュート';

  @override
  String get callMicrophoneUnmute => 'ミュート解除';

  @override
  String get callCameraStart => 'ビデオを開始';

  @override
  String get callCameraStop => 'ビデオを停止';

  @override
  String get callSpeakerOn => 'スピーカー';

  @override
  String get callSpeakerOff => '受話口';

  @override
  String get callLayoutGrid => 'グリッド';

  @override
  String get callLayoutSpeaker => '話者表示';

  @override
  String callPinParticipant(String name) {
    return '$nameさんをピン留め';
  }

  @override
  String callUnpinParticipant(String name) {
    return '$nameさんのピンを外す';
  }

  @override
  String get callMuteForEveryone => '全員に対してミュート';

  @override
  String get callUnmuteForEveryone => '発言を許可';

  @override
  String get callQualityExcellent => '接続は非常に良好です';

  @override
  String get callQualityGood => '接続は良好です';

  @override
  String get callQualityPoor => '接続が弱いです';

  @override
  String get callQualityLost => '接続が切れました';

  @override
  String get callMicrophonePermissionTitle => 'ChatiX にマイクの使用を許可';

  @override
  String get callMicrophonePermissionBody =>
      'ChatiX がマイクを使えないと、相手にはあなたの声が届きません。いつでもミュートに戻せます。';

  @override
  String get callCameraPermissionTitle => 'ChatiX にカメラの使用を許可';

  @override
  String get callCameraPermissionBody => '映像はカメラがオンの間だけ送られ、いつでもオフにできます。';

  @override
  String get callPermissionContinue => '続ける';

  @override
  String get callPermissionNotNow => '今はしない';

  @override
  String get callPermissionOpenSettings => '設定を開く';

  @override
  String get callMicrophoneBlocked => 'マイクはオフです。ChatiX に権限がありません。';

  @override
  String get callCameraBlocked => 'カメラはオフです。ChatiX に権限がありません。';

  @override
  String get callSelfPreview => '自分のカメラ';

  @override
  String get callSelfPreviewHint => 'ドラッグで移動';

  @override
  String get callShowControls => '通話の操作を表示';

  @override
  String get callOngoingInChat => 'このチャットの通話に参加中です';

  @override
  String get callReturn => '戻る';

  @override
  String callMiniPlayerLabel(String name) {
    return '$nameさんとの通話';
  }

  @override
  String get callMinimize => '通話を最小化';

  @override
  String get callDismiss => '閉じる';

  @override
  String get notificationNewMessage => '新しいメッセージ';

  @override
  String get notificationReplyHint => 'メッセージ';

  @override
  String get notificationReplyFailed => '返信を送信できませんでした';

  @override
  String get notificationActionFailed => 'この操作は完了できませんでした';

  @override
  String get notificationSettingsTitle => '通知';

  @override
  String get notificationSoundTitle => 'サウンド';

  @override
  String get notificationSoundSubtitle => '通知が届いたときに音を鳴らす';

  @override
  String get notificationVibrationTitle => 'バイブレーション';

  @override
  String get notificationVibrationSubtitle => '通知が届いたときに振動する';

  @override
  String get notificationPreviewTitle => 'メッセージのプレビュー';

  @override
  String get notificationPreviewSubtitle => '送信者と本文を表示する';

  @override
  String get quietHoursTitle => 'サイレント時間';

  @override
  String get quietHoursSubtitle => '通知は届きますが、音は鳴りません';

  @override
  String get quietHoursFrom => '開始';

  @override
  String get quietHoursTo => '終了';

  @override
  String get chatNotificationsTitle => 'チャットごとの例外';

  @override
  String get chatNotificationsEmpty => '例外はまだありません';

  @override
  String get chatNotificationsEmptyHint =>
      'すべてのチャットは上の設定に従います。個別の変更はチャット内から行えます。';

  @override
  String get chatNotificationsReset => 'すべてリセット';

  @override
  String get chatNotificationProfileTitle => 'このチャットの通知';

  @override
  String get chatNotificationProfileAll => 'すべてのメッセージ';

  @override
  String get chatNotificationProfileMentions => 'メンションのみ';

  @override
  String get chatNotificationProfileOff => 'なし';

  @override
  String get notificationPermissionOffTitle => '通知がオフになっています';

  @override
  String get notificationPermissionOffHint => 'システム設定で通知を許可するまで、以下の設定は届きません。';

  @override
  String get notificationsEmptyTitle => '通知はまだありません';

  @override
  String get notificationsEmptyMessage => '招待・メンション・メッセージがここに表示されます。';

  @override
  String get notificationsEmptyUnread => '未読はありません';

  @override
  String get notificationsEmptyRead => '既読はまだありません';

  @override
  String get notificationsEmptyFilterHint => 'すべてを表示するにはフィルターを「すべて」に切り替えてください。';

  @override
  String get timeJustNow => 'たった今';

  @override
  String notificationsMarkedRead(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 件の通知を既読にしました',
      zero: '未読はありませんでした',
    );
    return '$_temp0';
  }

  @override
  String timeMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 分前',
    );
    return '$_temp0';
  }

  @override
  String timeHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 時間前',
    );
    return '$_temp0';
  }

  @override
  String timeDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 日前',
      one: '昨日',
    );
    return '$_temp0';
  }

  @override
  String get appearanceTitle => '外観';

  @override
  String get appearanceHint => 'テーマ、アクセント、壁紙、吹き出し、メディア';

  @override
  String get appearancePreview => 'プレビュー';

  @override
  String get previewIncomingMessage => 'ここにあるものはすべてアクセントカラーから描かれています。';

  @override
  String get previewOutgoingMessage => '壁紙画像はありません。すべてコードです。';

  @override
  String get previewIncomingReply => 'スライダーを動かして確かめてください。';

  @override
  String get amoledTitle => 'ブラック（AMOLED）';

  @override
  String get amoledHint => '背景を純黒にします。OLED画面では黒い画素に電力がかかりません。';

  @override
  String get accentFromAvatar => '写真から色を取り込む';

  @override
  String get accentFromAvatarApplied => '写真からアクセントを取り込みました。';

  @override
  String get accentFromAvatarEmpty => '写真から取り込める色がありません。ほぼグレーです。';

  @override
  String get accentFromAvatarMissing => '先にプロフィール写真を追加してください。';

  @override
  String get accentFromAvatarFailed => '写真を読み取れませんでした。もう一度お試しください。';

  @override
  String get accentCustom => 'あなたの色';

  @override
  String get wallpaperNebula => 'ネビュラ';

  @override
  String get wallpaperRibbons => 'リボン';

  @override
  String get wallpaperPrism => 'プリズム';

  @override
  String get wallpaperHalo => 'ハロー';

  @override
  String get wallpaperDunes => 'デューン';

  @override
  String get wallpaperIntensity => '強さ';

  @override
  String get wallpaperPattern => 'パターン';

  @override
  String get appearanceDensity => '密度';

  @override
  String get appearanceDensityHint => '行と吹き出しが取る余白の量です。';

  @override
  String get textSizeHint => 'システムの文字サイズに重ねて適用されます。';

  @override
  String get bubbleShape => '吹き出しの形';

  @override
  String get bubbleCorners => '角の丸み';

  @override
  String get bubbleAnchor => 'アンカーの角';

  @override
  String get bubbleAnchorHint => '送信者側の角を絞り、吹き出しが送信者を指すようにします。';

  @override
  String get mediaSectionTitle => 'メディア';

  @override
  String get autoDownload => '自動ダウンロード';

  @override
  String get autoDownloadHint => '開く前に取得する添付ファイルを選びます。';

  @override
  String get autoDownloadPhotos => '写真';

  @override
  String get autoDownloadVideos => '動画';

  @override
  String get autoDownloadFiles => 'ファイル';

  @override
  String get autoDownloadVoice => 'ボイスメッセージ';

  @override
  String get autoDownloadWifi => 'Wi-Fi';

  @override
  String get autoDownloadMobile => 'モバイルデータ';

  @override
  String get autoDownloadNever => 'しない';

  @override
  String get cacheLimit => 'キャッシュの上限';

  @override
  String get cacheLimitHint => 'ダウンロードした添付ファイルは上限を超えるまで保持され、超えると古いものから削除されます。';

  @override
  String get cacheEmpty => 'キャッシュはまだありません';

  @override
  String get cacheClear => 'キャッシュを削除';

  @override
  String get cacheMeasuring => '計算中…';

  @override
  String get appearanceReduceMotionNotice =>
      'システムがアニメーションの軽減を求めているため、ここでは何も動きません。';

  @override
  String get appearanceHighContrastNotice =>
      'ハイコントラストが有効です。文字を読みやすくするため壁紙は控えめに描かれます。';

  @override
  String cacheInUse(String size) {
    return '$size 使用中';
  }

  @override
  String cacheCleared(String size) {
    return '$size を解放しました';
  }

  @override
  String sizeMegabytes(String value) {
    return '$value MB';
  }

  @override
  String sizeGigabytes(String value) {
    return '$value GB';
  }

  @override
  String get attachmentTapToDownload => 'タップしてダウンロード';

  @override
  String get welcomeHeadline => 'ChatiX へようこそ';

  @override
  String get welcomeTagline => 'あなたのテンポに合うメッセージを。';

  @override
  String get welcomeGetStarted => 'はじめる';

  @override
  String get welcomeSignIn => 'すでにアカウントがあります';

  @override
  String get onboardingSkip => 'スキップ';

  @override
  String get onboardingNext => '次へ';

  @override
  String get onboardingDone => 'アカウントを作成';

  @override
  String get onboardingRealtimeTitle => 'すべてリアルタイムで';

  @override
  String get onboardingRealtimeBody =>
      'メッセージも編集もリアクションも起きたその瞬間に届きます。アプリは通信の返事を待たずに、前回の続きから開きます。';

  @override
  String get onboardingTogetherTitle => 'チャット、グループ、チャンネル、通話';

  @override
  String get onboardingTogetherBody =>
      '1 対 1 でも、500 人のグループでも、誰でも読めるチャンネルでも。音声通話とビデオ通話はいつでもワンタップです。';

  @override
  String get onboardingPrivacyTitle => 'あなただけのもの';

  @override
  String get onboardingPrivacyBody =>
      'ログイン中の端末をすべて確認して終了でき、指紋でアプリをロックでき、ファイルは送信するまで端末の中に留まります。';

  @override
  String onboardingPageOf(int current, int total) {
    return '$total ページ中 $current ページ目';
  }

  @override
  String get loginHeadline => 'おかえりなさい';

  @override
  String get loginSubtitle => 'ログインして会話の続きを。';

  @override
  String get registerHeadline => 'アカウントを作成';

  @override
  String get registerSubtitle => '1 分ほどで終わります。';

  @override
  String get authOrContinueWith => 'または次で続ける';

  @override
  String get authNoAccount => 'アカウントをお持ちでないですか？';

  @override
  String get authHaveAccount => 'すでにアカウントをお持ちですか？';

  @override
  String get authErrorWrongLoginData => 'ユーザー名またはパスワードが違います。';

  @override
  String get authErrorEmailNotConfirmed => 'ログインする前にメールアドレスを確認してください。';

  @override
  String authErrorEmailNotConfirmedFor(String email) {
    return 'ログインする前に $email を確認してください。';
  }

  @override
  String get authResendEmail => 'メールを再送する';

  @override
  String get authErrorTooManyAttempts => '試行回数が多すぎます。1 分ほど待ってからやり直してください。';

  @override
  String get authErrorDuplicateUsername => 'このユーザー名はすでに使われています。';

  @override
  String get authErrorDuplicateEmail => 'このメールアドレスのアカウントはすでにあります。';

  @override
  String authErrorDuplicateField(String field) {
    return '$field はすでに使われています。';
  }

  @override
  String get authErrorPasswordMismatch => 'パスワードが一致しません。';

  @override
  String get authErrorInvalidCode => 'このコードはもう使えません。新しいものを取得してください。';

  @override
  String get authErrorUserNotFound => 'その情報のアカウントは見つかりませんでした。';

  @override
  String get authErrorOffline => '接続がありません。ネットワークを確認してやり直してください。';

  @override
  String get authErrorGeneric => '問題が発生しました。もう一度お試しください。';

  @override
  String get passwordStrengthLabel => 'パスワードの強度';

  @override
  String get passwordStrengthWeak => '弱い';

  @override
  String get passwordStrengthFair => 'ふつう';

  @override
  String get passwordStrengthGood => '良い';

  @override
  String get passwordStrengthStrong => '強い';

  @override
  String get passwordShow => 'パスワードを表示';

  @override
  String get passwordHide => 'パスワードを隠す';

  @override
  String get verifyEmailHeadline => 'メールを確認してください';

  @override
  String verifyEmailSentTo(String email) {
    return '$email に確認コードを送りました。';
  }

  @override
  String get verifyEmailSentToYou => '確認コードを送りました。';

  @override
  String get verifyEmailClipboardHint =>
      'メールのコードをコピーしてください。戻ってきた時点で ChatiX が自動で読み取ります。';

  @override
  String get verifyEmailCodeFromClipboard => 'クリップボードからコードを入力しました';

  @override
  String verifyEmailResendIn(int seconds) {
    return '次のメールは $seconds 秒後に送れます';
  }

  @override
  String get verifyEmailWrongAddress => 'アドレスが違いますか？';

  @override
  String get verifyEmailChangeAddress => '別のアドレスを使う';

  @override
  String get biometricUnlockTitle => '生体認証でロック解除';

  @override
  String get biometricUnlockSubtitle => 'ChatiX を開き直すたびに指紋または顔で確認します。';

  @override
  String get biometricUnlockUnavailable => 'この端末では生体認証が設定されていません。';

  @override
  String get biometricUnlockReason => 'ChatiX のロックを解除';

  @override
  String get biometricUnlockLockedTitle => 'ChatiX はロック中です';

  @override
  String get biometricUnlockLockedBody => 'ロックを解除してチャットに戻ります。';

  @override
  String get biometricUnlockAction => 'ロック解除';

  @override
  String get biometricUnlockFailed => '認証できませんでした。もう一度お試しください。';

  @override
  String get biometricUnlockLockedOut => '試行回数が多すぎるため、システムが生体認証を停止しました。';

  @override
  String get biometricUnlockNotEnrolled => 'この端末には指紋も顔も登録されていません。';

  @override
  String get biometricUnlockEnableFailed => '生体認証を有効にできませんでした。';

  @override
  String get settingsSecuritySection => 'セキュリティ';

  @override
  String get settingsAccountSection => 'アカウント';

  @override
  String get logoutConfirmTitle => 'ログアウトしますか？';

  @override
  String get logoutConfirmBody =>
      'この端末からメッセージ、下書き、ダウンロードしたファイルが消えます。アカウントはそのままです。';

  @override
  String get logoutAction => 'ログアウト';

  @override
  String get logoutFailed => 'ログアウトできませんでした。もう一度お試しください。';

  @override
  String get logoutInProgress => 'ログアウトしています…';

  @override
  String get appearanceFeel => '触感';

  @override
  String get appearanceHaptics => '触覚フィードバック';

  @override
  String get appearanceHapticsHint =>
      'メッセージの送信、リアクション、ジェスチャーの完了時に短く振動します。端末側の振動設定が優先されます。';

  @override
  String get failureGeneric => '問題が発生しました。もう一度お試しください。';

  @override
  String get failureRateLimited => '試行回数が多すぎます。1分ほど待ってからもう一度お試しください。';

  @override
  String get failureNoConnection => 'インターネットに接続できません。ネットワークを確認してください。';

  @override
  String get failureTimeout => 'サーバーの応答に時間がかかりすぎました。もう一度お試しください。';

  @override
  String get apiErrorSessionEnded => 'セッションが終了しました。もう一度サインインしてください。';

  @override
  String get apiErrorSessionExpired => 'セッションの有効期限が切れました。もう一度サインインしてください。';

  @override
  String get apiErrorSessionInvalid => 'セッションが無効になりました。もう一度サインインしてください。';

  @override
  String get apiErrorSessionSignedOut => 'このセッションはサインアウトされました。もう一度サインインしてください。';

  @override
  String get apiErrorAccessDenied => 'この操作を行う権限がありません。';

  @override
  String get apiErrorValidation => '入力内容に誤りがあります。確認してもう一度お試しください。';

  @override
  String get apiErrorNotFoundGeneric => '見つかりませんでした。削除された可能性があります。';

  @override
  String get apiErrorTooLongGeneric => '値が長すぎます。短くしてください。';

  @override
  String get apiErrorLimitExceededGeneric => '上限に達したため、この操作は利用できません。';

  @override
  String get apiErrorWrongLoginData => 'ユーザー名またはパスワードが正しくありません。';

  @override
  String get apiErrorPasswordMismatch => 'パスワードが一致しません。';

  @override
  String get apiErrorDuplicateUser => 'そのユーザー名またはメールアドレスは既に使われています。';

  @override
  String get apiErrorEmailNotConfirmed => 'サインインの前にメールアドレスを確認してください。';

  @override
  String get apiErrorOauthProviderUnsupported => 'そのサインイン方法には対応していません。';

  @override
  String get apiErrorOauthStateNotFound => 'サインインの試行が期限切れです。もう一度お試しください。';

  @override
  String get apiErrorOauthLinkedAnotherUser => 'そのアカウントは既に別のユーザーに連携されています。';

  @override
  String get apiErrorProfileExists => 'プロフィールは既に作成済みです。';

  @override
  String get apiErrorNotChatMember => 'あなたはこのチャットのメンバーではありません。';

  @override
  String get apiErrorAlreadyChatMember => 'その人は既にこのチャットにいます。';

  @override
  String get apiErrorInvalidChatRole => '有効なチャットロールではありません。';

  @override
  String get apiErrorDirectChatExists => 'この相手とのダイレクトチャットは既にあります。';

  @override
  String get apiErrorMessageTooLong => 'メッセージが長すぎます。短くしてください。';

  @override
  String get apiErrorInvalidMessage => 'そのままではこのメッセージを送信できません。';

  @override
  String get apiErrorSlowModeLimit => '低速モードが有効です。次の送信まで少しお待ちください。';

  @override
  String get apiErrorSlowModeOutOfRange => '低速モードは0秒から24時間の範囲で指定してください。';

  @override
  String get apiErrorAttachmentLimitExceeded => '1件のメッセージに添付できる数を超えています。';

  @override
  String get apiErrorAttachmentNotFound => 'その添付ファイルはもう利用できません。';

  @override
  String get apiErrorAttachmentValidation => 'このファイルは添付できません。種類とサイズを確認してください。';

  @override
  String get apiErrorEmptyAttachmentUpload => '添付するファイルを選んでください。';

  @override
  String get apiErrorInvalidUploadToken => 'アップロードの期限が切れました。ファイルを添付し直してください。';

  @override
  String get apiErrorAvatarNotImage => 'アバターには画像ファイルを指定してください。';

  @override
  String get apiErrorActiveCallExists => 'このチャットでは既に通話中です。';

  @override
  String get apiErrorNoActiveCall => 'このチャットに進行中の通話はありません。';

  @override
  String get apiErrorLivekitUnauthorized => 'この通話に参加できません。';

  @override
  String get apiErrorLivekitError => '通話サービスは現在利用できません。';

  @override
  String get apiErrorInvalidReaction => 'その絵文字はリアクションに使えません。';

  @override
  String get apiErrorReactionNotAllowed => 'このチャットではそのリアクションは許可されていません。';

  @override
  String get apiErrorReactionsDisabled => 'このチャットではリアクションが無効です。';

  @override
  String get apiErrorTooManyReactions => 'これ以上リアクションを追加できません。';

  @override
  String get apiErrorMaxLimitCursor => '一度に再開したチャットが多すぎます。';

  @override
  String a11yMessageFrom(String author, String time) {
    return '$authorからのメッセージ、$time';
  }

  @override
  String a11yMessageMine(String time) {
    return '自分のメッセージ、$time';
  }

  @override
  String get a11ySystemMessage => 'システムメッセージ';

  @override
  String a11yReactions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'リアクション$count件',
    );
    return '$_temp0';
  }

  @override
  String get a11yReactionYours => '自分のリアクションを含む';

  @override
  String get a11yMessageActionsHint => 'メッセージの操作を表示';

  @override
  String a11yMessageAttachmentsHint(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '添付ファイル$count件',
    );
    return '$_temp0';
  }

  @override
  String get reviewPromptTitle => 'アプリはいかがですか？';

  @override
  String get reviewPromptBody => 'ご意見をお聞かせいただけますか？';

  @override
  String get reviewPromptDecline => '今はしない';

  @override
  String get reviewPromptAccept => 'はい';

  @override
  String get feedbackTitle => 'ご意見をお聞かせください';

  @override
  String get feedbackBody =>
      'アプリの感想をお聞かせください。気に入っていただけたら、ストアでのレビューがとても励みになります。';

  @override
  String get feedbackHint => 'ここにご意見をご記入ください';

  @override
  String get feedbackSubmit => '送信';

  @override
  String get updateRequiredTitle => 'アップデートが必要です';

  @override
  String get updateAvailableTitle => 'アップデートがあります';

  @override
  String updateRequiredBody(String version) {
    return 'ChatiX を使い続けるにはバージョン $version が必要です。';
  }

  @override
  String updateAvailableBody(String version) {
    return 'バージョン $version が利用できます。';
  }

  @override
  String get updateWhatsNew => '更新内容';

  @override
  String get updateLater => 'あとで';

  @override
  String get updateNow => '今すぐ更新';

  @override
  String get updateAction => '更新';
}
