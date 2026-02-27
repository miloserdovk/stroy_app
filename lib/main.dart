import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import 'models.dart';

const String _defaultManagerId = 'u-manager-1';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

Future<bool> _initializeFirebaseSafely() async {
  if (const bool.fromEnvironment('FLUTTER_TEST')) {
    return false;
  }

  try {
    await Firebase.initializeApp().timeout(const Duration(seconds: 5));
    return true;
  } on Object {
    return false;
  }
}

final inventoryControllerProvider =
    StateNotifierProvider<InventoryController, InventoryState>(
  (ref) => InventoryController(),
);

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final Future<bool> _firebaseInitFuture = _initializeFirebaseSafely();

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp(
        title: 'StroyApp',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: Colors.orange,
          cardTheme: const CardTheme(
            elevation: 0,
            margin: EdgeInsets.zero,
          ),
        ),
        home: AppBootstrap(firebaseInitFuture: _firebaseInitFuture),
      ),
    );
  }
}

class AppBootstrap extends StatelessWidget {
  const AppBootstrap({
    super.key,
    required this.firebaseInitFuture,
  });

  final Future<bool> firebaseInitFuture;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: firebaseInitFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return InventoryHomeScreen(
          firebaseReady: snapshot.data ?? false,
        );
      },
    );
  }
}

class InventoryHomeScreen extends StatelessWidget {
  const InventoryHomeScreen({
    super.key,
    required this.firebaseReady,
  });

  final bool firebaseReady;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('StroyApp Inventory'),
          actions: [
            if (!firebaseReady)
              const Padding(
                padding: EdgeInsets.only(right: 16),
                child: Tooltip(
                  message: 'Firebase is not configured. Local mode is enabled.',
                  child: Icon(Icons.cloud_off_outlined),
                ),
              ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(
                icon: Icon(Icons.inventory_2_outlined),
                text: 'Inventory',
              ),
              Tab(
                icon: Icon(Icons.receipt_long_outlined),
                text: 'Log',
              ),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            InventoryTab(),
            TransactionsTab(),
          ],
        ),
      ),
    );
  }
}

