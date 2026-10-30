import 'package:kinos/theme/app_theme.dart';
import 'package:flutter/material.dart';

import 'package:cached_network_image/cached_network_image.dart';

import 'package:kinos/models/item_base_model.dart';
import 'package:kinos/seerr/seerr_models.dart';
import 'package:kinos/util/custom_cache_manager.dart';
import 'package:kinos/util/localization_helper.dart';

class SeerrUserLabel extends StatelessWidget {
  final SeerrUserModel? user;

  const SeerrUserLabel({
    required this.user,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final avatarUrl = user?.avatar;
    final placeholder = CircleAvatar(
      radius: AppManagementLayout.avatarSize / 2,
      child: Icon(
        KinosItemType.person.icon,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );

    final avatar = avatarUrl == null || avatarUrl.isEmpty
        ? placeholder
        : ClipOval(
            child: CachedNetworkImage(
              imageUrl: avatarUrl,
              cacheManager: CustomCacheManager.instance,
              cacheKey:
                  'seerr-avatar-${user?.id}-${user?.displayName}-$avatarUrl',
              width: AppManagementLayout.avatarSize,
              height: AppManagementLayout.avatarSize,
              fit: BoxFit.cover,
              placeholder: (_, __) => placeholder,
              errorWidget: (_, __, ___) => placeholder,
            ),
          );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        avatar,
        const SizedBox(width: AppSpacing.xs),
        Flexible(
          child: Text(
            user?.label ?? context.localized.unknown,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
