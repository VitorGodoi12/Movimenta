class Cliente {
  const Cliente({
    required this.nome,
    required this.estabelecimento,
    this.email = '',
    this.apelido = '',
    this.foto,
    this.corAvatar = 0,
  });

  final String nome;
  final String estabelecimento;
  final String email;
  final String apelido;
  final String? foto;
  final int corAvatar;

  String get nomeExibicao => apelido.trim().isEmpty ? nome : apelido.trim();

  String get primeiroNome => nome.trim().split(' ').first;

  Map<String, dynamic> toJson() => {
    'nome': nome,
    'estabelecimento': estabelecimento,
    'email': email,
    'apelido': apelido,
    'foto': foto,
    'corAvatar': corAvatar,
  };

  factory Cliente.fromJson(Map<String, dynamic> j) => Cliente(
    nome: j['nome'] as String,
    estabelecimento: j['estabelecimento'] as String,
    email: (j['email'] as String?) ?? '',
    apelido: (j['apelido'] as String?) ?? '',
    foto: j['foto'] as String?,
    corAvatar: (j['corAvatar'] as num?)?.toInt() ?? 0,
  );
}
