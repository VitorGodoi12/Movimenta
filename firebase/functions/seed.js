const { initializeApp, applicationDefault } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const itens = require('./catalogo-seed.json');

function codigoValido(codigo) {
  return /^\d{14}$/.test(codigo) &&
    Array.from(codigo).reduce((soma, n, i) => soma + Number(n) * (i % 2 === 0 ? 3 : 1), 0) % 10 === 0;
}

async function main() {
  const projeto = process.argv[2];
  const validos = itens.length >= 35 && itens.length <= 40 &&
    new Set(itens.map(i => i.codigoBarras)).size === itens.length &&
    itens.every(i => codigoValido(i.codigoBarras) && i.nome && i.fonte);
  if (!validos) throw new Error('Catálogo de carga inválido.');
  if (process.argv.includes('--dry-run')) {
    console.log(itens.length + ' registros com GTIN válido e fonte declarada.');
    return;
  }
  if (!projeto || !/^[a-z][a-z0-9-]+$/.test(projeto) || !process.argv.includes('--confirmar')) {
    throw new Error('Uso: node seed.js ID_DO_PROJETO --confirmar');
  }

  initializeApp({ projectId: projeto, credential: applicationDefault() });
  const db = getFirestore();
  const catalogo = db.collection('catalogo_produtos');
  const marcador = db.collection('config_interna').doc('catalogo_v1');
  const inseridos = await db.runTransaction(async tx => {
    const anterior = await tx.get(marcador);
    if (anterior.exists || !(await tx.get(catalogo.limit(1))).empty) return 0;
    for (const item of itens) tx.create(catalogo.doc(item.codigoBarras), item);
    tx.create(marcador, { quantidade: itens.length, criadoEm: FieldValue.serverTimestamp() });
    return itens.length;
  });
  console.log(inseridos + ' registros inseridos.');
}

main().catch(erro => { console.error(erro.message); process.exitCode = 1; });
