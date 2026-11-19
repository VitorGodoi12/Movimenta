class Cliente {
  const Cliente({
    required this.nome,
    required this.estabelecimento,
    this.email = '',
  });

  final String nome;
  final String estabelecimento;
  final String email;

  String get primeiroNome => nome.trim().split(' ').first;

  Map<String, dynamic> toJson() => {
        'nome': nome,
        'estabelecimento': estabelecimento,
        'email': email,
      };

  factory Cliente.fromJson(Map<String, dynamic> j) => Cliente(
        nome: j['nome'] as String,
        estabelecimento: j['estabelecimento'] as String,
        email: (j['email'] as String?) ?? '',
      );
}
