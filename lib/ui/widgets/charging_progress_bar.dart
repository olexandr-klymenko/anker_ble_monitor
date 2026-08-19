import 'package:flutter/material.dart';

class ChargingProgressBar extends StatefulWidget {
  final int soc;
  final bool isCharging;
  final int lowThreshold;
  final int fullThreshold;

  const ChargingProgressBar({
    super.key,
    required this.soc,
    required this.isCharging,
    required this.lowThreshold,
    required this.fullThreshold,
  });

  @override
  State<ChargingProgressBar> createState() => _ChargingProgressBarState();
}

class _ChargingProgressBarState extends State<ChargingProgressBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    if (widget.isCharging) _waveController.repeat();
  }

  @override
  void didUpdateWidget(covariant ChargingProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isCharging && !_waveController.isAnimating) {
      _waveController.repeat();
    } else if (!widget.isCharging && _waveController.isAnimating) {
      _waveController.stop();
    }
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  Color _getBarColor() {
    if (widget.isCharging) return Colors.amber;
    if (widget.soc <= widget.lowThreshold) return Colors.redAccent;
    if (widget.soc >= widget.fullThreshold) return Colors.greenAccent;
    return Colors.blueAccent;
  }

  @override
  Widget build(BuildContext context) {
    final double progress = (widget.soc.clamp(0, 100)) / 100.0;
    final Color baseColor = _getBarColor();

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 14,
        width: double.infinity,
        color: Colors.grey.shade800,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double fillWidth = constraints.maxWidth * progress;

            return Stack(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: fillWidth,
                  height: double.infinity,
                  color: baseColor,
                ),
                if (widget.isCharging && fillWidth > 0)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: fillWidth,
                      height: double.infinity,
                      child: Stack(
                        children: [
                          AnimatedBuilder(
                            animation: _waveController,
                            builder: (context, child) {
                              final double wavePos =
                                  (_waveController.value * (fillWidth + 60)) -
                                      30;

                              return Positioned(
                                left: wavePos,
                                top: 0,
                                bottom: 0,
                                width: 40,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.white.withValues(alpha: 0.0),
                                        Colors.white.withValues(alpha: 0.6),
                                        Colors.white.withValues(alpha: 0.0),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
