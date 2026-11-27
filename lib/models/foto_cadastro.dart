import 'dart:typed_data';

enum FinalidadeFoto { produto, validade, preco }

typedef ValidadeLida = ({DateTime data, String rotulo});
typedef PrecoLido = ({double valor, String trecho});

class FotoCadastro {
  const FotoCadastro({
    required this.imagem,
    required this.texto,
    required this.codigos,
  });

  final Uint8List imagem;
  final String texto;
  final List<String> codigos;

  List<ValidadeLida> get validades {
    final resultado = <DateTime, ValidadeLida>{};
    final completos = RegExp(r'\b(\d{1,2})([/.-])(\d{1,2})\2(\d{4}|\d{2})\b');
    final meses = RegExp(r'\b(0?[1-9]|1[0-2])[/.-](20\d{2})\b');
    final ocupados = completos.allMatches(texto).toList();
    for (final trecho in ocupados) {
      final dia = int.parse(trecho[1]!);
      final mes = int.parse(trecho[3]!);
      final ano = int.parse(trecho[4]!) + (trecho[4]!.length == 2 ? 2000 : 0);
      if (ano < 1900 || ano > 2199 || mes < 1 || mes > 12) continue;
      final data = DateTime(ano, mes, dia);
      if (data.day != dia || data.month != mes) continue;
      final rotulo = trecho[0]!;
      resultado[data] = (data: data, rotulo: rotulo);
    }
    for (final trecho in meses.allMatches(texto)) {
      if (ocupados.any((m) => m.start < trecho.end && trecho.start < m.end)) {
        continue;
      }
      final data = DateTime(
        int.parse(trecho[2]!),
        int.parse(trecho[1]!) + 1,
        0,
      );
      resultado.putIfAbsent(data, () => (data: data, rotulo: trecho[0]!));
    }
    return resultado.values.toList()..sort((a, b) => b.data.compareTo(a.data));
  }

  List<PrecoLido> get precos {
    final resultado = <PrecoLido>[];
    final numeros = RegExp(
      r'(R\$\s*)?\b(\d{1,3}(?:\.\d{3})+|\d+),(\d{2})\b',
      caseSensitive: false,
    );
    for (final linha in texto.split('\n')) {
      for (final m in numeros.allMatches(linha)) {
        final antes = linha.substring(0, m.start).toLowerCase();
        final depois = linha.substring(m.end).trimLeft().toLowerCase();
        if (RegExp(r'[/.,\d]$').hasMatch(antes) ||
            depois.startsWith('/') ||
            (m[1] == null &&
                RegExp(r'^(kg|mg|ml|g|l|cm|mm|%)\b').hasMatch(depois)) ||
            RegExp(r'\d+\s*[x×]\s*$').hasMatch(antes) ||
            (m[1] == null &&
                RegExp(r'parcel|prestaç').hasMatch(linha.toLowerCase()))) {
          continue;
        }
        final valor = double.tryParse(m[2]!.replaceAll('.', '') + '.' + m[3]!);
        if (valor != null && valor.isFinite && valor <= 9999999) {
          final candidato = (valor: valor, trecho: linha.trim());
          if (!resultado.contains(candidato)) resultado.add(candidato);
        }
      }
    }
    return resultado;
  }

  String get consulta {
    final linhas = texto
        .split('\n')
        .map((s) => s.trim())
        .where(
          (s) => s.length >= 3 && RegExp(r'\p{L}', unicode: true).hasMatch(s),
        );
    return linhas.take(3).join(' ');
  }

  int? get unidadesPorVolume {
    final correspondencia = RegExp(
      r'\b(\d{1,3})\s*(?:un(?:id(?:ades?)?)?|garrafas?|latas?)\b',
      caseSensitive: false,
    ).firstMatch(texto);
    return int.tryParse(correspondencia?[1] ?? '');
  }
}
