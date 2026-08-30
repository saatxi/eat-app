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

## Part 2 — Compartir restaurants (un o tots)

- [ ] Generar fitxer JSON (un restaurant o tota la llista) sense l'`id`
- [ ] `FileProvider` configurat (`exported="false"`, `grantUriPermissions`,
      `file_paths.xml` restringit a una subcarpeta de cau)
- [ ] Enviar amb `Intent.ACTION_SEND` + MIME propi (`application/vnd.eatapp+json`,
      extensió `.eatapp.json`)
- [ ] `<intent-filter>` per rebre (`ACTION_VIEW` + MIME/extensió propis)
- [ ] Pantalla de confirmació abans d'importar (mostra el/els restaurant/s
      rebuts)
- [ ] Detecció de duplicats per nom + adreça, amb opció d'afegir igualment /
      ometre / reemplaçar
- [ ] Compartir "tots els restaurants" reutilitzant el mateix flux amb un
      array

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
