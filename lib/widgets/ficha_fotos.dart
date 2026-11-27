import 'package:flutter/material.dart';
import 'package:stokio/models/foto_cadastro.dart';

class FichaFotos extends StatelessWidget {
  const FichaFotos({
    super.key,
    required this.fotos,
    required this.ocupado,
    required this.capturar,
    required this.catalogo,
    required this.bipar,
  });

  final Map<FinalidadeFoto, FotoCadastro> fotos;
  final bool ocupado;
  final ValueChanged<FinalidadeFoto> capturar;
  final VoidCallback catalogo;
  final VoidCallback bipar;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      OutlinedButton.icon(
        onPressed: ocupado ? null : catalogo,
        icon: const Icon(Icons.inventory_2_outlined),
        label: const Text('Usar catálogo de produtos'),
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: ocupado ? null : bipar,
        icon: const Icon(Icons.qr_code_scanner),
        label: const Text('Bipar código de barras'),
      ),
      for (final (tipo, rotulo) in const [
        (FinalidadeFoto.produto, 'Fotografar produto, fardo ou caixa'),
        (FinalidadeFoto.validade, 'Fotografar validade'),
        (FinalidadeFoto.preco, 'Fotografar preço'),
      ])
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            enabled: !ocupado,
            onTap: ocupado ? null : () => capturar(tipo),
            leading: fotos[tipo] == null
                ? const Icon(Icons.camera_alt_outlined)
                : ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      fotos[tipo]!.imagem,
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                    ),
                  ),
            title: Text(rotulo),
            subtitle: fotos[tipo] == null
                ? null
                : const Text('Toque para refazer'),
            trailing: const Icon(Icons.chevron_right),
          ),
        ),
      if (ocupado)
        const LinearProgressIndicator(semanticsLabel: 'Analisando foto'),
    ],
  );
}
