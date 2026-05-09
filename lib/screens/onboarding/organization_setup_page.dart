// @tier: community
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/cubits/onboarding/onboarding_cubit.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/models/types/site_type.dart';

class OrganizationSetupPage extends StatelessWidget {
  const OrganizationSetupPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OnboardingCubit, OnboardingState>(
      builder: (context, state) {
        if (state is! OnboardingOrganizationSetup) {
          return const Center(child: CircularProgressIndicator());
        }

        final cubit = context.read<OnboardingCubit>();
        final validationError = state.validate();

        return Scaffold(
          appBar: AppBar(
            title: const Text('Organization Setup'),
            leading: cubit.canGoBack()
                ? IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: cubit.previousStep,
                  )
                : null,
            automaticallyImplyLeading: cubit.canGoBack(),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Text(
                  'Set Up Your Organization',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Provide basic information about your organization. You can configure additional settings later in the admin panel.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 32),

                // Section 1: Organization Name
                _buildSectionHeader(
                  context,
                  'Organization Name',
                  'What is the name of your organization?',
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: state.nameController,
                  decoration: InputDecoration(
                    hintText: 'Enter your organization name',
                    border: const OutlineInputBorder(),
                    errorText: state.name.displayError?.message,
                  ),
                  onChanged: cubit.setName,
                ),
                const SizedBox(height: 32),

                // Section 1.5: Organization Slug/Domain
                _buildSectionHeader(
                  context,
                  'Organization Domain',
                  'This will be used for your organization\'s public URL. The slug after provenance.app/ is limited to 20 characters.',
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: state.slugController,
                  maxLength: 20,
                  decoration: InputDecoration(
                    hintText: 'organization-slug',
                    border: const OutlineInputBorder(),
                    prefixText: 'provenance.app/',
                    prefixStyle: Theme.of(context).textTheme.bodyLarge
                        ?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                    helperText:
                        'Max 20 characters for the URL slug (the part after provenance.app/). '
                        'Auto-generated from your organization name.',
                    helperMaxLines: 2,
                    errorText: state.slug.isEmpty && !state.isPure
                        ? 'Organization domain is required'
                        : null,
                  ),
                  onChanged: cubit.setSlug,
                ),
                const SizedBox(height: 32),

                // Section 2: Organisms
                _buildSectionHeader(
                  context,
                  'Organisms',
                  'What organisms do you work with? Select at least one.',
                ),
                const SizedBox(height: 16),
                ...OrganismKind.values.map((organism) {
                  final isSelected =
                      state.selectedOrganisms.contains(organism);

                  return CheckboxListTile(
                    title: Text(organism.metadata.displayName),
                    value: isSelected,
                    onChanged: (selected) => cubit.setOrganismSelection(
                        organism,
                        selected ?? false,
                      ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  );
                }),
                if (state.selectedOrganisms.isEmpty && !state.isPure)
                  Padding(
                    padding: const EdgeInsets.only(left: 16, top: 8),
                    child: Text(
                      'Please select at least one organism type',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                const SizedBox(height: 32),

                // Section 3: Site Types
                _buildSectionHeader(
                  context,
                  'Site Types',
                  state.selectedOrganisms.isEmpty
                      ? 'Select organisms above to see available site types'
                      : 'What types of sites will you manage? Select at least one.',
                ),
                const SizedBox(height: 16),
                Builder(
                  builder: (context) {
                    // Available site types for coral-only
                    final availableSiteTypes = <SiteType>{
                      SiteType.nursery,
                      SiteType.outplanting,
                    };
                    final sortedSiteTypes = availableSiteTypes.toList()
                      ..sort((a, b) => a.name.compareTo(b.name));

                    if (state.selectedOrganisms.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: Text(
                          'Please select at least one organism type above to see available site types',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                                fontStyle: FontStyle.italic,
                              ),
                        ),
                      );
                    }

                    return Column(
                      children: [
                        ...sortedSiteTypes.map(
                          (siteType) => CheckboxListTile(
                            title: Text(siteType.name),
                            subtitle: Text(
                              'Supports: ${siteType.groupTypes.map((gt) => gt.name).join(", ")}',
                              style: Theme.of(context).textTheme.bodySmall,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            value: state.selectedSiteTypes.contains(siteType),
                            onChanged: (selected) => cubit.setSiteTypeSelection(
                              siteType,
                              selected ?? false,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                if (state.selectedSiteTypes.isEmpty && !state.isPure)
                  Padding(
                    padding: const EdgeInsets.only(left: 16, top: 8),
                    child: Text(
                      'Please select at least one site type',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                const SizedBox(height: 32),

                // Continue Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: state.isValid ? cubit.nextStep : null,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Create Organization'),
                  ),
                ),
                if (validationError != null && !state.isPure)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      validationError,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                if (state.errorMessage != null &&
                    state.errorMessage!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(
                            context,
                          ).colorScheme.error.withValues(alpha: 0.5),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: Theme.of(context).colorScheme.error,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Error Creating Organization',
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.error,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            constraints: const BoxConstraints(maxHeight: 200),
                            child: SingleChildScrollView(
                              child: SelectableText(
                                state.errorMessage!,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onErrorContainer,
                                      fontFamily: 'monospace',
                                      height: 1.4,
                                    ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton.icon(
                                onPressed: () {
                                  // Clear the error to allow retry
                                  cubit.setName(state.name.value);
                                },
                                icon: const Icon(Icons.refresh, size: 16),
                                label: const Text('Dismiss & Retry'),
                                style: TextButton.styleFrom(
                                  foregroundColor: Theme.of(
                                    context,
                                  ).colorScheme.error,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    String subtitle,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
