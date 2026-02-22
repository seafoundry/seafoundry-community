// @tier: community
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/cubits/public_holdings_map/public_holdings_map_cubit.dart';
import 'package:seafoundry_app/widgets/public/holdings_map/filter_widgets.dart';
import 'package:seafoundry_app/widgets/public/holdings_map/holdings_map_utils.dart';

/// Filter panel for the public holdings map.
///
/// Displays filter chips for holdings/outplants/CRC data,
/// and expandable dropdown filters for region, site, species, year, and genet.
class CrcFilterPanel extends StatefulWidget {
  const CrcFilterPanel({
    super.key,
    required this.showHoldings,
    required this.showOutplants,
    required this.showCrcData,
    required this.enableSampleImpactData,
    required this.initialShowFilters,
    this.onHoldingsChanged,
    this.onOutplantsChanged,
    this.onCrcDataChanged,
  });

  final bool showHoldings;
  final bool showOutplants;
  final bool showCrcData;
  final bool enableSampleImpactData;
  final bool initialShowFilters;
  final ValueChanged<bool>? onHoldingsChanged;
  final ValueChanged<bool>? onOutplantsChanged;
  final ValueChanged<bool>? onCrcDataChanged;

  @override
  State<CrcFilterPanel> createState() => _CrcFilterPanelState();
}

class _CrcFilterPanelState extends State<CrcFilterPanel> {
  late bool _showFilters;

