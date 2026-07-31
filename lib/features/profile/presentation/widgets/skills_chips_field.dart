import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';

/// `flutter_form_builder` doesn't ship a tags/chips input out of the box,
/// so this wraps a plain [FormBuilderField]`<List<String>>` with a small
/// custom UI (existing chips + a text box that appends on submit) instead
/// of pulling in a separate chips-input package.
class SkillsChipsField extends StatefulWidget {
  final String name;
  final List<String>? initialValue;
  final String? Function(List<String>?)? validator;

  const SkillsChipsField({super.key, required this.name, this.initialValue, this.validator});

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
          field.didChange(skills.where((existing) => existing != skill).toList());
        }

        return InputDecorator(
          decoration: InputDecoration(
            labelText: 'Skills',
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
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: 'Type a skill and press enter',
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
