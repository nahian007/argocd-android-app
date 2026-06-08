import 'package:flutter/material.dart';
import '../models/argocd_app.dart';
import '../services/argocd_service.dart';
import '../services/auth_service.dart';
import '../widgets/splash_view.dart';
import '../widgets/status_badge.dart';
import 'app_detail_screen.dart';
import 'login_screen.dart';

class AppsScreen extends StatefulWidget {
  const AppsScreen({super.key});

  @override
  State<AppsScreen> createState() => _AppsScreenState();
}

class _AppsScreenState extends State<AppsScreen> {
  final _authService = AuthService();
  late final ArgoCDService _argoService;

  List<ArgoApp> _allApps = [];
  List<ArgoApp> _filteredApps = [];
  bool _loading = true;
  bool _loggingOut = false;
  String? _error;
  String _search = '';
  SyncStatus? _filterSync;
  HealthStatus? _filterHealth;

  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _argoService = ArgoCDService(_authService);
    _loadApps();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadApps() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final apps = await _argoService.listApplications();
      if (!mounted) return;
      setState(() {
        _allApps = apps;
        _loading = false;
      });
      _applyFilters();
    } on ArgoCDException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 401) {
        _logout();
        return;
      }
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Unexpected error: $e';
        _loading = false;
      });
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredApps = _allApps.where((app) {
        final matchesSearch = _search.isEmpty ||
            app.name.toLowerCase().contains(_search.toLowerCase()) ||
            app.project.toLowerCase().contains(_search.toLowerCase());
        final matchesSync =
            _filterSync == null || app.syncStatus == _filterSync;
        final matchesHealth =
            _filterHealth == null || app.healthStatus == _filterHealth;
        return matchesSearch && matchesSync && matchesHealth;
      }).toList();
    });
  }

  Future<void> _logout() async {
    if (_loggingOut) return;
    setState(() => _loggingOut = true);
    await _authService.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF16213e),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _FilterSheet(
        currentSync: _filterSync,
        currentHealth: _filterHealth,
        onApply: (sync, health) {
          setState(() {
            _filterSync = sync;
            _filterHealth = health;
          });
          _applyFilters();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Hide the dashboard while logout is in flight so the user doesn't
    // briefly see the apps list during the secure-storage delete.
    if (_loggingOut) return const SplashView();

    final hasFilters = _filterSync != null || _filterHealth != null;

    return Scaffold(
      backgroundColor: const Color(0xFF1a1a2e),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213e),
        elevation: 0,
        title: const Text(
          'Applications',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: hasFilters,
              backgroundColor: const Color(0xFFe94560),
              child: const Icon(Icons.filter_list, color: Colors.white70),
            ),
            onPressed: _showFilterSheet,
            tooltip: 'Filter',
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white70),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Column(
        children: [
          _SearchBar(
            controller: _searchController,
            onChanged: (v) {
              _search = v;
              _applyFilters();
            },
          ),
          _StatsRow(apps: _allApps),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return _LoadingList();

    if (_error != null) {
      return _ErrorView(
        message: _error!,
        onRetry: _loadApps,
      );
    }

    if (_filteredApps.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.white24),
            const SizedBox(height: 16),
            Text(
              _allApps.isEmpty ? 'No applications found' : 'No matches',
              style: const TextStyle(color: Colors.white38, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: const Color(0xFFe94560),
      backgroundColor: const Color(0xFF16213e),
      onRefresh: _loadApps,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _filteredApps.length,
        itemBuilder: (_, i) => _AppCard(
          app: _filteredApps[i],
          service: _argoService,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AppDetailScreen(
                app: _filteredApps[i],
                service: _argoService,
              ),
            ),
          ),
          onRefreshed: _loadApps,
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _SearchBar({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Search apps or projects...',
          hintStyle: const TextStyle(color: Colors.white38),
          prefixIcon: const Icon(Icons.search, color: Colors.white38),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.white38),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                )
              : null,
          filled: true,
          fillColor: const Color(0xFF16213e),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final List<ArgoApp> apps;

  const _StatsRow({required this.apps});

  @override
  Widget build(BuildContext context) {
    if (apps.isEmpty) return const SizedBox.shrink();

    final synced =
        apps.where((a) => a.syncStatus == SyncStatus.synced).length;
    final healthy =
        apps.where((a) => a.healthStatus == HealthStatus.healthy).length;
    final degraded =
        apps.where((a) => a.healthStatus == HealthStatus.degraded).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Row(
        children: [
          _StatChip(
            label: '${apps.length} total',
            color: Colors.white38,
            icon: Icons.apps,
          ),
          const SizedBox(width: 8),
          _StatChip(
            label: '$synced synced',
            color: Colors.green.shade400,
            icon: Icons.check_circle_outline,
          ),
          const SizedBox(width: 8),
          _StatChip(
            label: '$healthy healthy',
            color: Colors.teal.shade300,
            icon: Icons.favorite_outline,
          ),
          if (degraded > 0) ...[
            const SizedBox(width: 8),
            _StatChip(
              label: '$degraded degraded',
              color: Colors.red.shade400,
              icon: Icons.warning_amber_outlined,
            ),
          ],
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const _StatChip(
      {required this.label, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontSize: 11)),
        ],
      ),
    );
  }
}

class _AppCard extends StatefulWidget {
  final ArgoApp app;
  final ArgoCDService service;
  final VoidCallback onTap;
  final VoidCallback onRefreshed;

  const _AppCard({
    required this.app,
    required this.service,
    required this.onTap,
    required this.onRefreshed,
  });

  @override
  State<_AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<_AppCard> {
  bool _syncing = false;

  Future<void> _sync() async {
    setState(() => _syncing = true);
    try {
      await widget.service.syncApplication(widget.app.name);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync triggered for ${widget.app.name}'),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
        widget.onRefreshed();
      }
    } on ArgoCDException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: const Color(0xFF16213e),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: _borderColor(app).withOpacity(0.25),
          width: 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      app.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _syncing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFFe94560),
                          ),
                        )
                      : IconButton(
                          icon: const Icon(Icons.sync,
                              color: Colors.white54, size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: _sync,
                          tooltip: 'Sync',
                        ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Project: ${app.project}',
                style:
                    const TextStyle(color: Colors.white38, fontSize: 12),
              ),
              if (app.path.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  app.path,
                  style:
                      const TextStyle(color: Colors.white24, fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  SyncBadge(status: app.syncStatus),
                  const SizedBox(width: 8),
                  HealthBadge(status: app.healthStatus),
                  const Spacer(),
                  const Icon(Icons.chevron_right,
                      color: Colors.white24, size: 18),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _borderColor(ArgoApp app) {
    if (app.healthStatus == HealthStatus.degraded) return Colors.red;
    if (app.syncStatus == SyncStatus.outOfSync) return Colors.orange;
    if (app.healthStatus == HealthStatus.healthy &&
        app.syncStatus == SyncStatus.synced) return Colors.green;
    return Colors.white24;
  }
}

class _LoadingList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: 6,
      itemBuilder: (_, __) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        height: 110,
        decoration: BoxDecoration(
          color: const Color(0xFF16213e),
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 64, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(color: Colors.white60, fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFe94560),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterSheet extends StatefulWidget {
  final SyncStatus? currentSync;
  final HealthStatus? currentHealth;
  final void Function(SyncStatus?, HealthStatus?) onApply;

  const _FilterSheet({
    this.currentSync,
    this.currentHealth,
    required this.onApply,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  SyncStatus? _sync;
  HealthStatus? _health;

  @override
  void initState() {
    super.initState();
    _sync = widget.currentSync;
    _health = widget.currentHealth;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Filter Applications',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            const Text('Sync Status',
                style: TextStyle(color: Colors.white60, fontSize: 12)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _filterChip('All', _sync == null, () => setState(() => _sync = null)),
                ...SyncStatus.values.map((s) => _filterChip(
                    s.label, _sync == s, () => setState(() => _sync = s))),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Health',
                style: TextStyle(color: Colors.white60, fontSize: 12)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _filterChip(
                    'All', _health == null, () => setState(() => _health = null)),
                ...HealthStatus.values.map((h) => _filterChip(
                    h.label, _health == h, () => setState(() => _health = h))),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFe94560),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  widget.onApply(_sync, _health);
                  Navigator.pop(context);
                },
                child: const Text('Apply'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String label, bool selected, VoidCallback onTap) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: const Color(0xFFe94560).withOpacity(0.3),
      checkmarkColor: const Color(0xFFe94560),
      labelStyle: TextStyle(
          color: selected ? const Color(0xFFe94560) : Colors.white60,
          fontSize: 12),
      backgroundColor: const Color(0xFF1a1a2e),
      side: BorderSide(
          color: selected
              ? const Color(0xFFe94560).withOpacity(0.5)
              : Colors.white24),
    );
  }
}
