import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'phone_workspace_header.dart';

/// Full-screen scaffold for phone tool routes (stats, files, git, diff).
class PhoneToolScreen extends StatelessWidget {
  const PhoneToolScreen({
    super.key,
    required this.topInset,
    required this.title,
    required this.onBack,
    required this.child,
    this.onRefresh,
  });

  final double topInset;
  final String title;
  final VoidCallback onBack;
  final VoidCallback? onRefresh;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: Column(
        children: [
          if (topInset > 0) SizedBox(height: topInset),
          PhoneToolHeader(
            title: title,
            onBack: onBack,
            onRefresh: onRefresh,
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
