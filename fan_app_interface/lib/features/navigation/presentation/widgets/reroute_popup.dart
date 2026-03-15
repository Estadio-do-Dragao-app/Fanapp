import 'package:flutter/material.dart';
import 'dart:async';
import '../../../../l10n/app_localizations.dart';

class ReroutePopup extends StatefulWidget {
  final String arrivalTime;
  final String duration;
  final int distance;
  final String locationName; // e.g. "WC 2"
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const ReroutePopup({
    super.key,
    required this.arrivalTime,
    required this.duration,
    required this.distance,
    required this.locationName,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  State<ReroutePopup> createState() => _ReroutePopupState();
}

class _ReroutePopupState extends State<ReroutePopup> {
  static const int _totalSeconds = 10;
  int _remainingSeconds = _totalSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          _timer?.cancel();
          widget.onDecline();
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Calculate progress (1.0 to 0.0)
    final progress = _remainingSeconds / _totalSeconds;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF161A3E), // Dark Blue
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          // const SizedBox(height: 8),
          // Center(
          //   child: Container(
          //     width: 40,
          //     height: 4,
          //     decoration: BoxDecoration(
          //       color: Colors.white.withOpacity(0.2),
          //       borderRadius: BorderRadius.circular(2),
          //     ),
          //   ),
          // ),
          const SizedBox(height: 16),

          // Title
          Text(
            AppLocalizations.of(context)!.newDestinationFound,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              fontFamily: 'Gabarito',
            ),
          ),
          const SizedBox(height: 16),

          // Stats Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatItem(
                  context,
                  widget.arrivalTime,
                  AppLocalizations.of(context)!.arrival,
                ),
                _buildStatItem(
                  context,
                  AppLocalizations.of(context)!.durationMin(widget.duration),
                  AppLocalizations.of(context)!.time,
                ),
                _buildStatItem(
                  context,
                  AppLocalizations.of(context)!.distanceM(widget.distance),
                  AppLocalizations.of(
                    context,
                  )!.distance, // "m" or full word? Check translations. Actually distanceM uses {dist} m, so label should be "m" or empty if included. Let's check arb.
                  // arb says: "distance": "m".
                  // "distanceM": "{dist} m".
                  // If we use distanceM, we get "50 m". The label below says "m".
                  // In the screenshot: "50 m" (value) "m" (label). This seems redundant?
                  // Screenshot: "50 m" then "m" below.
                  // Let's stick to the screenshot.
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Timer visualization (Mocking the blue line with progress)
          // Progress bar
          LinearProgressIndicator(
            value: progress,
            backgroundColor: const Color(0xFF2A2E55),
            color: const Color(0xFF5E6AD2), // Lighter blue/purple
            minHeight: 4,
          ),
          const SizedBox(height: 16),

          // Reason Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                const Icon(
                  Icons.wc,
                  color: Colors.white,
                  size: 32,
                ), // Using generic WC icon
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    AppLocalizations.of(
                      context,
                    )!.lessQueue(widget.locationName),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Gabarito',
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Buttons Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                // No Button
                Expanded(
                  child: SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: widget.onDecline,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(
                          0xFFA1A5C8,
                        ), // Muted purple/grey
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        AppLocalizations.of(context)!.no,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Gabarito',
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Change Button
                Expanded(
                  child: SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: widget.onAccept,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8BC34A), // Green
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        AppLocalizations.of(context)!.change,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Gabarito',
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32), // Bottom padding
        ],
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
            fontFamily: 'Gabarito',
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 14,
            fontFamily: 'Gabarito',
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
