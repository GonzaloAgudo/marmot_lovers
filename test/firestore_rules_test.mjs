// Pruebas de las reglas de Firestore. Se ejecutan con el emulador:
//   npm install @firebase/rules-unit-testing firebase
//   firebase emulators:exec --only firestore "node test/firestore_rules_test.mjs"
import fs from 'node:fs';
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from '@firebase/rules-unit-testing';
import {
  doc, setDoc, deleteDoc, getDoc, updateDoc, Timestamp,
} from 'firebase/firestore';

// Ruta relativa a la raiz del proyecto.
const RULES = 'firestore.rules';

const env = await initializeTestEnvironment({
  projectId: 'reglas-marmot',
  firestore: { rules: fs.readFileSync(RULES, 'utf8'), host: '127.0.0.1', port: 8080 },
});

const hace = (min) => Timestamp.fromMillis(Date.now() - min * 60 * 1000);

async function sembrar(id, datos) {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'salas', id), datos);
    await setDoc(doc(db, 'salas', id, 'jugadores', 'ana'), { nombre: 'Ana' });
  });
}

const resultados = [];
async function prueba(nombre, fn) {
  try {
    await fn();
    resultados.push(['OK  ', nombre]);
  } catch (e) {
    resultados.push(['FALLA', `${nombre} -> ${e.message.split('\n')[0]}`]);
  }
}

const ana = env.authenticatedContext('ana').firestore();
const anon = env.unauthenticatedContext().firestore();

await sembrar('VIVA', {
  actualizada: hace(5),
  orden_jugadores: ['ana', 'bea'],
  estado: 1,
});
await sembrar('VIEJA', {
  actualizada: hace(200),
  orden_jugadores: ['ana', 'bea'],
  estado: 1,
});
await sembrar('LEGACY', { creada: hace(200), orden_jugadores: ['ana'], estado: 0 });
await sembrar('SOLOYO', {
  actualizada: hace(1),
  orden_jugadores: ['ana'],
  estado: 0,
});
await sembrar('AJENA', {
  actualizada: hace(1),
  orden_jugadores: ['bea'],
  estado: 0,
});

await prueba('una partida en curso NO se puede borrar',
  () => assertFails(deleteDoc(doc(ana, 'salas', 'VIVA'))));

await prueba('una sala de hace 3h SI se puede borrar',
  () => assertSucceeds(deleteDoc(doc(ana, 'salas', 'VIEJA'))));

await prueba('una sala antigua sin campo actualizada SI se puede borrar',
  () => assertSucceeds(deleteDoc(doc(ana, 'salas', 'LEGACY'))));

await prueba('el ultimo jugador que sale SI puede borrar su sala',
  () => assertSucceeds(deleteDoc(doc(ana, 'salas', 'SOLOYO'))));

await prueba('no puedo borrar una sala reciente de otro',
  () => assertFails(deleteDoc(doc(ana, 'salas', 'AJENA'))));

await prueba('sin sesion no se puede leer',
  () => assertFails(getDoc(doc(anon, 'salas', 'VIVA'))));

await prueba('sin sesion no se puede borrar una sala vieja',
  () => assertFails(deleteDoc(doc(anon, 'salas', 'VIVA'))));

await prueba('con sesion si se puede leer y jugar',
  async () => {
    await assertSucceeds(getDoc(doc(ana, 'salas', 'VIVA')));
    await assertSucceeds(updateDoc(doc(ana, 'salas', 'VIVA'), { estado: 2 }));
  });

await prueba('se pueden borrar los jugadores de la sala',
  () => assertSucceeds(deleteDoc(doc(ana, 'salas', 'VIVA', 'jugadores', 'ana'))));

await env.cleanup();

console.log('');
for (const [estado, nombre] of resultados) console.log(estado, nombre);
const fallos = resultados.filter(([e]) => e === 'FALLA').length;
console.log('');
console.log(fallos === 0 ? 'TODAS LAS REGLAS OK' : `${fallos} REGLAS MAL`);
process.exit(fallos === 0 ? 0 : 1);
