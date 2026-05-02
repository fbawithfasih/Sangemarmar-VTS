import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/api_service.dart';
import '../../core/constants/api_constants.dart';
import '../../core/utils/uppercase_formatter.dart';
import '../../core/widgets/app_bar.dart';

class StatementsScreen extends StatefulWidget {
  const StatementsScreen({super.key});

  @override
  State<StatementsScreen> createState() => _StatementsScreenState();
}

class _StatementsScreenState extends State<StatementsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _api = ApiService();

  final _types = ['DRIVER', 'GUIDE', 'LOCAL_AGENT', 'COMPANY'];
  final _labels = {
    'DRIVER': 'Drivers',
    'GUIDE': 'Guides',
    'LOCAL_AGENT': 'Local Agents',
    'COMPANY': 'Companies',
  };
  final _icons = {
    'DRIVER': Icons.drive_eta,
    'GUIDE': Icons.person_pin,
    'LOCAL_AGENT': Icons.support_agent,
    'COMPANY': Icons.business,
  };

  // Each tab has its own search + name list
  final Map<String, List<String>> _names = {
    'DRIVER': [], 'GUIDE': [], 'LOCAL_AGENT': [], 'COMPANY': [],
  };
  final Map<String, bool> _loading = {
    'DRIVER': false, 'GUIDE': false, 'LOCAL_AGENT': false, 'COMPANY': false,
  };
  final Map<String, TextEditingController> _searchCtrls = {
    'DRIVER': TextEditingController(),
    'GUIDE': TextEditingController(),
    'LOCAL_AGENT': TextEditingController(),
    'COMPANY': TextEditingController(),
  };

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _types.length, vsync: this);
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging) _loadNames(_types[_tabs.index]);
    });
    _loadNames('DRIVER');
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchCtrls.values.forEach((c) => c.dispose());
    super.dispose();
  }

  Future<void> _loadNames(String type) async {
    setState(() => _loading[type] = true);
    try {
      final res = await _api.get(ApiConstants.statementNames, queryParams: {'type': type});
      setState(() {
        _names[type] = (res.data as List).cast<String>();
        _loading[type] = false;
      });
    } catch (_) {
      setState(() => _loading[type] = false);
    }
  }

  List<String> _filtered(String type) {
    final q = _searchCtrls[type]!.text.toLowerCase();
    if (q.isEmpty) return _names[type]!;
    return _names[type]!.where((n) => n.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SangemarmarAppBar(
        title: const Text('Account Statements'),
        bottom: TabBar(
          controller: _tabs,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          isScrollable: true,
          tabs: _types
              .map((t) => Tab(icon: Icon(_icons[t], size: 18), text: _labels[t]))
              .toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: _types.map((type) => _buildTab(type)).toList(),
      ),
    );
  }

  Widget _buildTab(String type) {
    final loading = _loading[type]!;
    final filtered = _filtered(type);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _searchCtrls[type],
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [UpperCaseTextFormatter()],
            decoration: InputDecoration(
              hintText: 'Search ${_labels[type]?.toLowerCase()}...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchCtrls[type]!.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchCtrls[type]!.clear();
                        setState(() {});
                      },
                    )
                  : null,
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_icons[type], size: 48, color: Colors.grey.shade300),
                          const SizedBox(height: 8),
                          Text(
                            'No ${_labels[type]?.toLowerCase()} found',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () => _loadNames(type),
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final name = filtered[i];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: const Color(0xFFE8F5E9),
                                child: Icon(_icons[type], color: const Color(0xFF1B5E20)),
                              ),
                              title: Text(
                                name,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => context.push(
                                '/statements/detail',
                                extra: {'type': type, 'name': name},
                              ),
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }
}
