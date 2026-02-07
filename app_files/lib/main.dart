import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

void main() {
  runApp(const AluUpvcApp());
}

/// ========== Models ==========
class RulesDb {
  final List<Company> companies;
  RulesDb({required this.companies});

  static RulesDb fromJson(Map<String, dynamic> j) {
    final companies = (j['companies'] as List? ?? [])
        .map((e) => Company.fromJson(e as Map<String, dynamic>))
        .toList();
    return RulesDb(companies: companies);
  }

  Map<String, dynamic> toJson() => {
        'companies': companies.map((c) => c.toJson()).toList(),
      };
}

class Company {
  final String nameAr;
  final String nameEn;
  final List<Series> series;
  Company({required this.nameAr, required this.nameEn, required this.series});

  static Company fromJson(Map<String, dynamic> j) {
    final series = (j['series'] as List? ?? [])
        .map((e) => Series.fromJson(e as Map<String, dynamic>))
        .toList();
    return Company(
      nameAr: (j['name_ar'] ?? '').toString(),
      nameEn: (j['name_en'] ?? '').toString(),
      series: series,
    );
  }

  Map<String, dynamic> toJson() => {
        'name_ar': nameAr,
        'name_en': nameEn,
        'series': series.map((s) => s.toJson()).toList(),
      };
}

class Series {
  final String nameAr;
  final String nameEn;
  final List<TemplateModel> templates;
  Series({required this.nameAr, required this.nameEn, required this.templates});

  static Series fromJson(Map<String, dynamic> j) {
    final templates = (j['templates'] as List? ?? [])
        .map((e) => TemplateModel.fromJson(e as Map<String, dynamic>))
        .toList();
    return Series(
      nameAr: (j['name_ar'] ?? '').toString(),
      nameEn: (j['name_en'] ?? '').toString(),
      templates: templates,
    );
  }

  Map<String, dynamic> toJson() => {
        'name_ar': nameAr,
        'name_en': nameEn,
        'templates': templates.map((t) => t.toJson()).toList(),
      };
}

class TemplateModel {
  final String nameAr;
  final String nameEn;
  final List<PartRule> parts;
  TemplateModel({required this.nameAr, required this.nameEn, required this.parts});

  static TemplateModel fromJson(Map<String, dynamic> j) {
    final parts = (j['parts'] as List? ?? [])
        .map((e) => PartRule.fromJson(e as Map<String, dynamic>))
        .toList();
    return TemplateModel(
      nameAr: (j['name_ar'] ?? '').toString(),
      nameEn: (j['name_en'] ?? '').toString(),
      parts: parts,
    );
  }

  Map<String, dynamic> toJson() => {
        'name_ar': nameAr,
        'name_en': nameEn,
        'parts': parts.map((p) => p.toJson()).toList(),
      };
}

class PartRule {
  final String nameAr;
  final String nameEn;
  final String formula;
  final String qty; // keep as string to allow simple expressions later
  final String notesAr;
  final String notesEn;

  PartRule({
    required this.nameAr,
    required this.nameEn,
    required this.formula,
    required this.qty,
    required this.notesAr,
    required this.notesEn,
  });

  static PartRule fromJson(Map<String, dynamic> j) => PartRule(
        nameAr: (j['name_ar'] ?? '').toString(),
        nameEn: (j['name_en'] ?? '').toString(),
        formula: (j['formula'] ?? '').toString(),
        qty: (j['qty'] ?? '').toString(),
        notesAr: (j['notes_ar'] ?? '').toString(),
        notesEn: (j['notes_en'] ?? '').toString(),
      );

  Map<String, dynamic> toJson() => {
        'name_ar': nameAr,
        'name_en': nameEn,
        'formula': formula,
        'qty': qty,
        'notes_ar': notesAr,
        'notes_en': notesEn,
      };
}

