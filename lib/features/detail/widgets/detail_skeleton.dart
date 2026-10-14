import 'package:flutter/material.dart';

import '../../../core/theme/tokens/app_spacing.dart';
import '../../../core/widgets/shimmer_box.dart';

/// The same borderless two-block shape as the loaded screen, pulsing while the
/// restaurant is still being fetched.
class DetailSkeleton extends StatelessWidget {
  const DetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ShimmerBox(width: 120, height: 20),
          SizedBox(height: AppSpacing.md),
          ShimmerBox(width: 240, height: 16),
          SizedBox(height: 10),
          ShimmerBox(width: 180, height: 16),
          SizedBox(height: AppSpacing.xl),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              ShimmerBox(width: 110, height: 18),
              ShimmerBox(width: 36, height: 20),
            ],
          ),
        ],
      ),
    );
  }
}
