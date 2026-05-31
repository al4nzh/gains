import 'package:flutter/material.dart';
import 'package:gains/core/theme/app_colors.dart';

/// Animated shimmer wrapper — place skeleton placeholders as direct descendants.
class Shimmer extends StatefulWidget {
  const Shimmer({super.key, required this.child});

  final Widget child;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value * 2 - 1;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment(t - 1, 0),
              end: Alignment(t + 1, 0),
              colors: const [
                AppColors.surfaceElevated,
                Color(0xFF35353C),
                AppColors.surfaceElevated,
              ],
              stops: const [0.35, 0.5, 0.65],
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 14,
    this.borderRadius = const BorderRadius.all(Radius.circular(6)),
  });

  final double? width;
  final double height;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: borderRadius,
      ),
    );
  }
}

class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key, required this.child, this.padding = const EdgeInsets.all(16)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }
}

/// Home tab first-load placeholder matching dashboard card layout.
class HomeLoadingSkeleton extends StatelessWidget {
  const HomeLoadingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Shimmer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SkeletonCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SkeletonBox(width: 100, height: 12),
                    const SizedBox(height: 14),
                    const SkeletonBox(width: 120, height: 36),
                    const SizedBox(height: 10),
                    const SkeletonBox(width: 80, height: 14),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SkeletonCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const SkeletonBox(width: 90, height: 12),
                        const SkeletonBox(width: 36, height: 36, borderRadius: BorderRadius.all(Radius.circular(18))),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const SkeletonBox(width: double.infinity, height: 8, borderRadius: BorderRadius.all(Radius.circular(4))),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SkeletonCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SkeletonBox(width: 70, height: 12),
                          const SizedBox(height: 10),
                          const SkeletonBox(width: 90, height: 22),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SkeletonBox(width: 70, height: 12),
                          const SizedBox(height: 10),
                          const SkeletonBox(width: 90, height: 22),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SkeletonCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SkeletonBox(width: 110, height: 12),
                    const SizedBox(height: 12),
                    const SkeletonBox(width: 160, height: 16),
                    const SizedBox(height: 8),
                    const SkeletonBox(width: 200, height: 12),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 4,
                    child: SkeletonCard(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SkeletonBox(width: 60, height: 10),
                          const SizedBox(height: 10),
                          const SkeletonBox(width: 72, height: 24),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 6,
                    child: SkeletonCard(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const SkeletonBox(width: 42, height: 42, borderRadius: BorderRadius.all(Radius.circular(10))),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SkeletonBox(width: 48, height: 22),
                                    const SizedBox(height: 6),
                                    const SkeletonBox(width: 90, height: 10),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: List.generate(7, (_) => const SkeletonBox(width: 18, height: 18, borderRadius: BorderRadius.all(Radius.circular(9)))),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SkeletonCard(
                child: Row(
                  children: [
                    const SkeletonBox(width: 4, height: 72, borderRadius: BorderRadius.all(Radius.circular(2))),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SkeletonBox(width: 120, height: 12),
                          const SizedBox(height: 10),
                          const SkeletonBox(width: 80, height: 32),
                          const SizedBox(height: 8),
                          const SkeletonBox(width: 160, height: 10),
                        ],
                      ),
                    ),
                    const SkeletonBox(width: 52, height: 52, borderRadius: BorderRadius.all(Radius.circular(26))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Train tab first-load placeholder matching history tiles.
class TrainLoadingSkeleton extends StatelessWidget {
  const TrainLoadingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
      children: [
        Shimmer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SkeletonBox(width: 56, height: 12),
              const SizedBox(height: 12),
              for (var i = 0; i < 5; i++) ...[
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  clipBehavior: Clip.antiAlias,
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SkeletonBox(
                          width: 3,
                          height: 88,
                          borderRadius: BorderRadius.zero,
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SkeletonBox(width: i.isEven ? 140 : 180, height: 16),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    SkeletonBox(width: 56 + (i * 8).toDouble(), height: 22, borderRadius: const BorderRadius.all(Radius.circular(12))),
                                    const SizedBox(width: 6),
                                    const SkeletonBox(width: 48, height: 22, borderRadius: BorderRadius.all(Radius.circular(12))),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                SkeletonBox(width: 120 + (i * 12).toDouble(), height: 11),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Progress tab first-load placeholder matching exercise cards.
class ProgressLoadingSkeleton extends StatelessWidget {
  const ProgressLoadingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Shimmer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SkeletonBox(width: 220, height: 12),
              const SizedBox(height: 12),
              for (var i = 0; i < 6; i++) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SkeletonBox(width: i.isEven ? 100 : 130, height: 16),
                              const SizedBox(height: 8),
                              const SkeletonBox(width: 140, height: 13),
                              const SizedBox(height: 6),
                              SkeletonBox(width: 160 + (i * 6).toDouble(), height: 11),
                              const SizedBox(height: 4),
                              const SkeletonBox(width: 180, height: 11),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const SkeletonBox(width: 72, height: 14),
                            const SizedBox(height: 8),
                            const SkeletonBox(width: 64, height: 22, borderRadius: BorderRadius.all(Radius.circular(4))),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (i < 5) const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
