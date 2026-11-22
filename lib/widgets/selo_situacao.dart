import 'package:flutter/material.dart';
import 'package:stokio/models/produto.dart';
import 'package:stokio/theme/app_theme.dart';
import 'package:stokio/utils/formatadores.dart';

extension SituacaoVisual on SituacaoEstoque {
  Color get cor => switch (this) {
    SituacaoEstoque.normal => AppCores.roxo,
    SituacaoEstoque.baixo => AppCores.baixo,
    SituacaoEstoque.zerado => AppCores.zerado,
  };

  Color get fundo => switch (this) {
    SituacaoEstoque.normal => AppCores.roxoSuave,
    SituacaoEstoque.baixo => AppCores.baixoFundo,
    SituacaoEstoque.zerado => AppCores.zeradoFundo,
  };

  String get rotulo => switch (this) {
    SituacaoEstoque.normal => 'Em dia',
    SituacaoEstoque.baixo => 'Acabando',
    SituacaoEstoque.zerado => 'Zerado',
  };
}

class _Selo extends StatelessWidget {
  const _Selo({required this.cor, required this.fundo, required this.texto});

  final Color cor;
  final Color fundo;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: fundo,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: cor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            texto,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class SeloSituacao extends StatelessWidget {
  const SeloSituacao({super.key, required this.situacao});

  final SituacaoEstoque situacao;

  @override
  Widget build(BuildContext context) {
    if (situacao == SituacaoEstoque.normal) return const SizedBox.shrink();
    return _Selo(
      cor: situacao.cor,
      fundo: situacao.fundo,
      texto: situacao.rotulo,
    );
  }
}

class SeloValidade extends StatelessWidget {
  const SeloValidade({super.key, required this.situacao, required this.dias});

  final SituacaoValidade situacao;
  final int? dias;

  @override
  Widget build(BuildContext context) {
    if (dias == null) return const SizedBox.shrink();
    return switch (situacao) {
      SituacaoValidade.vencido => _Selo(
        cor: AppCores.zerado,
        fundo: AppCores.zeradoFundo,
        texto: descreverValidade(dias!),
      ),
      SituacaoValidade.vencendo => _Selo(
        cor: AppCores.baixo,
        fundo: AppCores.baixoFundo,
        texto: descreverValidade(dias!),
      ),
      _ => const SizedBox.shrink(),
    };
  }
}
