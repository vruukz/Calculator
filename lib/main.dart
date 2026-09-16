import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

const defaultAccent = Color(0xFFc8f060);
final ValueNotifier<Color> kAccentNotifier = ValueNotifier<Color>(defaultAccent);
Color get kAccent => kAccentNotifier.value;

Future<void> loadAccent() async {
  final prefs = await SharedPreferences.getInstance();
  final value = prefs.getInt('accent_color');
  if (value != null) kAccentNotifier.value = Color(value);
}

Future<void> setAccent(Color color) async {
  kAccentNotifier.value = color;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt('accent_color', color.value);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await loadAccent();
  runApp(const CalculatorApp());
}

class CalculatorApp extends StatelessWidget {
  const CalculatorApp({super.key});
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<Color>(
    valueListenable: kAccentNotifier,
    builder: (context, accent, _) => MaterialApp(
      title: 'Calculator',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: const Color(0xFF202020)),
      home: const CalculatorScreen(),
    ),
  );
}

const kBg      = Color(0xFF202020);
const kBtnNum  = Color(0xFF333333);
const kBtnOp   = Color(0xFF3D3D3D);
const kBtnSpec = Color(0xFF2D2D2D);
const kBtnSci  = Color(0xFF2A2A2A);
const kBorder  = Color(0xFF2A2A2A);
const kText    = Color(0xFFFFFFFF);
const kTextSub = Color(0xFF888888);
const kHistBg  = Color(0xFF181818);

enum BtnType { number, operator, special, science, equals }

class HistoryEntry {
  final String expression;
  final String result;
  HistoryEntry(this.expression, this.result);
}

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});
  @override
  State<CalculatorScreen> createState() => _CalcState();
}

class _CalcState extends State<CalculatorScreen> with SingleTickerProviderStateMixin {
  String _current  = '0';
  String _expr     = '';
  double _first    = 0;
  String _op       = '';
  bool   _newInput = true;
  bool   _justCalc = false;
  bool   _isDeg    = true;
  bool   _isInv    = false;
  bool   _sciOpen  = false;
  bool   _histOpen = false;

  final List<HistoryEntry> _history = [];

  late AnimationController _anim;
  late Animation<double> _sciAnim;
  final FocusNode _focus = FocusNode();

