import 'package:flutter/material.dart';
import 'package:movimenta/utils/formatadores.dart';

/// Campo que abre o calendário. O "x" limpa a data.
class CampoData extends StatelessWidget {
  const CampoData({
    super.key,
    required this.rotulo,
    required this.valor,
    required this.aoMudar,
  });

  final String rotulo;
  final DateTime? valor;
  final ValueChanged<DateTime?> aoMudar;

  Future<void> _escolher(BuildContext context) async {
    final agora = DateTime.now();
    final data = await showDatePicker(
      context: context,
      initialDate: valor ?? agora,
      firstDate: DateTime(agora.year - 2),
      lastDate: DateTime(agora.year + 10),
      helpText: rotulo,
      cancelText: 'Cancelar',
      confirmText: 'Escolher',
    );
    if (data != null) aoMudar(data);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _escolher(context),
      child: InputDecorator(
        isEmpty: valor == null,
        decoration: InputDecoration(
          labelText: rotulo,
          suffixIcon: valor == null
              ? const Icon(Icons.calendar_today_outlined, size: 20)
              : IconButton(
                  tooltip: 'Limpar data',
                  icon: const Icon(Icons.close),
                  onPressed: () => aoMudar(null),
                ),
        ),
        child: Text(valor == null ? '' : formatarData(valor!)),
      ),
    );
  }
}
