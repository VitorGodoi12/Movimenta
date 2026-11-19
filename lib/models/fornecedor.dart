class Fornecedor {
  Fornecedor({
    required this.id,
    required this.nome,
    this.telefone = '',
  });

  final String id;
  String nome;

  /// Número com DDD, usado para abrir o WhatsApp.
  String telefone;

  Map<String, dynamic> toJson() => {
        'id': id,
        'nome': nome,
        'telefone': telefone,
      };

  factory Fornecedor.fromJson(Map<String, dynamic> j) => Fornecedor(
        id: j['id'] as String,
        nome: j['nome'] as String,
        telefone: (j['telefone'] as String?) ?? '',
      );
}
