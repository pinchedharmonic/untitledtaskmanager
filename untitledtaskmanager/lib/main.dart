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
  int order;

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
    this.order = 0,
  });

  final String id;
  final String name;
  final String iconKey;
  final int order;

  factory TaskListInfo.fromRow(Map<String, dynamic> row) => TaskListInfo(
    id: row['id'] as String,
    name: row['name'] as String,
    iconKey: row['icon_key'] as String,
    order: (row['sort_order'] as num).toInt(),
  );

  IconData get icon => _listIconsByKey[iconKey] ?? Icons.list;

  TaskListInfo copyWith({String? name, String? iconKey, int? order}) {
    return TaskListInfo(
      id: id,
      name: name ?? this.name,
      iconKey: iconKey ?? this.iconKey,
      order: order ?? this.order,
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
    TaskListInfo(id: createRecordId(), name: 'Dojo', iconKey: 'karate'),
    TaskListInfo(id: createRecordId(), name: 'Home', iconKey: 'home'),
    TaskListInfo(id: createRecordId(), name: 'Work', iconKey: 'work'),
  ];

  // Each list has its own tasks.
  late final Map<String, List<TaskItem>> _tasksByList = {
    for (final list in _lists) list.id: <TaskItem>[],
  };

  final _taskController = TextEditingController();

  late String _selectedListId = _lists.first.id;
  int _selectedPriority = 3;
  StreamSubscription<void>? _cloudChangesSubscription;
  Timer? _cloudReloadDebounce;
  int _cloudLoadGeneration = 0;
  bool _hasCloudData = false;
  bool _isLoadingCloudData = false;
  String? _cloudLoadError;
  bool _localListsManuallyOrdered = false;
  final Set<String> _localTaskGroupsManuallyOrdered = {};
  List<TaskListInfo>? _pendingListOrder;
  List<TaskItem>? _pendingTaskOrder;
  String? _pendingTaskOrderListId;
  bool _isSavingListOrder = false;
  bool _isSavingTaskOrder = false;

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
        _cloudReloadDebounce?.cancel();
        _cloudReloadDebounce = Timer(
          const Duration(milliseconds: 150),
          () => _loadCloudData(),
        );
      });
      _loadCloudData(initial: true);
    }
  }

  @override
  void dispose() {
    _uiTicker?.cancel();
    _cloudReloadDebounce?.cancel();
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

    // Higher priority tasks go first; each priority group uses its saved order.
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
      final listId = _selectedListId;
      final priority = _selectedPriority;
      final groupKey = '$listId:$priority';
      final group = _tasksByList[listId]!
          .where((task) => task.priority == priority)
          .toList();
      final manuallyOrdered = _localTaskGroupsManuallyOrdered.contains(
        groupKey,
      );
      final newTask = TaskItem(
        id: createRecordId(),
        listId: listId,
        title: title,
        priority: priority,
        order: manuallyOrdered ? group.length : 0,
      );
      group.add(newTask);
      if (!manuallyOrdered) {
        group.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
      }
      for (var index = 0; index < group.length; index++) {
        group[index].order = index;
      }
      _tasksByList[listId]!.add(newTask);

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

  Future<void> _reorderLists(List<TaskListInfo> proposedOrder) async {
    if (_isSavingListOrder) return;
    final currentOrder = _pendingListOrder ?? _lists;
    if (_sameIds(
      currentOrder.map((list) => list.id).toList(),
      proposedOrder.map((list) => list.id).toList(),
    )) {
      return;
    }
    final reordered = List<TaskListInfo>.of(proposedOrder);

    final repository = widget.repository;
    // Keep the dropped order on screen while the cloud confirms it. Without
    // this preview, Flutter redraws the old list during the network request.
    setState(() {
      _pendingListOrder = reordered;
      _isSavingListOrder = repository != null;
    });
    try {
      if (repository != null) {
        await repository.reorderLists(
          reordered.map((list) => list.id).toList(),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _pendingListOrder = null;
          _isSavingListOrder = false;
        });
        _showMessage('List order was not saved: $error');
      }
      return;
    }

    if (repository != null) {
      try {
        // Confirm what Supabase actually returns so an unexpected cloud order
        // is visible instead of silently shuffling the sidebar.
        final confirmedLists = (await repository.loadLists())
            .map(TaskListInfo.fromRow)
            .toList();
        if (!_sameIds(
          reordered.map((list) => list.id).toList(),
          confirmedLists.map((list) => list.id).toList(),
        )) {
          if (mounted) {
            ++_cloudLoadGeneration;
            setState(() {
              _lists
                ..clear()
                ..addAll(confirmedLists);
              _pendingListOrder = null;
              _isSavingListOrder = false;
            });
            _showMessage(
              'Requested: ${reordered.map((list) => list.name).join(' → ')}. '
              'Supabase returned: '
              '${confirmedLists.map((list) => list.name).join(' → ')}.',
            );
          }
          return;
        }
      } catch (error) {
        if (mounted) {
          _showMessage('Order saved, but could not verify it: $error');
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _localListsManuallyOrdered = repository == null;
      _lists
        ..clear()
        ..addAll([
          for (var index = 0; index < reordered.length; index++)
            reordered[index].copyWith(order: index),
        ]);
      _pendingListOrder = null;
      _isSavingListOrder = false;
    });
    if (repository != null) {
      // Ignore any refresh that started before the ordering RPC completed.
      // Realtime sync will refresh the other records after this confirmed save.
      ++_cloudLoadGeneration;
    }
  }

  Future<void> _reorderTasks(List<TaskItem> proposedOrder) async {
    if (_isSavingTaskOrder) return;
    final listId = _selectedListId;
    for (var index = 1; index < proposedOrder.length; index++) {
      if (proposedOrder[index - 1].priority < proposedOrder[index].priority) {
        setState(() {});
        _showMessage('Tasks stay grouped by priority. Drag within a priority.');
        return;
      }
    }

    final currentOrder = _pendingTaskOrderListId == listId
        ? _pendingTaskOrder!
        : _visibleTasks;
    int? changedPriority;
    for (final priority in [5, 4, 3, 2, 1]) {
      final oldIds = currentOrder
          .where((task) => task.priority == priority)
          .map((task) => task.id)
          .toList();
      final newIds = proposedOrder
          .where((task) => task.priority == priority)
          .map((task) => task.id)
          .toList();
      if (!_sameIds(oldIds, newIds)) {
        changedPriority = priority;
        break;
      }
    }
    if (changedPriority == null) return;

    final priority = changedPriority;
    final newGroup = proposedOrder
        .where((task) => task.priority == priority)
        .toList();
    final repository = widget.repository;
    // Keep the drop target visible while Supabase confirms the new order.
    setState(() {
      _pendingTaskOrder = List<TaskItem>.of(proposedOrder);
      _pendingTaskOrderListId = listId;
      _isSavingTaskOrder = repository != null;
    });
    try {
      if (repository != null) {
        await repository.reorderTasks(
          listId: listId,
          priority: priority,
          taskIds: newGroup.map((task) => task.id).toList(),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _pendingTaskOrder = null;
          _pendingTaskOrderListId = null;
          _isSavingTaskOrder = false;
        });
        _showMessage('Task order was not saved: $error');
      }
      return;
    }

    if (!mounted) return;
    setState(() {
      for (var index = 0; index < newGroup.length; index++) {
        final task = _tasksByList[listId]!.firstWhere(
          (current) => current.id == newGroup[index].id,
        );
        task.order = index;
      }
      if (repository == null) {
        _localTaskGroupsManuallyOrdered.add('$listId:$priority');
      }
      _pendingTaskOrder = null;
      _pendingTaskOrderListId = null;
      _isSavingTaskOrder = false;
    });
    if (repository != null) {
      ++_cloudLoadGeneration;
      _loadCloudData();
    }
  }

  static bool _sameIds(List<String> first, List<String> second) {
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) return false;
    }
    return true;
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
      if (widget.repository != null) {
        _lists.sort((a, b) => a.order.compareTo(b.order));
      } else if (!_localListsManuallyOrdered) {
        _lists.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
        for (var index = 0; index < _lists.length; index++) {
          final list = _lists[index];
          _lists[index] = list.copyWith(order: index);
        }
      }
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
      if (widget.repository != null) {
        _lists.sort((a, b) => a.order.compareTo(b.order));
      } else if (!_localListsManuallyOrdered) {
        _lists.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
        for (var listIndex = 0; listIndex < _lists.length; listIndex++) {
          _lists[listIndex] = _lists[listIndex].copyWith(order: listIndex);
        }
      }
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
                lists: _pendingListOrder ?? _lists,
                onListSelected: _selectList,
                onAddList: _addList,
                onRenameList: _renameSelectedList,
                onDeleteList: _deleteSelectedList,
                onReorder: _reorderLists,
                inDrawer: true,
              ),
            ),
      body: Row(
        children: [
          if (isWide)
            TaskListSidebar(
              selectedListId: _selectedListId,
              lists: _pendingListOrder ?? _lists,
              onListSelected: _selectList,
              onAddList: _addList,
              onRenameList: _renameSelectedList,
              onDeleteList: _deleteSelectedList,
              onReorder: _reorderLists,
            ),
          Expanded(
            child: TaskListContent(
              selectedList: _selectedListInfo.name,
              tasks: _pendingTaskOrderListId == _selectedListId
                  ? _pendingTaskOrder!
                  : _visibleTasks,
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
              onReorderTasks: _reorderTasks,
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
    required this.onReorder,
    this.inDrawer = false,
  });

  final String selectedListId;
  final List<TaskListInfo> lists;
  final ValueChanged<String> onListSelected;
  final VoidCallback onAddList;
  final VoidCallback onRenameList;
  final VoidCallback onDeleteList;
  final ValueChanged<List<TaskListInfo>> onReorder;
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
                child: ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context)
                      .copyWith(scrollbars: false),
                  child: ReorderableListView.builder(
                    padding: EdgeInsets.zero,
                    buildDefaultDragHandles: false,
                    itemCount: lists.length,
                    onReorderItem: (oldIndex, newIndex) {
                      // Build the proposed order from the same list currently
                      // shown by the sidebar, matching the task reorder path.
                      final reordered = List<TaskListInfo>.of(lists);
                      final movedList = reordered.removeAt(oldIndex);
                      reordered.insert(newIndex, movedList);
                      onReorder(reordered);
                    },
                    itemBuilder: (context, index) {
                      final list = lists[index];
                      return Padding(
                        key: ValueKey(list.id),
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Material(
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
                            trailing: ReorderableDragStartListener(
                              index: index,
                              child: Tooltip(
                                message: 'Drag to reorder lists',
                                child: Icon(
                                  Icons.drag_handle,
                                  color: list.id == selectedListId
                                      ? AppColors.background
                                      : AppColors.muted,
                                ),
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
                      );
                    },
                  ),
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
    required this.onReorderTasks,
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
  final ValueChanged<List<TaskItem>> onReorderTasks;

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
                        child: ReorderableListView.builder(
                          padding: EdgeInsets.zero,
                          buildDefaultDragHandles: false,
                          itemCount: tasks.length,
                          onReorderItem: (oldIndex, newIndex) {
                            final reordered = List<TaskItem>.of(tasks);
                            final movedTask = reordered.removeAt(oldIndex);
                            reordered.insert(newIndex, movedTask);
                            onReorderTasks(reordered);
                          },
                          itemBuilder: (context, index) {
                            final task = tasks[index];
                            return Padding(
                              key: ValueKey(task.id),
                              padding: const EdgeInsets.only(bottom: 10),
                              child: TaskCard(
                                task: task,
                                reorderIndex: index,
                                now: now,
                                urgentVisible: urgentVisible,
                                onToggleTimer: () => onToggleTimer(task),
                                onToggleCompleted: () =>
                                    onToggleCompleted(task),
                                onDelete: () => onDeleteTask(task),
                              ),
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
    required this.reorderIndex,
    required this.now,
    required this.urgentVisible,
    required this.onToggleTimer,
    required this.onToggleCompleted,
    required this.onDelete,
  });

  final TaskItem task;
  final int reorderIndex;
  final DateTime now;
  final bool urgentVisible;
  final VoidCallback onToggleTimer;
  final VoidCallback onToggleCompleted;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isCompleted = task.isCompleted;
    final useCompactLayout =
        Theme.of(context).platform == TargetPlatform.android ||
        MediaQuery.sizeOf(context).width < 600;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isCompleted ? const Color(0xFF292929) : AppColors.card,
        border: Border.all(color: priorityColor(task.priority), width: 2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: useCompactLayout
          ? _buildCompactLayout(isCompleted)
          : _buildWideLayout(isCompleted),
    );
  }

  Widget _buildWideLayout(bool isCompleted) {
    return Row(
      children: [
        Tooltip(
          message: 'Drag to reorder within this priority',
          child: ReorderableDragStartListener(
            index: reorderIndex,
            child: const SizedBox(
              width: 30,
              height: 40,
              child: Icon(Icons.drag_indicator, color: AppColors.muted),
            ),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Row(
            children: [
              Expanded(child: _buildTaskTitle(isCompleted, maxLines: 1)),
              if (task.priority == 5 && !isCompleted)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: _buildUrgentLabel(),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
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
        _buildWideControls(isCompleted),
      ],
    );
  }

  Widget _buildCompactLayout(bool isCompleted) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Tooltip(
              message: 'Drag to reorder within this priority',
              child: ReorderableDragStartListener(
                index: reorderIndex,
                child: const SizedBox(
                  width: 30,
                  height: 36,
                  child: Icon(Icons.drag_indicator, color: AppColors.muted),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(child: _buildTaskTitle(isCompleted)),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (task.priority == 5 && !isCompleted) _buildUrgentLabel(),
            const SizedBox(width: 8),
            SizedBox(
              width: 72,
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  _formatDuration(task.elapsedAt(now)),
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ),
            ),
            const SizedBox(width: 4),
            _buildCompactControls(isCompleted),
          ],
        ),
      ],
    );
  }

  Widget _buildTaskTitle(bool isCompleted, {int? maxLines}) {
    return Text(
      task.title,
      maxLines: maxLines,
      overflow: maxLines == null ? null : TextOverflow.ellipsis,
      style: TextStyle(
        color: isCompleted ? AppColors.muted : AppColors.white,
        fontSize: 16,
        decoration: isCompleted ? TextDecoration.lineThrough : null,
      ),
    );
  }

  Widget _buildUrgentLabel() {
    return Opacity(
      opacity: urgentVisible ? 1 : 0,
      child: const Text(
        'URGENT',
        style: TextStyle(color: AppColors.urgent, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildWideControls(bool isCompleted) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
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
    );
  }

  Widget _buildCompactControls(bool isCompleted) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CompactControlSlot(
          child: IconButton(
            tooltip: task.isRunning ? 'Pause timer' : 'Start or resume timer',
            onPressed: isCompleted ? null : onToggleTimer,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 36, height: 36),
            icon: Icon(
              task.isRunning ? Icons.pause : Icons.play_arrow,
              color: isCompleted ? AppColors.muted : AppColors.gold,
            ),
          ),
        ),
        _CompactControlSlot(
          child: IconButton(
            tooltip: isCompleted ? 'Mark task incomplete' : 'Complete task',
            onPressed: onToggleCompleted,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 36, height: 36),
            icon: Icon(
              isCompleted ? Icons.check_box : Icons.check_box_outline_blank,
              color: AppColors.gold,
            ),
          ),
        ),
        _CompactControlSlot(
          child: isCompleted
              ? IconButton(
                  tooltip: 'Remove task',
                  onPressed: onDelete,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 36,
                    height: 36,
                  ),
                  icon: const Icon(Icons.close, color: AppColors.urgent),
                )
              : const SizedBox(width: 36, height: 36),
        ),
      ],
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

class _CompactControlSlot extends StatelessWidget {
  const _CompactControlSlot({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: 36, height: 36, child: Center(child: child));
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
