import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

class SkillsChipsField extends StatefulWidget {
  final String name;
  final List<String>? initialValue;
  final String? Function(List<String>?)? validator;

  const SkillsChipsField({
    super.key,
    required this.name,
    this.initialValue,
    this.validator,
  });

  @override
  State<SkillsChipsField> createState() => _SkillsChipsFieldState();
}

class _SkillsChipsFieldState extends State<SkillsChipsField> {
  final _textController = TextEditingController();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FormBuilderField<List<String>>(
      name: widget.name,
      initialValue: widget.initialValue ?? const [],
      validator: widget.validator,
      builder: (field) {
        final skills = field.value ?? const <String>[];

        void addSkill(String raw) {
          final skill = raw.trim();
          if (skill.isEmpty || skills.contains(skill)) {
            _textController.clear();
            return;
          }
          field.didChange([...skills, skill]);
          _textController.clear();
        }

        void removeSkill(String skill) {
          field.didChange(
            skills.where((existing) => existing != skill).toList(),
          );
        }

        return InputDecorator(
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context).profileSkills,
            border: const OutlineInputBorder(),
            errorText: field.errorText,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (skills.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: skills
                        .map(
                          (skill) => Chip(
                            label: Text(skill),
                            onDeleted: () => removeSkill(skill),
                          ),
                        )
                        .toList(),
                  ),
                ),
              TextField(
                controller: _textController,
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: AppLocalizations.of(context).skillsHint,
                ),
                onSubmitted: addSkill,
              ),
            ],
          ),
        );
      },
    );
  }
}
