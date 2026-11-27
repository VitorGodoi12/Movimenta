const { randomBytes, createHash } = require('node:crypto');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue, Timestamp } = require('firebase-admin/firestore');
const { onCall, HttpsError } = require('firebase-functions/v2/https');

initializeApp();
const db = getFirestore();
const users = db.collection('users');
const mercados = db.collection('mercados');
const cargos = ['dono', 'gerente', 'funcionario'];

function falhar(codigo, mensagem) {
  throw new HttpsError(codigo, mensagem);
}

function texto(valor, max, opcional = false) {
  if (valor == null && opcional) return '';
  if (typeof valor !== 'string' || valor.trim().length > max ||
      (!opcional && !valor.trim())) falhar('invalid-argument', 'Confira os campos.');
  return valor.trim();
}

function id(valor) {
  const s = texto(valor, 128);
  if (s.includes('/') || s === '.' || s === '..') falhar('invalid-argument', 'Identificador inválido.');
  return s;
}

function emailId(valor) {
  const email = texto(valor, 254).toLowerCase();
  if (!email.includes('@')) falhar('invalid-argument', 'Informe o e-mail completo.');
  return createHash('sha256').update(email).digest('hex');
}

function sessao(req) {
  if (!req.auth) falhar('unauthenticated', 'Entre para continuar.');
  if (req.auth.token.email_verified !== true) falhar('permission-denied', 'Confirme o e-mail da sua conta.');
  return req.auth;
}

function gerente(perfil) {
  if (perfil?.status !== 'ativo' || !['dono', 'gerente'].includes(perfil.cargo)) {
    falhar('permission-denied', 'Esta ação exige dono ou gerente.');
  }
  return perfil.mercadoId;
}

function dadosPessoais(req) {
  const auth = sessao(req);
  const telefone = texto(req.data.telefone, 24).replace(/\D/g, '');
  if (!/^\d{11}$/.test(telefone)) falhar('invalid-argument', 'Informe telefone com DDD e 11 dígitos.');
  return { nome: texto(req.data.nome, 100), telefone, email: texto(auth.token.email, 254) };
}

function destinoConsulta(dados) {
  if (dados.email) return db.collection('indice_donos').doc(emailId(dados.email));
  const codigo = texto(dados.codigo, 16).toUpperCase();
  if (!/^MKT-[A-F0-9]{4}$/.test(codigo)) falhar('invalid-argument', 'Código inválido.');
  return db.collection('convites').doc(codigo);
}

exports.criarMercado = onCall(async (req) => {
  const { uid } = sessao(req);
  const dados = dadosPessoais(req);
  const nome = texto(req.data.mercado, 120);
  const endereco = texto(req.data.endereco, 250, true);
  const mercado = mercados.doc(uid);
  for (let tentativa = 0; tentativa < 8; tentativa++) {
    const codigo = 'MKT-' + randomBytes(2).toString('hex').toUpperCase();
    const convite = db.collection('convites').doc(codigo);
    const indice = db.collection('indice_donos').doc(emailId(dados.email));
    const resultado = await db.runTransaction(async (tx) => {
      const [usuario, existente, ocupado, dono] =
        await tx.getAll(users.doc(uid), mercado, convite, indice);
      if (existente.exists && usuario.data()?.cargo === 'dono' &&
          usuario.data()?.mercadoId === mercado.id && usuario.data()?.status === 'ativo') {
        return { codigo: existente.data().codigoConvite };
      }
      if (usuario.exists || existente.exists || dono.exists) falhar('failed-precondition', 'Já existe um vínculo para esta conta.');
      if (ocupado.exists) return null;
      tx.create(mercado, { nome, endereco, codigoConvite: codigo, criadoPor: uid, criadoEm: FieldValue.serverTimestamp() });
      tx.create(convite, { mercadoId: mercado.id });
      tx.create(indice, { mercadoId: mercado.id });
      tx.create(users.doc(uid), { ...dados, mercadoId: mercado.id, cargo: 'dono', status: 'ativo' });
      return { codigo };
    });
    if (resultado) return resultado;
  }
  falhar('resource-exhausted', 'Não foi possível reservar um código. Tente novamente.');
});

exports.buscarMercado = onCall(async (req) => {
  const { uid } = sessao(req);
  const atual = (await users.doc(uid).get()).data();
  if (atual?.status === 'ativo' || atual?.status === 'pendente') falhar('failed-precondition', 'Você já tem um vínculo ou pedido.');
  const pista = (await destinoConsulta(req.data).get()).data();
  if (!pista) return null;
  const mercado = (await mercados.doc(pista.mercadoId).get()).data();
  return mercado ? { nome: mercado.nome } : null;
});

exports.solicitarAcesso = onCall(async (req) => {
  const { uid } = sessao(req);
  const dados = dadosPessoais(req);
  return db.runTransaction(async (tx) => {
    const [usuario, pista] = await tx.getAll(users.doc(uid), destinoConsulta(req.data));
    const mercadoId = pista.data()?.mercadoId;
    if (!mercadoId) falhar('not-found', 'Mercado não encontrado.');
    const mercado = await tx.get(mercados.doc(mercadoId));
    if (mercado.data()?.nome !== req.data.nomeConfirmado) falhar('failed-precondition', 'Busque e confirme o mercado novamente.');
    const atual = usuario.data();
    if (atual?.status === 'pendente' && atual.mercadoId === mercadoId) return { ok: true };
    if (atual?.status === 'ativo' || atual?.status === 'pendente') falhar('failed-precondition', 'Já existe um vínculo ou pedido.');
    tx.set(users.doc(uid), { ...dados, mercadoId, cargo: 'funcionario', status: 'pendente' });
    return { ok: true };
  });
});

