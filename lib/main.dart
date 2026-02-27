import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import 'models.dart';

const String _defaultManagerId = 'u-manager-1';
const List<String> _knownSiteIds = ['wh-a', 'site-17', 'site-19'];
enum _InventoryItemMenuAction { edit, delete }

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
          cardTheme: const CardThemeData(
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
          LayoutBuilder(
            builder: (context, constraints) {
              final singleColumn = constraints.maxWidth < 720;
              final fieldWidth = singleColumn
                  ? constraints.maxWidth
                  : (constraints.maxWidth - 24) / 3;

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: fieldWidth,
                    child: DropdownButtonFormField<ItemCategory?>(
                      isExpanded: true,
                      initialValue: state.categoryFilter,
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
                  SizedBox(
                    width: fieldWidth,
                    child: DropdownButtonFormField<ItemCondition?>(
                      isExpanded: true,
                      initialValue: state.conditionFilter,
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
                  SizedBox(
                    width: fieldWidth,
                    child: DropdownButtonFormField<String?>(
                      isExpanded: true,
                      initialValue: state.siteFilter,
                      decoration: const InputDecoration(
                        labelText: 'Site',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('All sites'),
                        ),
                        ...state.siteIds.map(
                          (siteId) => DropdownMenuItem<String?>(
                            value: siteId,
                            child: Text(_siteLabel(siteId)),
                          ),
                        ),
                      ],
                      onChanged: notifier.updateSiteFilter,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: () => _showAddItemDialog(
                context: context,
                ref: ref,
                siteIds: state.siteIds,
              ),
              icon: const Icon(Icons.add),
              label: const Text('Add item'),
            ),
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
                                  PopupMenuButton<_InventoryItemMenuAction>(
                                    onSelected: (action) {
                                      switch (action) {
                                        case _InventoryItemMenuAction.edit:
                                          _showEditItemDialog(
                                            context: context,
                                            ref: ref,
                                            item: item,
                                            siteIds: state.siteIds,
                                          );
                                          break;
                                        case _InventoryItemMenuAction.delete:
                                          _showDeleteItemDialog(
                                            context: context,
                                            ref: ref,
                                            item: item,
                                          );
                                          break;
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem<
                                          _InventoryItemMenuAction>(
                                        value: _InventoryItemMenuAction.edit,
                                        child: Text('Edit'),
                                      ),
                                      if (item.holderId == null)
                                        const PopupMenuItem<
                                            _InventoryItemMenuAction>(
                                          value:
                                              _InventoryItemMenuAction.delete,
                                          child: Text('Delete'),
                                        ),
                                    ],
                                  ),
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
                                    ? Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        alignment: WrapAlignment.end,
                                        children: [
                                          FilledButton.tonal(
                                            onPressed: state.workers.isEmpty
                                                ? null
                                                : () => _showCheckoutDialog(
                                                      context: context,
                                                      ref: ref,
                                                      item: item,
                                                      workers: state.workers,
                                                    ),
                                            child: const Text('Check out'),
                                          ),
                                          OutlinedButton.icon(
                                            onPressed: state.siteIds.length < 2
                                                ? null
                                                : () => _showTransferDialog(
                                                      context: context,
                                                      ref: ref,
                                                      item: item,
                                                      siteIds: state.siteIds,
                                                    ),
                                            icon: const Icon(Icons.swap_horiz),
                                            label: const Text('Transfer'),
                                          ),
                                        ],
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
      side: BorderSide(color: color.withValues(alpha: 0.3)),
      backgroundColor: color.withValues(alpha: 0.1),
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
    final notifier = ref.read(inventoryControllerProvider.notifier);
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');
    final itemById = <String, InventoryItem>{
      for (final item in state.items) item.id: item,
    };

    if (state.transactions.isEmpty) {
      return const Center(
        child: Text('No operations yet.'),
      );
    }

    final transactions = state.filteredTransactions;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          DropdownButtonFormField<TransactionType?>(
            isExpanded: true,
            initialValue: state.transactionTypeFilter,
            decoration: const InputDecoration(
              labelText: 'Operation type',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem<TransactionType?>(
                value: null,
                child: Text('All operations'),
              ),
              ...TransactionType.values.map(
                (type) => DropdownMenuItem<TransactionType?>(
                  value: type,
                  child: Text(_transactionLabel(type)),
                ),
              ),
            ],
            onChanged: notifier.updateTransactionTypeFilter,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: transactions.isEmpty
                ? const Center(
                    child: Text('No operations found for selected filter.'),
                  )
                : ListView.separated(
                    itemCount: transactions.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final transaction = transactions[index];
                      final itemName =
                          itemById[transaction.itemId]?.name ?? transaction.itemId;
                      final actorName = state.usersById[transaction.userId]?.name ??
                          transaction.userId;
                      final details = _transactionDetails(transaction);

                      return Card(
                        child: ListTile(
                          leading: Icon(
                            _transactionIcon(transaction.type),
                            color: _transactionColor(transaction.type),
                          ),
                          title:
                              Text('${_transactionLabel(transaction.type)}: $itemName'),
                          subtitle: Text(
                            details == null
                                ? '$actorName | ${dateFormat.format(transaction.timestamp)}'
                                : '$actorName | ${dateFormat.format(transaction.timestamp)}\n$details',
                          ),
                          isThreeLine: details != null,
                          trailing: Text(_conditionLabel(transaction.condition)),
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
              isExpanded: true,
              initialValue: selectedWorkerId,
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
              isExpanded: true,
              initialValue: selectedCondition,
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

Future<void> _showTransferDialog({
  required BuildContext context,
  required WidgetRef ref,
  required InventoryItem item,
  required List<String> siteIds,
}) async {
  final targetSiteIds =
      siteIds.where((siteId) => siteId != item.siteId).toList(growable: false);
  if (targetSiteIds.isEmpty) {
    return;
  }

  var selectedSiteId = targetSiteIds.first;

  final pickedSite = await showDialog<String>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('Transfer: ${item.name}'),
            content: DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: selectedSiteId,
              decoration: const InputDecoration(
                labelText: 'Target site',
                border: OutlineInputBorder(),
              ),
              items: targetSiteIds
                  .map(
                    (siteId) => DropdownMenuItem<String>(
                      value: siteId,
                      child: Text(_siteLabel(siteId)),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    selectedSiteId = value;
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
                onPressed: () => Navigator.of(context).pop(selectedSiteId),
                child: const Text('Confirm'),
              ),
            ],
          );
        },
      );
    },
  );

  if (pickedSite == null) {
    return;
  }

  ref.read(inventoryControllerProvider.notifier).transferItem(
        itemId: item.id,
        targetSiteId: pickedSite,
        processedBy: _defaultManagerId,
      );
}

Future<void> _showAddItemDialog({
  required BuildContext context,
  required WidgetRef ref,
  required List<String> siteIds,
}) async {
  final nameController = TextEditingController();
  var selectedCategory = ItemCategory.tool;
  var selectedCondition = ItemCondition.newOne;
  var selectedSiteId = siteIds.isEmpty ? _knownSiteIds.first : siteIds.first;
  var shouldShowValidation = false;

  final result = await showDialog<_AddItemInput>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Add inventory item'),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'Name',
                        border: const OutlineInputBorder(),
                        errorText: shouldShowValidation &&
                                nameController.text.trim().isEmpty
                            ? 'Name is required'
                            : null,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<ItemCategory>(
                      isExpanded: true,
                      initialValue: selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                      ),
                      items: ItemCategory.values
                          .map(
                            (category) => DropdownMenuItem<ItemCategory>(
                              value: category,
                              child: Text(_categoryLabel(category)),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            selectedCategory = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<ItemCondition>(
                      isExpanded: true,
                      initialValue: selectedCondition,
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
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: selectedSiteId,
                      decoration: const InputDecoration(
                        labelText: 'Site',
                        border: OutlineInputBorder(),
                      ),
                      items: _knownSiteIds
                          .map(
                            (siteId) => DropdownMenuItem<String>(
                              value: siteId,
                              child: Text(_siteLabel(siteId)),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            selectedSiteId = value;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final itemName = nameController.text.trim();
                  if (itemName.isEmpty) {
                    setState(() {
                      shouldShowValidation = true;
                    });
                    return;
                  }

                  Navigator.of(context).pop(
                    _AddItemInput(
                      name: itemName,
                      category: selectedCategory,
                      condition: selectedCondition,
                      siteId: selectedSiteId,
                    ),
                  );
                },
                child: const Text('Add'),
              ),
            ],
          );
        },
      );
    },
  );

  nameController.dispose();

  if (result == null) {
    return;
  }

  ref.read(inventoryControllerProvider.notifier).addItem(
        name: result.name,
        category: result.category,
        condition: result.condition,
        siteId: result.siteId,
        processedBy: _defaultManagerId,
      );
}

Future<void> _showEditItemDialog({
  required BuildContext context,
  required WidgetRef ref,
  required InventoryItem item,
  required List<String> siteIds,
}) async {
  final nameController = TextEditingController(text: item.name);
  var selectedCategory = item.category;
  var selectedCondition = item.condition;
  var selectedSiteId = item.siteId;
  var shouldShowValidation = false;
  final canChangeSite = item.holderId == null;

  final result = await showDialog<_EditItemInput>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('Edit item: ${item.id}'),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'Name',
                        border: const OutlineInputBorder(),
                        errorText: shouldShowValidation &&
                                nameController.text.trim().isEmpty
                            ? 'Name is required'
                            : null,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<ItemCategory>(
                      isExpanded: true,
                      initialValue: selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                      ),
                      items: ItemCategory.values
                          .map(
                            (category) => DropdownMenuItem<ItemCategory>(
                              value: category,
                              child: Text(_categoryLabel(category)),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            selectedCategory = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<ItemCondition>(
                      isExpanded: true,
                      initialValue: selectedCondition,
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
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: selectedSiteId,
                      decoration: const InputDecoration(
                        labelText: 'Site',
                        border: OutlineInputBorder(),
                      ),
                      items: siteIds
                          .map(
                            (siteId) => DropdownMenuItem<String>(
                              value: siteId,
                              child: Text(_siteLabel(siteId)),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: canChangeSite
                          ? (value) {
                              if (value != null) {
                                setState(() {
                                  selectedSiteId = value;
                                });
                              }
                            }
                          : null,
                    ),
                    if (!canChangeSite)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Site cannot be changed while item is assigned.',
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final itemName = nameController.text.trim();
                  if (itemName.isEmpty) {
                    setState(() {
                      shouldShowValidation = true;
                    });
                    return;
                  }

                  Navigator.of(context).pop(
                    _EditItemInput(
                      name: itemName,
                      category: selectedCategory,
                      condition: selectedCondition,
                      siteId: selectedSiteId,
                    ),
                  );
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      );
    },
  );

  nameController.dispose();

  if (result == null) {
    return;
  }

  ref.read(inventoryControllerProvider.notifier).editItem(
        itemId: item.id,
        name: result.name,
        category: result.category,
        condition: result.condition,
        siteId: result.siteId,
        processedBy: _defaultManagerId,
      );
}

Future<void> _showDeleteItemDialog({
  required BuildContext context,
  required WidgetRef ref,
  required InventoryItem item,
}) async {
  final confirm = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Delete item'),
        content: Text('Delete "${item.name}" (${item.id})?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      );
    },
  );

  if (confirm != true) {
    return;
  }

  ref.read(inventoryControllerProvider.notifier).deleteItem(itemId: item.id);
}

class _AddItemInput {
  const _AddItemInput({
    required this.name,
    required this.category,
    required this.condition,
    required this.siteId,
  });

  final String name;
  final ItemCategory category;
  final ItemCondition condition;
  final String siteId;
}

class _EditItemInput {
  const _EditItemInput({
    required this.name,
    required this.category,
    required this.condition,
    required this.siteId,
  });

  final String name;
  final ItemCategory category;
  final ItemCondition condition;
  final String siteId;
}

class InventoryState {
  const InventoryState({
    required this.users,
    required this.items,
    required this.transactions,
    this.searchQuery = '',
    this.categoryFilter,
    this.conditionFilter,
    this.siteFilter,
    this.transactionTypeFilter,
  });

  static const Object _unset = Object();

  final List<AppUser> users;
  final List<InventoryItem> items;
  final List<InventoryTransaction> transactions;
  final String searchQuery;
  final ItemCategory? categoryFilter;
  final ItemCondition? conditionFilter;
  final String? siteFilter;
  final TransactionType? transactionTypeFilter;

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

  List<String> get siteIds {
    final sites = {
      ..._knownSiteIds,
      ...items.map((item) => item.siteId),
    }.toList(growable: false);
    sites.sort();
    return sites;
  }

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
      final matchSite = siteFilter == null || item.siteId == siteFilter;

      return matchSearch && matchCategory && matchCondition && matchSite;
    }).toList(growable: false);
  }

  List<InventoryTransaction> get filteredTransactions {
    if (transactionTypeFilter == null) {
      return transactions;
    }

    return transactions
        .where((transaction) => transaction.type == transactionTypeFilter)
        .toList(growable: false);
  }

  InventoryState copyWith({
    List<AppUser>? users,
    List<InventoryItem>? items,
    List<InventoryTransaction>? transactions,
    String? searchQuery,
    Object? categoryFilter = _unset,
    Object? conditionFilter = _unset,
    Object? siteFilter = _unset,
    Object? transactionTypeFilter = _unset,
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
      siteFilter: identical(siteFilter, _unset)
          ? this.siteFilter
          : siteFilter as String?,
      transactionTypeFilter: identical(transactionTypeFilter, _unset)
          ? this.transactionTypeFilter
          : transactionTypeFilter as TransactionType?,
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

  void updateSiteFilter(String? value) {
    state = state.copyWith(siteFilter: value);
  }

  void updateTransactionTypeFilter(TransactionType? value) {
    state = state.copyWith(transactionTypeFilter: value);
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

  void transferItem({
    required String itemId,
    required String targetSiteId,
    required String processedBy,
  }) {
    final index = state.items.indexWhere((item) => item.id == itemId);
    if (index < 0) {
      return;
    }

    final item = state.items[index];
    if (item.holderId != null || item.siteId == targetSiteId) {
      return;
    }

    final updatedItems = List<InventoryItem>.from(state.items);
    updatedItems[index] = InventoryItem(
      id: item.id,
      name: item.name,
      siteId: targetSiteId,
      category: item.category,
      condition: item.condition,
    );

    final transaction = InventoryTransaction(
      id: _uuid.v4(),
      itemId: item.id,
      type: TransactionType.transfer,
      status: TransactionStatus.completed,
      timestamp: DateTime.now(),
      userId: processedBy,
      sourceSiteId: item.siteId,
      targetSiteId: targetSiteId,
      condition: item.condition,
    );

    state = state.copyWith(
      items: updatedItems,
      transactions: [transaction, ...state.transactions],
    );
  }

  void addItem({
    required String name,
    required ItemCategory category,
    required ItemCondition condition,
    required String siteId,
    required String processedBy,
  }) {
    final itemId = 'itm-${_uuid.v4().substring(0, 8)}';
    final item = InventoryItem(
      id: itemId,
      name: name,
      siteId: siteId,
      category: category,
      condition: condition,
    );

    final transaction = InventoryTransaction(
      id: _uuid.v4(),
      itemId: itemId,
      type: TransactionType.checkIn,
      status: TransactionStatus.completed,
      timestamp: DateTime.now(),
      userId: processedBy,
      targetSiteId: siteId,
      condition: condition,
    );

    state = state.copyWith(
      items: [item, ...state.items],
      transactions: [transaction, ...state.transactions],
    );
  }

  void editItem({
    required String itemId,
    required String name,
    required ItemCategory category,
    required ItemCondition condition,
    required String siteId,
    required String processedBy,
  }) {
    final index = state.items.indexWhere((item) => item.id == itemId);
    if (index < 0) {
      return;
    }

    final item = state.items[index];
    if (item.holderId != null && item.siteId != siteId) {
      return;
    }

    final updatedItems = List<InventoryItem>.from(state.items);
    updatedItems[index] = InventoryItem(
      id: item.id,
      name: name,
      siteId: siteId,
      holderId: item.holderId,
      category: category,
      condition: condition,
    );

    final updatedTransactions = List<InventoryTransaction>.from(state.transactions);
    if (item.siteId != siteId) {
      updatedTransactions.insert(
        0,
        InventoryTransaction(
          id: _uuid.v4(),
          itemId: item.id,
          type: TransactionType.transfer,
          status: TransactionStatus.completed,
          timestamp: DateTime.now(),
          userId: processedBy,
          sourceSiteId: item.siteId,
          targetSiteId: siteId,
          condition: condition,
        ),
      );
    }

    state = state.copyWith(
      items: updatedItems,
      transactions: updatedTransactions,
    );
  }

  void deleteItem({
    required String itemId,
  }) {
    final index = state.items.indexWhere((item) => item.id == itemId);
    if (index < 0) {
      return;
    }

    final item = state.items[index];
    if (item.holderId != null) {
      return;
    }

    final updatedItems = List<InventoryItem>.from(state.items)..removeAt(index);
    state = state.copyWith(items: updatedItems);
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

String? _transactionDetails(InventoryTransaction transaction) {
  if (transaction.type == TransactionType.transfer &&
      transaction.sourceSiteId != null &&
      transaction.targetSiteId != null) {
    return '${_siteLabel(transaction.sourceSiteId!)} -> ${_siteLabel(transaction.targetSiteId!)}';
  }

  if (transaction.type == TransactionType.checkIn &&
      transaction.targetSiteId != null) {
    return 'Added to ${_siteLabel(transaction.targetSiteId!)}';
  }

  return null;
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

