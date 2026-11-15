import 'dart:async';
import 'dart:math';

import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/supabase_app_config.dart';
import 'data/supabase_task_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final supabase = await SupabaseAppConfig.initializeIfConfigured();
  runApp(MyApp(supabase: supabase));
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

String createRecordId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));

  // Mark this as a version 4 UUID with the standard variant bits.
  bytes[6] = (bytes[6] & 0x0F) | 0x40;
  bytes[8] = (bytes[8] & 0x3F) | 0x80;

  final hex = bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-'
      '${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-'
      '${hex.substring(16, 20)}-'
      '${hex.substring(20, 32)}';
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.supabase});

  final SupabaseClient? supabase;

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
      home: supabase == null
          ? const TaskManagerHome()
          : SupabaseAuthGate(supabase: supabase!),
    );
  }
}

class SupabaseAuthGate extends StatefulWidget {
  const SupabaseAuthGate({super.key, required this.supabase});

  final SupabaseClient supabase;

  @override
  State<SupabaseAuthGate> createState() => _SupabaseAuthGateState();
}

class _SupabaseAuthGateState extends State<SupabaseAuthGate> {
  late bool _signedIn = widget.supabase.auth.currentSession != null;
  late final StreamSubscription<AuthState> _authSubscription;

  @override
  void initState() {
    super.initState();
    _authSubscription = widget.supabase.auth.onAuthStateChange.listen((state) {
      if (mounted) setState(() => _signedIn = state.session != null);
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_signedIn) {
      return TaskManagerHome(
        repository: SupabaseTaskRepository(widget.supabase),
      );
    }
    return SupabaseSignInPage(supabase: widget.supabase);
  }
}

class SupabaseSignInPage extends StatefulWidget {
  const SupabaseSignInPage({super.key, required this.supabase});

  final SupabaseClient supabase;