exports.alterarEquipe = onCall(async (req) => {
  const { uid } = sessao(req);
  const alvo = id(req.data.uid);
  const acao = texto(req.data.acao, 24);
  const cargo = req.data.cargo;
  if (alvo === uid) falhar('permission-denied', 'Você não pode mudar o próprio vínculo.');
  return db.runTransaction(async (tx) => {
    const [autor, membro] = await tx.getAll(users.doc(uid), users.doc(alvo));
    const mercadoId = gerente(autor.data());
    const atual = membro.data();
    if (atual?.mercadoId !== mercadoId) falhar('permission-denied', 'O usuário pertence a outro mercado.');
    let mudanca;
    if (acao === 'aprovar' && atual.status === 'pendente' && cargos.includes(cargo)) {
      mudanca = { status: 'ativo', cargo };
    } else if (acao === 'recusar' && atual.status === 'pendente') {
      mudanca = { status: 'recusado', cargo: 'funcionario' };
    } else if (acao === 'cargo' && atual.status === 'ativo' && cargos.includes(cargo)) {
      mudanca = { cargo };
    } else if (acao === 'remover' && atual.status === 'ativo') {
      mudanca = { status: 'removido', cargo: 'funcionario' };
    } else falhar('failed-precondition', 'A ação não se aplica ao vínculo atual.');
    if (atual.status === 'ativo' && atual.cargo === 'dono' && mudanca.cargo !== 'dono') {
      const donos = await tx.get(users.where('mercadoId', '==', mercadoId).where('status', '==', 'ativo').where('cargo', '==', 'dono'));
      if (donos.size <= 1) falhar('failed-precondition', 'O mercado precisa de um dono ativo.');
    }
    tx.update(membro.ref, mudanca);
    return { ok: true };
  });
});

exports.confirmarEntrada = onCall(async (req) => {
  const { uid } = sessao(req);
  const dados = req.data;
  const entradaId = id(dados.entradaId);
  const codigo = texto(dados.codigoBarras, 40, true);
  if (codigo && !/^[A-Za-z0-9_-]+$/.test(codigo)) falhar('invalid-argument', 'Código inválido.');
  const chave = /^(?:\d{8}|\d{12,14})$/.test(codigo) ? codigo.padStart(14, '0') : codigo;
  const produtoId = chave ? 'cod_' + chave : 'manual_' + entradaId;
  const nome = texto(dados.nome, 180).toUpperCase();
  const categoria = texto(dados.categoria, 80);
  const corredorId = texto(dados.corredorId, 128, true);
  if (corredorId) id(corredorId);
  const preco = dados.preco;
  if (typeof preco !== 'number' || !Number.isFinite(preco) || preco < 0 || preco > 9999999) falhar('invalid-argument', 'Preço inválido.');
  if (!Array.isArray(dados.lotes) || !dados.lotes.length || dados.lotes.length > 50) falhar('invalid-argument', 'Confira os lotes.');
  const lotes = dados.lotes.map((lote) => {
    if (!Number.isInteger(lote.quantidade) || lote.quantidade < 1 || lote.quantidade > 999999999 || !['loja', 'estoque'].includes(lote.destino)) falhar('invalid-argument', 'Confira quantidade e destino.');
    let validade = null;
    if (lote.validade != null) {
      const valor = texto(lote.validade, 40);
      const data = new Date(valor);
      if (!Number.isFinite(data.valueOf())) falhar('invalid-argument', 'Validade inválida.');
      validade = Timestamp.fromDate(data);
    }
    return { quantidade: lote.quantidade, destino: lote.destino, validade };
  });
  return db.runTransaction(async (tx) => {
    const mercadoId = gerente((await tx.get(users.doc(uid))).data());
    if (dados.mercadoId !== mercadoId) falhar('permission-denied', 'O mercado da entrada mudou.');
    const mercado = mercados.doc(mercadoId);
    const produto = mercado.collection('produtos').doc(produtoId);
    const entrada = mercado.collection('entradas').doc(entradaId);
    const [anterior, repetida] = await tx.getAll(produto, entrada);
    if (repetida.exists) return { produtoId: repetida.data().produtoId };
    if (corredorId && !(await tx.get(mercado.collection('corredores').doc(corredorId))).exists) {
      falhar('failed-precondition', 'Corredor não encontrado.');
    }
    const catalogo = chave && /^\d{14}$/.test(chave) ? db.collection('catalogo_produtos').doc(chave) : null;
    const novoGlobal = catalogo && dados.publicarNoCatalogo === true && !(await tx.get(catalogo)).exists;
    const total = lotes.reduce((soma, l) => soma + l.quantidade, 0);
    tx.set(produto, {
      codigoBarras: codigo,
      nome,
      categoria,
      preco,
      corredorId,
      unidade: texto(dados.unidade, 24),
      quantidade: (anterior.data()?.quantidade ?? 0) + total,
      naLoja: anterior.data()?.naLoja === true || lotes.some(l => l.destino === 'loja'),
      adicionadoPor: anterior.data()?.adicionadoPor ?? uid,
      atualizadoEm: FieldValue.serverTimestamp(),
    });
    lotes.forEach((lote, i) => tx.create(produto.collection('lotes').doc(entradaId + '_' + i), {
      ...lote, corredorId, adicionadoPor: uid, atualizadoEm: FieldValue.serverTimestamp(),
    }));
    if (novoGlobal) tx.create(catalogo, { codigoBarras: chave, nome, categoria, fonte: 'Confirmação de mercado' });
    tx.create(entrada, { produtoId, uid, criadoEm: FieldValue.serverTimestamp() });
    return { produtoId };
  });
});