class InventoryTab extends ConsumerWidget {
  const InventoryTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(inventoryControllerProvider);
    final notifier = ref.read(inventoryControllerProvider.notifier);
    final items = state.filteredItems;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            onChanged: notifier.updateSearchQuery,
            decoration: const InputDecoration(
              labelText: 'Search by name or ID',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<ItemCategory?>(
                  value: state.categoryFilter,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<ItemCategory?>(
                      value: null,
                      child: Text('All categories'),
                    ),
                    ...ItemCategory.values.map(
                      (category) => DropdownMenuItem<ItemCategory?>(
                        value: category,
                        child: Text(_categoryLabel(category)),
                      ),
                    ),
                  ],
                  onChanged: notifier.updateCategoryFilter,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<ItemCondition?>(
                  value: state.conditionFilter,
                  decoration: const InputDecoration(
                    labelText: 'Condition',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<ItemCondition?>(
                      value: null,
                      child: Text('All conditions'),
                    ),
                    ...ItemCondition.values.map(
                      (condition) => DropdownMenuItem<ItemCondition?>(
                        value: condition,
                        child: Text(_conditionLabel(condition)),
                      ),
                    ),
                  ],
                  onChanged: notifier.updateConditionFilter,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          InventorySummary(state: state),
          const SizedBox(height: 12),
          Expanded(
            child: items.isEmpty
                ? const Center(
                    child: Text('No items found with current filters.'),
                  )
                : ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final holderName = item.holderId == null
                          ? null
                          : state.usersById[item.holderId!]?.name ??
                              item.holderId!;

                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      item.name,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ),
                                  StatusChip(isAssigned: item.holderId != null),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text('ID: ${item.id}'),
                              Text('Site: ${_siteLabel(item.siteId)}'),
                              Text('Category: ${_categoryLabel(item.category)}'),
                              Text(
                                'Condition: ${_conditionLabel(item.condition)}',
                              ),
                              if (holderName != null) Text('Holder: $holderName'),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerRight,
                                child: item.holderId == null
                                    ? FilledButton.tonal(
                                        onPressed: state.workers.isEmpty
                                            ? null
                                            : () => _showCheckoutDialog(
                                                  context: context,
                                                  ref: ref,
                                                  item: item,
                                                  workers: state.workers,
                                                ),
                                        child: const Text('Check out'),
                                      )
                                    : OutlinedButton(
                                        onPressed: () => _showReturnDialog(
                                          context: context,
                                          ref: ref,
                                          item: item,
                                        ),
                                        child: const Text('Return'),
                                      ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class InventorySummary extends StatelessWidget {
  const InventorySummary({
    super.key,
    required this.state,
  });

  final InventoryState state;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 700;
        final cardWidth =
            isCompact ? constraints.maxWidth : (constraints.maxWidth - 24) / 4;

        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            SizedBox(
              width: cardWidth,
              child: SummaryCard(
                label: 'Total',
                value: state.totalItems.toString(),
                color: Colors.blue,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: SummaryCard(
                label: 'Available',
                value: state.availableItems.toString(),
                color: Colors.green,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: SummaryCard(
                label: 'Checked out',
                value: state.checkedOutItems.toString(),
                color: Colors.orange,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: SummaryCard(
                label: 'Needs service',
                value: state.needsServiceItems.toString(),
                color: Colors.red,
              ),
            ),
          ],
        );
      },
    );
  }
}

class SummaryCard extends StatelessWidget {
  const SummaryCard({
    super.key,
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.isAssigned,
  });

  final bool isAssigned;

  @override
  Widget build(BuildContext context) {
    final color = isAssigned ? Colors.orange : Colors.green;
    final text = isAssigned ? 'Assigned' : 'Available';

    return Chip(
      label: Text(text),
      side: BorderSide(color: color.withOpacity(0.3)),
      backgroundColor: color.withOpacity(0.1),
      labelStyle: TextStyle(color: color.shade700),
      visualDensity: VisualDensity.compact,
    );
  }
}

class TransactionsTab extends ConsumerWidget {
  const TransactionsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(inventoryControllerProvider);
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');
    final itemById = <String, InventoryItem>{
      for (final item in state.items) item.id: item,
    };

    if (state.transactions.isEmpty) {
      return const Center(
        child: Text('No operations yet.'),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: state.transactions.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final transaction = state.transactions[index];
        final itemName = itemById[transaction.itemId]?.name ?? transaction.itemId;
        final actorName = state.usersById[transaction.userId]?.name ??
            transaction.userId;

        return Card(
          child: ListTile(
            leading: Icon(
              _transactionIcon(transaction.type),
              color: _transactionColor(transaction.type),
            ),
            title: Text('${_transactionLabel(transaction.type)}: $itemName'),
            subtitle: Text(
              '$actorName | ${dateFormat.format(transaction.timestamp)}',
            ),
            trailing: Text(_conditionLabel(transaction.condition)),
          ),
        );
      },
    );
  }
}

Future<void> _showCheckoutDialog({
  required BuildContext context,
  required WidgetRef ref,
  required InventoryItem item,
  required List<AppUser> workers,
}) async {
  var selectedWorkerId = workers.first.id;

  final pickedWorker = await showDialog<String>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('Check out: ${item.name}'),
            content: DropdownButtonFormField<String>(
              value: selectedWorkerId,
              decoration: const InputDecoration(
                labelText: 'Worker',
                border: OutlineInputBorder(),
              ),
              items: workers
                  .map(
                    (worker) => DropdownMenuItem<String>(
                      value: worker.id,
                      child: Text(worker.name),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    selectedWorkerId = value;
                  });
                }
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(selectedWorkerId),
                child: const Text('Confirm'),
              ),
            ],
          );
        },
      );
    },
  );

  if (pickedWorker == null) {
    return;
  }

  ref.read(inventoryControllerProvider.notifier).checkOutItem(
        itemId: item.id,
        workerId: pickedWorker,
      );
}

Future<void> _showReturnDialog({
  required BuildContext context,
  required WidgetRef ref,
  required InventoryItem item,
}) async {
  var selectedCondition = item.condition;

  final pickedCondition = await showDialog<ItemCondition>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('Return: ${item.name}'),
            content: DropdownButtonFormField<ItemCondition>(
              value: selectedCondition,
              decoration: const InputDecoration(
                labelText: 'Condition',
                border: OutlineInputBorder(),
              ),
              items: ItemCondition.values
                  .map(
                    (condition) => DropdownMenuItem<ItemCondition>(
                      value: condition,
                      child: Text(_conditionLabel(condition)),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    selectedCondition = value;
                  });
                }
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(selectedCondition),
                child: const Text('Confirm'),
              ),
            ],
          );
        },
      );
    },
  );

  if (pickedCondition == null) {
    return;
  }

  ref.read(inventoryControllerProvider.notifier).returnItem(
        itemId: item.id,
        condition: pickedCondition,
        processedBy: _defaultManagerId,
      );
}

