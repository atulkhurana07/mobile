import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

enum LoadingSize { sm, md, lg }

class LoadingView extends StatefulWidget {
  final String? message;
  final LoadingSize size;
  final bool isDark;
  final bool compact;

  const LoadingView({
    super.key,
    this.message,
    this.size = LoadingSize.md,
    this.isDark = true,
    this.compact = false,
  });

  @override
  State<LoadingView> createState() => _LoadingViewState();
}

class _LoadingViewState extends State<LoadingView>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _glowAnimation = Tween<double>(begin: 0.25, end: 0.55).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double get _logoHeight {
    switch (widget.size) {
      case LoadingSize.sm:
        return 42.0;
      case LoadingSize.md:
        return 62.0;
      case LoadingSize.lg:
        return 82.0;
    }
  }

  double get _glowSize {
    switch (widget.size) {
      case LoadingSize.sm:
        return 60.0;
      case LoadingSize.md:
        return 90.0;
      case LoadingSize.lg:
        return 120.0;
    }
  }

  double get _fontSize {
    switch (widget.size) {
      case LoadingSize.sm:
        return 11.5;
      case LoadingSize.md:
        return 13.0;
      case LoadingSize.lg:
        return 15.0;
    }
  }

  String get _animatedAsset {
    return widget.isDark
        ? 'assets/images/urja_loading_darkmode.gif'
        : 'assets/images/urja_loading.gif';
  }

  String get _fallbackPng {
    return widget.isDark
        ? 'assets/images/urja-logo-darkmode.png'
        : 'assets/images/urja-logo.png';
  }

  @override
  Widget build(BuildContext context) {
    final content = Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: widget.compact ? 8.0 : 20.0,
          vertical: widget.compact ? 6.0 : 16.0,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: _pulseAnimation,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Dynamic pulsing charging aura behind the loader
                  AnimatedBuilder(
                    animation: _glowAnimation,
                    builder: (context, child) {
                      return Container(
                        width: _glowSize,
                        height: _glowSize * 0.75,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(_glowSize / 2),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryLight.withValues(
                                alpha: _glowAnimation.value,
                              ),
                              blurRadius: widget.size == LoadingSize.sm ? 18 : 32,
                              spreadRadius: widget.size == LoadingSize.sm ? 3 : 6,
                            ),
                            BoxShadow(
                              color: AppColors.success.withValues(
                                alpha: _glowAnimation.value * 0.6,
                              ),
                              blurRadius: widget.size == LoadingSize.sm ? 12 : 22,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  // Official Animated URJA Loading Graphic
                  Image.asset(
                    _animatedAsset,
                    height: _logoHeight,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      // First fallback: Static branded URJA PNG
                      return Image.asset(
                        _fallbackPng,
                        height: _logoHeight,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: _logoHeight,
                          height: _logoHeight,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.primaryLight,
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            Icons.electric_bolt_rounded,
                            size: _logoHeight * 0.55,
                            color: AppColors.primaryLight,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            if (widget.message != null && widget.message!.isNotEmpty) ...[
              SizedBox(height: widget.compact ? 12 : 20),
              Text(
                widget.message!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: widget.isDark ? Colors.white.withValues(alpha: 0.82) : Colors.black87,
                  fontSize: _fontSize,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 8),
              // Synchronized animated energy dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (index) {
                  return AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      final phase = (_controller.value + (index * 0.25)) % 1.0;
                      final opacity = (0.3 + 0.7 * (1.0 - (phase - 0.5).abs() * 2)).clamp(0.2, 1.0);
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2.5),
                        width: widget.size == LoadingSize.sm ? 4.5 : 6.0,
                        height: widget.size == LoadingSize.sm ? 4.5 : 6.0,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primaryLight.withValues(alpha: opacity),
                        ),
                      );
                    },
                  );
                }),
              ),
            ],
          ],
        ),
      ),
    );

    if (widget.compact) {
      return content;
    }

    return Center(child: content);
  }
}