  @override
  void initState() {
    super.initState();
    _showFilters = widget.initialShowFilters;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PublicHoldingsMapCubit, PublicHoldingsMapState>(
      builder: (context, cubitState) {
        final cubit = context.read<PublicHoldingsMapCubit>();
        final isFilterLoading = cubitState.isFilterLoading;
        final filteredCount =
            isFilterLoading ? null : cubit.getFilteredCrcPoints().length;

        return Card(
          elevation: 4,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildChipRow(cubitState, cubit),
                _buildLoadingIndicators(cubitState, cubit),
                _buildExpandedFilters(cubitState, cubit, filteredCount),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildChipRow(
    PublicHoldingsMapState cubitState,
    PublicHoldingsMapCubit cubit,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CompactFilterChip(
            label: 'Holdings',
            selected: widget.showHoldings,
            color: const Color(0xFF1E88E5),
            onSelected: widget.onHoldingsChanged,
          ),
          const SizedBox(width: 6),
          CompactFilterChip(
            label: 'Outplants',
            selected: widget.showOutplants,
            color: const Color(0xFFFF9100),
            onSelected: widget.onOutplantsChanged,
          ),
          if (widget.enableSampleImpactData) ...[
            const SizedBox(width: 6),
            Container(height: 20, width: 1, color: Colors.grey.shade300),
            const SizedBox(width: 6),
            CompactFilterChip(
              label: cubitState.isLoadingCrcData
                  ? 'CRC...'
                  : 'CRC (${cubitState.crcPoints.length})',
              selected: widget.showCrcData,
              color: crcAccentColor,
              onSelected: cubitState.isLoadingCrcData
                  ? null
                  : widget.onCrcDataChanged,
              icon: Icons.public,
            ),
            if (widget.showCrcData && !cubitState.isLoadingCrcData) ...[
              const SizedBox(width: 4),
              _buildFilterToggle(cubitState),
              if (cubitState.hasActiveFilters) ...[
                const SizedBox(width: 4),
                _buildClearButton(cubit),
              ],
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildFilterToggle(PublicHoldingsMapState cubitState) {
    return InkWell(
      onTap: () => setState(() => _showFilters = !_showFilters),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(
          _showFilters ? Icons.expand_less : Icons.tune,
          size: 18,
          color: cubitState.hasActiveFilters ? crcAccentColor : Colors.grey,
        ),
      ),
    );
  }

  Widget _buildClearButton(PublicHoldingsMapCubit cubit) {
    return InkWell(
      onTap: () => cubit.clearFilters(),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Text(
          'Clear',
          style: TextStyle(fontSize: 11, color: crcAccentColor),
        ),
      ),
    );
  }

  Widget _buildLoadingIndicators(
    PublicHoldingsMapState cubitState,
    PublicHoldingsMapCubit cubit,
  ) {
    return Column(
      children: [
        if (cubitState.isLoadingCrcData)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 6),
                Text(
                  cubitState.loadingStatus,
                  style: TextStyle(fontSize: 11, color: crcAccentColor),
                ),
              ],
            ),
          ),
        if (cubitState.crcError != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, color: Colors.red.shade700, size: 14),
                const SizedBox(width: 4),
                Text(
                  'Load failed',
                  style: TextStyle(color: Colors.red.shade700, fontSize: 11),
                ),
                const SizedBox(width: 4),
                InkWell(
                  onTap: () => cubit.loadCrcData(),
                  child: const Text(
                    'Retry',
                    style: TextStyle(fontSize: 11, color: Colors.blue),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildExpandedFilters(
    PublicHoldingsMapState cubitState,
    PublicHoldingsMapCubit cubit,
    int? filteredCount,
  ) {
    final showExpanded = widget.enableSampleImpactData &&
        widget.showCrcData &&
        _showFilters &&
        !cubitState.isLoadingCrcData &&
        cubitState.crcError == null;

    if (!showExpanded) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Divider(height: 1),
        ),
        _buildFilterHeader(cubitState, filteredCount),
        const SizedBox(height: 6),
        _buildFilterDropdowns(cubitState, cubit),
      ],
    );
  }

  Widget _buildFilterHeader(
    PublicHoldingsMapState cubitState,
    int? filteredCount,
  ) {
    return Row(
      children: [
        Text(
          'Filter:',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: crcAccentColor,
          ),
        ),
        const SizedBox(width: 6),
        if (cubitState.isFilterLoading)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 10,
                height: 10,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 4),
              Text(
                'Searching...',
                style: TextStyle(fontSize: 10, color: Colors.orange.shade700),
              ),
            ],
          )
        else if (cubitState.hasActiveFilters)
          Text(
            '$filteredCount/${cubitState.crcPoints.length}',
            style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
          ),
      ],
    );
  }

  Widget _buildFilterDropdowns(
    PublicHoldingsMapState cubitState,
    PublicHoldingsMapCubit cubit,
  ) {
    final speciesOptions = cubitState.filterOptions.species;
    final speciesNameById = <String, String>{
      for (final option in speciesOptions) option.id: option.name,
    };
    final speciesIdByName = <String, String>{
      for (final option in speciesOptions) option.name: option.id,
    };
    final selectedSpeciesLabel =
        speciesNameById[cubitState.selectedSpecies] ??
        cubitState.selectedSpecies;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          CompactFilterDropdown(
            label: 'Region',
            value: cubitState.selectedRegion,
            items: cubitState.filterOptions.regions.map((r) => r.name).toList(),
            onChanged: (v) => cubit.setRegion(v),
          ),
          const SizedBox(width: 6),
          CompactFilterDropdown(
            label: 'Site',
            value: cubitState.selectedReef,
            items: cubit.getAvailableReefs(),
            onChanged: (v) => cubit.setReef(v),
          ),
          const SizedBox(width: 6),
          CompactFilterDropdown(
            label: 'Species',
            value: selectedSpeciesLabel,
            items: speciesOptions.map((s) => s.name).toList(),
            onChanged: (v) => cubit.setSpecies(
              v == null ? null : speciesIdByName[v],
            ),
          ),
          const SizedBox(width: 6),
          CompactFilterDropdown(
            label: cubitState.isLoadingYears ? 'Year...' : 'Year',
            value: cubitState.selectedYear?.toString(),
            items: cubitState.availableYears.map((y) => y.toString()).toList(),
            onChanged: cubitState.isLoadingYears ||
                    cubitState.isLoadingYearFilter
                ? null
                : (v) => cubit.setYear(v != null ? int.tryParse(v) : null),
          ),
          const SizedBox(width: 6),
          GenetSearchField(cubitState: cubitState, cubit: cubit),
        ],
      ),
    );
  }
}
