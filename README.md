# Marmot Lovers

Juego de cartas online para 2-6 jugadores con las reglas de *Power Hungry Pets*
(la variante de *Love Letter* de Exploding Kittens), con diseño de cartas propio.
Flutter + Firebase (Auth + Firestore).

## Reglas implementadas

Mazo de 21 cartas:

| Valor | Carta | Copias | Efecto |
|---|---|---|---|
| 10 | Rey del Trono de Peluche | 1 | Si la bajas por cualquier motivo, quedas eliminado |
| 9 | La Venganza de la Perezosa | 1 | Quien tenga al Rey del Trono intercambia su carta contigo |
| 8 | Forja de Hephesto | 1 | Intercambias tu carta con la de un rival |
| 7 | El Animador de la Fiesta | 1 | Todos devuelven su carta, se baraja y se reparte de nuevo |
| 6 | El Ladrón de Sombras | 1 | Miras la carta apartada y puedes quedártela |
| 5 | El Rey de las Mareas | 2 | Un rival baja su carta sin efecto y roba otra |
| 4 | La Sabia del Valle | 2 | Te protege hasta tu siguiente turno |
| 3 | El Matón del Campo de Batalla | 3 | Comparas carta con un rival; pierde el más bajo |
| 2 | El Correvvidile | 3 | Miras la carta superior y la devuelves donde quieras |
| 1 | La Pitonisa de los Túneles | 5 | Adivinas la carta de un rival (**del 1 al 10**, regla de la casa) |
| 0 | El Capo de la Colonia | 1 | Al final de la ronda gana al Rey del Trono (10), y solo a él |

Los nombres son los que están impresos en `assets/cards/clasico/`.

- Con 2 jugadores se apartan 3 cartas (2 boca arriba y 1 boca abajo);
  con 3 o más, solo 1 boca abajo.
- La ronda acaba cuando solo queda un jugador o cuando se agota el mazo:
  gana la carta más alta en mano, desempatando por la carta más alta ya jugada.
- Fichas para ganar la partida: 3 con 2-3 jugadores, 2 con 4-6.
- La primera ronda la empieza un jugador **al azar**; las siguientes las
  empieza quien ganó la ronda anterior.

**Regla de la casa:** con La Pitonisa (1) se puede adivinar también el 1, cosa
que el reglamento original no permite.

### Jugando en persona

Tu mano empieza **tapada** (se ve el dorso), para poder dejar el móvil sobre la
mesa sin que nadie te vea la carta. Se destapa con el botón MIRAR o tocando
las cartas, y se vuelve a tapar sola en cuanto juegas, que es cuando se pasa
el móvil al siguiente.

Como tapadas ocupan menos, el tablero se queda con ese hueco: la zona de la
mano pasa del 38% al 20% del alto libre.

### Invitar por enlace

El lobby comparte `https://marmot-lovers.web.app/?sala=CODIGO` con el menú de
compartir del sistema. Quien lo abra entra directo en esa sala, sin teclear el
código (si nunca ha puesto nombre, se lo pide antes).

En **Android el enlace abre la app** si está instalada (App Links). Hacen
falta tres piezas, y si falla alguna Android se limita a abrir el navegador:

1. el `intent-filter` con `android:autoVerify="true"` en `AndroidManifest.xml`;
2. `web/.well-known/assetlinks.json` con el paquete y la **huella SHA-256** de
   la clave con la que se firma el APK;
3. que ese fichero se publique: ojo, el `ignore` que trae Firebase Hosting por
   defecto (`**/.*`) se cargaba la carpeta `.well-known` entera.

Para comprobar que la asociación es válida:

```bash
curl "https://digitalassetlinks.googleapis.com/v1/statements:list?source.web.site=https://marmot-lovers.web.app&relation=delegate_permission/common.handle_all_urls"
```

**Si cambias la clave de firma hay que actualizar la huella del
`assetlinks.json`**, o el enlace dejará de abrir la app. Al pasar a la clave
de release se dejaron las dos huellas (la nueva y la de la vieja clave de
depuración) para que los APK ya instalados siguieran abriendo el enlace;
cuando todo el mundo tenga el APK nuevo, la vieja se puede quitar.