/// ========== Simple Expression Evaluator (W/H, + - * / () ) ==========
class ExprEval {
  static double? eval(String expr, {required double W, required double H}) {
    final tokens = _tokenize(expr, W: W, H: H);
    if (tokens == null || tokens.isEmpty) return null;
    final rpn = _toRpn(tokens);
    if (rpn == null) return null;
    return _evalRpn(rpn);
  }

  static List<String>? _tokenize(String expr, {required double W, required double H}) {
    final s = expr.trim();
    if (s.isEmpty) return null;
    final out = <String>[];
    int i = 0;

    String readNumber() {
      final start = i;
      while (i < s.length && RegExp(r'[0-9.]').hasMatch(s[i])) i++;
      return s.substring(start, i);
    }

    while (i < s.length) {
      final ch = s[i];
      if (ch.trim().isEmpty) {
        i++;
        continue;
      }
      if (RegExp(r'[0-9.]').hasMatch(ch)) {
        out.add(readNumber());
        continue;
      }
      if (ch == 'W' || ch == 'w') {
        out.add(W.toString());
        i++;
        continue;
      }
      if (ch == 'H' || ch == 'h') {
        out.add(H.toString());
        i++;
        continue;
      }
      if ('+-*/()'.contains(ch)) {
        out.add(ch);
        i++;
        continue;
      }
      // unsupported char
      return null;
    }
    return out;
  }

  static int _prec(String op) => (op == '+' || op == '-') ? 1 : (op == '*' || op == '/') ? 2 : 0;
  static bool _isOp(String t) => t == '+' || t == '-' || t == '*' || t == '/';

  static List<String>? _toRpn(List<String> tokens) {
    final output = <String>[];
    final stack = <String>[];

    for (final t in tokens) {
      if (_isOp(t)) {
        while (stack.isNotEmpty && _isOp(stack.last) && _prec(stack.last) >= _prec(t)) {
          output.add(stack.removeLast());
        }
        stack.add(t);
      } else if (t == '(') {
        stack.add(t);
      } else if (t == ')') {
        bool found = false;
        while (stack.isNotEmpty) {
          final top = stack.removeLast();
          if (top == '(') {
            found = true;
            break;
          }
          output.add(top);
        }
        if (!found) return null; // mismatched
      } else {
        // number
        output.add(t);
      }
    }

    while (stack.isNotEmpty) {
      final top = stack.removeLast();
      if (top == '(' || top == ')') return null;
      output.add(top);
    }
    return output;
  }

  static double? _evalRpn(List<String> rpn) {
    final st = <double>[];
    for (final t in rpn) {
      if (_isOp(t)) {
        if (st.length < 2) return null;
        final b = st.removeLast();
        final a = st.removeLast();
        switch (t) {
          case '+':
            st.add(a + b);
            break;
          case '-':
            st.add(a - b);
            break;
          case '*':
            st.add(a * b);
            break;
          case '/':
            st.add(b == 0 ? double.nan : a / b);
            break;
        }
      } else {
        final v = double.tryParse(t);
        if (v == null) return null;
        st.add(v);
      }
    }
    if (st.length != 1) return null;
    return st.single;
  }
}

/// ========== App ==========
class AluUpvcApp extends StatefulWidget {
  const AluUpvcApp({super.key});
  @override
  State<AluUpvcApp> createState() => _AluUpvcAppState();
}

class _AluUpvcAppState extends State<AluUpvcApp> {
  static const _prefsKey = 'alupvc_rules_v01';
  RulesDb? _db;
  String _lang = 'ar'; // ar/en
  String _rulesRaw = '';
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    Map<String, dynamic> jsonMap;

    if (saved == null || saved.trim().isEmpty) {
      final raw = await rootBundle.loadString('assets/rules_default.json');
      jsonMap = json.decode(raw) as Map<String, dynamic>;
      await prefs.setString(_prefsKey, const JsonEncoder.withIndent('  ').convert(jsonMap));
    } else {
      jsonMap = json.decode(saved) as Map<String, dynamic>;
    }