  @override
  State<SupabaseSignInPage> createState() => _SupabaseSignInPageState();
}

class _SupabaseSignInPageState extends State<SupabaseSignInPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isCreatingAccount = false;
  bool _isBusy = false;
  String? _message;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _message = 'Enter your email and password.');
      return;
    }

    setState(() {
      _isBusy = true;
      _message = null;
    });
    try {
      if (_isCreatingAccount) {
        final response = await widget.supabase.auth.signUp(
          email: email,
          password: password,
        );
        if (response.session == null && mounted) {
          setState(
            () =>
                _message = 'Check your email to finish creating your account.',
          );
        }
      } else {
        await widget.supabase.auth.signInWithPassword(
          email: email,
          password: password,
        );
      }
    } catch (error) {
      if (mounted) setState(() => _message = error.toString());
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            color: AppColors.sidebar,
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'UNTITLEDTASKMANAGER',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.gold,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _isCreatingAccount
                        ? 'Create your account'
                        : 'Sign in to sync',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 20),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.username],
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    decoration: const InputDecoration(labelText: 'Password'),
                    onSubmitted: (_) => _isBusy ? null : _submit(),
                  ),
                  if (_message != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _message!,
                      style: const TextStyle(color: AppColors.urgent),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _isBusy ? null : _submit,
                    child: Text(
                      _isBusy
                          ? 'Please wait…'
                          : _isCreatingAccount
                          ? 'Create account'
                          : 'Sign in',
                    ),
                  ),
                  TextButton(
                    onPressed: _isBusy
                        ? null
                        : () => setState(() {
                            _isCreatingAccount = !_isCreatingAccount;
                            _message = null;
                          }),
                    child: Text(
                      _isCreatingAccount
                          ? 'I already have an account'
                          : 'Create a new account',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Each task keeps its priority and timer information.
class TaskItem {
  TaskItem({
    required this.id,
    required this.listId,
    required this.title,
    required this.priority,
    required this.order,
  });

  final String id;
  final String listId;
  final String title;
  final int priority;
  final int order;

  // Time saved from earlier timer runs, including paused time.
  Duration accumulatedTime = Duration.zero;

  // Null means the timer is paused or has not started.
  DateTime? startedAt;

  bool isCompleted = false;

  bool get isRunning => startedAt != null;

  factory TaskItem.fromRow(Map<String, dynamic> row) {
    final startedAtValue = row['timer_started_at'] as String?;
    final completedAtValue = row['completed_at'] as String?;
    return TaskItem(
        id: row['id'] as String,
        listId: row['list_id'] as String,
        title: row['title'] as String,
        priority: (row['priority'] as num).toInt(),
        order: (row['sort_order'] as num).toInt(),
      )
      ..accumulatedTime = Duration(
        seconds: (row['elapsed_seconds'] as num).toInt(),
      )
      ..startedAt = startedAtValue == null
          ? null
          : DateTime.parse(startedAtValue).toUtc()
      ..isCompleted = completedAtValue != null;
  }

  Duration elapsedAt(DateTime now) {
    final currentRun = startedAt == null
        ? Duration.zero
        : now.difference(startedAt!);
    return accumulatedTime + currentRun;
  }
}

class TaskListInfo {
  const TaskListInfo({
    required this.id,
    required this.name,
    required this.iconKey,
  });

  final String id;
  final String name;
  final String iconKey;

  factory TaskListInfo.fromRow(Map<String, dynamic> row) => TaskListInfo(
    id: row['id'] as String,
    name: row['name'] as String,
    iconKey: row['icon_key'] as String,
  );

  IconData get icon => _listIconsByKey[iconKey] ?? Icons.list;

  TaskListInfo copyWith({String? name, String? iconKey}) {
    return TaskListInfo(
      id: id,
      name: name ?? this.name,
      iconKey: iconKey ?? this.iconKey,
    );
  }
}

const _listIconsByKey = <String, IconData>{
  'general': Icons.list,
  'work': Icons.work_outline,
  'home': Icons.home_outlined,
  'karate': Icons.sports_martial_arts,
  'school': Icons.school_outlined,
  'shopping': Icons.shopping_cart_outlined,
  'fitness': Icons.fitness_center,
  'food': Icons.restaurant_outlined,
  'pets': Icons.pets_outlined,
  'health': Icons.favorite_border,
  'travel': Icons.flight_outlined,
  'car': Icons.directions_car_outlined,
  'tools': Icons.build_outlined,
  'music': Icons.music_note_outlined,
  'reading': Icons.book_outlined,
  'ideas': Icons.lightbulb_outline,
  'events': Icons.event_outlined,
  'favorites': Icons.star_outline,
  'selfCare': Icons.spa_outlined,
  'computer': Icons.computer_outlined,
};

String _iconKeyFor(IconData icon) {
  for (final entry in _listIconsByKey.entries) {
    if (entry.value == icon) return entry.key;
  }
  return 'general';
}

const _availableListIcons = <IconData>[
  Icons.list,
  Icons.work_outline,
  Icons.home_outlined,
  Icons.sports_martial_arts,
  Icons.school_outlined,
  Icons.shopping_cart_outlined,
  Icons.fitness_center,
  Icons.restaurant_outlined,
  Icons.pets_outlined,
  Icons.favorite_border,
  Icons.flight_outlined,
  Icons.directions_car_outlined,
  Icons.build_outlined,
  Icons.music_note_outlined,
  Icons.book_outlined,
  Icons.lightbulb_outline,
  Icons.event_outlined,
  Icons.star_outline,
  Icons.spa_outlined,
  Icons.computer_outlined,
];

class TaskManagerHome extends StatefulWidget {
  const TaskManagerHome({super.key, this.repository});

  final SupabaseTaskRepository? repository;

  @override
  State<TaskManagerHome> createState() => _TaskManagerHomeState();
}

class _TaskManagerHomeState extends State<TaskManagerHome>
    with WidgetsBindingObserver {
  final List<TaskListInfo> _lists = [
    TaskListInfo(id: createRecordId(), name: 'Work', iconKey: 'work'),
    TaskListInfo(id: createRecordId(), name: 'Dojo', iconKey: 'karate'),
    TaskListInfo(id: createRecordId(), name: 'Home', iconKey: 'home'),
  ];

  // Each list has its own tasks.
  late final Map<String, List<TaskItem>> _tasksByList = {
    for (final list in _lists) list.id: <TaskItem>[],
  };

  final _taskController = TextEditingController();

  late String _selectedListId = _lists.first.id;
  int _selectedPriority = 3;
  StreamSubscription<void>? _cloudChangesSubscription;
  int _cloudLoadGeneration = 0;
  bool _hasCloudData = false;
  bool _isLoadingCloudData = false;
  String? _cloudLoadError;

  Timer? _uiTicker;
  bool _urgentVisible = true;

  TaskListInfo get _selectedListInfo =>
      _lists.firstWhere((list) => list.id == _selectedListId);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Refresh running timer displays and flash the URGENT label.
    _uiTicker = Timer.periodic(const Duration(milliseconds: 500), (_) {
      final needsRefresh = _tasksByList.values.any(
        (tasks) => tasks.any(
          (task) => task.isRunning || (task.priority == 5 && !task.isCompleted),
        ),
      );

      if (needsRefresh) {
        setState(() {
          _urgentVisible = !_urgentVisible;
        });
      }
    });

    if (widget.repository != null) {
      _isLoadingCloudData = true;
      _cloudChangesSubscription = widget.repository!.watchChanges().listen((_) {
        _loadCloudData();
      });
      _loadCloudData(initial: true);
    }
  }

  @override
  void dispose() {
    _uiTicker?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _cloudChangesSubscription?.cancel();
    _taskController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.repository != null) {
      _loadCloudData();
    }
  }

  Future<void> _loadCloudData({bool initial = false}) async {
    final repository = widget.repository;
    if (repository == null) return;
    final generation = ++_cloudLoadGeneration;

    try {
      await repository.syncServerClock();
      final listRows = await repository.loadLists();
      final taskRows = await repository.loadTasks();
      final lists = listRows.map(TaskListInfo.fromRow).toList();
      final tasksByList = <String, List<TaskItem>>{
        for (final list in lists) list.id: <TaskItem>[],
      };
      for (final row in taskRows) {
        final task = TaskItem.fromRow(row);
        tasksByList[task.listId]?.add(task);
      }

      if (!mounted || generation != _cloudLoadGeneration) return;
      setState(() {
        _lists
          ..clear()
          ..addAll(lists);
        _tasksByList
          ..clear()
          ..addAll(tasksByList);
        if (!_lists.any((list) => list.id == _selectedListId)) {
          _selectedListId = _lists.first.id;
        }
        _isLoadingCloudData = false;
        _cloudLoadError = null;
        _hasCloudData = true;
      });
    } catch (error) {
      if (!mounted || generation != _cloudLoadGeneration) return;
      setState(() {
        _isLoadingCloudData = false;
        _cloudLoadError = initial || !_hasCloudData ? error.toString() : null;
      });
      if (_hasCloudData) _showMessage('Could not refresh from cloud: $error');
    }
  }

  List<TaskItem> get _visibleTasks {
    final tasks = List<TaskItem>.of(_tasksByList[_selectedListId]!);

    // Higher priority tasks go first. Equal priorities stay in add order.
    tasks.sort((a, b) {
      final priorityOrder = b.priority.compareTo(a.priority);
      if (priorityOrder != 0) return priorityOrder;
      return a.order.compareTo(b.order);
    });

    return tasks;
  }

  Future<void> _addTask() async {
    final title = _taskController.text.trim();
    if (title.isEmpty) return;

    final repository = widget.repository;
    if (repository != null) {
      final listId = _selectedListId;
      final priority = _selectedPriority;
      try {
        final row = await repository.createTask(
          id: createRecordId(),
          listId: listId,
          title: title,
          priority: priority,
        );
        if (!mounted) return;
        final savedTask = TaskItem.fromRow(row);
        setState(() {
          _tasksByList[savedTask.listId]!.add(savedTask);
          _taskController.clear();
          _selectedPriority = 3;
        });
      } catch (error) {
        if (mounted) _showMessage('Task was not saved: $error');
      }
      return;
    }

    setState(() {
      _tasksByList[_selectedListId]!.add(
        TaskItem(
          id: createRecordId(),
          listId: _selectedListId,
          title: title,
          priority: _selectedPriority,
          order: _tasksByList[_selectedListId]!.length,
        ),
      );

      _taskController.clear();

      // Reset the picker to the middle, orange priority after each task.
      _selectedPriority = 3;
    });
  }

  void _selectList(String listId) {
    setState(() {
      _selectedListId = listId;
    });
  }

  Future<void> _addList() async {
    final result = await _showListEditor();
    if (!mounted || result == null) return;

    if (_lists.any(
      (list) => list.name.toLowerCase() == result.name.toLowerCase(),
    )) {
      _showMessage('A list with that name already exists.');
      return;
    }

    var savedList = result;
    if (widget.repository case final repository?) {
      try {
        final row = await repository.createList(
          id: result.id,
          name: result.name,
          iconKey: result.iconKey,
        );
        savedList = TaskListInfo.fromRow(row);
      } catch (error) {
        if (mounted) _showMessage('List was not saved: $error');
        return;
      }
    }
    if (!mounted) return;

    setState(() {
      _lists.add(savedList);
      _tasksByList[savedList.id] = [];
      _selectedListId = savedList.id;
    });
  }

  Future<TaskListInfo?> _showListEditor({TaskListInfo? existing}) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    var selectedIcon = existing?.icon ?? _availableListIcons.first;

    TaskListInfo listWithName(String name) {
      final iconKey = _iconKeyFor(selectedIcon);
      return existing == null
          ? TaskListInfo(id: createRecordId(), name: name, iconKey: iconKey)
          : existing.copyWith(name: name, iconKey: iconKey);
    }

    final result = await showDialog<TaskListInfo>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.sidebar,
          title: Text(
            existing == null ? 'Add list' : 'Rename list',
            style: const TextStyle(color: AppColors.gold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'List name',
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: AppColors.gold),
                  ),
                ),
                onSubmitted: (_) {
                  final name = nameController.text.trim();
                  if (name.isNotEmpty) {
                    Navigator.pop(dialogContext, listWithName(name));
                  }
                },
              ),
              const SizedBox(height: 18),
              DropdownButtonFormField<IconData>(
                initialValue: selectedIcon,
                decoration: const InputDecoration(labelText: 'Choose an icon'),
                dropdownColor: AppColors.card,
                items: [
                  for (final icon in _availableListIcons)
                    DropdownMenuItem(
                      value: icon,
                      child: Row(
                        children: [
                          Icon(icon, color: AppColors.gold),
                          const SizedBox(width: 12),
                          Text(_iconLabel(icon)),
                        ],
                      ),
                    ),
                ],
                onChanged: (icon) {
                  if (icon != null) setDialogState(() => selectedIcon = icon);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                Navigator.pop(dialogContext, listWithName(name));
              },
              child: Text(existing == null ? 'Add' : 'Save'),
            ),
          ],
        ),
      ),
    );
    nameController.dispose();
    return result;
  }

  Future<void> _renameSelectedList() async {
    final oldList = _selectedListInfo;
    final result = await _showListEditor(existing: oldList);
    if (!mounted ||
        result == null ||
        (result.name == oldList.name && result.icon == oldList.icon)) {
      return;
    }

    if (_lists.any(
      (list) =>
          list.id != oldList.id &&
          list.name.toLowerCase() == result.name.toLowerCase(),
    )) {
      _showMessage('A list with that name already exists.');
      return;
    }

    var savedList = result;
    if (widget.repository case final repository?) {
      try {
        final row = await repository.updateList(
          id: result.id,
          name: result.name,
          iconKey: result.iconKey,
        );
        savedList = TaskListInfo.fromRow(row);
      } catch (error) {
        if (mounted) _showMessage('List changes were not saved: $error');
        return;
      }
    }
    if (!mounted) return;

    setState(() {
      final index = _lists.indexWhere((list) => list.id == savedList.id);
      if (index >= 0) _lists[index] = savedList;
      _selectedListId = savedList.id;
    });
  }

  Future<void> _deleteSelectedList() async {
    if (_lists.length == 1) {
      _showMessage('Keep at least one list.');
      return;
    }

    final selectedList = _selectedListInfo;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.sidebar,
        title: const Text(
          'Delete list?',
          style: TextStyle(color: AppColors.gold),
        ),
        content: Text('Delete "${selectedList.name}" and all of its tasks?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    if (widget.repository case final repository?) {
      try {
        await repository.deleteList(selectedList.id);
      } catch (error) {
        _showMessage('List was not deleted: $error');
        return;
      }
    }
    if (!mounted) return;
    setState(() {
      _lists.removeWhere((list) => list.id == selectedList.id);
      _tasksByList.remove(selectedList.id);
      _selectedListId = _lists.first.id;
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  static String _iconLabel(IconData icon) {
    if (icon == Icons.sports_martial_arts) return 'Karate';
    if (icon == Icons.work_outline) return 'Work';
    if (icon == Icons.home_outlined) return 'Home';
    if (icon == Icons.school_outlined) return 'School';
    if (icon == Icons.shopping_cart_outlined) return 'Shopping';
    if (icon == Icons.fitness_center) return 'Fitness';
    if (icon == Icons.restaurant_outlined) return 'Food';
    if (icon == Icons.pets_outlined) return 'Pets';
    if (icon == Icons.favorite_border) return 'Health';
    if (icon == Icons.flight_outlined) return 'Travel';
    if (icon == Icons.directions_car_outlined) return 'Car';
    if (icon == Icons.build_outlined) return 'Tools';
    if (icon == Icons.music_note_outlined) return 'Music';
    if (icon == Icons.book_outlined) return 'Reading';
    if (icon == Icons.lightbulb_outline) return 'Ideas';
    if (icon == Icons.event_outlined) return 'Events';
    if (icon == Icons.star_outline) return 'Favorites';
    if (icon == Icons.spa_outlined) return 'Self care';
    if (icon == Icons.computer_outlined) return 'Computer';
    return 'General';
  }

  Future<void> _toggleTimer(TaskItem task) async {
    final now = widget.repository?.now ?? DateTime.now();

    if (widget.repository case final repository?) {
      try {
        final row = task.isRunning
            ? await repository.pauseTimer(task.id)
            : await repository.startTimer(task.id);
        if (mounted) _applySavedTask(row);
      } catch (error) {
        if (mounted) _showMessage('Timer change was not saved: $error');
      }
      return;
    }

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

  Future<void> _toggleCompleted(TaskItem task) async {
    final now = DateTime.now();

    if (widget.repository case final repository?) {
      try {
        final row = await repository.setCompleted(
          task.id,
          completed: !task.isCompleted,
        );
        if (mounted) _applySavedTask(row);
      } catch (error) {
        if (mounted) _showMessage('Completion change was not saved: $error');
      }
      return;
    }

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

  Future<void> _deleteTask(TaskItem task) async {
    if (widget.repository case final repository?) {
      try {
        await repository.deleteTask(task.id);
      } catch (error) {
        if (mounted) _showMessage('Task was not deleted: $error');
        return;
      }
      if (!mounted) return;
    }

    setState(() {
      _tasksByList[task.listId]!.remove(task);
    });
  }

  void _applySavedTask(Map<String, dynamic> row) {
    final savedTask = TaskItem.fromRow(row);
    final tasks = _tasksByList[savedTask.listId];
    if (tasks == null) return;
    setState(() {
      final index = tasks.indexWhere((task) => task.id == savedTask.id);
      if (index >= 0) tasks[index] = savedTask;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingCloudData) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.gold)),
      );
    }

    if (_cloudLoadError != null) {
      return Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.cloud_off,
                    color: AppColors.urgent,
                    size: 40,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Could not load your cloud lists.',
                    style: TextStyle(color: AppColors.gold, fontSize: 20),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Check the connection and confirm the Supabase setup SQL '
                    'has been run for this project.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  SelectableText(
                    _cloudLoadError!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.muted),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () {
                      setState(() {
                        _isLoadingCloudData = true;
                        _cloudLoadError = null;
                      });
                      _loadCloudData(initial: true);
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try again'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final isWide = MediaQuery.sizeOf(context).width >= 720;
    final now = widget.repository?.now ?? DateTime.now();

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
                selectedListId: _selectedListId,
                lists: _lists,
                onListSelected: _selectList,
                onAddList: _addList,
                onRenameList: _renameSelectedList,
                onDeleteList: _deleteSelectedList,
                inDrawer: true,
              ),
            ),
      body: Row(
        children: [
          if (isWide)
            TaskListSidebar(
              selectedListId: _selectedListId,
              lists: _lists,
              onListSelected: _selectList,
              onAddList: _addList,
              onRenameList: _renameSelectedList,
              onDeleteList: _deleteSelectedList,
            ),
          Expanded(
            child: TaskListContent(
              selectedList: _selectedListInfo.name,
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
    required this.selectedListId,
    required this.lists,
    required this.onListSelected,
    required this.onAddList,
    required this.onRenameList,
    required this.onDeleteList,
    this.inDrawer = false,
  });

  final String selectedListId;
  final List<TaskListInfo> lists;
  final ValueChanged<String> onListSelected;
  final VoidCallback onAddList;
  final VoidCallback onRenameList;
  final VoidCallback onDeleteList;
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
                    for (final list in lists)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Material(
                          key: ValueKey(list.id),
                          color: list.id == selectedListId
                              ? const Color(0xFF9C8237)
                              : Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: list.id == selectedListId
                                ? const BorderSide(
                                    color: AppColors.gold,
                                    width: 2,
                                  )
                                : BorderSide.none,
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: ListTile(
                            selected: list.id == selectedListId,
                            selectedTileColor: Colors.transparent,
                            selectedColor: AppColors.background,
                            leading: Icon(
                              list.icon,
                              color: list.id == selectedListId
                                  ? AppColors.background
                                  : AppColors.gold,
                            ),
                            title: Text(
                              list.name,
                              style: TextStyle(
                                color: list.id == selectedListId
                                    ? AppColors.background
                                    : AppColors.white,
                                fontWeight: list.id == selectedListId
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            onTap: () {
                              onListSelected(list.id);
                              if (inDrawer) Navigator.pop(context);
                            },
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              SidebarButton(
                icon: Icons.add,
                label: 'Add list',
                onPressed: onAddList,
              ),
              SidebarButton(
                icon: Icons.edit_outlined,
                label: 'Rename',
                onPressed: onRenameList,
              ),
              SidebarButton(
                icon: Icons.delete_outline,
                label: 'Delete list',
                onPressed: onDeleteList,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SidebarButton extends StatelessWidget {
  const SidebarButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Container(
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
          ),
        ),
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
                            borderSide: const BorderSide(color: AppColors.gold),
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
                      behavior: ScrollConfiguration.of(context)
                          .copyWith(scrollbars: false),
                      child: Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: ListView.separated(
                          itemCount: tasks.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final task = tasks[index];
                            return TaskCard(
                              key: ValueKey(task.id),
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
        border: Border.all(color: priorityColor(task.priority), width: 2),
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
                      decoration: isCompleted
                          ? TextDecoration.lineThrough
                          : null,
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
              constraints: const BoxConstraints.tightFor(width: 40, height: 40),
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
              constraints: const BoxConstraints.tightFor(width: 40, height: 40),
              icon: Icon(
                isCompleted ? Icons.check_box : Icons.check_box_outline_blank,
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
                    icon: const Icon(Icons.close, color: AppColors.urgent),
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
    return SizedBox(width: 40, height: 40, child: Center(child: child));
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
