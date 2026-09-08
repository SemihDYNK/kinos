import 'package:flutter/material.dart';

import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kinos/jellyfin/jellyfin_open_api.swagger.dart';
import 'package:kinos/providers/control_panel/control_libraries_provider.dart';
import 'package:kinos/screens/settings/settings_list_tile.dart';
import 'package:kinos/screens/settings/widgets/settings_label_divider.dart';
import 'package:kinos/screens/settings/widgets/settings_list_group.dart';
import 'package:kinos/screens/shared/outlined_text_field.dart';
import 'package:kinos/util/localization_helper.dart';
import 'package:kinos/util/string_extensions.dart';
import 'package:kinos/widgets/shared/enum_selection.dart';
import 'package:kinos/widgets/shared/item_actions.dart';

class NewLibrarySection extends ConsumerWidget {
  final VirtualFolderInfo selectedFolder;
  const NewLibrarySection({
    required this.selectedFolder,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = ref.read(controlLibrariesProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...settingsListGroup(
          context,
          SettingsLabelDivider(label: context.localized.newLibrary),
          [
            SettingsListTile(
              label: Text(context.localized.name),
              trailing: OutlinedTextField(
                placeHolder: context.localized.name,
                controller: TextEditingController(
                  text: selectedFolder.name,
                ),
                onSubmitted: (value) {
                  provider.updateNewFolder(
                    selectedFolder.copyWith(
                      name: value,
                    ),
                  );
                },
              ),
            ),
            SettingsListTile(
              label: Text(context.localized.contentType),
              trailing: EnumBox(
                current: selectedFolder.collectionType?.name.toUpperCaseSplit() ?? context.localized.none,
                itemBuilder: (context) => CollectionTypeOptions.values
                    .whereNot((value) => value == CollectionTypeOptions.swaggerGeneratedUnknown)
                    .map(
                      (type) => ItemActionButton(
                        label: Text((type.value ?? "").toUpperCaseSplit()),
                        action: () {
                          provider.updateNewLibraryType(type);
                        },
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
