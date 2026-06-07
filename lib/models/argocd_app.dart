class ArgoApp {
  final String name;
  final String namespace;
  final String project;
  final String server;
  final String repoUrl;
  final String targetRevision;
  final String path;
  final SyncStatus syncStatus;
  final HealthStatus healthStatus;
  final String? message;
  final DateTime? syncedAt;

  const ArgoApp({
    required this.name,
    required this.namespace,
    required this.project,
    required this.server,
    required this.repoUrl,
    required this.targetRevision,
    required this.path,
    required this.syncStatus,
    required this.healthStatus,
    this.message,
    this.syncedAt,
  });

  factory ArgoApp.fromJson(Map<String, dynamic> json) {
    final spec = (json['spec'] as Map<String, dynamic>?) ?? {};
    final source = (spec['source'] as Map<String, dynamic>?) ?? {};
    final destination = (spec['destination'] as Map<String, dynamic>?) ?? {};
    final status = (json['status'] as Map<String, dynamic>?) ?? {};
    final sync = (status['sync'] as Map<String, dynamic>?) ?? {};
    final health = (status['health'] as Map<String, dynamic>?) ?? {};
    final metadata = (json['metadata'] as Map<String, dynamic>?) ?? {};
    final operationState = status['operationState'] as Map<String, dynamic>?;

    DateTime? syncedAt;
    try {
      final finishedAt = operationState?['finishedAt'] as String?;
      if (finishedAt != null) {
        syncedAt = DateTime.tryParse(finishedAt);
      }
    } catch (_) {}

    return ArgoApp(
      name: metadata['name'] as String? ?? 'unknown',
      namespace: metadata['namespace'] as String? ?? 'argocd',
      project: spec['project'] as String? ?? 'default',
      server: destination['server'] as String? ?? '',
      repoUrl: source['repoURL'] as String? ?? '',
      targetRevision: source['targetRevision'] as String? ?? 'HEAD',
      path: source['path'] as String? ?? '',
      syncStatus: SyncStatus.fromString(sync['status'] as String?),
      healthStatus: HealthStatus.fromString(health['status'] as String?),
      message: health['message'] as String?,
      syncedAt: syncedAt,
    );
  }
}

enum SyncStatus {
  synced,
  outOfSync,
  unknown;

  static SyncStatus fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'synced':
        return SyncStatus.synced;
      case 'outofsync':
        return SyncStatus.outOfSync;
      default:
        return SyncStatus.unknown;
    }
  }

  String get label {
    switch (this) {
      case SyncStatus.synced:
        return 'Synced';
      case SyncStatus.outOfSync:
        return 'OutOfSync';
      case SyncStatus.unknown:
        return 'Unknown';
    }
  }
}

enum HealthStatus {
  healthy,
  degraded,
  progressing,
  suspended,
  missing,
  unknown;

  static HealthStatus fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'healthy':
        return HealthStatus.healthy;
      case 'degraded':
        return HealthStatus.degraded;
      case 'progressing':
        return HealthStatus.progressing;
      case 'suspended':
        return HealthStatus.suspended;
      case 'missing':
        return HealthStatus.missing;
      default:
        return HealthStatus.unknown;
    }
  }

  String get label {
    switch (this) {
      case HealthStatus.healthy:
        return 'Healthy';
      case HealthStatus.degraded:
        return 'Degraded';
      case HealthStatus.progressing:
        return 'Progressing';
      case HealthStatus.suspended:
        return 'Suspended';
      case HealthStatus.missing:
        return 'Missing';
      case HealthStatus.unknown:
        return 'Unknown';
    }
  }
}

class ResourceNode {
  final String kind;
  final String name;
  final String? namespace;
  final String? status;
  final String? health;
  final List<ResourceNode> children;

  const ResourceNode({
    required this.kind,
    required this.name,
    this.namespace,
    this.status,
    this.health,
    this.children = const [],
  });

  factory ResourceNode.fromJson(Map<String, dynamic> json) {
    final childrenJson = (json['children'] as List<dynamic>?) ?? [];
    return ResourceNode(
      kind: json['kind'] as String? ?? 'Unknown',
      name: json['name'] as String? ?? '',
      namespace: json['namespace'] as String?,
      status: json['status'] as String?,
      health: (json['health'] as Map<String, dynamic>?)?['status'] as String?,
      children: childrenJson
          .whereType<Map<String, dynamic>>()
          .map((c) => ResourceNode.fromJson(c))
          .toList(),
    );
  }
}
