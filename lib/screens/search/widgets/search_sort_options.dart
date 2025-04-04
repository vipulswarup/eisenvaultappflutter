import 'package:flutter/material.dart';
import '../../../constants/colors.dart';

class SearchSortOptions extends StatelessWidget {
  final String currentSortBy;
  final bool isAscending;
  final Function(String, bool) onSortChanged;

  const SearchSortOptions({
    Key? key,
    required this.currentSortBy,
    required this.isAscending,
    required this.onSortChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          const Text(
            'Sort by:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          _buildSortDropdown(),
          const Spacer(),
          _buildOrderToggle(),
        ],
      ),
    );
  }

  Widget _buildSortDropdown() {
    return DropdownButton<String>(
      value: currentSortBy,
      underline: Container(), // Remove the default underline
      icon: const Icon(Icons.arrow_drop_down, size: 18),
      isDense: true,
      items: const [
        DropdownMenuItem(
          value: 'name',
          child: Text('Name'),
        ),
        DropdownMenuItem(
          value: 'modifiedAt',
          child: Text('Modified Date'),
        ),
        DropdownMenuItem(
          value: 'createdAt',
          child: Text('Created Date'),
        ),
        DropdownMenuItem(
          value: 'type',
          child: Text('Type'),
        ),
      ],
      onChanged: (String? value) {
        if (value != null) {
          onSortChanged(value, isAscending);
        }
      },
    );
  }

  Widget _buildOrderToggle() {
    return InkWell(
      onTap: () => onSortChanged(currentSortBy, !isAscending),
      child: Row(
        children: [
          Text(
            isAscending ? 'Ascending' : 'Descending',
            style: const TextStyle(
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            isAscending ? Icons.arrow_upward : Icons.arrow_downward,
            size: 18,
            color: EVColors.primaryBlue,
          ),
        ],
      ),
    );
  }
}
