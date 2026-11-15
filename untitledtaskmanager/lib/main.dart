import 'dart:async';

import 'package:material_ui/material_ui.dart';

void main() {
  runApp(const MyApp());
}

class AppColors {
  static const background = Color(0xFF0B0B0B);
  static const sidebar = Color(0xFF151515);
  static const card = Color(0xFF1D1D1D);
  static const gold = Color(0xFFD4AF37);
  static const white = Color(0xFFF4F1E8);
  static const muted = Color(0xFFAAA6A0);
  static const urgent = Color(0xFFFF3030);
}

// Priority 5 is red (highest); priority 1 is yellow (lowest).
Color priorityColor(int priority) {
  switch (priority) {
    case 5:
      return const Color(0xFFFF3030);
    case 4:
      return const Color(0xFFFF632F);
    case 3:
      return const Color(0xFFFF982F);
    case 2:
      return const Color(0xFFFFC34A);
    default:
      return const Color(0xFFFFE36E);
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Untitled Task Manager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.gold,
          brightness: Brightness.dark,
        ),
      ),
      home: const TaskManagerHome(),
    );
  }
}

// Each task keeps its priority and timer information.
class TaskItem {
  TaskItem({
    required this.title,
    required this.priority,
    required this.order,
  });

  final String title;
  final int priority;
  final int order;

  // Time saved from earlier timer runs, including paused time.
  Duration accumulatedTime = Duration.zero;

  // Null means the timer is paused or has not started.
  DateTime? startedAt;

  bool isCompleted = false;

  bool get isRunning => startedAt != null;

  Duration elapsedAt(DateTime now) {
    final currentRun =
        startedAt == null ? Duration.zero : now.difference(startedAt!);
    return accumulatedTime + currentRun;
  }
}

class TaskManagerHome extends StatefulWidget {
  const TaskManagerHome({super.key});

  @override
  State<TaskManagerHome> createState() => _TaskManagerHomeState();
}

class _TaskManagerHomeState extends State<TaskManagerHome> {
  static const _listNames = ['Work', 'Dojo', 'Home'];

  // Each list has its own tasks.
  final Map<String, List<TaskItem>> _tasksByList = {
    'Work': [],
    'Dojo': [],
    'Home': [],
  };

  final _taskController = TextEditingController();

  String _selectedList = 'Work';
  int _selectedPriority = 3;
  int _nextTaskOrder = 0;

  Timer? _uiTicker;
  bool _urgentVisible = true;

  @override
  void initState() {
    super.initState();

    // Refresh running timer displays and flash the URGENT label.
    _uiTicker = Timer.periodic(const Duration(milliseconds: 500), (_) {
      final needsRefresh = _tasksByList.values.any(
        (tasks) => tasks.any(
          (task) =>
              task.isRunning || (task.priority == 5 && !task.isCompleted),
        ),
      );

      if (needsRefresh) {
        setState(() {
          _urgentVisible = !_urgentVisible;
        });
      }
    });
  }

  @override
  void dispose() {
    _uiTicker?.cancel();
    _taskController.dispose();
    super.dispose();
  }

  List<TaskItem> get _visibleTasks {
    final tasks = List<TaskItem>.of(_tasksByList[_selectedList]!);

    // Higher priority tasks go first. Equal priorities stay in add order.
    tasks.sort((a, b) {
      final priorityOrder = b.priority.compareTo(a.priority);
      if (priorityOrder != 0) return priorityOrder;
      return a.order.compareTo(b.order);
    });

    return tasks;
  }

  void _addTask() {
    final title = _taskController.text.trim();
    if (title.isEmpty) return;

    setState(() {
      _tasksByList[_selectedList]!.add(
        TaskItem(
          title: title,
          priority: _selectedPriority,
          order: _nextTaskOrder++,
        ),
      );

      _taskController.clear();

      // Reset the picker to the middle, orange priority after each task.
      _selectedPriority = 3;
    });
  }

  void _selectList(String listName) {
    setState(() {
      _selectedList = listName;
    });
  }

  void _toggleTimer(TaskItem task) {
    final now = DateTime.now();

    setState(() {
      if (task.isRunning) {
        // Pause: save this run's time and clear the start time.
        task.accumulatedTime = task.elapsedAt(now);
        task.startedAt = null;
      } else if (!task.isCompleted) {
        // Play: start the timer, or resume after a pause.
        task.startedAt = now;
      }
    });
  }

  void _toggleCompleted(TaskItem task) {
    final now = DateTime.now();

    setState(() {
      if (!task.isCompleted) {
        // Completing a running task stops its timer.
        if (task.isRunning) {
          task.accumulatedTime = task.elapsedAt(now);
          task.startedAt = null;
        }

        task.isCompleted = true;
      } else {
        // Unchecking restores the task with its timer paused.
        task.isCompleted = false;
      }
    });
  }

