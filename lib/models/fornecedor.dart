class Fornecedor {
  Fornecedor({
    required this.id,
    required this.nome,
    this.telefone = '',
    this.prazoDias = 3,
  });

  final String id;
  String nome;

  /// Número com DDD, usado para abrir o WhatsApp.
  String telefone;
  int prazoDias;

  Map<String, dynamic> toJson() => {
    'id': id,
    'nome': nome,
    'telefone': telefone,
    'prazoDias': prazoDias,
  };

  factory Fornecedor.fromJson(Map<String, dynamic> j) => Fornecedor(
    id: j['id'] as String,
    nome: j['nome'] as String,
    telefone: (j['telefone'] as String?) ?? '',
    prazoDias: (j['prazoDias'] as num?)?.toInt() ?? 3,
  );
}
