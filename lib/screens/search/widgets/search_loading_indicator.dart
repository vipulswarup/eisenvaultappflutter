import 'package:flutter/material.dart';
import '../../../constants/colors.dart';

class SearchLoadingIndicator extends StatelessWidget {
  final String searchQuery;
  
  const SearchLoadingIndicator({
    Key? key,
    required this.searchQuery,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(EVColors.buttonBackground),
          ),
          const SizedBox(height: 16),
          Text(
            'Searching for "$searchQuery"...',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'This may take a moment depending on your repository size',
            style: TextStyle(
              fontSize: 12,
              color: EVColors.iconGreyLight,
            ),
            textAlign: TextAlign.center,
          ),        ],
      ),
    );
  }
}