  // Hidden text field controller for capturing physical keyboard on Android
  final TextEditingController _hiddenCtrl = TextEditingController();
  final FocusNode _hiddenFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _anim    = AnimationController(vsync: this, duration: const Duration(milliseconds: 220));
    _sciAnim = CurvedAnimation(parent: _anim, curve: Curves.easeInOut);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focus.requestFocus();
      _hiddenFocus.requestFocus();
    });
    _hiddenCtrl.addListener(_onHiddenTextChange);
  }

  void _onHiddenTextChange() {
    final text = _hiddenCtrl.text;
    if (text.isEmpty) return;
    for (final char in text.characters) {
      _processChar(char);
    }
    _hiddenCtrl.clear();
  }

  void _processChar(String char) {
    switch (char) {
      case '0': case '1': case '2': case '3': case '4':
      case '5': case '6': case '7': case '8': case '9':
        _digit(char); break;
      case '.': case ',': _dot(); break;
      case '+': _inputOp('+'); break;
      case '-': _inputOp('−'); break;
      case '*': _inputOp('×'); break;
      case '/': _inputOp('÷'); break;
      case '=': _calc(); break;
      case '%': setState(() { final v = double.tryParse(_current) ?? 0; _current = _fmt(v / 100); }); break;
      case '^': _inputOp('xʸ'); break;
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    _focus.dispose();
    _hiddenCtrl.dispose();
    _hiddenFocus.dispose();
    super.dispose();
  }

  double get _toRad => _isDeg ? math.pi / 180 : 1.0;

  String _fmt(double v) {
    if (v.isNaN || v.isInfinite) return 'Error';
    if (v == v.truncateToDouble()) return v.toInt().toString();
    String s = v.toStringAsFixed(10);
    s = s.replaceAll(RegExp(r'0+$'), '');
    s = s.replaceAll(RegExp(r'\.$'), '');
    return s;
  }

  void _digit(String d) => setState(() {
    if (_justCalc) { _expr = ''; _current = d; _justCalc = false; _newInput = false; return; }
    if (_newInput) { _current = d; _newInput = false; }
    else if (_current == '0') _current = d;
    else if (_current.length < 14) _current += d;
  });

  void _dot() => setState(() {
    _justCalc = false;
    if (_newInput) { _current = '0.'; _newInput = false; }
    else if (!_current.contains('.')) _current += '.';
  });

  void _inputOp(String op) => setState(() {
    _justCalc = false;
    if (_op.isNotEmpty && !_newInput) _calc(finalize: false);
    _first = double.tryParse(_current) ?? 0;
    _op = op;
    _expr = '${_fmt(_first)} $op';
    _newInput = true;
  });

  void _calc({bool finalize = true}) {
    if (_op.isEmpty) return;
    final b = double.tryParse(_current) ?? 0;
    double r;
    switch (_op) {
      case '+':  r = _first + b; break;
      case '−':  r = _first - b; break;
      case '×':  r = _first * b; break;
      case '÷':  r = b == 0 ? double.nan : _first / b; break;
      case 'xʸ': r = math.pow(_first, b).toDouble(); break;
      default: return;
    }
    if (finalize) {
      final fullExpr = '${_fmt(_first)} $_op ${_fmt(b)}';
      final result   = _fmt(r);
      setState(() {
        _history.insert(0, HistoryEntry(fullExpr, result));
        _expr = '$fullExpr =';
        _current = result;
        _op = ''; _first = r; _newInput = true; _justCalc = true;
      });
    } else {
      _current = _fmt(r); _first = r; _newInput = true;
    }
  }

  void _clear() => setState(() {
    _current = '0'; _expr = ''; _op = ''; _first = 0; _newInput = true; _justCalc = false;
  });

  void _backspace() => setState(() {
    if (_justCalc || _newInput) return;
    if (_current.length <= 1 || (_current.startsWith('-') && _current.length == 2)) {
      _current = '0'; _newInput = true;
    } else {
      _current = _current.substring(0, _current.length - 1);
    }
  });

  void _sciFunc(String fn) {
    final v = double.tryParse(_current) ?? 0;
    double r;
    switch (fn) {
      case 'sin':  r = _isInv ? math.asin(v) / _toRad     : math.sin(v * _toRad); break;
      case 'cos':  r = _isInv ? math.acos(v) / _toRad     : math.cos(v * _toRad); break;
      case 'tan':  r = _isInv ? math.atan(v) / _toRad     : math.tan(v * _toRad); break;
      case 'ln':   r = _isInv ? math.exp(v)                : math.log(v); break;
      case 'log':  r = _isInv ? math.pow(10, v).toDouble() : math.log(v) / math.ln10; break;
      case '²√x':  r = math.sqrt(v); break;
      case 'x²':   r = v * v; break;
      case '1/x':  r = v == 0 ? double.nan : 1 / v; break;
      case 'n!':   r = _factorial(v.toInt()).toDouble(); break;
      case 'π':    setState(() { _current = _fmt(math.pi); _newInput = false; }); return;
      case 'e':    setState(() { _current = _fmt(math.e);  _newInput = false; }); return;
      case 'xʸ':   _inputOp('xʸ'); return;
      default: return;
    }
    final result = _fmt(r);
    setState(() {
      _history.insert(0, HistoryEntry('$fn(${_fmt(v)})', result));
      _expr = '$fn(${_fmt(v)}) =';
      _current = result;
      _newInput = true; _justCalc = true;
    });
  }

  int _factorial(int n) {
    if (n < 0 || n > 20) return -1;
    if (n <= 1) return 1;
    return n * _factorial(n - 1);
  }

  void _onTap(String lbl) {
    switch (lbl) {
      case 'C':    _clear(); break;
      case 'CE':   setState(() { _current = '0'; _newInput = true; }); break;
      case '⌫':   _backspace(); break;
      case '+/-':  setState(() { final v = double.tryParse(_current) ?? 0; _current = _fmt(-v); }); break;
      case '%':    setState(() { final v = double.tryParse(_current) ?? 0; _current = _fmt(v / 100); }); break;
      case '.':    _dot(); break;
      case '=':    _calc(); break;
      case '÷': case '×': case '−': case '+': _inputOp(lbl); break;
      case 'INV':  setState(() => _isInv = !_isInv); break;
      case 'DEG':  setState(() => _isDeg = !_isDeg); break;
      default:
        if (RegExp(r'^\d$').hasMatch(lbl)) _digit(lbl);
        else _sciFunc(lbl);
    }
  }

  KeyEventResult _handleKey(FocusNode n, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    final shift = HardwareKeyboard.instance.isShiftPressed;

    if (shift && k == LogicalKeyboardKey.equal)  { _inputOp('+'); return KeyEventResult.handled; }
    if (shift && k == LogicalKeyboardKey.digit8) { _inputOp('×'); return KeyEventResult.handled; }
    if (shift && k == LogicalKeyboardKey.digit5) { setState(() { final v = double.tryParse(_current) ?? 0; _current = _fmt(v / 100); }); return KeyEventResult.handled; }
    if (shift && k == LogicalKeyboardKey.digit6) { _inputOp('xʸ'); return KeyEventResult.handled; }

    final map = <LogicalKeyboardKey, VoidCallback>{
      LogicalKeyboardKey.digit0: () => _digit('0'), LogicalKeyboardKey.numpad0: () => _digit('0'),
      LogicalKeyboardKey.digit1: () => _digit('1'), LogicalKeyboardKey.numpad1: () => _digit('1'),
      LogicalKeyboardKey.digit2: () => _digit('2'), LogicalKeyboardKey.numpad2: () => _digit('2'),
      LogicalKeyboardKey.digit3: () => _digit('3'), LogicalKeyboardKey.numpad3: () => _digit('3'),
      LogicalKeyboardKey.digit4: () => _digit('4'), LogicalKeyboardKey.numpad4: () => _digit('4'),
      LogicalKeyboardKey.digit5: () => _digit('5'), LogicalKeyboardKey.numpad5: () => _digit('5'),
      LogicalKeyboardKey.digit6: () => _digit('6'), LogicalKeyboardKey.numpad6: () => _digit('6'),
      LogicalKeyboardKey.digit7: () => _digit('7'), LogicalKeyboardKey.numpad7: () => _digit('7'),
      LogicalKeyboardKey.digit8: () => _digit('8'), LogicalKeyboardKey.numpad8: () => _digit('8'),
      LogicalKeyboardKey.digit9: () => _digit('9'), LogicalKeyboardKey.numpad9: () => _digit('9'),
      LogicalKeyboardKey.period: _dot, LogicalKeyboardKey.numpadDecimal: _dot,
      LogicalKeyboardKey.comma: _dot,
      LogicalKeyboardKey.enter: _calc, LogicalKeyboardKey.numpadEnter: _calc,
      LogicalKeyboardKey.equal: _calc,
      LogicalKeyboardKey.escape: _clear,
      LogicalKeyboardKey.delete: _clear,
      LogicalKeyboardKey.backspace: _backspace,
      LogicalKeyboardKey.numpadAdd: () => _inputOp('+'),
      LogicalKeyboardKey.minus: () => _inputOp('−'),
      LogicalKeyboardKey.numpadSubtract: () => _inputOp('−'),
      LogicalKeyboardKey.numpadMultiply: () => _inputOp('×'),
      LogicalKeyboardKey.slash: () => _inputOp('÷'),
      LogicalKeyboardKey.numpadDivide: () => _inputOp('÷'),
    };

    if (map.containsKey(k)) { map[k]!(); return KeyEventResult.handled; }
    return KeyEventResult.ignored;
  }

  String _resolveLabel(String lbl) {
    if (!_isInv) return lbl;
    const inv = {'sin': 'sin⁻¹', 'cos': 'cos⁻¹', 'tan': 'tan⁻¹', 'ln': 'eˣ', 'log': '10ˣ'};
    return inv[lbl] ?? lbl;
  }

  void _openAccentPicker() {
    Color pending = kAccent;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kHistBg,
        title: const Text('Accent color', style: TextStyle(color: kText)),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: pending,
            onColorChanged: (color) => pending = color,
            enableAlpha: false,
            labelTypes: const [],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setAccent(pending);
              Navigator.of(context).pop();
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  Widget _btn(String label, BtnType type) => _Btn(
    label: _resolveLabel(label),
    type: type,
    isActive: (label == 'INV' && _isInv),
    onTap: () => _onTap(label),
  );

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focus,
      onKeyEvent: _handleKey,
      autofocus: true,
      child: Scaffold(
        backgroundColor: kBg,
        body: SafeArea(
          child: Stack(
            children: [
              // Hidden text field for Android physical keyboard
              Positioned(
                left: -1000,
                top: -1000,
                child: TextField(
                  controller: _hiddenCtrl,
                  focusNode: _hiddenFocus,
                  keyboardType: TextInputType.none,
                  enableInteractiveSelection: false,
                  showCursor: false,
                ),
              ),

              Row(children: [
                // ══ LEFT: Calculator ══
                Expanded(
                  flex: 3,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

                    // Title bar
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Row(children: [
                        GestureDetector(
                          onTap: () {
                            setState(() => _sciOpen = !_sciOpen);
                            _sciOpen ? _anim.forward() : _anim.reverse();
                          },
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.menu, color: kText, size: 18),
                            const SizedBox(width: 12),
                            Text(_sciOpen ? 'Scientific' : 'Standard',
                              style: const TextStyle(color: kText, fontSize: 18, fontWeight: FontWeight.w600)),
                            const SizedBox(width: 4),
                            AnimatedRotation(
                              turns: _sciOpen ? 0.5 : 0,
                              duration: const Duration(milliseconds: 220),
                              child: const Icon(Icons.keyboard_arrow_down, color: kTextSub, size: 18),
                            ),
                          ]),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: _openAccentPicker,
                          child: const Padding(
                            padding: EdgeInsets.only(right: 16),
                            child: Icon(Icons.palette_outlined, color: kTextSub, size: 20),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => setState(() => _histOpen = !_histOpen),
                          child: Icon(Icons.history, color: _histOpen ? kAccent : kTextSub, size: 20),
                        ),
                      ]),
                    ),

                    // Display
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        const SizedBox(height: 24),
                        Text(_expr,
                          style: const TextStyle(color: kTextSub, fontSize: 14),
                          textAlign: TextAlign.right,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            _current,
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              color: kText,
                              fontSize: 64,
                              fontWeight: FontWeight.w200,
                            ),
                          ),
                        ),
                      ]),
                    ),

                    // Scientific panel
                    SizeTransition(
                      sizeFactor: _sciAnim,
                      axisAlignment: -1,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(children: [
                          Row(children: [
                            Expanded(child: _btn('INV',  BtnType.special)),
                            Expanded(child: _btn('DEG',  BtnType.special)),
                            Expanded(child: _btn('π',    BtnType.science)),
                            Expanded(child: _btn('e',    BtnType.science)),
                            Expanded(child: _btn('n!',   BtnType.science)),
                          ]),
                          Row(children: [
                            Expanded(child: _btn('sin',  BtnType.science)),
                            Expanded(child: _btn('cos',  BtnType.science)),
                            Expanded(child: _btn('tan',  BtnType.science)),
                            Expanded(child: _btn('ln',   BtnType.science)),
                            Expanded(child: _btn('log',  BtnType.science)),
                          ]),
                          Row(children: [
                            Expanded(child: _btn('x²',   BtnType.science)),
                            Expanded(child: _btn('xʸ',   BtnType.science)),
                            Expanded(child: _btn('²√x',  BtnType.science)),
                            Expanded(child: _btn('1/x',  BtnType.science)),
                            Expanded(child: _btn('%',    BtnType.special)),
                          ]),
                        ]),
                      ),
                    ),

                    const Divider(color: kBorder, height: 1),

                    // Main keypad
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Column(children: [
                          Expanded(child: Row(children: [
                            Expanded(child: _btn('%',   BtnType.special)),
                            Expanded(child: _btn('CE',  BtnType.special)),
                            Expanded(child: _btn('C',   BtnType.special)),
                            Expanded(child: _btn('⌫',  BtnType.special)),
                          ])),
                          Expanded(child: Row(children: [
                            Expanded(child: _btn('1/x', BtnType.science)),
                            Expanded(child: _btn('x²',  BtnType.science)),
                            Expanded(child: _btn('²√x', BtnType.science)),
                            Expanded(child: _btn('÷',   BtnType.operator)),
                          ])),
                          Expanded(child: Row(children: [
                            Expanded(child: _btn('7', BtnType.number)),
                            Expanded(child: _btn('8', BtnType.number)),
                            Expanded(child: _btn('9', BtnType.number)),
                            Expanded(child: _btn('×', BtnType.operator)),
                          ])),
                          Expanded(child: Row(children: [
                            Expanded(child: _btn('4', BtnType.number)),
                            Expanded(child: _btn('5', BtnType.number)),
                            Expanded(child: _btn('6', BtnType.number)),
                            Expanded(child: _btn('−', BtnType.operator)),
                          ])),
                          Expanded(child: Row(children: [
                            Expanded(child: _btn('1', BtnType.number)),
                            Expanded(child: _btn('2', BtnType.number)),
                            Expanded(child: _btn('3', BtnType.number)),
                            Expanded(child: _btn('+', BtnType.operator)),
                          ])),
                          Expanded(child: Row(children: [
                            Expanded(child: _btn('+/-', BtnType.special)),
                            Expanded(child: _btn('0',   BtnType.number)),
                            Expanded(child: _btn('.',   BtnType.number)),
                            Expanded(child: _btn('=',   BtnType.equals)),
                          ])),
                        ]),
                      ),
                    ),
                  ]),
                ),

                // ══ RIGHT: History panel ══
                GestureDetector(
                  onHorizontalDragEnd: (details) {
                    if (details.primaryVelocity != null && details.primaryVelocity! > 200) {
                      setState(() => _histOpen = false);
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeInOut,
                    width: _histOpen ? 220 : 0,
                    decoration: const BoxDecoration(
                      color: kHistBg,
                      border: Border(left: BorderSide(color: kBorder)),
                    ),
                    clipBehavior: Clip.hardEdge,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                        child: Row(children: [
                          const Text('History', style: TextStyle(
                            color: kText, fontSize: 16, fontWeight: FontWeight.w600)),
                          const Spacer(),
                          GestureDetector(
                            onTap: () => setState(() => _histOpen = false),
                            child: const Icon(Icons.close, color: kTextSub, size: 18),
                          ),
                          if (_history.isNotEmpty) ...[
                            const SizedBox(width: 12),
                            GestureDetector(
                              onTap: () => setState(() => _history.clear()),
                              child: const Icon(Icons.delete_outline, color: kTextSub, size: 18),
                            ),
                          ],
                        ]),
                      ),
                      const Divider(color: kBorder, height: 1),
                      Expanded(
                        child: _history.isEmpty
                          ? const Center(child: Text('No history yet',
                              style: TextStyle(color: kTextSub, fontSize: 13)))
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              itemCount: _history.length,
                              itemBuilder: (_, i) {
                                final h = _history[i];
                                return GestureDetector(
                                  onTap: () => setState(() {
                                    _current = h.result;
                                    _newInput = true;
                                    _justCalc = true;
                                  }),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    decoration: BoxDecoration(
                                      border: Border(bottom: BorderSide(color: kBorder.withOpacity(0.5))),
                                    ),
                                    child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                      Text(h.expression, style: const TextStyle(color: kTextSub, fontSize: 12)),
                                      const SizedBox(height: 2),
                                      Text(h.result, style: const TextStyle(
                                        color: kText, fontSize: 18, fontWeight: FontWeight.w300)),
                                    ]),
                                  ),
                                );
                              },
                            ),
                      ),
                    ]),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _Btn extends StatefulWidget {
  final String label;
  final BtnType type;
  final bool isActive;
  final VoidCallback onTap;
  const _Btn({required this.label, required this.type, required this.onTap, this.isActive = false});
  @override
  State<_Btn> createState() => _BtnState();
}

class _BtnState extends State<_Btn> {
  bool _pressed = false;

  Color get _bg {
    if (widget.isActive) return kAccent.withOpacity(0.2);
    switch (widget.type) {
      case BtnType.equals:   return kAccent.withOpacity(0.25);
      case BtnType.operator: return kBtnOp;
      case BtnType.special:  return kBtnSpec;
      case BtnType.science:  return kBtnSci;
      case BtnType.number:   return kBtnNum;
    }
  }

  Color get _fg {
    if (widget.isActive) return kAccent;
    switch (widget.type) {
      case BtnType.equals:  return kAccent;
      case BtnType.science: return const Color(0xFFBBBBBB);
      default:              return kText;
    }
  }

  double get _fontSize {
    if (widget.label.length > 4) return 12;
    if (widget.label.length > 2) return 14;
    return 18;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(2),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) { setState(() => _pressed = false); widget.onTap(); },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 60),
          decoration: BoxDecoration(
            color: _pressed ? _bg.withOpacity(0.5) : _bg,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Center(child: Text(widget.label, style: TextStyle(
            color: _fg, fontSize: _fontSize, fontWeight: FontWeight.w400,
          ))),
        ),
      ),
    );
  }
}