  void _deleteTask(TaskItem task) {
    setState(() {
      _tasksByList[_selectedList]!.remove(task);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 720;
    final now = DateTime.now();

    return Scaffold(
      appBar: isWide
          ? null
          : AppBar(
              title: const Text(
                'UNTITLEDTASKMANAGER',
                style: TextStyle(
                  color: AppColors.gold,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              leading: Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              ),
            ),
      drawer: isWide
          ? null
          : Drawer(
              backgroundColor: AppColors.sidebar,
              child: TaskListSidebar(
                selectedList: _selectedList,
                listNames: _listNames,
                onListSelected: _selectList,
                inDrawer: true,
              ),
            ),
      body: Row(
        children: [
          if (isWide)
            TaskListSidebar(
              selectedList: _selectedList,
              listNames: _listNames,
              onListSelected: _selectList,
            ),
          Expanded(
            child: TaskListContent(
              selectedList: _selectedList,
              tasks: _visibleTasks,
              now: now,
              urgentVisible: _urgentVisible,
              taskController: _taskController,
              selectedPriority: _selectedPriority,
              onPrioritySelected: (priority) {
                setState(() {
                  _selectedPriority = priority;
                });
              },
              onAddTask: _addTask,
              onToggleTimer: _toggleTimer,
              onToggleCompleted: _toggleCompleted,
              onDeleteTask: _deleteTask,
            ),
          ),
        ],
      ),
    );
  }
}

class TaskListSidebar extends StatelessWidget {
  const TaskListSidebar({
    super.key,
    required this.selectedList,
    required this.listNames,
    required this.onListSelected,
    this.inDrawer = false,
  });

  final String selectedList;
  final List<String> listNames;
  final ValueChanged<String> onListSelected;
  final bool inDrawer;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: inDrawer ? null : 250,
      decoration: const BoxDecoration(
        color: AppColors.sidebar,
        border: Border(right: BorderSide(color: Color(0x55D4AF37))),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!inDrawer)
                const Text(
                  'UNTITLEDTASKMANAGER',
                  style: TextStyle(
                    color: AppColors.gold,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              const SizedBox(height: 24),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    for (final name in listNames)
                      ListTile(
                        selected: name == selectedList,
                        selectedTileColor: AppColors.gold,
                        selectedColor: AppColors.background,
                        leading: Icon(_iconForList(name)),
                        title: Text(name),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        onTap: () {
                          onListSelected(name);
                          if (inDrawer) Navigator.pop(context);
                        },
                      ),
                  ],
                ),
              ),
              const SidebarButton(icon: Icons.add, label: 'Add list'),
              const SidebarButton(
                icon: Icons.edit_outlined,
                label: 'Rename',
              ),
              const SidebarButton(
                icon: Icons.palette_outlined,
                label: 'Color',
              ),
              const SidebarButton(
                icon: Icons.delete_outline,
                label: 'Delete list',
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconForList(String name) {
    switch (name) {
      case 'Work':
        return Icons.work_outline;
      case 'Dojo':
        return Icons.sports_martial_arts;
      case 'Home':
        return Icons.home_outlined;
      default:
        return Icons.list;
    }
  }
}

class SidebarButton extends StatelessWidget {
  const SidebarButton({
    super.key,
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.gold),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.gold, size: 19),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(color: AppColors.white)),
        ],
      ),
    );
  }
}

class TaskListContent extends StatelessWidget {
  const TaskListContent({
    super.key,
    required this.selectedList,
    required this.tasks,
    required this.now,
    required this.urgentVisible,
    required this.taskController,
    required this.selectedPriority,
    required this.onPrioritySelected,
    required this.onAddTask,
    required this.onToggleTimer,
    required this.onToggleCompleted,
    required this.onDeleteTask,
  });

  final String selectedList;
  final List<TaskItem> tasks;
  final DateTime now;
  final bool urgentVisible;
  final TextEditingController taskController;
  final int selectedPriority;
  final ValueChanged<int> onPrioritySelected;
  final VoidCallback onAddTask;
  final ValueChanged<TaskItem> onToggleTimer;
  final ValueChanged<TaskItem> onToggleCompleted;
  final ValueChanged<TaskItem> onDeleteTask;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              selectedList,
              style: const TextStyle(
                color: AppColors.gold,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'NEW TASK',
                        style: TextStyle(
                          color: AppColors.gold,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: taskController,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => onAddTask(),
                        decoration: InputDecoration(
                          hintText: 'Type a task name...',
                          hintStyle: const TextStyle(color: AppColors.muted),
                          filled: true,
                          fillColor: AppColors.card,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 15,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: const BorderSide(
                              color: AppColors.gold,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: const BorderSide(
                              color: AppColors.gold,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                PriorityPicker(
                  selectedPriority: selectedPriority,
                  onPrioritySelected: onPrioritySelected,
                ),
                const SizedBox(width: 12),
                IconButton(
                  tooltip: 'Add task',
                  onPressed: onAddTask,
                  style: IconButton.styleFrom(
                    fixedSize: const Size(52, 52),
                    backgroundColor: AppColors.background,
                    foregroundColor: AppColors.gold,
                    side: const BorderSide(color: AppColors.gold, width: 2),
                    shape: const CircleBorder(),
                  ),
                  icon: const Icon(Icons.add, size: 28),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: tasks.isEmpty
                  ? const EmptyTaskArea()
: ScrollConfiguration(
  behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
  child: Padding(
    padding: const EdgeInsets.only(right: 12),
    child: ListView.separated(
      itemCount: tasks.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final task = tasks[index];
        return TaskCard(
          task: task,
          now: now,
          urgentVisible: urgentVisible,
          onToggleTimer: () => onToggleTimer(task),
          onToggleCompleted: () => onToggleCompleted(task),
          onDelete: () => onDeleteTask(task),
        );
      },
    ),
  ),
),
            ),
          ],
        ),
      ),
    );
  }
}