### Repaso de la ronda

Al acabar la ronda, **antes del marcador**, se repasa la partida enseñando las
cartas: jugada a jugada, con quién la bajó, la carta en grande y qué provocó,
y una tira abajo que va acumulando todo lo que ha salido. Termina destapando
las manos con las que se decidió la ronda, con el ganador resaltado.

Avanza solo cada 2,2 s, se adelanta tocando y se puede saltar entero.

Esto lo hace posible `sala.historial_jugadas`, que el motor va rellenando en
cada jugada (las cartas de dos pasos, la 2 y la 6, completan su entrada al
resolverse en vez de crear otra). Antes el desarrollo de la ronda solo existía
como texto en el registro.

### Aviso de turno

Cuando el turno pasa a ser tuyo, el móvil vibra (dos toques) y los bordes de la
pantalla dan un par de destellos ámbar. Se puede silenciar con la campana de
la barra superior y la elección se recuerda.

### Anuncio de la jugada

Cuando alguien juega una carta, la mesa se cubre un momento con el anuncio:
la carta jugada entra volteándose, con el nombre de quién la bajó, y después
salen de una en una las cartas que el efecto ha revelado **en público**:

- el **5** (Rey de las Mareas): la carta que el rival baja forzado;
- el **3** (Matón): solo la del eliminado (la del ganador sigue siendo
  secreta, y si empatan no sale ninguna);
- el **1** (Pitonisa): si acierta, la del eliminado; si falla, nada;
- el **10** (Rey del Trono): también la otra carta de su mano, que queda
  boca arriba al ser eliminado.

Los intercambios (8 y 9) y el reparto del 7 siguen siendo secretos. El
anuncio avanza solo y se salta tocando en cualquier sitio; si llegan varias
jugadas seguidas, se anuncian por orden. El motor apunta esas cartas en
`ultima_jugada.reveladas` (y con ellas se rellena `historial_jugadas`), así
que el dato queda guardado por si el repaso de fin de ronda quiere enseñarlas
más adelante.

### En la mesa

- **El tablero cabe entero en pantalla, sin scroll.** El alto disponible se
  reparte en porcentajes entre las zonas (barras fijas, asientos 22%, centro
  40%, tu zona el resto) y cada zona calcula el tamaño de sus cartas a partir
  del hueco que recibe. Cuando hay poco sitio se recorta lo accesorio (las
  fichas del rival, la tira de "has jugado", la pista de abajo) antes que
  desbordar.
- En pantallas anchas el tablero **no se estira**: se limita a 560 px y se
  centra, con forma de mesa.
- `test/mesa_layout_test.dart` comprueba en 8 tamaños (desde 320x568 hasta
  1920x870, incluido apaisado) que no hay desbordamientos **y** que ningún
  scroll vertical tiene contenido fuera de su hueco.

- La última carta jugada se enseña **en grande** en el centro, con quién la
  jugó y qué provocó. La información va en `sala.ultima_jugada`, que escribe
  el motor juntando lo que se registró al resolver esa carta.
- **Cualquier carta visible se puede ampliar** tocándola: las del centro, las
  que tiene jugadas cada rival, las tuyas y las de la pantalla de resultados.
  Las de tu mano se amplían manteniéndolas pulsadas, porque al tocarlas las
  eliges para jugar.

## Si te acaban de pasar este repo

```bash
flutter pub get
```

```bash
flutter run
```

El proyecto ya apunta al Firebase de Gonzalo, así que **funciona sin
configurar nada** y juegas contra la misma base de datos que los demás.

Dos avisos:

- **El acceso con Google fallará en tu build de Android.** Está atado a la
  huella SHA-1 del keystore de depuración de *ese* equipo, y el tuyo tiene
  otra. Mientras tanto entra con correo y contraseña, o usa
  https://marmot-lovers.web.app. Si lo quieres arreglar, pásale tu SHA-1 a
  Gonzalo para que la añada en Firebase:

  ```bash
  keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
  ```

