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
  String get messageDensity => 'メッセージの余白';

  @override
  String get densityCompact => 'コンパクト';

  @override
  String get densityCosy => '標準';

  @override
  String get densitySpacious => 'ゆったり';

  @override
  String get voiceSlideToCancel => '左にスワイプで取消、上で固定';

  @override
  String get voiceReleaseToCancel => '離すと取り消し';

  @override
  String get voiceRecordingLocked => '録音中 — 完了したら送信をタップ';

  @override
  String get voicePermissionDenied => 'マイクへのアクセスが無効です';

  @override
  String get voiceMessage => 'ボイスメッセージ';

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
}
