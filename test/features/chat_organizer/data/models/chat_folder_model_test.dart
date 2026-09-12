import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat_organizer/data/models/chat_folder_model.dart';
import 'package:chatix/features/chat_organizer/data/models/folder_rule_model.dart';
import 'package:chatix/features/chat_organizer/domain/entities/chat_folder.dart';
import 'package:chatix/features/chat_organizer/domain/entities/folder_preset.dart';
import 'package:chatix/features/chat_organizer/domain/entities/folder_rule.dart';

void main() {
  test('a folder survives a trip through storage unchanged', () {
    const folder = ChatFolder(
      id: 'custom.1',
      title: 'Work',
      iconKey: 'work',
      matchMode: FolderMatchMode.any,
      rules: [
        ChatTypeRule({ChatType.group, ChatType.supergroup}),
        UnreadRule(),
        PinnedRule(expected: false),
        NoReplyFromMeRule(days: 3),
        MemberRule(userId: 9, label: 'Ann'),
      ],
    );

    final encoded = json.encode(ChatFolderModel.fromEntity(folder).toJson());
    final decoded = ChatFolderModel.fromJson(
      json.decode(encoded) as Map<String, dynamic>,
    ).toEntity();

    expect(decoded, folder);
  });

  test('a preset keeps knowing that it is one', () {
    final folder = ChatFolder.fromPreset(FolderPreset.noReplyFromMe);

    final decoded = ChatFolderModel.fromJson(
      ChatFolderModel.fromEntity(folder).toJson(),
    ).toEntity();

    expect(decoded?.preset, FolderPreset.noReplyFromMe);
    expect(decoded, folder);
  });

  test('a rule kind this build does not know is dropped, not guessed at', () {
    const unknown = FolderRuleModel(type: 'invented_in_a_later_build');

    expect(unknown.toEntity(), isNull);

    final folder = ChatFolderModel(
      id: 'custom.2',
      title: 'Half known',
      rules: const [unknown, FolderRuleModel(type: 'unread', expected: true)],
    ).toEntity();

    expect(folder?.rules, const [UnreadRule()]);
  });

  test('a folder left with no rules at all is dropped whole', () {
    final folder = const ChatFolderModel(
      id: 'custom.3',
      title: 'All unknown',
      rules: [FolderRuleModel(type: 'invented')],
    ).toEntity();

    // Keeping it would mean a tab whose rules match the entire list.
    expect(folder, isNull);
  });

  test('a member rule with no user id is not a rule', () {
    expect(const FolderRuleModel(type: 'member').toEntity(), isNull);
  });

  test('an over-long wait is clamped rather than trusted', () {
    final rule = const FolderRuleModel(
      type: 'no_reply_from_me',
      days: 100000,
    ).toEntity();

    expect(rule, const NoReplyFromMeRule(days: NoReplyFromMeRule.maxDays));
  });
}
