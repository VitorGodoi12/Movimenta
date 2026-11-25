import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:stokio/utils/formatadores.dart';

class CampoData extends StatefulWidget {
  const CampoData({
    super.key,
    required this.rotulo,
    required this.valor,
    required this.aoMudar,
  });

  final String rotulo;
  final DateTime? valor;
  final ValueChanged<DateTime?> aoMudar;

  @override
  State<CampoData> createState() => _CampoDataState();
}

class _CampoDataState extends State<CampoData> {
  late final _texto = TextEditingController(
    text: widget.valor == null ? '' : formatarData(widget.valor!),
  );

  DateTime? _ler(String texto) {
    if (!RegExp(r'^\d{2}/\d{2}/\d{4}$').hasMatch(texto)) return null;
    final [dia, mes, ano] = texto.split('/').map(int.parse).toList();
    final data = DateTime(ano, mes, dia);
    return ano >= 1900 && data.day == dia && data.month == mes ? data : null;
  }

  Future<void> _calendario() async {
    final agora = DateTime.now();
    final ultimo = DateTime(agora.year + 30, 12, 31);
    final valor = _ler(_texto.text);
    final data = await showDatePicker(
      context: context,
      initialDate: valor != null && !valor.isAfter(ultimo) ? valor : agora,
      firstDate: DateTime(1900),
      lastDate: ultimo,
      helpText: widget.rotulo,
    );
    if (data == null || !mounted) return;
    _texto.text = formatarData(data);
    widget.aoMudar(data);
  }

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: _texto,
    keyboardType: TextInputType.number,
    inputFormatters: [
      TextInputFormatter.withFunction((antes, depois) {
        final digitos = depois.text.replaceAll(RegExp(r'\D'), '');
        if (digitos.length > 8) return antes;
        if (antes.text == '$digitos/' && depois.text == digitos) return depois;
        final texto = [
          digitos.substring(0, digitos.length.clamp(0, 2)),
          if (digitos.length > 2)
            digitos.substring(2, digitos.length.clamp(2, 4)),
          if (digitos.length > 4) digitos.substring(4),
        ].join('/');
        return TextEditingValue(
          text: texto,
          selection: TextSelection.collapsed(offset: texto.length),
        );
      }),
    ],
    decoration: InputDecoration(
      labelText: widget.rotulo,
      hintText: 'DD/MM/AAAA',
      suffixIcon: IconButton(
        tooltip: 'Abrir calendário',
        icon: const Icon(Icons.calendar_today_outlined),
        onPressed: _calendario,
      ),
    ),
    validator: (texto) =>
        texto != null && texto.isNotEmpty && _ler(texto) == null
        ? 'Digite uma data válida em DD/MM/AAAA.'
        : null,
    onChanged: (texto) => widget.aoMudar(_ler(texto)),
  );
}