class PriorityPicker extends StatelessWidget {
  const PriorityPicker({
    super.key,
    required this.selectedPriority,
    required this.onPrioritySelected,
  });

  final int selectedPriority;
  final ValueChanged<int> onPrioritySelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(
          'PRIORITY',
          style: TextStyle(
            color: AppColors.gold,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        PopupMenuButton<int>(
          tooltip: 'Choose priority color',
          initialValue: selectedPriority,
          onSelected: onPrioritySelected,

          // These constraints make the menu as wide as its 52-pixel button.
          constraints: const BoxConstraints(minWidth: 52, maxWidth: 52),
          padding: EdgeInsets.zero,
          menuPadding: EdgeInsets.zero,
          color: AppColors.sidebar,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
          itemBuilder: (context) => [
            // The five circles appear from highest priority to lowest.
            for (final priority in [5, 4, 3, 2, 1])
              PopupMenuItem<int>(
                value: priority,
                height: 48,
                padding: EdgeInsets.zero,
                child: Center(
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: priorityColor(priority),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: priority == selectedPriority
                            ? AppColors.white
                            : AppColors.gold,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
          ],
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: priorityColor(selectedPriority),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.gold, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

class TaskCard extends StatelessWidget {
  const TaskCard({
    super.key,
    required this.task,
    required this.now,
    required this.urgentVisible,
    required this.onToggleTimer,
    required this.onToggleCompleted,
    required this.onDelete,
  });

  final TaskItem task;
  final DateTime now;
  final bool urgentVisible;
  final VoidCallback onToggleTimer;
  final VoidCallback onToggleCompleted;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isCompleted = task.isCompleted;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isCompleted ? const Color(0xFF292929) : AppColors.card,
        border: Border.all(
          color: priorityColor(task.priority),
          width: 2,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
  child: Row(
    children: [
      Expanded(
        child: Text(
          task.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: isCompleted ? AppColors.muted : AppColors.white,
            fontSize: 16,
            decoration: isCompleted ? TextDecoration.lineThrough : null,
          ),
        ),
      ),
      if (task.priority == 5 && !isCompleted)
        Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Opacity(
            opacity: urgentVisible ? 1 : 0,
            child: const Text(
              'URGENT',
              style: TextStyle(
                color: AppColors.urgent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
    ],
  ),
),
          const SizedBox(width: 8),

          // Fixed-width control slots keep the row from shifting.
          SizedBox(
            width: 78,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                _formatDuration(task.elapsedAt(now)),
                style: const TextStyle(color: AppColors.muted),
              ),
            ),
          ),
          _ControlSlot(
            child: IconButton(
              tooltip: task.isRunning ? 'Pause timer' : 'Start or resume timer',
              onPressed: isCompleted ? null : onToggleTimer,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(
                width: 40,
                height: 40,
              ),
              icon: Icon(
                task.isRunning ? Icons.pause : Icons.play_arrow,
                color: isCompleted ? AppColors.muted : AppColors.gold,
              ),
            ),
          ),
          _ControlSlot(
            child: IconButton(
              tooltip: isCompleted ? 'Mark task incomplete' : 'Complete task',
              onPressed: onToggleCompleted,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(
                width: 40,
                height: 40,
              ),
              icon: Icon(
                isCompleted
                    ? Icons.check_box
                    : Icons.check_box_outline_blank,
                color: AppColors.gold,
              ),
            ),
          ),

          // Keep this slot even while incomplete, so the X doesn't move controls.
          _ControlSlot(
            child: isCompleted
                ? IconButton(
                    tooltip: 'Remove task',
                    onPressed: onDelete,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 40,
                      height: 40,
                    ),
                    icon: const Icon(
                      Icons.close,
                      color: AppColors.urgent,
                    ),
                  )
                : const SizedBox(width: 40, height: 40),
          ),
        ],
      ),
    );
  }
}

class _ControlSlot extends StatelessWidget {
  const _ControlSlot({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: Center(child: child),
    );
  }
}

String _formatDuration(Duration duration) {
  final hours = duration.inHours.toString().padLeft(2, '0');
  final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
  final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');

  return '$hours:$minutes:$seconds';
}

class EmptyTaskArea extends StatelessWidget {
  const EmptyTaskArea({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: const Color(0x55D4AF37)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.checklist, color: AppColors.gold, size: 42),
            SizedBox(height: 12),
            Text(
              'Your tasks will appear here',
              style: TextStyle(color: AppColors.white, fontSize: 17),
            ),
          ],
        ),
      ),
    );
  }
}