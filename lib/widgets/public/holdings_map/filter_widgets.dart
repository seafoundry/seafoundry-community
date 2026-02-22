// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/cubits/public_holdings_map/public_holdings_map_cubit.dart';
import 'package:seafoundry_app/widgets/public/holdings_map/holdings_map_utils.dart';

/// Compact filter chip widget for map filters.
class CompactFilterChip extends StatelessWidget {
  const CompactFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.color,
    this.onSelected,
    this.icon,
  });

  final String label;
  final bool selected;
  final Color color;
  final ValueChanged<bool>? onSelected;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSelected != null ? () => onSelected!(!selected) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color:
              selected ? color.withValues(alpha: 0.15) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? color : Colors.grey.shade300,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 12, color: selected ? color : Colors.grey),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                color: selected ? color : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact dropdown filter widget for map filters.
class CompactFilterDropdown extends StatelessWidget {
  const CompactFilterDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    this.onChanged,
  });

  final String label;
  final String? value;
  final List<String> items;
  final ValueChanged<String?>? onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String?>(
      initialValue: value,
      onSelected: onChanged,
      enabled: onChanged != null,
      tooltip: label,
      offset: const Offset(0, 36),
      constraints: const BoxConstraints(maxHeight: 300, maxWidth: 200),
      itemBuilder: (context) => [
        PopupMenuItem<String?>(
          value: null,
          child: Text('All $label', style: const TextStyle(fontSize: 12)),
        ),
        ...items.map(
          (item) => PopupMenuItem<String?>(
            value: item,
            child: Text(
              item,
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: value != null
              ? crcAccentColor.withValues(alpha: 0.1)
              : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: value != null ? crcAccentColor : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value ?? label,
              style: TextStyle(
                fontSize: 11,
                color: value != null ? crcAccentColor : Colors.grey.shade600,
                fontWeight: value != null ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.arrow_drop_down,
              size: 14,
              color: value != null ? crcAccentColor : Colors.grey,
            ),
          ],
        ),
      ),
    );
  }
}

/// Genet search autocomplete field.
class GenetSearchField extends StatelessWidget {
  const GenetSearchField({
    super.key,
    required this.cubitState,
    required this.cubit,
  });

  final PublicHoldingsMapState cubitState;
  final PublicHoldingsMapCubit cubit;

  @override
  Widget build(BuildContext context) {
    final isDisabled =
        cubitState.isLoadingGenets || cubitState.isLoadingGenetFilter;

    return SizedBox(
      width: 140,
      height: 28,
      child: Autocomplete<String>(
        optionsBuilder: (TextEditingValue textEditingValue) {
          if (textEditingValue.text.isEmpty || isDisabled) {
            return const Iterable<String>.empty();
          }

          // Case-insensitive partial match, limit to 10 suggestions
          final matches = cubitState.availableGenets.where((genet) {
            return genet
                .toLowerCase()
                .contains(textEditingValue.text.toLowerCase());
          }).take(10).toList();

          return matches;
        },
        onSelected: (String selection) {
          cubit.setGenet(selection);
          cubit.setGenetSearchError(null);
        },
        fieldViewBuilder:
            (context, textEditingController, focusNode, onFieldSubmitted) {
          // Pre-populate with selected genet
          if (cubitState.selectedGenet != null &&
              textEditingController.text.isEmpty) {
            textEditingController.text = cubitState.selectedGenet!;
          }

          return _buildTextField(
            textEditingController,
            focusNode,
            isDisabled,
          );
        },
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController textEditingController,
    FocusNode focusNode,
    bool isDisabled,
  ) {
    return TextField(
      controller: textEditingController,
      focusNode: focusNode,
      enabled: !isDisabled,
      style: const TextStyle(fontSize: 11),
      decoration: InputDecoration(
        hintText: cubitState.isLoadingGenets ? 'Loading...' : 'Genet',
        hintStyle: TextStyle(fontSize: 11, color: Colors.grey.shade500),
        errorText: cubitState.genetSearchError,
        errorStyle: const TextStyle(fontSize: 9),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: crcAccentColor),
        ),
        filled: true,
        fillColor: cubitState.selectedGenet != null
            ? crcAccentColor.withValues(alpha: 0.1)
            : Colors.white,
        isDense: true,
        suffixIcon: _buildSuffixIcon(textEditingController),
      ),
      onSubmitted: isDisabled ? null : (value) => _handleSubmit(value),
    );
  }

  Widget _buildSuffixIcon(TextEditingController textEditingController) {
    if (cubitState.isLoadingGenetFilter) {
      return const Padding(
        padding: EdgeInsets.all(6),
        child: SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (cubitState.selectedGenet != null) {
      return InkWell(
        onTap: () {
          textEditingController.clear();
          cubit.setGenet(null);
          cubit.setGenetSearchError(null);
        },
        child: const Icon(Icons.clear, size: 14),
      );
    }
    return const Icon(Icons.search, size: 14);
  }

  void _handleSubmit(String value) {
    if (value.isEmpty) {
      cubit.setGenet(null);
      cubit.setGenetSearchError(null);
      return;
    }

    // Check for exact match
    if (cubitState.availableGenets.contains(value)) {
      cubit.setGenet(value);
      cubit.setGenetSearchError(null);
    } else {
      // Show "Did you mean" suggestions
      final suggestions = cubitState.availableGenets
          .where((g) => g.toLowerCase().contains(value.toLowerCase()))
          .take(3)
          .toList();

      if (suggestions.isNotEmpty) {
        cubit.setGenetSearchError(
          'Did you mean: ${suggestions.join(", ")}?',
        );
      } else {
        cubit.setGenetSearchError('No matching genet found');
      }
    }
  }
}