- Los tests de las reglas de Firestore (`test/firestore_rules_test.mjs`)
  necesitan npm y el emulador:

  ```bash
  npm install @firebase/rules-unit-testing firebase
  ```

## Cómo ejecutarlo

```bash
flutter pub get
```

```bash
flutter run
```

## Publicar

**Web** (es la vía más cómoda para quien no tenga Android):

```bash
flutter build web --release
```

```bash
firebase deploy --only hosting --project marmot-lovers
```

Queda en **https://marmot-lovers.web.app**. Es una PWA: desde el móvil se puede
añadir a la pantalla de inicio y queda con su icono, como una app.

**APK de Android** para pasar a mano:

```bash
flutter build apk --release --split-per-abi
```

Salen en `build/app/outputs/flutter-apk/`:

| Archivo | Tamaño | Para quién |
|---|---|---|
| `app-arm64-v8a-release.apk` | ~30 MB | Prácticamente cualquier móvil actual |
| `app-armeabi-v7a-release.apk` | ~27 MB | Móviles viejos de 32 bits |
| `app-x86_64-release.apk` | ~31 MB | Emuladores |

Sin `--split-per-abi` sale un APK universal de ~61 MB que vale para todos, pero
pesa el doble porque lleva las librerías nativas de las tres arquitecturas.

Para instalarlo hay que permitir "instalar apps de origen desconocido" en el
móvil, que es lo normal al instalar fuera de Play.

### Sobre la firma del APK

La build de release se firma con la **clave de release**
(`android/app/release.keystore`) cuando existe `android/key.properties`.
Ninguno de los dos está en el repo; `key.properties` tiene esta pinta:

```
storeFile=release.keystore
keyAlias=marmot_lovers
storePassword=...
keyPassword=...
```

El keystore es PKCS12, así que la contraseña de la clave y la del almacén
son la misma.

La SHA-1 de esa clave está registrada en Firebase, así que el acceso con
Google funciona en el APK que repartas, y su SHA-256 está en
`web/.well-known/assetlinks.json` para que los enlaces abran la app.
**Si algún día cambia la clave, hay que actualizar los dos sitios.**

Sin `key.properties` (un clon fresco) la build cae en la clave de depuración,
y el acceso con Google solo funcionará si la SHA-1 de ese equipo también está
en Firebase. Al firmar ya con una clave de verdad, el APK vale para Play; si
algún día se sube, basta con no perder el keystore.

### APK desde GitHub Actions

`.github/workflows/apk.yml` compila los APK (uno por ABI, firmados con la
clave de release) en cada push a `main` y bajo demanda. Antes de compilar
pasa `flutter analyze` y `flutter test`; si algo falla, no hay APK. Los APK
quedan como **artefacto** de la ejecución (90 días), descargables desde el
resumen del workflow en la pestaña Actions.

Además, con cada merge a `main` crea (o actualiza) la **GitHub Release**
`v<versión>` y adjunta solo el APK arm64 (`app-arm64-v8a-release.apk`), que
queda en la pestaña Releases sin caducidad. Para sacar versión basta subir
el número en `pubspec.yaml` y hacer merge a `main`; si se hace merge sin
subir la versión, la release existente se actualiza con el APK nuevo.

La firma sale de cuatro secretos del repo
(Settings → Secrets and variables → Actions):

| Secreto | Valor |
|---|---|
| `RELEASE_KEYSTORE_BASE64` | salida de `base64 -w0 android/app/release.keystore` |
| `RELEASE_KEY_ALIAS` | `marmot_lovers` |
| `RELEASE_STORE_PASSWORD` | la contraseña del almacén |
| `RELEASE_KEY_PASSWORD` | la misma (es un PKCS12) |

Para que el APK de CI funcione del todo hacen falta además dos cosas fuera de
GitHub: tener la SHA-1 de la clave de release en Firebase (Authentication →
Google) y publicar el `assetlinks.json` con
`firebase deploy --only hosting`.

