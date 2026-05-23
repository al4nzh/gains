import 'package:flutter/material.dart';
import 'package:gains/core/theme/app_colors.dart';

class GainsScaffold extends StatelessWidget {
  const GainsScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.padding = const EdgeInsets.symmetric(horizontal: 24),
  });

  final Widget body;
  final PreferredSizeWidget? appBar;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: appBar,
      body: SafeArea(
        child: Padding(padding: padding, child: body),
      ),
    );
  }
}