class InventoryState {
  const InventoryState({
    required this.users,
    required this.items,
    required this.transactions,
    this.searchQuery = '',
    this.categoryFilter,
    this.conditionFilter,
  });

  static const Object _unset = Object();

  final List<AppUser> users;
  final List<InventoryItem> items;
  final List<InventoryTransaction> transactions;
  final String searchQuery;
  final ItemCategory? categoryFilter;
  final ItemCondition? conditionFilter;

  factory InventoryState.initial() {
    final now = DateTime.now();

    final users = <AppUser>[
      AppUser(
        id: _defaultManagerId,
        employeeId: 'M-001',
        name: 'Ivan Petrov',
        jobTitle: 'Warehouse Manager',
        role: UserRole.manager,
      ),
      AppUser(
        id: 'u-worker-1',
        employeeId: 'W-014',
        name: 'Aleksei Smirnov',
        jobTitle: 'Electrician',
        role: UserRole.worker,
      ),
      AppUser(
        id: 'u-worker-2',
        employeeId: 'W-027',
        name: 'Nikolai Sokolov',
        jobTitle: 'Foreman',
        role: UserRole.worker,
      ),
    ];

    final items = <InventoryItem>[
      InventoryItem(
        id: 'itm-001',
        name: 'Hammer Drill Makita HR2470',
        siteId: 'wh-a',
        category: ItemCategory.tool,
        condition: ItemCondition.good,
      ),
      InventoryItem(
        id: 'itm-002',
        name: 'Laser Level Bosch GLL 3-80',
        siteId: 'site-17',
        holderId: 'u-worker-2',
        category: ItemCategory.tool,
        condition: ItemCondition.good,
      ),
      InventoryItem(
        id: 'itm-003',
        name: 'Cement Mix M500 (40 bags)',
        siteId: 'wh-a',
        category: ItemCategory.material,
        condition: ItemCondition.newOne,
      ),
      InventoryItem(
        id: 'itm-004',
        name: 'Portable Generator 6kW',
        siteId: 'site-19',
        category: ItemCategory.tool,
        condition: ItemCondition.worn,
      ),
      InventoryItem(
        id: 'itm-005',
        name: 'Steel Rebar A500 (bundle)',
        siteId: 'site-17',
        category: ItemCategory.material,
        condition: ItemCondition.good,
      ),
    ];

    final transactions = <InventoryTransaction>[
      InventoryTransaction(
        id: 'tx-001',
        itemId: 'itm-002',
        type: TransactionType.checkOut,
        status: TransactionStatus.completed,
        timestamp: now.subtract(const Duration(hours: 7)),
        userId: 'u-worker-2',
        condition: ItemCondition.good,
      ),
      InventoryTransaction(
        id: 'tx-002',
        itemId: 'itm-004',
        type: TransactionType.checkIn,
        status: TransactionStatus.completed,
        timestamp: now.subtract(const Duration(days: 1, hours: 3)),
        userId: _defaultManagerId,
        condition: ItemCondition.worn,
      ),
    ];

    return InventoryState(
      users: users,
      items: items,
      transactions: transactions,
    );
  }

  Map<String, AppUser> get usersById => {
        for (final user in users) user.id: user,
      };

  List<AppUser> get workers => users
      .where((user) => user.role == UserRole.worker)
      .toList(growable: false);

  int get totalItems => items.length;

  int get availableItems =>
      items.where((item) => item.holderId == null).length;

  int get checkedOutItems => totalItems - availableItems;

  int get needsServiceItems => items
      .where(
        (item) =>
            item.condition == ItemCondition.worn ||
            item.condition == ItemCondition.damaged ||
            item.condition == ItemCondition.broken,
      )
      .length;

  List<InventoryItem> get filteredItems {
    final needle = searchQuery.trim().toLowerCase();

    return items.where((item) {
      final matchSearch = needle.isEmpty ||
          item.name.toLowerCase().contains(needle) ||
          item.id.toLowerCase().contains(needle);
      final matchCategory =
          categoryFilter == null || item.category == categoryFilter;
      final matchCondition =
          conditionFilter == null || item.condition == conditionFilter;

      return matchSearch && matchCategory && matchCondition;
    }).toList(growable: false);
  }

  InventoryState copyWith({
    List<AppUser>? users,
    List<InventoryItem>? items,
    List<InventoryTransaction>? transactions,
    String? searchQuery,
    Object? categoryFilter = _unset,
    Object? conditionFilter = _unset,
  }) {
    return InventoryState(
      users: users ?? this.users,
      items: items ?? this.items,
      transactions: transactions ?? this.transactions,
      searchQuery: searchQuery ?? this.searchQuery,
      categoryFilter: identical(categoryFilter, _unset)
          ? this.categoryFilter
          : categoryFilter as ItemCategory?,
      conditionFilter: identical(conditionFilter, _unset)
          ? this.conditionFilter
          : conditionFilter as ItemCondition?,
    );
  }
}