## Icono de la app

El original es un JPEG cuadrado. El proceso es:

```bash
dart run tool/prepara_icono.dart ruta/al/icono.jpeg
```

```bash
dart run flutter_launcher_icons
```

El primer comando saca de la imagen dos PNG en `assets/icon/` (el icono
completo y el primer plano del icono adaptativo, recortado al contenido) y
además escribe `build/preview_icono.png`, donde se ve cómo quedará con máscara
redonda y cuadrada. **Conviene mirar esa vista previa**: Android recorta el
icono y es fácil que se coma el banner.

## Configuración de Firebase

El proyecto ya apunta a `marmot-lovers` (ver `firebase_options.dart`).

### 1. Acceso con correo

**Authentication → Sign-in method → Correo/contraseña: activado.**

### 2. Acceso con Google

En **Authentication → Sign-in method → Google: activado** (hay que elegir un
correo de soporte del proyecto).

Para **Android** ya está todo puesto en el repo:

- `android/app/google-services.json` es el bueno, con el cliente Android
  (`client_type: 1`) y el cliente web (`client_type: 3`).
- Están registradas dos huellas SHA-1:
  - la de la **clave de release** (la que firman los APK que se reparten,
    incluidos los de GitHub Actions):

    ```
    18:C7:4F:53:51:5D:46:1D:12:47:53:77:DA:54:12:E2:3A:8D:76:DE
    ```
  - la del keystore de depuración del equipo donde nació el proyecto, para
    las builds locales:

    ```
    EB:65:70:8A:E5:69:D9:69:58:3E:33:0F:0C:D6:C7:14:F4:23:60:67
    ```

Para sacar la huella de depuración en otro equipo (cada uno tiene la suya, y
hay que añadirla también en Firebase o el acceso con Google fallará ahí):

```bash
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
```

La de la clave de release se saca igual, con su contraseña:

```bash
keytool -list -v -keystore android/app/release.keystore -alias marmot_lovers
```

No hace falta escribir ningún ID de cliente en el código: Android lo saca del
`google-services.json` y la web usa el popup de Firebase directamente.

Para **iOS** falta trabajo: el proyecto de Firebase ya tiene cliente de iOS
(bundle `com.marmota.marmotLovers`), pero hay que añadir `GIDClientID` y el
`CFBundleURLTypes` de Google en `ios/Runner/Info.plist`. Hay constantes
preparadas en `lib/repositories/auth_repository.dart` por si prefieres pasarlo
desde Dart.

### Salas abandonadas

Las salas se borran solas (con sus jugadores dentro) cuando llevan **2 horas
sin actividad**. Se mide desde la última jugada, no desde que se creó la sala,
para no cargarse una partida larga que se esté jugando.

La limpieza la hace la propia app al abrir la pantalla de inicio
(`GameRepository.limpiarSalasAbandonadas`), así que basta con que alguien entre
de vez en cuando. Además, si el último jugador sale del lobby, la sala se borra
al momento.

Se descartaron las dos alternativas "de servidor":

- el **TTL de Firestore** no borra subcolecciones (los jugadores quedarían
  colgados) y solo garantiza el borrado *dentro de las 24 h siguientes*;
- las **Cloud Functions programadas** exigen plan Blaze.

Las reglas solo permiten borrar salas abandonadas o vacías, así que ni un
error de la app ni un reloj mal puesto pueden cargarse una partida en curso.
Para cambiar el plazo hay que tocar `vidaDeUnaSala` en
`game_repository.dart` **y** el `duration.value(2, 'h')` de `firestore.rules`.

Las reglas están probadas contra el emulador. Para volver a pasarlas:

```bash
firebase emulators:exec --only firestore "node test.mjs"
```

### 3. Firestore

Crea la base de datos y publica las reglas:

```bash
firebase deploy --only firestore:rules
```

### Si el acceso con Google falla

