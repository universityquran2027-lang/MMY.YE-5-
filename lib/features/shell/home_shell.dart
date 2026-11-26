import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../core/db/app_database.dart';
import '../auth/auth_service.dart';
import '../auth/biometric_service.dart';
import '../centers/centers_screen.dart';
import '../staff/staff_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../control/control_screen.dart';
import '../management/management_screen.dart';
import '../tasks/tasks_screen.dart';
import '../evaluation/evaluation_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.app, required this.auth, required this.bio, required this.user});
  final AppDatabase app;
  final AuthService auth;
  final BiometricService bio;
  final Map<String, Object?> user;
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _Section {
  const _Section(this.title, this.subtitle, this.icon);
  final String title, subtitle;
  final IconData icon;
}

const _sections = [
  _Section('النظرة العامة', 'ملخص شامل للبرنامج', Symbols.dashboard),
  _Section('الإدارة', 'المدير ومساعد المدير والأرشيف', Symbols.admin_panel_settings),
  _Section('المراكز', 'إدارة المراكز الإعلامية', Symbols.apartment),
  _Section('المهام الميدانية', 'إنشاء المهام ومتابعة تنفيذها', Symbols.assignment),
  _Section('الكادر الإعلامي', 'ملفات الإعلاميين وتوزيعهم', Symbols.groups),
  _Section('التقييم', 'تقييم أداء المراكز', Symbols.analytics),
  _Section('لوحة التحكم', 'الحماية والحسابات والهوية والإعدادات', Symbols.settings),
];

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  Widget _page() => switch (_index) {
    0 => DashboardScreen(app: widget.app, user: widget.user),
    1 => ManagementScreen(app: widget.app, user: widget.user),
    2 => CentersScreen(key: const ValueKey('centers'), app: widget.app, user: widget.user),
    3 => TasksScreen(app: widget.app, user: widget.user),
    4 => StaffScreen(key: const ValueKey('staff'), app: widget.app, user: widget.user),
    5 => EvaluationScreen(app: widget.app, user: widget.user),
    6 => ControlScreen(app: widget.app, user: widget.user),
    _ => const SizedBox.shrink(),
  };

  void _select(int index) => setState(() => _index = index);

  Future<void> _showMore() async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Align(alignment: AlignmentDirectional.centerStart,
              child: Text('المزيد من الأقسام', style: Theme.of(context).textTheme.titleLarge)),
            const SizedBox(height: 10),
            for (final i in [1, 5, 6])
              ListTile(
                leading: Icon(_sections[i].icon, color: _index == i ? Theme.of(context).colorScheme.primary : null),
                title: Text(_sections[i].title),
                subtitle: Text(_sections[i].subtitle),
                trailing: _index == i ? const Icon(Symbols.check_circle) : null,
                onTap: () => Navigator.pop(context, i),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
          ]),
        ),
      ),
    );
    if (selected != null) _select(selected);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 1000;
    final medium = width >= 650;
    final section = _sections[_index];

    if (medium) {
      return Scaffold(
        body: Row(children: [
          NavigationRail(
            extended: wide,
            minExtendedWidth: 232,
            selectedIndex: _index,
            onDestinationSelected: _select,
            leading: Padding(
              padding: const EdgeInsets.fromLTRB(12, 18, 12, 22),
              child: wide
                ? Row(children: [
                    Container(width: 42, height: 42, padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                      child: SvgPicture.asset('assets/brand/logo.svg')),
                    const SizedBox(width: 10),
                    const Expanded(child: Text('النظام الإداري الإعلامي', maxLines: 2,
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13))),
                  ])
                : Container(width: 48, height: 48, padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                    child: SvgPicture.asset('assets/brand/logo.svg')),
            ),
            destinations: [
              for (final item in _sections)
                NavigationRailDestination(icon: Icon(item.icon), selectedIcon: Icon(item.icon, fill: 1), label: Text(item.title)),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: Column(children: [
            _DesktopHeader(section: section, user: widget.user),
            Expanded(child: _page()),
          ])),
        ]),
      );
    }

    final primaryItems = const [0, 2, 3, 4];
    final selectedPrimary = primaryItems.indexOf(_index);
    return Scaffold(
      appBar: AppBar(
        title: Text(section.title),
        actions: [
          IconButton(
            tooltip: 'الأقسام الأخرى',
            onPressed: _showMore,
            icon: const Icon(Symbols.grid_view),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _page(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedPrimary < 0 ? 4 : selectedPrimary,
        onDestinationSelected: (i) {
          if (i == 4) { _showMore(); } else { _select(primaryItems[i]); }
        },
        destinations: const [
          NavigationDestination(icon: const Icon(Symbols.dashboard), selectedIcon: const Icon(Symbols.dashboard, fill: 1), label: 'الرئيسية'),
          NavigationDestination(icon: const Icon(Symbols.apartment), selectedIcon: const Icon(Symbols.apartment, fill: 1), label: 'المراكز'),
          NavigationDestination(icon: const Icon(Symbols.assignment), selectedIcon: const Icon(Symbols.assignment, fill: 1), label: 'المهام'),
          NavigationDestination(icon: const Icon(Symbols.groups), selectedIcon: const Icon(Symbols.groups, fill: 1), label: 'الكادر'),
          NavigationDestination(icon: const Icon(Symbols.grid_view), selectedIcon: const Icon(Symbols.grid_view, fill: 1), label: 'المزيد'),
        ],
      ),
    );
  }
}

class _DesktopHeader extends StatelessWidget {
  const _DesktopHeader({required this.section, required this.user});
  final _Section section;
  final Map<String, Object?> user;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final role = switch (user['role']) {
      'manager' => 'المدير',
      'assistant' => 'مساعد المدير',
      'archivist' => 'موظف الأرشيف',
      _ => 'مستخدم النظام',
    };
    return Container(
      height: 78,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: BoxDecoration(color: cs.surface, border: Border(bottom: BorderSide(color: cs.outline.withValues(alpha: .7)))),
      child: Row(children: [
        Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(section.title, style: Theme.of(context).textTheme.titleLarge),
          Text(section.subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurface.withValues(alpha: .62))),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          decoration: BoxDecoration(color: cs.primary.withValues(alpha: .08), borderRadius: BorderRadius.circular(30)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Symbols.account_circle, size: 19, color: cs.primary),
            const SizedBox(width: 8),
            Text(role, style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700)),
          ]),
        ),
      ]),
    );
  }
}
