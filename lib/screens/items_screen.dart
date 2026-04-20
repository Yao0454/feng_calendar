import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../widgets/event_card.dart';
import '../widgets/todo_card.dart';
import '../widgets/empty_state.dart';

enum _Filter { all, events, todos }

class ItemsScreen extends StatefulWidget {
  const ItemsScreen({super.key});

  @override
  State<ItemsScreen> createState() => _ItemsScreenState();
}

class _ItemsScreenState extends State<ItemsScreen> {
  _Filter _filter = _Filter.all;

  Widget _swipeable({
    required Key key,
    required VoidCallback? onDelete,
    required Widget child,
  }) {
    if (onDelete == null) return child;
    return Dismissible(
      key: key,
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444),
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 22),
        child: const Icon(Icons.delete_rounded, color: Colors.white, size: 22),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final provider = context.watch<AppProvider>();
    final allEvents = provider.events;
    final allTodos = provider.todos;
    final events =
        _filter != _Filter.todos ? allEvents : <ScheduleEvent>[];
    final todos = _filter != _Filter.events ? allTodos : <Todo>[];
    final hasContent = events.isNotEmpty || todos.isNotEmpty;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => context.read<AppProvider>().loadLocal(),
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              title: const Text('日程 & 待办'),
              floating: true,
              snap: true,
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(56),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: SegmentedButton<_Filter>(
                    segments: [
                      ButtonSegment(
                        value: _Filter.all,
                        label: Text(allEvents.isEmpty && allTodos.isEmpty
                            ? '全部'
                            : '全部 ${allEvents.length + allTodos.length}'),
                      ),
                      ButtonSegment(
                        value: _Filter.events,
                        label: Text(allEvents.isEmpty
                            ? '日程'
                            : '日程 ${allEvents.length}'),
                      ),
                      ButtonSegment(
                        value: _Filter.todos,
                        label: Text(allTodos.isEmpty
                            ? '待办'
                            : '待办 ${allTodos.length}'),
                      ),
                    ],
                    selected: {_filter},
                    onSelectionChanged: (s) =>
                        setState(() => _filter = s.first),
                  ),
                ),
              ),
            ),
            if (hasContent) ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                sliver: SliverList.list(
                  children: [
                    if (events.isNotEmpty) ...[
                      if (_filter == _Filter.all)
                        _SectionHeader(
                            icon: Icons.calendar_month_rounded,
                            label: '日程',
                            color: cs.primary),
                      ...events.map((e) => _swipeable(
                            key: ValueKey('event_${e.id}'),
                            onDelete: e.id != null
                                ? () => context
                                    .read<AppProvider>()
                                    .deleteEvent(e.id!)
                                : null,
                            child: EventCard(
                              event: e,
                              onDelete: e.id != null
                                  ? () => context
                                      .read<AppProvider>()
                                      .deleteEvent(e.id!)
                                  : null,
                            ),
                          )),
                    ],
                    if (todos.isNotEmpty) ...[
                      if (_filter == _Filter.all && events.isNotEmpty)
                        const SizedBox(height: 8),
                      if (_filter == _Filter.all)
                        const _SectionHeader(
                            icon: Icons.checklist_rounded,
                            label: '待办',
                            color: Color(0xFFF97316)),
                      ...todos.map((t) => _swipeable(
                            key: ValueKey('todo_${t.id}'),
                            onDelete: t.id != null
                                ? () => context
                                    .read<AppProvider>()
                                    .deleteTodo(t.id!)
                                : null,
                            child: TodoCard(
                              todo: t,
                              onToggle: t.id != null
                                  ? (done) => context
                                      .read<AppProvider>()
                                      .toggleTodo(t.id!, done)
                                  : null,
                              onDelete: t.id != null
                                  ? () => context
                                      .read<AppProvider>()
                                      .deleteTodo(t.id!)
                                  : null,
                            ),
                          )),
                    ],
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ] else
              const SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(),
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _SectionHeader(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 4, 0, 8),
      child: Row(
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
          ),
        ],
      ),
    );
  }
}
