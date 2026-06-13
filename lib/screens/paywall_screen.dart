import 'package:flutter/material.dart';

/// Shown when a free user reaches the saved-videos limit.
class PaywallScreen extends StatelessWidget {
  final VoidCallback onUpgrade;
  final VoidCallback onClose;

  const PaywallScreen({
    super.key,
    required this.onUpgrade,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0E12),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: onClose,
                ),
              ),
              const Spacer(),
              const Icon(Icons.workspace_premium,
                  size: 64, color: Color(0xFF8B5CF6)),
              const SizedBox(height: 24),
              const Text(
                "You've reached your free limit",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Reelr Free lets you save up to 50 videos. '
                'Upgrade to Reelr Premium for unlimited videos and '
                'unlimited categories.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: onUpgrade,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Upgrade to Premium',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: onClose,
                child: const Text(
                  'Not now',
                  style: TextStyle(color: Colors.white60),
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
