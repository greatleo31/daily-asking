import 'package:flutter/material.dart';

class CosmicScaffold extends StatelessWidget {
  const CosmicScaffold({required this.child, this.padding, super.key});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? const [Color(0xFF090D1B), Color(0xFF151B36), Color(0xFF23183A)]
              : const [Color(0xFFFFF9F1), Color(0xFFF5F1FF), Color(0xFFEAF6FF)],
        ),
      ),
      child: SafeArea(
        child: Stack(
          children: [
            Positioned(
              right: -72,
              top: -48,
              child: _GlowOrb(color: scheme.primary.withOpacity(0.22), size: 190),
            ),
            Positioned(
              left: -64,
              bottom: 90,
              child: _GlowOrb(color: scheme.secondary.withOpacity(0.18), size: 160),
            ),
            Padding(
              padding: padding ?? const EdgeInsets.fromLTRB(20, 18, 20, 18),
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: color, blurRadius: 80, spreadRadius: 44)],
      ),
    );
  }
}
