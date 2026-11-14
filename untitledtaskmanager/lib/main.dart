import 'package:material_ui/material_ui.dart';

void main() {
  runApp(const MyApp());
}

// These named colors make it easy to keep the app's colors consistent.
class AppColors {
  static const background = Color(0xFF0B0B0B);
  static const sidebar = Color(0xFF151515);
  static const card = Color(0xFF1D1D1D);
  static const gold = Color(0xFFD4AF37);
  static const white = Color(0xFFF4F1E8);
  static const muted = Color(0xFFAAA6A0);
}

// MyApp sets up the overall Flutter application.
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

// This is the main screen. It shows a sidebar on a wide window,
// and puts that sidebar in a menu on a narrow phone screen.
class TaskManagerHome extends StatelessWidget {
  const TaskManagerHome({super.key});

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 720;

    return Scaffold(
      // On a narrow screen, the list menu opens from the side.
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
          : const Drawer(
              backgroundColor: AppColors.sidebar,
              child: TaskListSidebar(inDrawer: true),
            ),

      // Row places the sidebar beside the main area.
      body: Row(
        children: [
          if (isWide) const TaskListSidebar(),
          Expanded(
            // Expanded gives the main area all the space left over.
            child: const TaskListContent(),
          ),
        ],
      ),
    );
  }
}

// The left pane: app name, task lists, and list controls.
class TaskListSidebar extends StatelessWidget {
  const TaskListSidebar({super.key, this.inDrawer = false});

  final bool inDrawer;

  @override
  Widget build(BuildContext context) {
    const lists = [
      ('Work', Icons.work_outline),
      ('Dojo', Icons.sports_martial_arts),
      ('Home', Icons.home_outlined),
    ];

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

              // Expanded lets the list names use the open space.
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    for (final (name, icon) in lists)
                      ListTile(
                        selected: name == 'Work',
                        selectedTileColor: AppColors.gold,
                        selectedColor: AppColors.background,
                        leading: Icon(icon),
                        title: Text(name),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                  ],
                ),
              ),

              // These are visual placeholders. We'll wire them up later.
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
}

// A gold-outlined placeholder for one of the sidebar controls.
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

// The right side: selected list name, task-entry area, and empty task area.
class TaskListContent extends StatelessWidget {
  const TaskListContent({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Work',
              style: TextStyle(
                color: AppColors.gold,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),

            // This row holds the task field, priority circle, and plus button.
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Expanded(child: TaskEntryPlaceholder()),
                const SizedBox(width: 12),
                const PriorityPlaceholder(),
                const SizedBox(width: 12),
                const AddTaskPlaceholder(),
              ],
            ),
            const SizedBox(height: 24),

            // Tasks will appear in this area once we add task behavior.
            Expanded(
              child: Container(
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
                      Icon(
                        Icons.checklist,
                        color: AppColors.gold,
                        size: 42,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Your tasks will appear here',
                        style: TextStyle(
                          color: AppColors.white,
                          fontSize: 17,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'This is just the first layout.',
                        style: TextStyle(color: AppColors.muted),
                      ),
                    ],
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

// This draws the task-entry field for now; it doesn't add tasks yet.
class TaskEntryPlaceholder extends StatelessWidget {
  const TaskEntryPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
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
        Container(
          height: 52,
          width: double.infinity,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: AppColors.card,
            border: Border.all(color: AppColors.gold),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            'Type a task name...',
            style: TextStyle(color: AppColors.muted),
          ),
        ),
      ],
    );
  }
}

// A sample priority circle. We'll make it selectable later.
class PriorityPlaceholder extends StatelessWidget {
  const PriorityPlaceholder({super.key});

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
        Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.gold, width: 2),
          ),
          child: const Text(
            '3',
            style: TextStyle(
              color: AppColors.gold,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

// The gold plus circle is also just a visual placeholder at this stage.
class AddTaskPlaceholder extends StatelessWidget {
  const AddTaskPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.background,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.gold, width: 2),
      ),
      child: const Icon(Icons.add, color: AppColors.gold, size: 28),
    );
  }
}