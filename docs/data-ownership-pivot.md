# Pivot: app buida per defecte + restaurants propis + compartir amb amics

Document de seguiment de la implementació. El disseny complet i les
decisions preses es troben al pla de la conversa; aquest fitxer és només la
llista de comprovació per saber, en qualsevol moment, què està fet i què
falta.

## Part 1 — App buida + CRUD de restaurants propis — Feta

- [x] Eliminar `data/eatapp.db` (fitxer curat)
- [x] Eliminar `RemoteConfig.kt`
- [x] Eliminar `RestaurantDatabaseReader.kt`
- [x] Eliminar `RestaurantDatabaseSyncManager.kt`
- [x] Eliminar `DatabaseSyncResult.kt`
- [x] Conservar/moure la validació de website/Instagram (ara
      `data/local/LinkValidation.kt`) cap al formulari nou
- [x] Eliminar `DATABASE_URL` / `releaseDatabaseUrl` de `build.gradle.kts`
      (i l'override `eatapp.database.url` / `EATAPP_DATABASE_URL`)
- [x] Eliminar el botó "Refresh Data" / "Actualitzar dades"
- [x] `RestaurantDao`/`RestaurantRepository`: substituir `replaceAll()` per
      `insert(restaurant)`, `update(restaurant)`, `delete(id)`
- [x] Nova pantalla "Afegir/Editar restaurant" (nom, tipus de cuina, adreça,
      puntuació, rang de preu, web, Instagram) — `ui/edit/`
- [x] Acció d'esborrar des de la pantalla de detall (amb confirmació)
- [x] Estat buit amb crida a l'acció ("Afegeix el teu primer restaurant")

Extra fet en aquesta passada, perquè se'n derivava directament: eliminats els
permisos `INTERNET`/`ACCESS_NETWORK_STATE` del manifest (ja no queda cap
codi de xarxa) i actualitzats README.md/CLAUDE.md perquè no descriguin un
flux de sync que ja no existeix. `./gradlew test` i `./gradlew assembleDebug`
verds.

## Part 2 — Compartir restaurants (un o tots) — Feta

- [x] Generar fitxer JSON (un restaurant o tota la llista) sense l'`id`
      (`data/share/RestaurantShareModels.kt` + `RestaurantShareWriter.kt`)
- [x] `FileProvider` configurat (`exported="false"`, `grantUriPermissions`,
      `file_paths.xml` restringit a `cacheDir/shared/`)
- [x] Enviar amb `Intent.ACTION_SEND`
- [x] `<intent-filter>` a `MainActivity` per rebre (`ACTION_VIEW`)
- [x] Pantalla de confirmació abans d'importar (`ui/importing/`, mostra
      el/els restaurant/s rebuts amb una fila per candidat)
- [x] Detecció de duplicats per nom + adreça, amb opció Afegeix / Ometre /
      Reemplaça per fila (per defecte Ometre si sembla duplicat, Afegeix si no)
- [x] Compartir "tots els restaurants" reutilitzant el mateix fitxer/flux amb
      un array (botó a la `TopAppBar` de la llista)

**Desviació deliberada del disseny original**: en lloc del MIME/extensió
propis (`application/vnd.eatapp+json` / `.eatapp.json`), s'ha fet servir el
MIME estàndard `application/json` i l'extensió `.json`. Raó: un MIME/extensió
personalitzats no es preserven de manera fiable quan un fitxer passa per
WhatsApp/Gmail/etc. (moltes apps el reinterpreten per extensió amb el
`MimeTypeMap` del sistema, que no coneix `.eatapp.json`), cosa que faria que
"Obrir amb EatApp" no aparegués sovint. Amb `application/json` es garanteix
que l'intent-filter es dispara sempre; a canvi, EatApp apareix també com a
opció per obrir qualsevol fitxer `.json` del sistema — mitigat perquè
`RestaurantImportReader` rebutja amb un missatge clar (`import_error_invalid`)
qualsevol JSON que no porti el tag `"format": "eatapp.restaurants.v1"`.

## Part 3 — Backup

- [ ] Escriure `backup.json` a `context.filesDir` automàticament en cada
      `insert`/`update`/`delete`
- [ ] Botó "Exporta/Comparteix les meves dades" que comparteix `backup.json`
      amb el mateix mecanisme de la Part 2
- [ ] Confirmar que `android:allowBackup="true"` i les regles de backup
      actuals es mantenen sense canvis (ja correctes un cop tot Room és
      dada d'usuari)

## Part 4 — Seguretat

- [x] Eliminar permisos `INTERNET` i `ACCESS_NETWORK_STATE` del manifest
      (fet amb la Part 1, ja que en depenia directament)
- [ ] Import (Part 2) amb límit de mida de fitxer
- [ ] Parsing JSON amb `kotlinx.serialization` (sense reflexió)
- [ ] Validació de camps a l'import (nom/cuina no buits, rating 0..5, preu
      0..4, whitelist website/Instagram) abans d'escriure a Room
- [ ] Ids sempre generats localment en importar, mai confiats de l'exterior
- [ ] `FileProvider` amb `file_paths.xml` restringit (revisat a Part 2)
- [ ] `backup.json` només a emmagatzematge privat de l'app

## Fora d'abast (backlog separat, no d'aquesta feina)

- `surfaceTint` pla a `PaletteSchemes.kt`
- Substituir `Icons.Filled` per una llibreria d'icones de tercers
- Encapsular `Button`/`TextField` en components propis (`AppPrimaryButton`, etc.)
