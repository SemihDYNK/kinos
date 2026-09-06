import 'package:flutter/material.dart';

import 'package:fladder/models/items/item_shared_models.dart';
import 'package:fladder/screens/details_screens/person_detail_screen.dart';
import 'package:fladder/theme/app_theme.dart';
import 'package:fladder/util/fladder_image.dart';
import 'package:fladder/util/localization_helper.dart';
import 'package:fladder/util/string_extensions.dart';
import 'package:fladder/widgets/shared/focus_row.dart';

/// Casting en une seule rangée horizontale, défilable — photo et nom,
/// aucune pastille ni fond rempli (cf. CLAUDE.md, pas de couleur d'accent
/// décorative).
class MediaCastRow extends StatelessWidget {
  final List<Person> people;
  final EdgeInsets contentPadding;

  const MediaCastRow({
    required this.people,
    required this.contentPadding,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (people.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: contentPadding.copyWith(top: 0, bottom: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.localized.castAndCrew,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 150,
            child: FocusRow(
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: people.length,
                separatorBuilder: (context, index) => const SizedBox(width: AppSpacing.sm),
                itemBuilder: (context, index) {
                  final person = people[index];
                  return SizedBox(
                    width: 96,
                    child: FocusRing(
                      borderRadius: AppRadii.controlBorder,
                      onActivate: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => PersonDetailScreen(person: person),
                        ),
                      ),
                      child: ExcludeFocus(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: AppRadii.controlBorder,
                              child: AspectRatio(
                                aspectRatio: 1,
                                child: FladderImage(
                                  image: person.image,
                                  fit: BoxFit.cover,
                                  placeHolder: ColoredBox(
                                    color: AppColors.surfaceHigh,
                                    child: Center(
                                      child: Text(
                                        person.name.getInitials(),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(color: AppColors.textSecondary),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              person.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary),
                            ),
                            if (person.role.isNotEmpty)
                              Text(
                                person.role,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