    setState(() {
      _db = RulesDb.fromJson(jsonMap);
      _rulesRaw = const JsonEncoder.withIndent('  ').convert(jsonMap);
      _loaded = true;
    });
  }

  Future<void> _saveRules(String raw) async {
    final prefs = await SharedPreferences.getInstance();
    final obj = json.decode(raw) as Map<String, dynamic>;
    await prefs.setString(_prefsKey, const JsonEncoder.withIndent('  ').convert(obj));
    setState(() {
      _db = RulesDb.fromJson(obj);
      _rulesRaw = const JsonEncoder.withIndent('  ').convert(obj);
    });
  }

  Future<void> _resetRules() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = await rootBundle.loadString('assets/rules_default.json');
    await prefs.setString(_prefsKey, const JsonEncoder.withIndent('  ').convert(json.decode(raw)));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final isAr = _lang == 'ar';
    final title = isAr ? 'نسخة احترافية (تجريبية) — تخصيمات' : 'Pro Trial — Deductions';
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: title,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.green),
      home: !_loaded
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : HomeScreen(
              db: _db!,
              lang: _lang,
              rulesRaw: _rulesRaw,
              onLang: (v) => setState(() => _lang = v),
              onSaveRules: _saveRules,
              onReset: _resetRules,
            ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final RulesDb db;
  final String lang;
  final String rulesRaw;
  final void Function(String) onLang;
  final Future<void> Function(String) onSaveRules;
  final Future<void> Function() onReset;

  const HomeScreen({
    super.key,
    required this.db,
    required this.lang,
    required this.rulesRaw,
    required this.onLang,
    required this.onSaveRules,
    required this.onReset,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class CutRow {
  final String nameAr;
  final String nameEn;
  final double? len;
  final int qty;
  final String notesAr;
  final String notesEn;
  final String formula;
  const CutRow({
    required this.nameAr,
    required this.nameEn,
    required this.len,
    required this.qty,
    required this.notesAr,
    required this.notesEn,
    required this.formula,
  });
}

class _HomeScreenState extends State<HomeScreen> {
  int companyIdx = 0;
  int seriesIdx = 0;
  int templateIdx = 0;

  final wCtrl = TextEditingController(text: '200');
  final hCtrl = TextEditingController(text: '150');
  final unitsCtrl = TextEditingController(text: '1');

  final rulesCtrl = TextEditingController();

  List<CutRow> rows = [];
  int totalPieces = 0;
  double totalLen = 0;

  @override
  void initState() {
    super.initState();
    rulesCtrl.text = widget.rulesRaw;
    _calc();
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rulesRaw != widget.rulesRaw) {
      rulesCtrl.text = widget.rulesRaw;
      // indices might be out of range after edit
      companyIdx = companyIdx.clamp(0, widget.db.companies.length - 1);
      seriesIdx = seriesIdx.clamp(0, widget.db.companies[companyIdx].series.length - 1);
      templateIdx = templateIdx.clamp(0, widget.db.companies[companyIdx].series[seriesIdx].templates.length - 1);
      _calc();
    }
  }

  Company get company => widget.db.companies[companyIdx];
  Series get series => company.series[seriesIdx];
  TemplateModel get template => series.templates[templateIdx];

  void _calc() {
    final W = double.tryParse(wCtrl.text.trim());
    final H = double.tryParse(hCtrl.text.trim());
    final units = int.tryParse(unitsCtrl.text.trim()) ?? 1;
    if (W == null || H == null) return;

    final out = <CutRow>[];
    int pieces = 0;
    double lenSum = 0;

    for (final p in template.parts) {
      final len = ExprEval.eval(p.formula, W: W, H: H);
      final qtyBaseD = ExprEval.eval(p.qty, W: W, H: H) ?? double.tryParse(p.qty) ?? 0;
      final qty = (qtyBaseD.round()) * (units < 1 ? 1 : units);

      pieces += qty;
      if (len != null && !len.isNaN) {
        lenSum += len * qty;
      }
      out.add(CutRow(
        nameAr: p.nameAr,
        nameEn: p.nameEn,
        len: len,
        qty: qty,
        notesAr: p.notesAr,
        notesEn: p.notesEn,
        formula: p.formula,
      ));
    }

    setState(() {
      rows = out;
      totalPieces = pieces;
      totalLen = lenSum;
    });
  }

  Future<void> _exportCsv() async {
    final isAr = widget.lang == 'ar';
    final W = wCtrl.text.trim();
    final H = hCtrl.text.trim();
    final units = unitsCtrl.text.trim();

    final header = [
      'Company',
      'Series',
      'Template',
      'W',
      'H',
      'Units',
      'Part_AR',
      'Part_EN',
      'Length_cm',
      'Qty',
      'Formula',
      'Notes_AR',
      'Notes_EN'
    ];

    final lines = <List<String>>[header];
    for (final r in rows) {
      lines.add([
        company.nameEn,
        series.nameEn,
        template.nameEn,
        W,
        H,
        units,
        r.nameAr,
        r.nameEn,
        (r.len == null || r.len!.isNaN) ? '' : r.len!.toStringAsFixed(2),
        r.qty.toString(),
        r.formula,
        r.notesAr,
        r.notesEn,
      ]);
    }

    String esc(String v) {
      if (v.contains(',') || v.contains('\n') || v.contains('"')) {
        return '"${v.replaceAll('"', '""')}"';
      }
      return v;
    }

    final csv = lines.map((row) => row.map(esc).join(',')).join('\n');

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/cutting_list.csv');
    await file.writeAsString(csv, encoding: utf8);

    await Share.shareXFiles([XFile(file.path)], text: isAr ? 'تصدير Cutting List' : 'Cutting List Export');
  }

  Future<void> _saveRules() async {
    final isAr = widget.lang == 'ar';
    try {
      json.decode(rulesCtrl.text); // validate JSON
      await widget.onSaveRules(rulesCtrl.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isAr ? 'تم حفظ القواعد ✅' : 'Rules saved ✅')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text((isAr ? 'JSON غير صحيح: ' : 'Invalid JSON: ') + e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = widget.lang == 'ar';
    final title = isAr ? 'تخصيمات UPVC/ألمنيوم — تجريبي' : 'Alu/UPVC Deductions — Trial';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: widget.lang,
              items: const [
                DropdownMenuItem(value: 'ar', child: Text('AR')),
                DropdownMenuItem(value: 'en', child: Text('EN')),
              ],
              onChanged: (v) => widget.onLang(v ?? 'ar'),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) {
            final wide = c.maxWidth >= 980;
            final left = _calculatorCard(isAr);
            final right = _rulesCard(isAr);
            return Padding(
              padding: const EdgeInsets.all(12),
              child: wide
                  ? Row(
                      children: [
                        Expanded(flex: 7, child: left),
                        const SizedBox(width: 12),
                        Expanded(flex: 5, child: right),
                      ],
                    )
                  : ListView(
                      children: [
                        left,
                        const SizedBox(height: 12),
                        right,
                      ],
                    ),
            );
          },
        ),
      ),
    );
  }

  Widget _calculatorCard(bool isAr) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            _sectionTitle(isAr ? 'الحاسبة' : 'Calculator'),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _dd<Company>(
                    label: isAr ? 'الشركة' : 'Company',
                    value: companyIdx,
                    items: widget.db.companies,
                    text: (c) => isAr ? c.nameAr : c.nameEn,
                    onChanged: (idx) {
                      setState(() {
                        companyIdx = idx;
                        seriesIdx = 0;
                        templateIdx = 0;
                      });
                      _calc();
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _dd<Series>(
                    label: isAr ? 'السيريز / النظام' : 'Series / System',
                    value: seriesIdx,
                    items: company.series,
                    text: (s) => isAr ? s.nameAr : s.nameEn,
                    onChanged: (idx) {
                      setState(() {
                        seriesIdx = idx;
                        templateIdx = 0;
                      });
                      _calc();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _dd<TemplateModel>(
                    label: isAr ? 'نوع الشغل (Template)' : 'Template',
                    value: templateIdx,
                    items: series.templates,
                    text: (t) => isAr ? t.nameAr : t.nameEn,
                    onChanged: (idx) {
                      setState(() => templateIdx = idx);
                      _calc();
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _tf(
                    label: isAr ? 'عدد الوحدات' : 'Units',
                    controller: unitsCtrl,
                    onChanged: (_) => _calc(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _tf(
                    label: isAr ? 'العرض W (سم)' : 'Width W (cm)',
                    controller: wCtrl,
                    onChanged: (_) => _calc(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _tf(
                    label: isAr ? 'الارتفاع H (سم)' : 'Height H (cm)',
                    controller: hCtrl,
                    onChanged: (_) => _calc(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                FilledButton(
                  onPressed: _calc,
                  child: Text(isAr ? 'احسب' : 'Calculate'),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: _exportCsv,
                  child: Text(isAr ? 'تصدير CSV' : 'Export CSV'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                isAr ? 'Cutting List' : 'Cutting List',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 8),
            _cutTable(isAr),
            const SizedBox(height: 10),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                isAr
                    ? 'الإجمالي: $totalPieces قطعة — أطوال تقريبية: ${totalLen.toStringAsFixed(2)} سم'
                    : 'Total: $totalPieces pieces — Approx length: ${totalLen.toStringAsFixed(2)} cm',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black54),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rulesCard(bool isAr) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            _sectionTitle(isAr ? 'قواعد التخصيم (Rules)' : 'Deduction Rules'),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                isAr
                    ? 'عدّل/أضف قواعد — وهي ثابتة لكل قطاع. احفظها، والنتيجة هتتحدث.'
                    : 'Edit/add rules — fixed per profile. Save to update output.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.black54),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: rulesCtrl,
              minLines: 12,
              maxLines: 16,
              decoration: InputDecoration(
                labelText: isAr ? 'القواعد (JSON)' : 'Rules (JSON)',
                border: const OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                FilledButton(
                  onPressed: _saveRules,
                  child: Text(isAr ? 'حفظ' : 'Save'),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: () async {
                    await widget.onReset();
                    if (!mounted) return;
                    _calc();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(isAr ? 'تمت إعادة الافتراضي ✅' : 'Reset ✅')),
                    );
                  },
                  child: Text(isAr ? 'Reset' : 'Reset'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _cutTable(bool isAr) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: [
          DataColumn(label: Text(isAr ? 'القطعة' : 'Part')),
          DataColumn(label: Text(isAr ? 'الطول (سم)' : 'Length (cm)')),
          DataColumn(label: Text(isAr ? 'العدد' : 'Qty')),
          DataColumn(label: Text(isAr ? 'ملاحظات' : 'Notes')),
        ],
        rows: rows
            .map(
              (r) => DataRow(cells: [
                DataCell(Text(isAr ? r.nameAr : r.nameEn)),
                DataCell(Text(r.len == null || r.len!.isNaN ? '—' : r.len!.toStringAsFixed(2))),
                DataCell(Text(r.qty.toString())),
                DataCell(Text(isAr ? r.notesAr : r.notesEn)),
              ]),
            )
            .toList(),
      ),
    );
  }

  Widget _sectionTitle(String t) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Text(t, style: Theme.of(context).textTheme.titleMedium),
    );
  }

  Widget _tf({required String label, required TextEditingController controller, required void Function(String) onChanged}) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: false),
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      onChanged: onChanged,
    );
  }

  Widget _dd<T>({
    required String label,
    required int value,
    required List<T> items,
    required String Function(T) text,
    required void Function(int) onChanged,
  }) {
    return InputDecorator(
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          isExpanded: true,
          value: value.clamp(0, items.length - 1),
          items: List.generate(items.length, (i) => DropdownMenuItem(value: i, child: Text(text(items[i])))),
          onChanged: (v) => onChanged(v ?? 0),
        ),
      ),
    );
  }
}
