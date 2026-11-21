import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const red = Color(0xFFF04444);
const bg = Color(0xFF0D0E10);
const panel = Color(0xFF191B20);

void main() => runApp(const LifeOS());

class LifeOS extends StatelessWidget {
  const LifeOS({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'LIFE OS', debugShowCheckedModeBanner: false,
    theme: ThemeData.dark().copyWith(
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme.fromSeed(seedColor: red, brightness: Brightness.dark),
      cardColor: panel,
    ),
    home: const Dashboard(),
  );
}

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});
  @override State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  int tab = 0;
  bool ready = false;
  final sections = ['Задачи', 'Привычки', 'Цели', 'Финансы', 'Заметки'];
  final data = <String, List<Map<String, dynamic>>>{
    'Задачи': [], 'Привычки': [], 'Цели': [], 'Финансы': [], 'Заметки': [],
  };

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    for (final section in sections) {
      final raw = prefs.getString(section);
      if (raw != null) {
        data[section] = (jsonDecode(raw) as List)
          .map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    }
    if (mounted) setState(() => ready = true);
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    for (final section in sections) {
      await prefs.setString(section, jsonEncode(data[section]));
    }
    if (mounted) setState(() {});
  }

  Future<void> addItem(String section) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: panel,
        title: Text('Добавить: $section'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Название или описание'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('Добавить')),
        ],
      ),
    );
    controller.dispose();
    if (value == null || value.isEmpty) return;
    data[section]!.insert(0, {
      'id': DateTime.now().microsecondsSinceEpoch,
      'name': value, 'done': false, 'progress': 0.0,
    });
    await save();
  }

  Widget stat(String title, String value) => SizedBox(
    width: 145,
    child: Card(color: panel, child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: Colors.white60)),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
      ]),
    )),
  );

  Widget overview() {
    final tasks = data['Задачи']!;
    final habits = data['Привычки']!;
    final done = tasks.where((x) => x['done'] == true).length;
    return ListView(padding: const EdgeInsets.all(20), children: [
      Text(DateTime.now().hour < 12 ? 'Доброе утро' : DateTime.now().hour < 18 ? 'Хорошего дня' : 'Добрый вечер',
        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
      const Text('Твоя жизнь. Твои правила.', style: TextStyle(color: Colors.white54)),
      const SizedBox(height: 20),
      Wrap(spacing: 10, runSpacing: 10, children: [
        stat('Задачи', '$done/${tasks.length}'),
        stat('Привычки', '${habits.where((x) => x['done'] == true).length}/${habits.length}'),
        stat('Цели', '${data['Цели']!.length}'),
        stat('Заметки', '${data['Заметки']!.length}'),
      ]),
      const SizedBox(height: 22),
      const Text('План на день', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
      if (tasks.isEmpty) const Card(color: panel, child: ListTile(
        title: Text('Пока нет задач'),
        subtitle: Text('Добавь первую задачу в разделе «Задачи».'),
      )),
      ...tasks.take(5).map((t) => Card(color: panel, child: ListTile(
        title: Text(t['name'] as String),
        leading: Icon(t['done'] == true ? Icons.check_circle : Icons.circle_outlined, color: red),
      ))),
    ]);
  }

  Widget sectionView(String section) {
    final items = data[section]!;
    return ListView(padding: const EdgeInsets.all(16), children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(section, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold)),
        IconButton(onPressed: () => addItem(section), icon: const Icon(Icons.add_circle, color: red, size: 30)),
      ]),
      if (items.isEmpty) const Padding(
        padding: EdgeInsets.only(top: 55),
        child: Center(child: Text('Здесь пока пусто. Нажми +, чтобы добавить запись.', textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white54))),
      ),
      ...items.map((item) => Card(
        color: panel,
        child: ListTile(
          leading: section == 'Задачи' || section == 'Привычки'
            ? Checkbox(value: item['done'] == true, activeColor: red, onChanged: (v) async {
                item['done'] = v ?? false; await save();
              })
            : const Icon(Icons.circle_outlined, color: red),
          title: Text(item['name'] as String,
            style: TextStyle(decoration: item['done'] == true ? TextDecoration.lineThrough : null)),
          trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () async {
            items.remove(item); await save();
          }),
        ),
      )),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    if (!ready) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final labels = ['Обзор', ...sections];
    return Scaffold(
      appBar: AppBar(title: const Text('LIFE OS', style: TextStyle(fontWeight: FontWeight.bold))),
      body: tab == 0 ? overview() : sectionView(sections[tab - 1]),
      floatingActionButton: tab == 0 ? null : FloatingActionButton(
        backgroundColor: red, onPressed: () => addItem(sections[tab - 1]),
        child: const Icon(Icons.add)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        backgroundColor: panel,
        indicatorColor: red.withValues(alpha: 0.2),
        destinations: [
          for (var i = 0; i < labels.length; i++)
            NavigationDestination(
              icon: Icon([Icons.dashboard_outlined, Icons.checklist, Icons.repeat, Icons.flag_outlined, Icons.account_balance_wallet_outlined, Icons.note_alt_outlined][i]),
              label: labels[i],
            ),
        ],
      ),
    );
  }
}