- **"Falta configurar el acceso con Google..."** → falta la SHA-1 de ese
  equipo o de esa clave de firma, o el `google-services.json` está sin
  actualizar. Que Gradle genere el recurso se comprueba así, después de
  compilar:

  ```bash
  grep default_web_client_id build/app/generated/res/google-services/debug/values/values.xml
  ```
- En Android, una configuración mal puesta a veces se manifiesta como si
  hubieras **cancelado** el diálogo justo después de elegir la cuenta. Es un
  problema conocido del SDK: si te pasa, revisa la SHA-1.
- En web, comprueba que el dominio está en
  **Authentication → Settings → Authorized domains** (`localhost` ya viene).

## Logotipo de Google

`assets/google/logo.svg` es el logotipo oficial, y se dibuja con `flutter_svg`.
Se le quitaron los `<filter>` de desenfoque porque `flutter_svg` no aplica
filtros SVG (avisaba por consola y no cambiaban nada en pantalla).

## Diseños de cartas

Los PNG viven en `assets/cards/<estilo>/carta_0.png` … `carta_10.png`
(opcionalmente `dorso.png`). Para añadir un mazo nuevo:

1. crea la carpeta con los 11 PNG,
2. añádela a la sección `assets:` del `pubspec.yaml`,
3. añade el nombre a `estilosDisponibles` en `lib/providers/style_provider.dart`.

Si falta algún PNG, la app pinta una carta de respaldo con el número y el
nombre en vez de romperse.

## Estructura

```
lib/
  models/       carta.dart (catálogo), jugador.dart, sala.dart, fin_ronda.dart
  providers/    style_provider.dart (mazo de diseño activo)
  repositories/ auth_repository.dart, game_repository.dart (motor del juego)
  screens/      login, home, lobby, game
  theme/        app_theme.dart (paleta, tema y piezas comunes)
  widgets/      carta_widget.dart, asiento_widget.dart, boton_google.dart
tool/           preview_mesa.dart (banco de pruebas visual)
```

Todo el motor está en `game_repository.dart` y cada jugada se resuelve dentro
de una transacción de Firestore, así que dos jugadores no pueden pisarse.

## Ver el diseño sin arrancar Firebase

Hay un banco de pruebas visual que dibuja la mesa con datos falsos:

```bash
flutter run -d chrome -t tool/preview_mesa.dart
```

Muestra a la vez el turno propio, el turno ajeno, las cartas de dos pasos, el
aviso privado, el fin de ronda y la partida de 2. Sirve para tocar el diseño
sin tener que montar una partida real.

`test/mesa_layout_test.dart` comprueba que la mesa cabe en pantalla (los
desbordamientos de layout hacen fallar el test) en móvil pequeño, mesa llena
de 6 y todas las capas modales.

## Limitaciones conocidas

### El texto de efecto de las cartas no cuadra

El arte de `assets/cards/clasico/` tiene los textos de efecto descolocados
respecto al reglamento:

- la **10** lleva impreso, además del suyo, el efecto de la 9;
- la **9** lleva el efecto de la 0;
- la **6** dice "mira la carta de otro jugador" cuando la regla es mirar la
  carta que se aparta al principio de la ronda.

La app aplica **el reglamento del PDF**, no lo que pone el dibujo. Si quieres
que coincidan, hay que regenerar esas tres imágenes.

### Se puede hacer trampa

La lógica corre en el móvil, no en el servidor. Cualquier jugador autenticado
puede leer los documentos de la sala, incluidas las manos de los demás. Para
partidas entre amigos va bien; para que sea imposible hacer trampas habría que
mover `game_repository.dart` a Cloud Functions y dejar las reglas de Firestore
en solo lectura.

## Tests

```bash
flutter test
```

## Buenas prácticas

Antes de ponerte a escribir nada, haz siempre un `git fetch` para ver qué
ramas y cambios nuevos hay en el remoto y no trabajar sobre una copia vieja:

```bash
git fetch
```

Sin `--prune`: no queremos que se borre del tracking remoto nada en lo que
otro pueda estar trabajando.
