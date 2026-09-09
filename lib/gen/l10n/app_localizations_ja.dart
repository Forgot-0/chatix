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
  String get change_language => 'Change application language';

  @override
  String get theme => 'Theme';

  @override
  String get change_theme => 'Change application theme';

  @override
  String get notifications => 'Notifications';

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
}
