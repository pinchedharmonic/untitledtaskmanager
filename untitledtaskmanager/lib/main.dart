import 'package:material_ui/material_ui.dart';

void main() {
  runApp(const MyApp());
}

// Keeping colors here makes the palette easy to adjust later.
class AppColors {
  static const background = Color(0xFF0B0B0B);
  static const sidebar = Color(0xFF151515);
  static const card = Color(0xFF1D1D1D);
  static const gold = Color(0xFFD4AF37);
  static const white = Color(0xFFF4F1E8);
  static const muted = Color(0xFFAAA6A0);
  static const urgent = Color(0xFFFF3030);
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

// A task has a name, a priority, and an order number.
// The order number keeps tasks of equal priority in the order they were added.
class TaskItem {
  const TaskItem({
    required this.title,
    required this.priority,
    required this.order,
  });

  final String title;
  final int priority;
  final int order;
}

class TaskManagerHome extends StatefulWidget {
  const TaskManagerHome({super.key});

  @override
  State<TaskManagerHome> createState() => _TaskManagerHomeState();
}

class _TaskManagerHomeState extends State<TaskManagerHome> {
  static const _listNames = ['Work', 'Dojo', 'Home'];

  // Each list gets its own collection of tasks.
  final Map<String, List<TaskItem>> _tasksByList = {
    'Work': [],
    'Dojo': [],
    'Home': [],
  };

  final _taskController = TextEditingController();

  String _selectedList = 'Work';
  int _selectedPriority = 3;
  int _nextTaskOrder = 0;

  // Return a sorted copy, so the original task collection stays intact.
  List<TaskItem> get _visibleTasks {
    final tasks = List<TaskItem>.of(_tasksByList[_selectedList]!);
    tasks.sort((a, b) {
      final priorityOrder = b.priority.compareTo(a.priority);
      if (priorityOrder != 0) return priorityOrder;
      return a.order.compareTo(b.order);
    });
    return tasks;
  }

  // Add the typed task to the currently selected list.
  void _addTask() {
    final title = _taskController.text.trim();

    // Ignore the plus button if the field is empty.
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
    });
  }

  @override
  void dispose() {
    // Clean up the text field controller when this screen closes.
    _taskController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 720;

    return Scaffold(
      // On a narrow phone screen, the list menu opens from the side.
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

      // Row places the sidebar and task area next to each other.
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
              taskController: _taskController,
              selectedPriority: _selectedPriority,
              onPrioritySelected: (priority) {
                setState(() {
                  _selectedPriority = priority;
                });
              },
              onAddTask: _addTask,
            ),
          ),
        ],
      ),
    );
  }

  void _selectList(String listName) {
    setState(() {
      _selectedList = listName;
    });
  }
}

// This is the left pane: app name, lists, and list-control placeholders.
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
        border: Border(
          right: BorderSide(color: Color(0x55D4AF37)),
        ),
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

              // Tapping a list tells the main screen which tasks to show.
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

              // These are still visual placeholders; we can wire them up later.
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
    required this.taskController,
    required this.selectedPriority,
    required this.onPrioritySelected,
    required this.onAddTask,
  });

  final String selectedList;
  final List<TaskItem> tasks;
  final TextEditingController taskController;
  final int selectedPriority;
  final ValueChanged<int> onPrioritySelected;
  final VoidCallback onAddTask;

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

            // Show an empty message until this list has tasks.
            Expanded(
              child: tasks.isEmpty
                  ? const EmptyTaskArea()
                  : ListView.separated(
                      itemCount: tasks.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        return TaskCard(task: tasks[index]);
                      },
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
          tooltip: 'Choose priority',
          initialValue: selectedPriority,
          onSelected: onPrioritySelected,
          itemBuilder: (context) => [
            for (var priority = 1; priority <= 5; priority++)
              PopupMenuItem(
                value: priority,
                child: Text(
                  '$priority  ${_priorityName(priority)}',
                  style: TextStyle(
                    color: priority == 5 ? AppColors.urgent : AppColors.white,
                  ),
                ),
              ),
          ],
          child: Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.gold, width: 2),
            ),
            child: Text(
              '$selectedPriority',
              style: const TextStyle(
                color: AppColors.gold,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _priorityName(int priority) {
    if (priority == 1) return 'Low';
    if (priority == 5) return 'High';
    return '';
  }
}

class TaskCard extends StatelessWidget {
  const TaskCard({super.key, required this.task});

  final TaskItem task;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: const Color(0x55D4AF37)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.gold),
            ),
            child: Text(
              '${task.priority}',
              style: const TextStyle(
                color: AppColors.gold,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              task.title,
              style: const TextStyle(color: AppColors.white, fontSize: 16),
            ),
          ),
          if (task.priority == 5)
            const Text(
              'URGENT',
              style: TextStyle(
                color: AppColors.urgent,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
    );
  }
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