import 'package:flutter/material.dart';

class ShimmerPlaceholder extends StatefulWidget {
  final double? width;

  final double? height;

  final BoxShape shape;

  final BorderRadius? borderRadius;

  final Color baseColor;

  final Color highlightColor;

  final Duration duration;

  const ShimmerPlaceholder({
    super.key,
    this.width,
    this.height,
    this.shape = BoxShape.rectangle,
    this.borderRadius,
    this.baseColor = const Color(0xFFEEEEEE),
    this.highlightColor = const Color(0xFFF5F5F5),
    this.duration = const Duration(milliseconds: 1500),
  });

  @override
  State<ShimmerPlaceholder> createState() => _ShimmerPlaceholderState();
}

class _ShimmerPlaceholderState extends State<ShimmerPlaceholder>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);

    _animation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );

    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            shape: widget.shape,
            borderRadius: widget.shape == BoxShape.rectangle
                ? widget.borderRadius ?? BorderRadius.zero
                : null,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                widget.baseColor,
                widget.highlightColor,
                widget.baseColor,
              ],
              stops: [0.0, _animation.value, 1.0],
            ),
          ),
        );
      },
    );
  }
}

class ImageCardSkeleton extends StatelessWidget {
  final double? width;

  final double? height;

  final BorderRadius borderRadius;

  final bool showTitle;

  final bool showDescription;

  final bool showFooter;

  const ImageCardSkeleton({
    super.key,
    this.width,
    this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
    this.showTitle = true,
    this.showDescription = false,
    this.showFooter = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: borderRadius,
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: ShimmerPlaceholder(
              width: double.infinity,
              borderRadius: BorderRadius.only(
                topLeft: borderRadius.topLeft,
                topRight: borderRadius.topRight,
              ),
            ),
          ),
          if (showTitle || showDescription || showFooter)
            Expanded(
              flex: showDescription ? 2 : 1,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showTitle) ...[
                      const SizedBox(height: 4),
                      ShimmerPlaceholder(
                        width: width != null ? width! * 0.7 : 120,
                        height: 16,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                    if (showDescription) ...[
                      const SizedBox(height: 8),
                      ShimmerPlaceholder(
                        width: double.infinity,
                        height: 10,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      const SizedBox(height: 4),
                      ShimmerPlaceholder(
                        width: width != null ? width! * 0.9 : 160,
                        height: 10,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                    if (showFooter) ...[
                      const Spacer(),
                      ShimmerPlaceholder(
                        width: width != null ? width! * 0.4 : 80,
                        height: 10,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      const SizedBox(height: 4),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class ImagePlaceholderGrid extends StatelessWidget {
  final int itemCount;

  final int crossAxisCount;

  final double childAspectRatio;

  final double mainAxisSpacing;

  final double crossAxisSpacing;

  const ImagePlaceholderGrid({
    super.key,
    this.itemCount = 6,
    this.crossAxisCount = 2,
    this.childAspectRatio = 0.7,
    this.mainAxisSpacing = 16.0,
    this.crossAxisSpacing = 16.0,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: childAspectRatio,
        mainAxisSpacing: mainAxisSpacing,
        crossAxisSpacing: crossAxisSpacing,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index % 3 == 0) {
          return const ShimmerPlaceholder(shape: BoxShape.circle);
        }
        return ImageCardSkeleton(
          showTitle: true,
          showDescription: index % 2 == 0,
          showFooter: index % 4 == 0,
        );
      },
    );
  }
}
