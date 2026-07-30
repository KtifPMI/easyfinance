import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  final double height;
  final bool showWordmark;

  const AppLogo({super.key, this.height = 28, this.showWordmark = true});

  /// Compact mark for app bars (PNG, transparent bg).
  const AppLogo.appBar({super.key})
      : height = 28,
        showWordmark = true;

  /// Large logo for splash / login.
  const AppLogo.hero({super.key})
      : height = 72,
        showWordmark = true;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/logo.png',
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, __, ___) => Icon(
        Icons.account_balance_wallet_rounded,
        size: height,
        color: Theme.of(context).primaryColor,
      ),
    );
  }
}
