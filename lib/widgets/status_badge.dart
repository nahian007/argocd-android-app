import 'package:flutter/material.dart';
import '../models/argocd_app.dart';

class SyncBadge extends StatelessWidget {
  final SyncStatus status;
  final bool compact;

  const SyncBadge({super.key, required this.status, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (status) {
      SyncStatus.synced => (Colors.green.shade400, Icons.check_circle_outline),
      SyncStatus.outOfSync =>
        (Colors.orange.shade400, Icons.sync_problem_outlined),
      SyncStatus.unknown => (Colors.grey.shade400, Icons.help_outline),
    };

    if (compact) {
      return Icon(icon, color: color, size: 16);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(
            status.label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class HealthBadge extends StatelessWidget {
  final HealthStatus status;
  final bool compact;

  const HealthBadge({super.key, required this.status, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (status) {
      HealthStatus.healthy => (Colors.green.shade400, Icons.favorite_outline),
      HealthStatus.degraded => (Colors.red.shade400, Icons.heart_broken_outlined),
      HealthStatus.progressing =>
        (Colors.blue.shade400, Icons.hourglass_empty_outlined),
      HealthStatus.suspended =>
        (Colors.yellow.shade600, Icons.pause_circle_outline),
      HealthStatus.missing => (Colors.grey.shade400, Icons.cloud_off_outlined),
      HealthStatus.unknown => (Colors.grey.shade400, Icons.help_outline),
    };

    if (compact) {
      return Icon(icon, color: color, size: 16);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(
            status.label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
