import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../models/argocd_app.dart';
import '../services/argocd_service.dart';
import '../widgets/status_badge.dart';
import 'logs_screen.dart';

class AppDetailScreen extends StatefulWidget {
  final ArgoApp app;
  final ArgoCDService service;

  const AppDetailScreen({
    super.key,
    required this.app,
    required this.service,
  });

  @override
  State<AppDetailScreen> createState() => _AppDetailScreenState();
}

class _AppDetailScreenState extends State<AppDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late ArgoApp _app;
  List<ResourceNode> _resources = [];
  bool _loadingResources = true;
  bool _syncing = false;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _app = widget.app;
    _tabController = TabController(length: 2, vsync: this);
    _loadResources();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadResources() async {
    if (!mounted) return;
    setState(() => _loadingResources = true);
    try {
      final nodes = await widget.service.getResourceTree(widget.app.name);
      if (!mounted) return;
      setState(() {
        _resources = nodes;
        _loadingResources = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingResources = false);
    }
  }

  Future<void> _sync() async {
    setState(() => _syncing = true);
    try {
      await widget.service.syncApplication(_app.name);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sync triggered for ${_app.name}'),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on ArgoCDException catch (e) {
      if (!mounted) return;
      _showError(e.message);
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    try {
      final updated = await widget.service.refreshApplication(_app.name);
      if (!mounted) return;
      setState(() => _app = updated);
      await _loadResources();
    } on ArgoCDException catch (e) {
      if (!mounted) return;
      _showError(e.message);
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openLogs({String? podName, String? namespace, String? container}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LogsScreen(
          app: _app,
          service: widget.service,
          podName: podName,
          namespace: namespace,
          container: container,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a1a2e),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213e),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _app.name,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (_refreshing)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Color(0xFFe94560)),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white70),
              onPressed: _refresh,
              tooltip: 'Hard Refresh',
            ),
          const SizedBox(width: 4),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFe94560),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white38,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Resources'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _OverviewTab(
            app: _app,
            onSync: _sync,
            syncing: _syncing,
            onOpenLogs: _openLogs,
          ),
          _ResourcesTab(
            resources: _resources,
            loading: _loadingResources,
            onOpenLogs: _openLogs,
          ),
        ],
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  final ArgoApp app;
  final VoidCallback onSync;
  final bool syncing;
  final void Function({String? podName, String? namespace, String? container})
      onOpenLogs;

  const _OverviewTab({
    required this.app,
    required this.onSync,
    required this.syncing,
    required this.onOpenLogs,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status card
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionHeader('Status'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _StatusTile(
                        label: 'Sync',
                        badge: SyncBadge(status: app.syncStatus),
                      ),
                    ),
                    Expanded(
                      child: _StatusTile(
                        label: 'Health',
                        badge: HealthBadge(status: app.healthStatus),
                      ),
                    ),
                  ],
                ),
                if (app.message != null && app.message!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade900.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber,
                            color: Colors.red.shade300, size: 14),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            app.message!,
                            style: TextStyle(
                                color: Colors.red.shade300, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (app.syncedAt != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Last synced ${timeago.format(app.syncedAt!)}',
                    style:
                        const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Details card
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionHeader('Details'),
                const SizedBox(height: 12),
                _InfoRow('Project', app.project),
                _InfoRow('Namespace', app.namespace),
                _InfoRow('Revision', app.targetRevision),
                if (app.path.isNotEmpty) _InfoRow('Path', app.path),
                _InfoRow('Repo', app.repoUrl, compact: true),
                _InfoRow('Server', app.server, compact: true),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Actions
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionHeader('Actions'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.sync,
                        label: 'Sync',
                        color: const Color(0xFFe94560),
                        loading: syncing,
                        onPressed: onSync,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.description_outlined,
                        label: 'View Logs',
                        color: Colors.blue.shade400,
                        onPressed: () => onOpenLogs(namespace: app.namespace),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ResourcesTab extends StatelessWidget {
  final List<ResourceNode> resources;
  final bool loading;
  final void Function({String? podName, String? namespace, String? container})
      onOpenLogs;

  const _ResourcesTab({
    required this.resources,
    required this.loading,
    required this.onOpenLogs,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFe94560)),
      );
    }

    if (resources.isEmpty) {
      return const Center(
        child: Text('No resources found',
            style: TextStyle(color: Colors.white38)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: resources.length,
      itemBuilder: (_, i) => _ResourceTile(
        node: resources[i],
        onOpenLogs: onOpenLogs,
      ),
    );
  }
}

class _ResourceTile extends StatelessWidget {
  final ResourceNode node;
  final void Function({String? podName, String? namespace, String? container})
      onOpenLogs;

  const _ResourceTile({required this.node, required this.onOpenLogs});

  @override
  Widget build(BuildContext context) {
    final isPod = node.kind.toLowerCase() == 'pod';
    final healthColor = _healthColor(node.health);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: const Color(0xFF16213e),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: healthColor.withOpacity(0.2)),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: healthColor.withOpacity(0.15),
          radius: 20,
          child: Text(
            node.kind.substring(0, node.kind.length > 2 ? 2 : node.kind.length),
            style: TextStyle(
                color: healthColor, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          node.name,
          style: const TextStyle(
              color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          node.kind + (node.namespace != null ? ' · ${node.namespace}' : ''),
          style: const TextStyle(color: Colors.white38, fontSize: 11),
        ),
        trailing: isPod
            ? IconButton(
                icon:
                    const Icon(Icons.description_outlined, color: Colors.white54),
                onPressed: () => onOpenLogs(
                  podName: node.name,
                  namespace: node.namespace,
                ),
                tooltip: 'Logs',
              )
            : node.health != null
                ? Text(
                    node.health!,
                    style: TextStyle(color: healthColor, fontSize: 11),
                  )
                : null,
      ),
    );
  }

  Color _healthColor(String? health) {
    switch (health?.toLowerCase()) {
      case 'healthy':
        return Colors.green.shade400;
      case 'degraded':
        return Colors.red.shade400;
      case 'progressing':
        return Colors.blue.shade400;
      default:
        return Colors.white38;
    }
  }
}

// Shared UI helpers

class _Card extends StatelessWidget {
  final Widget child;

  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16213e),
        borderRadius: BorderRadius.circular(14),
      ),
      child: child,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
          color: Colors.white60,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8),
    );
  }
}

class _StatusTile extends StatelessWidget {
  final String label;
  final Widget badge;

  const _StatusTile({required this.label, required this.badge});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white38, fontSize: 11)),
        const SizedBox(height: 6),
        badge,
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool compact;

  const _InfoRow(this.label, this.value, {this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style:
                  const TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : '—',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
              overflow:
                  compact ? TextOverflow.ellipsis : TextOverflow.visible,
              maxLines: compact ? 1 : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;
  final bool loading;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.15),
        foregroundColor: color,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: color.withOpacity(0.3)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
      onPressed: loading ? null : onPressed,
      icon: loading
          ? SizedBox(
              width: 16,
              height: 16,
              child:
                  CircularProgressIndicator(strokeWidth: 2, color: color),
            )
          : Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontSize: 13)),
    );
  }
}