class InventoryController extends StateNotifier<InventoryState> {
  InventoryController() : super(InventoryState.initial());

  final Uuid _uuid = const Uuid();

  void updateSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void updateCategoryFilter(ItemCategory? value) {
    state = state.copyWith(categoryFilter: value);
  }

  void updateConditionFilter(ItemCondition? value) {
    state = state.copyWith(conditionFilter: value);
  }

  void checkOutItem({
    required String itemId,
    required String workerId,
  }) {
    final index = state.items.indexWhere((item) => item.id == itemId);
    if (index < 0) {
      return;
    }

    final item = state.items[index];
    if (item.holderId != null) {
      return;
    }

    final updatedItems = List<InventoryItem>.from(state.items);
    updatedItems[index] = InventoryItem(
      id: item.id,
      name: item.name,
      siteId: item.siteId,
      holderId: workerId,
      category: item.category,
      condition: item.condition,
    );

    final transaction = InventoryTransaction(
      id: _uuid.v4(),
      itemId: itemId,
      type: TransactionType.checkOut,
      status: TransactionStatus.completed,
      timestamp: DateTime.now(),
      userId: workerId,
      condition: item.condition,
    );

    state = state.copyWith(
      items: updatedItems,
      transactions: [transaction, ...state.transactions],
    );
  }

  void returnItem({
    required String itemId,
    required ItemCondition condition,
    required String processedBy,
  }) {
    final index = state.items.indexWhere((item) => item.id == itemId);
    if (index < 0) {
      return;
    }

    final item = state.items[index];
    final currentHolder = item.holderId;
    if (currentHolder == null) {
      return;
    }

    final updatedItems = List<InventoryItem>.from(state.items);
    updatedItems[index] = InventoryItem(
      id: item.id,
      name: item.name,
      siteId: item.siteId,
      category: item.category,
      condition: condition,
    );

    final transaction = InventoryTransaction(
      id: _uuid.v4(),
      itemId: item.id,
      type: TransactionType.turnIn,
      status: TransactionStatus.completed,
      timestamp: DateTime.now(),
      userId: processedBy,
      targetUserId: currentHolder,
      condition: condition,
    );

    state = state.copyWith(
      items: updatedItems,
      transactions: [transaction, ...state.transactions],
    );
  }
}

String _categoryLabel(ItemCategory category) {
  switch (category) {
    case ItemCategory.material:
      return 'Material';
    case ItemCategory.tool:
      return 'Tool';
  }
}

String _conditionLabel(ItemCondition condition) {
  switch (condition) {
    case ItemCondition.newOne:
      return 'New';
    case ItemCondition.good:
      return 'Good';
    case ItemCondition.worn:
      return 'Worn';
    case ItemCondition.damaged:
      return 'Damaged';
    case ItemCondition.broken:
      return 'Broken';
  }
}

String _siteLabel(String siteId) {
  switch (siteId) {
    case 'wh-a':
      return 'Warehouse A';
    case 'site-17':
      return 'Construction Site 17';
    case 'site-19':
      return 'Construction Site 19';
    default:
      return siteId;
  }
}

String _transactionLabel(TransactionType type) {
  switch (type) {
    case TransactionType.checkIn:
      return 'Check in';
    case TransactionType.checkOut:
      return 'Check out';
    case TransactionType.transfer:
      return 'Transfer';
    case TransactionType.assign:
      return 'Assign';
    case TransactionType.turnIn:
      return 'Turn in';
  }
}

IconData _transactionIcon(TransactionType type) {
  switch (type) {
    case TransactionType.checkIn:
      return Icons.keyboard_return_outlined;
    case TransactionType.checkOut:
      return Icons.open_in_new_outlined;
    case TransactionType.transfer:
      return Icons.compare_arrows_outlined;
    case TransactionType.assign:
      return Icons.assignment_ind_outlined;
    case TransactionType.turnIn:
      return Icons.task_alt_outlined;
  }
}

Color _transactionColor(TransactionType type) {
  switch (type) {
    case TransactionType.checkIn:
      return Colors.green;
    case TransactionType.checkOut:
      return Colors.orange;
    case TransactionType.transfer:
      return Colors.blue;
    case TransactionType.assign:
      return Colors.purple;
    case TransactionType.turnIn:
      return Colors.teal;
  }
}

