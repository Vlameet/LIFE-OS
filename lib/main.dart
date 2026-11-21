import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';

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
      appBarTheme: const AppBarTheme(backgroundColor: bg, elevation: 0),
      inputDecorationTheme: InputDecorationTheme(
        filled: true, fillColor: bg,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
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
  String searchQuery = '';
  WebViewController? musicController;
  bool musicStarted = false;
  int musicProgress = 0;
  String musicError = '';
  final sections = ['Задачи', 'Привычки', 'Цели', 'Финансы', 'Заметки'];
  final data = <String, List<Map<String, dynamic>>>{
    'Задачи': [], 'Привычки': [], 'Цели': [], 'Финансы': [], 'Заметки': [],
  };
  String get today => DateTime.now().toIso8601String().substring(0, 10);

  @override
  void initState() { super.initState(); load(); }

  Future<void> openMusic() async {
    if (musicStarted) return;
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      setState(() => musicError = 'Встроенный плеер пока доступен в Android-версии.');
      return;
    }
    setState(() { musicStarted = true; musicError = ''; });
    final controller = WebViewController();
    musicController = controller;
    await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    await controller.setBackgroundColor(const Color(0xFF10131B));
    await controller.setNavigationDelegate(NavigationDelegate(
      onProgress: (progress) {
        if (mounted) setState(() => musicProgress = progress);
      },
      onWebResourceError: (error) {
        if (mounted && error.isForMainFrame == true) {
          setState(() => musicError = 'Не удалось загрузить Яндекс Музыку. Проверь интернет и обнови страницу.');
        }
      },
    ));
    await controller.loadRequest(Uri.parse('https://music.yandex.ru/'));
    if (mounted) setState(() {});
  }

  Widget musicPlaceholder() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.music_note_rounded, size: 64, color: Colors.lightBlueAccent),
        const SizedBox(height: 12),
        const Text('Яндекс Музыка', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(musicError.isEmpty ? 'Открой официальный музыкальный сервис внутри LIFE OS.' : musicError,
          textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60)),
        const SizedBox(height: 18),
        if (musicProgress > 0 && musicProgress < 100) ...[
          LinearProgressIndicator(value: musicProgress / 100, color: Colors.lightBlueAccent),
          const SizedBox(height: 16),
        ],
        FilledButton.icon(
          onPressed: openMusic,
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Открыть Яндекс Музыку'),
        ),
      ]),
    ),
  );

  Widget musicMiniBar() => InkWell(
    onTap: () {
      setState(() => tab = 6);
      openMusic();
    },
    child: Container(
      margin: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFF142D50), Color(0xFF24203D), Color(0xFF3A1B30)],
        ),
        border: Border.all(color: Colors.lightBlueAccent.withOpacity(0.25)),
      ),
      child: Row(children: [
        const Icon(Icons.music_note_rounded, color: Colors.lightBlueAccent, size: 28),
        const SizedBox(width: 10),
        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Яндекс Музыка', style: TextStyle(fontWeight: FontWeight.bold)),
          Text('Открыть музыкальный плеер', style: TextStyle(fontSize: 11, color: Colors.white60)),
        ])),
        const Icon(Icons.open_in_full_rounded, color: Colors.white70),
      ]),
    ),
  );

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    for (final section in sections) {
      final raw = prefs.getString(section);
      if (raw != null) {
        try {
          data[section] = (jsonDecode(raw) as List)
            .map((e) => Map<String, dynamic>.from(e as Map)).toList();
        } catch (_) { data[section] = []; }
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

  Future<void> editItem(String section, {Map<String, dynamic>? item}) async {
    final isNew = item == null;
    final name = TextEditingController(text: item?['name']?.toString() ?? '');
    final detail = TextEditingController(text: item?['detail']?.toString() ?? '');
    final amount = TextEditingController(text: item?['amount']?.toString() ?? '');
    String priority = item?['priority']?.toString() ?? 'Средний';
    String kind = item?['kind']?.toString() ?? 'Расход';
    String due = item?['due']?.toString() ?? '';
    double progress = (item?['progress'] as num?)?.toDouble() ?? 0;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, refresh) => AlertDialog(
        backgroundColor: panel,
        title: Text(item == null ? 'Новая запись: $section' : 'Изменить: $section'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, autofocus: true, decoration: const InputDecoration(labelText: 'Название')),
          const SizedBox(height: 10),
          if (section == 'Задачи') ...[
            DropdownButtonFormField<String>(
              value: priority, decoration: const InputDecoration(labelText: 'Приоритет'),
              items: ['Низкий', 'Средний', 'Высокий'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
              onChanged: (v) => refresh(() => priority = v ?? 'Средний'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              icon: const Icon(Icons.calendar_today),
              label: Text(due.isEmpty ? 'Добавить срок' : 'Срок: $due'),
              onPressed: () async {
                final picked = await showDatePicker(context: ctx, initialDate: DateTime.now(),
                  firstDate: DateTime(2020), lastDate: DateTime(2100));
                if (picked != null) refresh(() => due = picked.toIso8601String().substring(0, 10));
              },
            ),
          ],
          if (section == 'Цели') ...[
            TextField(controller: detail, decoration: const InputDecoration(labelText: 'Описание / результат')),
            const SizedBox(height: 14),
            Row(children: [const Text('Прогресс'), const Spacer(), Text((progress * 100).round().toString() + '%')]),
            Slider(value: progress, onChanged: (v) => refresh(() => progress = v), activeColor: red),
          ],
          if (section == 'Финансы') ...[
            TextField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Сумма')),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: kind, decoration: const InputDecoration(labelText: 'Тип операции'),
              items: ['Доход', 'Расход'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
              onChanged: (v) => refresh(() => kind = v ?? 'Расход'),
            ),
            const SizedBox(height: 10),
            TextField(controller: detail, decoration: const InputDecoration(labelText: 'Категория / комментарий')),
          ],
          if (section == 'Заметки')
            TextField(controller: detail, minLines: 3, maxLines: 6, decoration: const InputDecoration(labelText: 'Текст заметки')),
          if (section == 'Привычки')
            const Padding(padding: EdgeInsets.only(top: 8), child: Text('Отмечай выполнение каждый день, чтобы вести серию.')),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Сохранить')),
        ],
      )),
    );
    if (result != true) { name.dispose(); detail.dispose(); amount.dispose(); return; }
    final title = name.text.trim();
    if (title.isEmpty) { name.dispose(); detail.dispose(); amount.dispose(); return; }
    if (section == 'Финансы') {
      final parsed = double.tryParse(amount.text.replaceAll(',', '.'));
      if (parsed == null || parsed <= 0) {
        name.dispose(); detail.dispose(); amount.dispose();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Укажи корректную сумму больше нуля.')));
        return;
      }
      if (item == null) item = {'id': DateTime.now().microsecondsSinceEpoch};
      item!['amount'] = parsed;
      item!['kind'] = kind;
      item!['detail'] = detail.text.trim();
    }
    final target = item ?? {'id': DateTime.now().microsecondsSinceEpoch, 'done': false};
    target['name'] = title;
    if (section == 'Задачи') { target['priority'] = priority; target['due'] = due; }
    if (section == 'Цели') { target['detail'] = detail.text.trim(); target['progress'] = progress; }
    if (section == 'Заметки') target['detail'] = detail.text.trim();
    if (isNew) data[section]!.insert(0, target);
    await save();
    name.dispose(); detail.dispose(); amount.dispose();
  }

  Future<void> removeItem(String section, Map<String, dynamic> item) async {
    data[section]!.remove(item);
    await save();
  }

  int streak(Map<String, dynamic> item) {
    final dates = (item['dates'] as List? ?? []).map((e) => e.toString()).toSet();
    var count = 0;
    var day = DateTime.now();
    if (!dates.contains(day.toIso8601String().substring(0, 10))) day = day.subtract(const Duration(days: 1));
    while (dates.contains(day.toIso8601String().substring(0, 10))) {
      count++;
      day = day.subtract(const Duration(days: 1));
    }
    return count;
  }

  Widget stat(String title, String value, IconData icon) => SizedBox(
    width: 155,
    child: Card(color: panel, child: Padding(
      padding: const EdgeInsets.all(15),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: red), const SizedBox(height: 10),
        Text(value, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.bold)),
        Text(title, style: const TextStyle(color: Colors.white60)),
      ]),
    )),
  );

  double get income => data['Финансы']!.where((x) => x['kind'] == 'Доход')
    .fold(0.0, (s, x) => s + ((x['amount'] as num?)?.toDouble() ?? 0));
  double get expenses => data['Финансы']!.where((x) => x['kind'] == 'Расход')
    .fold(0.0, (s, x) => s + ((x['amount'] as num?)?.toDouble() ?? 0));
  String money(double value) => value.toStringAsFixed(2);

  Widget quickAction(String label, IconData icon, int destination) => ActionChip(
    avatar: Icon(icon, size: 18, color: Colors.white), label: Text(label),
    backgroundColor: const Color(0xFF202B43), side: BorderSide(color: (destination.isEven ? red : Colors.blueAccent).withOpacity(0.4)),
    onPressed: () async { setState(() => tab = destination); await editItem(sections[destination - 1]); },
  );

  Widget overview() {
    final tasks = data['Задачи']!;
    final habits = data['Привычки']!;
    final done = tasks.where((x) => x['done'] == true).length;
    final openTasks = tasks.where((x) => x['done'] != true).take(4).toList();
    return ListView(padding: const EdgeInsets.all(18), children: [
      Text(DateTime.now().hour < 12 ? 'Доброе утро' : DateTime.now().hour < 18 ? 'Хорошего дня' : 'Добрый вечер',
        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
      const Text('Твоя жизнь. Твои правила.', style: TextStyle(color: Colors.white54)),
      const SizedBox(height: 5),
      Text(DateTime.now().toIso8601String().substring(0, 10), style: const TextStyle(color: Colors.lightBlueAccent, fontWeight: FontWeight.w600)),
      const SizedBox(height: 18),
      Wrap(spacing: 8, runSpacing: 8, children: [
        quickAction('Задача', Icons.add_task, 1), quickAction('Привычка', Icons.repeat, 2),
        quickAction('Цель', Icons.flag_outlined, 3), quickAction('Финансы', Icons.add_chart, 4),
      ]),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, children: [
        stat('Выполнено задач', done.toString() + '/' + tasks.length.toString(), Icons.task_alt),
        stat('Активных привычек', habits.length.toString(), Icons.repeat),
        stat('Доходы', money(income), Icons.trending_up),
        stat('Расходы', money(expenses), Icons.trending_down),
      ]),
      Card(color: panel, child: ListTile(
        title: const Text('Баланс', style: TextStyle(color: Colors.white60)),
        subtitle: Text(money(income - expenses), style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold)),
        trailing: const Icon(Icons.account_balance_wallet, color: red, size: 30),
      )),
      const SizedBox(height: 16),
      const Text('Ближайшие задачи', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
      if (openTasks.isEmpty) const Card(color: panel, child: ListTile(title: Text('Все задачи выполнены. Или их пока нет.'))),
      ...openTasks.map((t) => Card(color: panel, child: ListTile(
        leading: const Icon(Icons.circle_outlined, color: red),
        title: Text(t['name'].toString()),
        subtitle: Text((t['due'] ?? '').toString().isEmpty ? 'Без срока' : 'До: ' + t['due'].toString()),
      ))),
      const SizedBox(height: 14),
      const Text('Цели', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
      ...data['Цели']!.take(3).map((g) => Card(color: panel, child: Padding(
        padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(g['name'].toString()), const SizedBox(height: 8),
          LinearProgressIndicator(value: (g['progress'] as num?)?.toDouble() ?? 0, color: red, backgroundColor: Colors.white12),
        ]),
      ))),
    ]);
  }

  Widget searchField() => TextField(
    onChanged: (v) => setState(() => searchQuery = v),
    decoration: InputDecoration(hintText: 'Поиск по записям...', prefixIcon: const Icon(Icons.search),
      suffixIcon: searchQuery.isEmpty ? null : IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => searchQuery = '')),
      filled: true, fillColor: const Color(0xFF172033), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16))),
  );

  Widget sectionView(String section) {
    final allItems = data[section]!;
    final q = searchQuery.trim().toLowerCase();
    final items = q.isEmpty ? allItems : allItems.where((x) => [x['name'], x['detail'], x['priority'], x['kind']].whereType<Object>().any((v) => v.toString().toLowerCase().contains(q))).toList();
    if (section == 'Финансы') {
      return ListView(padding: const EdgeInsets.all(16), children: [
        const Text('Финансы', style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12), searchField(),
        Wrap(spacing: 8, children: [
          stat('Доходы', money(income), Icons.arrow_downward),
          stat('Расходы', money(expenses), Icons.arrow_upward),
        ]),
        Card(color: panel, child: ListTile(title: const Text('Текущий баланс'), subtitle: Text(money(income - expenses), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)))),
        ...items.map((item) => Card(color: panel, child: ListTile(
          title: Text(item['name'].toString()),
          subtitle: Text((item['kind'] ?? '').toString() + ((item['detail'] ?? '').toString().isEmpty ? '' : ' • ' + item['detail'].toString())),
          trailing: Text((item['kind'] == 'Доход' ? '+' : '-') + money((item['amount'] as num?)?.toDouble() ?? 0),
            style: TextStyle(color: item['kind'] == 'Доход' ? Colors.greenAccent : red, fontWeight: FontWeight.bold)),
          onTap: () => editItem(section, item: item),
          leading: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => removeItem(section, item)),
        ))),
      ]);
    }
    return ListView(padding: const EdgeInsets.all(16), children: [
      searchField(),
      const SizedBox(height: 10),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(section, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold)),
        IconButton(onPressed: () => editItem(section), icon: const Icon(Icons.add_circle, color: red, size: 30)),
      ]),
      if (items.isEmpty) const Padding(
        padding: EdgeInsets.only(top: 55),
        child: Center(child: Text('Здесь пока пусто. Нажми +, чтобы добавить запись.', textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white54))),
      ),
      ...items.map((item) {
        if (section == 'Привычки') {
          final dates = List<String>.from(item['dates'] as List? ?? []);
          final marked = dates.contains(today);
          return Card(color: panel, child: ListTile(
            leading: Checkbox(value: marked, activeColor: red, onChanged: (v) async {
              if (v == true) { dates.add(today); } else { dates.remove(today); }
              item['dates'] = dates.toSet().toList(); await save();
            }),
            title: Text(item['name'].toString()),
            subtitle: Text('Серия: ' + streak(item).toString() + ' дн.'),
            trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => removeItem(section, item)),
            onTap: () => editItem(section, item: item),
          ));
        }
        if (section == 'Цели') {
          final value = (item['progress'] as num?)?.toDouble() ?? 0;
          return Card(color: panel, child: Padding(padding: const EdgeInsets.all(14), child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Expanded(child: Text(item['name'].toString(), style: const TextStyle(fontWeight: FontWeight.bold))),
                IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => editItem(section, item: item)),
                IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => removeItem(section, item)),
              ]),
              if ((item['detail'] ?? '').toString().isNotEmpty) Text(item['detail'].toString(), style: const TextStyle(color: Colors.white60)),
              Row(children: [Expanded(child: Slider(value: value.clamp(0, 1).toDouble(), activeColor: red, onChanged: (v) async { item['progress'] = v; await save(); })),
                Text((value * 100).round().toString() + '%'),
              ]),
            ],
          )));
        }
        return Card(color: panel, child: ListTile(
          leading: section == 'Задачи'
            ? Checkbox(value: item['done'] == true, activeColor: red, onChanged: (v) async { item['done'] = v ?? false; await save(); })
            : const Icon(Icons.notes, color: red),
          title: Text(item['name'].toString(), style: TextStyle(decoration: item['done'] == true ? TextDecoration.lineThrough : null)),
          subtitle: section == 'Задачи'
            ? Text((item['priority'] ?? 'Средний').toString() + ((item['due'] ?? '').toString().isEmpty ? '' : ' • ' + item['due'].toString()))
            : Text((item['detail'] ?? '').toString(), maxLines: 2, overflow: TextOverflow.ellipsis),
          trailing: PopupMenuButton<String>(
            onSelected: (v) { if (v == 'edit') editItem(section, item: item); else removeItem(section, item); },
            itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('Изменить')), PopupMenuItem(value: 'delete', child: Text('Удалить'))],
          ),
          onTap: () => editItem(section, item: item),
        ));
      }),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    if (!ready) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final labels = ['Обзор', ...sections, 'Музыка'];
    final icons = [Icons.dashboard_outlined, Icons.checklist, Icons.repeat, Icons.flag_outlined, Icons.account_balance_wallet_outlined, Icons.note_alt_outlined, Icons.music_note_rounded];
    return Scaffold(
      appBar: AppBar(
        title: const Text('LIFE OS', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: LinearGradient(
          colors: [Color(0xFF14233D), Color(0xFF251A2C), Color(0xFF351B27)], begin: Alignment.centerLeft, end: Alignment.centerRight))),
        actions: [IconButton(tooltip: 'На главную', onPressed: () => setState(() { tab = 0; searchQuery = ''; }), icon: const Icon(Icons.home_outlined))],
      ),
      body: Container(decoration: const BoxDecoration(gradient: LinearGradient(
        colors: [Color(0xFF0B1422), Color(0xFF11121B), Color(0xFF1C1019)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
        child: IndexedStack(
          index: tab,
          children: [
            overview(),
            ...sections.map((section) => sectionView(section)),
            musicController == null ? musicPlaceholder() : WebViewWidget(controller: musicController!),
          ],
        )),
      floatingActionButton: tab == 0 ? null : FloatingActionButton(
        backgroundColor: red, onPressed: () => editItem(sections[tab - 1]), child: const Icon(Icons.add)),
      bottomNavigationBar: Column(mainAxisSize: MainAxisSize.min, children: [
        musicMiniBar(),
        NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) { setState(() => tab = i); if (i == 6) openMusic(); },
        backgroundColor: panel, indicatorColor: red.withOpacity(0.18),
        destinations: [for (var i = 0; i < labels.length; i++)
          NavigationDestination(icon: Icon(icons[i]), label: labels[i])],
        ),
      ]),
    );
  }
}
