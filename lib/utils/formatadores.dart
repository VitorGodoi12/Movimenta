String _dois(int n) => n.toString().padLeft(2, '0');

String formatarPreco(double valor) {
  final negativo = valor < 0;
  final partes = valor.abs().toStringAsFixed(2).split('.');
  final inteiro = partes[0];
  final buffer = StringBuffer();
  for (var i = 0; i < inteiro.length; i++) {
    if (i > 0 && (inteiro.length - i) % 3 == 0) buffer.write('.');
    buffer.write(inteiro[i]);
  }
  final sinal = negativo ? '-' : '';
  return '${sinal}R\$ $buffer,${partes[1]}';
}

String formatarData(DateTime d) => '${_dois(d.day)}/${_dois(d.month)}/${d.year}';

String formatarHora(DateTime d) => '${_dois(d.hour)}:${_dois(d.minute)}';

/// Quantos dias se passaram desde [d] até hoje (negativo se for no futuro).
int diasDesde(DateTime d) {
  final antes = DateTime.utc(d.year, d.month, d.day);
  final agora = DateTime.now();
  final hoje = DateTime.utc(agora.year, agora.month, agora.day);
  return hoje.difference(antes).inDays;
}

String rotuloDia(DateTime d) {
  final n = diasDesde(d);
  if (n == 0) return 'Hoje';
  if (n == 1) return 'Ontem';
  return formatarData(d);
}

String formatarQuando(DateTime d) {
  final n = diasDesde(d);
  final hora = formatarHora(d);
  if (n == 0) return 'Hoje, $hora';
  if (n == 1) return 'Ontem, $hora';
  return '${_dois(d.day)}/${_dois(d.month)}, $hora';
}

String descreverValidade(int dias) {
  if (dias < -1) return 'Venceu há ${-dias} dias';
  if (dias == -1) return 'Venceu ontem';
  if (dias == 0) return 'Vence hoje';
  if (dias == 1) return 'Vence amanhã';
  return 'Vence em $dias dias';
}
