// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/models/organization.dart';

/// Individual suggestion row for the organization autocomplete dropdown.
class OrganizationSuggestionTile extends StatelessWidget {
  const OrganizationSuggestionTile({
    super.key,
    required this.organization,
    required this.isHighlighted,
    required this.onTap,
  });

  final Organization organization;
  final bool isHighlighted;
  final ValueChanged<Organization> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: isHighlighted
          ? theme.colorScheme.primaryContainer
          : Colors.transparent,
      child: InkWell(
        onTap: () => onTap(organization),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor:
                    theme.colorScheme.primary.withValues(alpha: 0.1),
                child: Icon(
                  Icons.business,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      organization.name,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      organization.domain,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
