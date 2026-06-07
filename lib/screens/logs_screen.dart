import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/argocd_service.dart';
import '../models/argocd_app.dart';

class LogsScreen extends StatefulWidget {
  final ArgoApp app;
  final ArgoCDService service;
  final String? podName;
  final String? namespace;
  final String? container;

  const LogsScreen({
    super.key,
    required this.app,
    required this.service,
    this.podName,
    this.namespace,
    this.container,
  });

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  final List<String> _lines = [];
  final ScrollController _scrollController = ScrollController();
  bool _loading = true;
  bool _autoScroll = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchLogs();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchLogs() async {
    if (!mounted) return;
    setState(() {
      _lines.clear();
      _loading = true;
      _error = null;
    });

    try {
      await for (final line in widget.service.streamLogs(
        appName: widget.app.name,
        namespace: widget.namespace ?? widget.app.namespace,
        podName: widget.podName,
        container: widget.container,
        tailLines: 500,
      )) {
        if (!mounted) break;
        setState(() {
          _lines.add(line);
          _loading = false;
        });
        if (_autoScroll && _scrollController.hasClients) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients) {
              _scrollController.jumpTo(
                _scrollController.position.maxScrollExtent,
              );
            }
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _copyAll() {
    Clipboard.setData(ClipboardData(text: _lines.join('\n')));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Logs copied to clipboard'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.podName != null
        ? widget.podName!
        : '${widget.app.name} logs';

    return Scaffold(
      backgroundColor: const Color(0xFF0d0d0d),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1a1a1a),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style:
                  const TextStyle(color: Colors.white, fontSize: 15),
              overflow: TextOverflow.ellipsis,
            ),
            if (widget.container != null)
              Text(
                widget.container!,
                style:
                    const TextStyle(color: Colors.white38, fontSize: 11),
              ),
          ],
        ),
        actions: [
          if (_lines.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.copy, color: Colors.white70),
              onPressed: _copyAll,
              tooltip: 'Copy all',
            ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: _fetchLogs,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: Icon(
              _autoScroll
                  ? Icons.vertical_align_bottom
                  : Icons.vertical_align_center,
              color: _autoScroll ? const Color(0xFFe94560) : Colors.white70,
            ),
            onPressed: () => setState(() => _autoScroll = !_autoScroll),
            tooltip: 'Auto-scroll',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading && _lines.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFFe94560)),
            SizedBox(height: 16),
            Text('Fetching logs...',
                style: TextStyle(color: Colors.white38)),
          ],
        ),
      );
    }

    if (_error != null && _lines.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: Colors.red.shade300, size: 48),
              const SizedBox(height: 16),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white54)),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFe94560),
                ),
                onPressed: _fetchLogs,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_lines.isEmpty) {
      return const Center(
        child: Text('No logs found',
            style: TextStyle(color: Colors.white38)),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(8),
            itemCount: _lines.length,
            itemBuilder: (_, i) => _LogLine(line: _lines[i], index: i),
          ),
        ),
        if (_loading)
          const LinearProgressIndicator(
            backgroundColor: Colors.transparent,
            color: Color(0xFFe94560),
          ),
      ],
    );
  }
}

class _LogLine extends StatelessWidget {
  final String line;
  final int index;

  const _LogLine({required this.line, required this.index});

  @override
  Widget build(BuildContext context) {
    final isError = line.toLowerCase().contains('error') ||
        line.toLowerCase().contains('exception') ||
        line.toLowerCase().contains('fatal');
    final isWarn = line.toLowerCase().contains('warn');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 36,
            child: Text(
              '${index + 1}',
              style: const TextStyle(
                  color: Colors.white12,
                  fontSize: 10,
                  fontFamily: 'monospace'),
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SelectableText(
              line,
              style: TextStyle(
                color: isError
                    ? Colors.red.shade300
                    : isWarn
                        ? Colors.yellow.shade600
                        : Colors.green.shade200,
                fontSize: 11,
                fontFamily: 'monospace',
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
