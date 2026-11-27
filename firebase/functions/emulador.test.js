const { initializeApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const assert = require('node:assert/strict');

const projeto = 'demo-movimenta';
const authHost = process.env.FIREBASE_AUTH_EMULATOR_HOST;
const storeHost = process.env.FIRESTORE_EMULATOR_HOST;
if (!authHost || !storeHost) throw new Error('Execute com firebase emulators:exec --project demo-movimenta.');
initializeApp({ projectId: projeto });

async function usuario(nome) {
  const email = nome + '@example.test';
  const password = 'Teste-local-2026';
  const user = await getAuth().createUser({ email, password, emailVerified: true });
  const res = await fetch('http://' + authHost + '/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=demo-key', {
    method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password, returnSecureToken: true }),
  });
  assert.equal(res.ok, true);
  return { uid: user.uid, token: (await res.json()).idToken, nome };
}

async function chamar(user, funcao, data, erro = false) {
  const res = await fetch('http://127.0.0.1:5001/' + projeto + '/us-central1/' + funcao, {
    method: 'POST', headers: { 'Content-Type': 'application/json', Authorization: 'Bearer ' + user.token },
    body: JSON.stringify({ data }),
  });
  const body = await res.json();
  if (erro) assert.equal(res.ok, false, JSON.stringify(body));
  else assert.equal(res.ok, true, JSON.stringify(body));
  return body.result;
}

async function documento(user, caminho, init = {}) {
  return fetch('http://' + storeHost + '/v1/projects/' + projeto + '/databases/(default)/documents/' + caminho, {
    ...init, headers: { Authorization: 'Bearer ' + user.token, 'Content-Type': 'application/json' },
  });
}

async function main() {
  const [dono, funcionario, outroDono] = await Promise.all(['dono', 'funcionario', 'outro'].map(usuario));
  const dados = { nome: 'Dono Teste', telefone: '11999998888', mercado: 'Mercado Teste' };
  const criado = await chamar(dono, 'criarMercado', dados);
  assert.deepEqual(await chamar(dono, 'criarMercado', dados), criado);
  await chamar(outroDono, 'criarMercado', { ...dados, mercado: 'Outro Mercado' });

  const busca = await chamar(funcionario, 'buscarMercado', { email: 'dono@example.test' });
  assert.deepEqual(busca, { nome: 'Mercado Teste' });
  const pedido = { nome: 'Funcionário Teste', telefone: dados.telefone, nomeConfirmado: busca.nome, codigo: criado.codigo };
  await chamar(funcionario, 'solicitarAcesso', pedido);
  await chamar(funcionario, 'solicitarAcesso', pedido);
  assert.equal((await documento(funcionario, 'mercados/' + dono.uid)).status, 403);
  await chamar(funcionario, 'alterarEquipe', { uid: funcionario.uid, acao: 'aprovar', cargo: 'dono' }, true);
  await chamar(outroDono, 'alterarEquipe', { uid: funcionario.uid, acao: 'aprovar', cargo: 'gerente' }, true);
  await chamar(dono, 'alterarEquipe', { uid: funcionario.uid, acao: 'aprovar', cargo: 'funcionario' });
  assert.equal((await documento(funcionario, 'mercados/' + dono.uid)).status, 200);
  assert.equal((await documento(funcionario, 'mercados/' + outroDono.uid)).status, 403);

  const entrada = {
    entradaId: 'entrada-idempotente', mercadoId: dono.uid, codigoBarras: '7896005801512',
    nome: 'Café', categoria: 'Cafés', unidade: 'un', preco: 12.5,
    lotes: [
      { quantidade: 2, destino: 'estoque', validade: '2028-01-10T00:00:00Z' },
      { quantidade: 4, destino: 'loja', validade: '2028-01-20T00:00:00Z' },
    ],
  };
  const confirmado = await chamar(dono, 'confirmarEntrada', entrada);
  assert.deepEqual(await chamar(dono, 'confirmarEntrada', entrada), confirmado);
  await chamar(funcionario, 'confirmarEntrada', entrada, true);
  const caminho = 'mercados/' + dono.uid + '/produtos/' + confirmado.produtoId;
  const produto = await documento(dono, caminho);
  assert.equal((await produto.json()).fields.quantidade.integerValue, '6');
  assert.equal((await documento(funcionario, caminho + '/lotes/entrada-idempotente_0')).status, 403);
  assert.equal((await documento(funcionario, caminho + '/lotes/entrada-idempotente_1')).status, 200);
  assert.equal((await documento(funcionario, 'users/' + funcionario.uid + '?updateMask.fieldPaths=cargo', {
    method: 'PATCH', body: JSON.stringify({ fields: { cargo: { stringValue: 'dono' } } }),
  })).status, 403);
  await chamar(dono, 'alterarEquipe', { uid: funcionario.uid, acao: 'cargo', cargo: 'gerente' });
  await chamar(funcionario, 'alterarEquipe', { uid: dono.uid, acao: 'remover' }, true);
  console.log('Convite, vínculo, isolamento, lote por destino e idempotência verificados.');
}

main().catch(erro => { console.error(erro); process.exitCode = 1; });
