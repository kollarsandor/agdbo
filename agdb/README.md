## Áttekintés

az agdb egy nagy teljesítményű, Zig nyelven írt, perzisztens adatbázis-motor, amelyet hibrid keresésre (teljes szöveges és vektoros), többszemélyes használatra és alacsony késleltetésű műveletekre terveztek. Egyéni tartós halom, write-ahead logging (WAL) és egy robusztus, felhő-képes architektúra jellemzi, amely támogatja a sandboxolt tenant izolációt.

### Rendszerarchitektúra

Az agdb architektúra az alacsony szintű memóriakezeléstől a magas szintű HTTP- és CLI-interfészekig többszintű. Áthidalja a nyers hardverteljesítmény (az io_uring, HTM és SIMD funkciókat használva) és a fejlesztőbarát keresési képességek közötti szakadékot.

### Rendszerkomponensek térképe

Ez az ábra szemlélteti a kapcsolatot a főbb architektúrális rétegek és az azokat megvalósító konkrét kódegységek között.

### Kulcsfontosságú képességek

### 1. Hibrid keresőmotor

Az agdb magja az Adatbázis struktúra, amely három elsődleges tároló és indexelő alrendszert hangszerel a rugalmas lekérdezés érdekében:

- Kulcs-érték tároló: KvStore (KvStore) a nyers rekordok megőrzéséhez
- Teljes szöveges keresés: BM25 rangsoroló algoritmust alkalmazó Bm25Index a dokumentumkereséshez
- Vektoros keresés: VectorIndex, amely támogatja a különböző távolsági metrikákat (koszinusz, euklideszi stb.) a hasonlósági kereséshez

A motorral kapcsolatos részletekért lásd

### 2. Tartós futásidő réteg

A futásidő biztosítja az adatok tartósságának és konzisztenciájának alapinfrastruktúráját. Kezeli:

- Tartós halom: PersistentHeap: Memóriakártyás fájlkezelés a PersistentHeap segítségével
- Tranzakciók: TransactionManager és WAL (Write-Ahead Log) segítségével ACID-megfelelőség: TransactionManager és WAL (Write-Ahead Log)
- Egyidejűség: Topológiatudatos végrehajtás és hardveres tranzakciós memória (HTM) integrálása

A részletekért lásd

### 3. Felhő-natív többszemélyes használat

az agdb-t skálázásra tervezték egy dedikált felhő alcsomaggal. Egy Registry-t használ a bérlők kezelésére és egy Router-t a kérések elszigetelt Linux sandboxokba történő továbbítására.

A részletekért lásd

### Rendszer és célok építése

A projekt a Zig építési rendszert (build.zig) használja négy elsődleges artefaktum előállításához:

1.   Statikus könyvtár: libagdb.a, a beágyazás alapmotorja
2.   CLI: agdb, a helyi adatbázis-kezelés parancssori eszköze
3.   Futtatási idő: agdb-runtime, az önálló kiszolgáló démon
4.   Sandbox Runner: sandbox_runner, egy speciális statikus bináris program az izolált bérlői végrehajtáshoz

| Opció | Alapértelmezett érték | Leírás |
| --- | --- | --- |
| AGDB_REGISTRY_PATH | /var/lib/agdb/registry.agdb | A többszereplős nyilvántartás elérési útvonala |
| AGDB_DATA_ROOT | /var/lib/agdb/tenants | A bérlői adatok gyökérkönyvtára |
| sandbox_runner_path | /usr/lib/agdb/sandbox_runner | A sandbox bináris telepítési helye |

A részletekért lásd

### Interfész áttekintések

### Parancssori felület (CLI)

A CLI parancsokat biztosít az adatbázis inicializálásához (init), a rekordok kezeléséhez (put, get, del) és a keresési műveletekhez. A serve paranccsal a HTTP-kiszolgálót is el tudja indítani. A részletekért lásd

### HTTP-kiszolgáló API

A beágyazott kiszolgáló egy RESTful API-t tesz közzé. A legfontosabb végpontok a következők:

- POST /records: Dokumentumok beszúrása vagy frissítése.
- POST /search: Hibrid szöveges/vektoros keresések végrehajtása.
- GET /stats: A motor és a futásidejű telemetria lekérdezése. Részletekért lásd

## Kezdő lépések és rendszerépítés

Ez az oldal az agdb, egy Zig-ben implementált adatbázis-rendszer építési infrastruktúráját mutatja be. Kitér a build rendszer konfigurációjára, a különböző build targetekre, valamint a rendszer teszteléséhez és telepítéséhez szükséges lépésekre.

### Build System áttekintés

az agdb a szabványos Zig build rendszert használja. Az építési folyamatot a build.zig rendszerezi, amely meghatározza, hogy a könyvtár, a CLI, a futásidő és a homokozó futó hogyan kerül lefordításra és linkelésre. A projekt a Zig 0.14.0 vagy magasabb verzióját célozza meg

### Építési idő beállítások

Az építési rendszer számos konfigurációs opciót tesz közzé, amelyek a generált build_options modulon keresztül beépülnek az eredményül kapott bináris állományokba.Ezek az opciók határozzák meg a rendszer által a registry-kezeléshez és a bérlői adatok tárolásához használt alapértelmezett elérési utakat.

| Opció | Alapértelmezett érték | Leírás |
| --- | --- | --- |
| AGDB_REGISTRY_PATH | /var/lib/agdb/registry.agdb | A globális bérlői nyilvántartási adatbázis elérési útvonala |
| AGDB_DATA_ROOT | /var/lib/agdb/tenants | Gyökérkönyvtár, ahol az egyes bérlői adatbázis-fájlok tárolódnak |
| sandbox_runner_path | /usr/lib/agdb/sandbox_runner | Az a fájlrendszeri elérési út, ahová a sandbox_runner bináris program telepítve van és ahová a futásidő várja |

Ezek felülbírálhatók az építéskor a -D jelzővel:

zig build -DAGDB_REGISTRY_PATH=/custom/path/registry.agdb -Doptimize=ReleaseFast

### Célok építése

Az agdb kódbázis négy elsődleges leletet állít elő. A lib_mod (amely az src/agdb.zig-ben van definiálva) az összes többi célprogram által importált alapmodulként szolgál

### 1. Könyvtár (agdb)

- Forrás:src/agdb.zig
- Típus: Statikus könyvtár
- Szerep: Tartalmazza az alapvető adatbázis-motor logikát, beleértve a KV tárolót, a BM25 indexet és a vektoros keresési képességeket.

### 2. CLI (agdb)

- Forrás:src/cli_main.zig
- Típus: Végrehajtható
- Szerep: A helyi adatbázisfájlokkal való interakcióhoz szükséges parancssori felület. Importálja a core könyvtárat és a build opciókat

### 3. Futtatási idő (agdb-runtime)

- Forrás:src/runtime_main.zig
- Típus: Végrehajtható
- Szerep: A hosszú ideig futó kiszolgáló folyamat, amely a többszemélyes használatot és a kérések útválasztását kezeli.

### 4. Sandbox Runner (sandbox_runner)

- Forrás:src/cloud/sandbox_runner.zig
- Típus: (x86_64-linux-musl)
- Szerep: Egy speciális, minimális bináris rendszer, amelyet a bérlői kérések izolált névtereken belüli végrehajtására használnak. A kiadási verziókban le van csupaszítva, hogy minimalizálja a többletköltséget

### Építsünk ki műtárgy-kapcsolatokat

A következő ábra azt szemlélteti, hogy a build.zig szkript hogyan kapcsolja össze a forrásfájlokat a build modulokkal és a végleges artefaktumokkal.

## Rendszerfüggőségi grafikon készítése

### Telepítés és kivitelezés

### Standard építés

Az összes komponens összeállítása és telepítése a zig-out/ könyvtárba:

zig építés

Ez elindítja a telepítési lépést, amely a telepítő-futó lépést is tartalmazza

### A CLI futtatása

A build rendszer egy parancsikont biztosít a CLI közvetlen futtatásához:

zig build run -- [cli_arguments]

A futtatási lépés a telepítési lépéstől függ, hogy a bináris program naprakész legyen

### Sandbox Runner telepítése

A sandbox_runner különleges bánásmódban részesül, mivel gyakran egy adott rendszerútvonalon (például /usr/lib/agdb/) kell lennie, hogy a futásidő izolációs logikája számára elérhető legyen. Az install-runner lépés kezeli a bináris állomány elhelyezését a sandbox_runner_path által megadott helyre

### Tesztelési infrastruktúra

az agdb kétszintű tesztelési stratégiát alkalmaz, amely egységtesztekből és integrációs tesztekből áll.

### Tesztcélok

1.   Egységtesztek: Az alapvető könyvtári modulokban definiáltak. Az építési rendszer ezeket a lib_mod
2.   Integrációs tesztek: Zig. Ezek a tesztek a teljes rendszert gyakorolják, beleértve az adatbázis-perzisztenciát és a keresési folyamatokat is

### Tesztvégrehajtási parancsok

- Az összes teszt futtatása:zig build test Ez mind az egység-, mind az integrációs teszteket lefuttatja
- Csak integrációs tesztek futtatása:zig build test-integration Ez csak az src/tests.zig fájlban definiált teszteket hajtja végre

### Teszt adatáramlás

A következő ábra azt mutatja, hogy a tesztfutó hogyan lép kölcsönhatásba a kódbázissal a rendszer integritásának ellenőrzése érdekében.

## Tesztvégrehajtás folyamata

## CLI-hivatkozás

Az agdb parancssori felület átfogó eszközkészletet biztosít az adatbázis-példányok kezeléséhez, a dokumentumok indexeléséhez, a nagy teljesítményű keresések elvégzéséhez és a beágyazott kiszolgáló adminisztrálásához. A helyi fejlesztés és a rendszeradminisztráció elsődleges belépési pontjaként szolgál.

### Végrehajtási folyamat

A CLI belépési pontja az src/cli_main.zig fájlban található, amely inicializálja a GeneralPurposeAllocator-t, és átadja az argumentumokat a CLI központi futójának.

### CLI inicializálási diagram

Ez az ábra azt mutatja, hogy a CLI hogyan elemzi az argumentumokat, és hogyan továbbítja azokat az adatbázisban lévő konkrét parancskezelőknek.Adatbázis motor.

### Globális lehetőségek

A következő jelzőket szinte minden parancshoz alkalmazhatjuk az adatbázis-környezet konfigurálásához:

| Zászló | Rövid | Alapértelmezett | Leírás |
| --- | --- | --- | --- |
| --data | -d | ./agdb-data | A KV- és indexfájlokat tartalmazó adatbázis könyvtár elérési útvonala. |
| --dim | | | 256 | Vektorbeágyazás dimenzióssága a VectorIndexhez. |
| --bind | | | 127.0.0.0.1 | Hálózati interfész a serve parancshoz. |
| --port | | | 7878 | A beágyazott HTTP-kiszolgáló TCP-portja. |

### Parancshivatkozás

### Adatfelvétel

### init

Új adatbázis könyvtárat inicializál. Létrehozza a szükséges fájlstruktúrát és kitölti a kezdeti fejléceket.

- Használat: agdb init [--data <path>] [--dim <N>]
- Belső: Open, majd Database.flush.

### put

Nyers karakterlánc rekordot illeszt be az adatbázisba.

- Használat: agdb put <body> [--tag <t>] [--kind <k>] [--id <N>]
- Érvek:
- <body>: Az indexelendő szöveges tartalom.
- --tag: (Ismételhető) Metaadat címkék a szűréshez.
- --féle: Dokumentum, beszélgetés, jelenet, személyiség, szokás.
- --id: Ha 0, akkor automatikusan generálódik egy u64 azonosító.

### put-file

Beolvassa egy fájl tartalmát, és rekordként tárolja.

- Használat: agdb put-file <elérési útvonal> [--kind <k>] [--tag <t>]
- Végrehajtás: Fs.cwd().openFile-t használ, és a db.putBytes hívása előtt legfeljebb 64MB-ot olvas be a memóriába.

### put-json

A JSON fájl vagy karakterlánc elemzése és átalakítása Record struktúrává a json_mod segítségével.

- Használat: agdb put-json --file <path> [--kind <k>]

### Visszakeresés és keresés

### kap

Egy adott rekordot keres le annak egyedi u64 azonosítója alapján.

- Használat: agdb get <id>

### keresés

Teljes szöveges keresést végez a Bm25Index segítségével.

- Használat: agdb search <kérdés>
- Adatáramlás:
- 1.   Tokenizálja a lekérdezést.
- 2.   Kiszámítja a BM25 pontszámokat a PostingListában.
- 3.   Visszaadja a rangsorolt azonosítókat.

### vektor-keresés

Szemantikus keresést végez a VectorIndex segítségével.

- Használat: agdb vector-search <query_text>
- Végrehajtás: A CLI a hashEmbed segítségével a lekérdezés szövegét a konfigurált --dim Tensorba konvertálja, mielőtt lekérdezné az indexet.

### Karbantartás és adminisztráció

### statisztikák

Megjeleníti az adatbázis belső mérőszámait, beleértve a rekordok számát, az indexek méretét és a memóriahasználatot.

### kompakt

A KvStore tömörítési folyamatának elindítása. Ez helyet nyer vissza azáltal, hogy törölt vagy árnyékolt rekordokat távolít el a csak függelékként tárolt naplóból.

### flush

Kényszeríti az összes memórián belüli puffer (WAL, PHeap és Index pillanatképek) szinkronizálását a tartós tárolóba.

### pillanatkép

Létrehozza az adatbázis időponti biztonsági mentését.

- Használat: agdb snapshot <célcím_elérési útvonal>

### lista

A KvStore-ban jelenleg tárolt összes rekordot listázza.

### Kiszolgáló műveletek

### szolgálja ki a

Elindítja a beágyazott HTTP REST-kiszolgálót.

- Használat: agdb serve [--bind <addr>] [--port <port>] [--data <path>]
- Végrehajtás:
- Létrehozza a server_mod.Server.
- A megadott TCP-címhez kötődik.
- Figyeli a bejövő kéréseket, és továbbítja azokat az Adatbázis-példányhoz.

### Adatáramlás: CLI a tárolóhoz

A következő ábra a CLI-parancsokat a perzisztenciáért felelős kódegységekhez rendeli hozzá.

## HTTP-kiszolgáló API

Az agdb projekt tartalmaz egy beágyazott HTTP-kiszolgálót, amely az adatbázis alapvető funkcióit egy RESTful API-n keresztül teszi elérhetővé. Ez a kiszolgáló a szabványos könyvtár std.http.Server használatával épül fel, és az adatbázis-motorhoz való átjáróként működik, támogatva a rekordok kezelését, a keresési műveleteket és az adminisztrációs feladatokat.

### Kiszolgáló architektúra és konfiguráció

A kiszolgáló a Server struktúrába van foglalva, amely kezeli a HTTP-hallgató életciklusát és továbbítja a bejövő kéréseket a megfelelő kezelőknek.

### Kiszolgáló konfigurációja

A ServerConfig struktúra határozza meg a működési paramétereket:

| Mező | Típus | Alapértelmezett | Leírás |
| --- | --- | --- | --- |
| address | []const u8 | "127.0.0.0.1" | Kapcsolódási felület. |
| port | u16 | 7878 | TCP port a hallgatóhoz. |
| backlog | u31 | 64 | Connection backlog size. |
| max_body_size | usize | 16 MB | Maximális megengedett kérés testméret. |
| api_token | ?[]const u8 | null | Választható token a Bearer hitelesítéshez. |

### Kérés életciklusa

A kiszolgáló a run() szinkron ciklusban szinkron hurkot használ a kapcsolatok fogadására. Minden egyes kapcsolat átadásra kerül a handleConnection() függvénynek, amely inicializálja a HTTP protokoll elemzőt. A központi útválasztási logika a handleRequest()

### Adatáramlás: HTTP-kérelem az adatbázisba

Az alábbi ábra azt szemlélteti, hogyan áramlik egy kérés (pl. POST /rekordok) a hálózatról az adatbázis-motorba.

Kérés küldési folyamata

### Hitelesítés

Ha az api_token be van állítva a ServerConfigban, a kiszolgáló Bearer-hitelesítést alkalmaz

- Fejléc:Engedélyezés: Bearer <token>
- Kudarc: Visszatérítés: 401 Unauthorized egy JSON hibaüzenettel

### REST végpontok

### Metaadatok és egészség

- GET /egészségügy: {"status": "ok"}
- GET /verzió: Visszaadja az alkalmazás nevét és verzióját
- GET /stats: Database.count() hívása: Az adatbázisban lévő összes rekord számát adja vissza

### Record Management

- POST /records: Létrehoz egy új rekordot.
- A testnek egy JSON objektumnak kell lennie.
- A fajta mező (pl. "dokumentum", "beszélgetés") határozza meg a RecordKind mezőt
- Visszatér {"id": <u64>}} siker esetén

- GET /records/:id: Hívja le a rekordot az egyedi azonosítója alapján Hívja Database.getJson()
- DELETE /records/:id: Database.del() hívása

### Keresés műveletek

- POST /search: Szöveges, vektoros vagy hibrid keresések végrehajtása.
- A kiszolgáló a kérés testét keresési lekérdezéssé elemzi, és a Database.search() vagy Database.vectorSearch() parancsra delegálja.
- Végrehajtás: HandleSearch()

### Karbantartás

- POST /compact: Database.compact() hívása.
- POST /flush: Database.flush() hívása.

### Hibakezelés

Minden hiba következetes szerkezetű JSON objektumként kerül visszaadásra: {"error": "ErrorName", "message": "hiba": "hiba": "hiba": "hiba": "leírás"}. Ezt a belső segédprogram respondJsonError() kezeli

Entitás leképezés: API a motorhoz

- src/server.zig: A HTTP-kiszolgáló, az útválasztás és a kéréskezelés elsődleges implementációja.
- src/api.zig: A tartós fogantyúk és interakciós módok definíciói.
- src/database.zig: A kiszolgáló kezelői által hívott backend metódusok.

## Core Database Engine

Az Adatbázis struktúra az agdb motor elsődleges belépési pontjaként és irányítójaként szolgál. Integrálja az alacsony szintű tárolást a magas szintű keresési képességekkel, három különböző, de egymással összekapcsolt alrendszert kezelve: egy napló-struktúrált kulcs-érték tárolót, egy BM25 teljes szöveges indexet és egy vektoros hasonlósági indexet.

### Rendszerarchitektúra

Az adatbázis kezeli a rekordok életciklusát a beviteltől a visszakeresésig. Amikor egy rekordot beillesztünk, azt szerializáljuk és tároljuk a KvStore-ban, a kulcsszavas kereséshez a Bm25Index indexeli, a szemantikus kereséshez pedig a VectorIndexbe ágyazza.

### Core Orchestration diagram

Ez az ábra azt szemlélteti, hogy az Adatbázis struktúra hogyan koordinálja az adatáramlást a belső összetevői között.

### Alapvető összetevők

A motor négy elsődleges alrendszerből áll, amelyek mindegyikét dedikált aloldalak kezelik részletesen.

### 1. Kulcs-érték tároló (KvStore)

A KvStore biztosítja a motor tartós gerincét. Csak függelékkel ellátott naplóstruktúrájú formátumot használ (store.kv), és egy memórián belüli StringHashMap-ot tart fenn az O(1) keresésekhez. Felelős mind a nyers Record adatok, mind a BM25 és Vector indexek szerializált állapotainak tárolásáért.

- Kulcsfájlok:src/kv.zig
- Részletek: Lásd

### 2. Teljes szöveges keresés: BM25 Index

A Bm25Index a BM25 rangsoroló algoritmust alkalmazza, hogy releváns kulcsszavas keresési eredményeket adjon. A rekordok testmezőjét egy tokenizáló csővezetéken keresztül dolgozza fel (támogatja az n-grammok és a zárószavak szűrését), és a hatékony visszakeresés érdekében bejegyzési listákat vezet.

- Kulcsfájlok:src/bm25.zig
- Részletek: Lásd

### 3. Vektor keresési index

A VectorIndex kezeli a szemantikus hasonlósághoz szükséges nagydimenziós beágyazásokat. Többféle távolsági metrikát támogat (koszinusz, euklideszi stb.), és egy hashEmbed függvényt biztosít a beágyazások automatikus generálásához a szövegből, ha nincs megadva.

- Kulcsfájlok:src/vector.zig
- Részletek: Lásd

### 4. Rekordok és séma

A Record struktúra határozza meg az adatbázis adatmodelljét, amely támogatja a különböző RecordKind típusokat (pl. dokumentum, beszélgetés). A RecordWriter és RecordReader kezeli ezen rekordok bináris szerializálását egy saját RECORD_MAGIC előtaggal ellátott formátum segítségével.

- Kulcsfájlok:src/record.zig
- Részletek: Lásd

### Adatbeviteli folyamat

A put művelet az összevonási logikát mutatja be. Belső mutexek és kézi hibajavítás segítségével biztosítja az atomicitást a három tárolási rétegben.

| Lépés | Entitás/Funkció | Leírás |
| --- | --- | --- |
| 1 | nextId() | Egyedi u64 azonosítót generál vagy érvényesít a rekordhoz. |
| 2 | hashEmbed() | Ha az automatikus beágyazás engedélyezve van, a szövegtestből vektort generál. |
| 3 | RecordWriter.encode() | Sorozatba rendezi a Record struktúrát egy bináris pufferbe. |
| 4 | KvStore.put() | A szerializált rekordot a csak függelékként használt naplóba írja. |
| 5 | Bm25Index.addDocument() | Tokenizálja a szöveget és frissíti az invertált indexet. |
| 6 | VectorIndex.upsert() | Beilleszti a beágyazást a vektortérbe. |

### Állapotmegmaradás és állapothelyreállítás

Az adatbázis nem tárolja a keresési indexeket külön fájlokban. Ehelyett a teljes Bm25Indexet és VectorIndexet byte tömbökké szerializálja és speciális kulcsokként tárolja a KvStore-on belül

Amikor az adatbázist a Database.open() segítségével megnyitjuk, a rendszer újratölti ezeket az állapotokat a KvStore-ból. Ha az állapotkulcsok hiányoznak vagy sérültek, akkor az indexek üresen inicializálódnak újra

### Keresési lehetőségek

A motor három elsődleges keresési módot támogat, amelyek a QueryResult.Source-ban vannak definiálva

1.   BM25: Kulcsszó alapú rangsorolás.
2.   Vektor: Szemantikai hasonlósági rangsor.
3.   Hibrid: A kettő kombinációja (a végrehajtás részletei a gyermekoldalakon).

A keresési funkció egy QueryResults objektumot ad vissza, amely a QueryResult elemek listáját tartalmazza, amely tartalmazza a számított pontszámot, az eredmény forrását és a hidratált Record objektumot

## Kulcs-érték tároló (KvStore)

A KvStore egy nagy teljesítményű, csak függelékkel rendelkező, naplószerkezetű tárolómotor, amelyet az agdb mind a belső metaadatok (bérlői nyilvántartás), mind a felhasználói adatok számára használ. Tartós, szálbiztos interfészt biztosít tetszőleges bájtmintatömb kulcsok és értékek tárolására.

### Áttekintés és cél

A KvStore egy Log-Structured Merge-Tree (LSM) stílusú, csak függelékkel ellátott naplót valósít meg Minden írási művelet (put vagy delete) a .kv fájl végére kerül, így biztosítva a nagy írási teljesítményt és az adatok integritását a szekvenciális I/O révén. A memórián belüli index $O(1)$ keresési teljesítményt biztosít

### Fő jellemzők

- Append-Only Persistence: Minimalizálja a lemezkeresést és egyszerűsíti a helyreállítást
- Memórián belüli indexelés: StringHashMap-ot használ a gyors kulcs-az-Offset kereséshez
- Integritásvédelem: Minden rekordot CRC32 ellenőrző összeg véd
- Atomic Header frissítések: Fenntartja a FileHeader-t az utolsó érvényes eltolással, hogy megakadályozza a részleges írások olvasását
- Automatikus tömörítés: A törölt vagy felülírt kulcsok eltávolításával visszanyeri a helyet

### Fájlformátum specifikáció

A .kv fájl egy fix méretű FileHeader-ből áll, amelyet változó hosszúságú Record bejegyzések sorozata követ.

### Fájl elrendezés diagram

A FileHeader a 0-ás eltoláson található, és a tároló állapotára vonatkozó metaadatokat tartalmazza.

| Mező | Típus | Leírás |
| --- | --- | --- |
| magic | u32 | Mindig 0x41474442 ("AGDB") |
| version | u16 | Fájlformátum verzió |
| created_at | u64 | Létrehozási időbélyeg mikroszekundumokban |
| last_offset | u64 | Az utolsó sikeres írás végének bájteltávolsága |
| record_count | u64 | Az aktív rekordok száma |

Minden írási művelet egy RecordHeader-t csatol, amelyet a nyers kulcs és érték bájtok követnek.

| Mező | Típus | Leírás |
| --- | --- | --- |
| magic | u32 | Érvényesíti a rekord kezdetét |
| op | u8 | Művelet típusa: |
| key_len | u16 | A kulcs hossza (max. 64KB) |
| value_len | u32 | Az érték hossza (Max 64MB) |
| crc32 | u32 | Op + kulcs + érték + időbélyegző |

### Alapvető végrehajtás

### Az In-Memory index

A KvStore egy std.StringHashMapUnmanaged(Entry) Az Entry struktúra tárolja az érték helyét és méretét a lemezen:

- kompenzáció: A rekord abszolút fájlpozíciója
- value_offset: Az értékadatok kezdete
- value_len: Az érték mérete

### Adatáramlás: Put művelet

A put(kulcs, érték) hívásakor a tároló a következő lépéseket hajtja végre:

1.   Zárolás: A szálak biztonságának biztosítása érdekében mutexet szerez
2.   Sorozatba rendezés: Előkészíti a RecordHeader-t és kiszámítja a CRC32-t
3.   Függelék: A fejlécet, a kulcsot és az értéket a fájl végére írja
4.   Fejlécfrissítés: Frissíti a fájlfejlécben a last_offset értéket és törli a lemezre
5.   Indexfrissítés: A kulcs és az új bejegyzés beillesztése a StringHashMap-be. Ha a kulcs már létezett, a régi bájtokat dead_bytes-ként jelöli

### Helyreállítás és integritás

### Napló visszajátszás

Amikor egy KvStore-t megnyit, egy naplóvisszajátszást hajt végre A FileHeader végétől indul, és a rekordokat szekvenciálisan olvassa, amíg el nem éri a last_offset értéket

- Ha egy rekord varázsa érvénytelen vagy a crc32 hibás, a lejátszás leáll 211
- Ez biztosítja, hogy a rendszerösszeomlásból származó részleges írásokat figyelmen kívül hagyja, és gyakorlatilag visszaállítja a legutóbbi atomi FileHeader frissítést.

### Tömörítés

Mivel a tároló csak függelékkel működik, a kulcsok törlése vagy frissítése "holt" adatokat hagy a fájlban. A compact() függvény visszaszerzi ezt a helyet:

1.   Új ideiglenes .kv.compact fájlt hoz létre
2.   Végigfut az aktuális memórián belüli indexen (amely csak élő kulcsokat tartalmaz)
3.   Átmásolja az élő adatokat a régi fájlból az új fájlba
4.   Atomikusan kicseréli a régi fájlt az újjal

### Iterátor interfész

A KvStore biztosít egy Iterátort a tárolóban jelenleg található összes kulcs bejárásához.

var it = store.iterator();while (try it.next()) |entry| { // entry.key a kulcs string // entry.value az érték byte-okat tartalmazza}

### A végrehajtás részletei

Az iterátor létrehozásakor zárolja a KvStore-t, hogy pillanatfelvételt készítsen az aktuális állapotról, vagy a mögöttes HashMap iterátorra támaszkodik Egy next() metódust biztosít, amely egy Iterator.Entry-t ad vissza, amely tartalmazza a kulcsot és egy frissen allokált puffert az értéknek

### Műszaki összefoglaló táblázat

| Component | Code Entity | Fájlhivatkozás |
| --- | --- | --- |
| Tároló példány | KvStore | | |
| Record Header | RecordHeader | | | |
| Fájlfejléc | Fájlfejléc | | | |
| Indexbejegyzés | Bejegyzés | | |
| Checksum Logic | computeCrc | | |
| Hashing | stableHash | | |

## Teljes szöveges keresés: BM25 Index & Tokenizer

Az agdb Full-Text Search (FTS) alrendszere a BM25 (Best Matching 25) rangsoroló algoritmust használó, relevanciaalapú dokumentumkeresést biztosít. Ez egy robusztus tokenizáló csővezetékből áll a szöveg normalizálásához és egy invertált indexstruktúrából, amelyet gyors kifejezésalapú keresésre és pontozásra optimalizáltak.

### BM25 index végrehajtása

A Bm25Index struktúra kezeli az invertált indexet, a dokumentumstatisztikákat és a pontozási logikát. Invertált indexet használ, ahol a kulcsok hashelt tokenek, az értékek pedig dokumentumazonosítókat és kifejezésfrekvenciákat tartalmazó postázási listák.

### Főbb összetevők

- Bm25Params: Az algoritmus konstansait $k_1$ (kifejezésfrekvencia telítettség) és $b$ (hossz normalizálás), valamint az alapul szolgáló tokenizáló opciókat konfigurálja
- Postázás: Egyszerű struktúra, amely rögzíti a doc_id-t és egy adott kifejezés tf gyakoriságát az adott dokumentumon belül
- Bm25Index: A BM25 pontozáshoz szükséges átlagos dokumentumhossz ($avgdl$) kiszámításához szükséges total_terms, total_docs és doc_lengths értékeket nyomon követő elsődleges motor

### Pontszámítási képlet

Az implementáció kiszámítja a lekérdezés relevancia pontszámát egy dokumentumhoz a következő módon: $score(D, Q) = \sum_{q \in Q} IDF(q) \cdot \frac{f(q, D) \cdot (k_1 + 1)}{f(q, D) + k_1 \cdot (1 - b + b \cdot \frac{|D|}{avgdl})}$

Ahol az $IDF$-t úgy számoljuk ki, hogy $\ln(\frac{N - n(q) + 0.5}{n(q) + 0.5} + 1)$

### BM25 Keresés adatáramlás

Ez az ábra azt szemlélteti, hogyan alakul át egy lekérdezési karakterlánc a SearchHit objektumok rangsorolt listájává.

Lekérdezés-feldolgozás és pontozás

### Tokenizer csővezeték

A tokenizáló felelős a nyers karakterláncok normalizált tokenek folyamává alakításáért. Támogatja az Unicode-alapú kisbetűzést, a zárószavak eltávolítását és az n-grammok generálását.

### Tokenizálási folyamat

1.   UTF-8 dekódolás: A bemenetet 21 bites kódpontokból álló folyamként dolgozza fel az utf8DecodeNext használatával
2.   Normalizálás: A kódpontok szűrése az isAlphaNum segítségével történik, és opcionálisan kisbetűvé alakíthatók a toLowerCodepoint használatával
3.   Szűrés: A TokenizerOptions-ban meghatározott min_token_len vagy max_token_len határértékeken kívül eső tokeneket elvetjük
4.   N-grammok: Ha ngram_max > 1, a tokenizeAndNgram függvény átfedő tokenszekvenciákat generál (pl. "quick brown fox" -> "quick brown", "brown fox")

### Tokenizer entitás leképezés

Ez az ábra a természetes nyelvi fogalmakat a belső Zig-reprezentációkkal hidalja át.

Természetes nyelv az entitás tér kódolásához

### RankIndex & MinHash

A RankIndex a BM25 alternatíváját kínálja a MinHash aláírások és a Jaccard-hasonlóság használatával az újrarangsoroláshoz és a szekvencia pontozáshoz.

- RankIndex: Integrál egy rangsorolót és egy SSI-t (Sequence Segment Index) a dokumentumsorozatok kezelésére
- MinHash: A rangsoroló képes kiszámítani egy MinHash aláírást egy tokenhalmazra, ami lehetővé teszi a dokumentumok közötti Jaccard-hasonlóság közelítését a teljes tokenhalmazok összehasonlítása nélkül
- Újrarangsorolás: A rerank funkció a meglévő keresőjelölteket veszi (pl. vektoros keresésből), és az n-gram átfedés és a sokféleség súlyai alapján módosítja a pontszámukat

### Kitartás

A Bm25Index támogatja a lemezre történő szerializálást a serialize és deserialize függvényeken keresztül. Ezek a metódusok a belső HashMaps (postings, doc_lengths, doc_id_set) és a globális számlálókat egy std.io.Writer-be írják Ez biztosítja, hogy a keresési index gyorsan újratölthető legyen anélkül, hogy az adatbázis indításakor a teljes KV tárolót újraindexelnénk.

| Funkció | Szerep | Forrás |
| --- | --- | --- |
| addDocument | Tokenizálja a szöveget és frissíti az invertált indexet | | |
| removeDocument | Eltávolítja a dokumentumot a bejegyzésekből és frissíti a statisztikákat | | |
| Keresés | BM25 pontozás és a K legjobb találat visszaadása | | | |
| tokenize | A karakterláncok normalizálásának fő belépési pontja | | |
| hashToken | 64 bites hash kiszámítása a kifejezés kereséséhez | | |

## Vektor keresési index

A VectorIndex nagy teljesítményű hasonlósági keresési lehetőségeket biztosít a nagydimenziós adatokhoz. Többféle távolsági metrikát támogat, integrál egy speciális Tensor típust a matematikai műveletekhez, és kihasználja a GPU-gyorsítást a Futhark által generált kernelek segítségével a számításigényes feladatokhoz.

### Architektúra és adatáramlás

A vektorkeresési alrendszer a VectorIndex struktúra köré épül, amely a VectorEntry objektumok gyűjteményét kezeli. Minden egyes bejegyzés egy dokumentum azonosítóját társítja a megfelelő beágyazással és az előre kiszámított normával a gyorsabb hasonlósági számítások érdekében.

### Rendszer leképezése: Természetes nyelvből kódolt entitásokba

A következő ábra azt szemlélteti, hogy a konceptuális vektoros keresési műveletek hogyan kapcsolódnak az agdb motoron belüli konkrét kódegységekhez.

Vektoros keresési komponens térkép

### VectorIndex API

A VectorIndex az elsődleges felület a beágyazások kezelésére és lekérdezésére. Úgy tervezték, hogy szálbiztos legyen egy belső std.Thread.Mutex.

### Támogatott távolsági mérőszámok

Az index négy elsődleges mérőszámot támogat a hasonlóság meghatározásához:

- Kozinusz: Két vektor közötti szög koszinuszát méri.
- Belső termék: Standard ponttermék.
- Euklideszi: Pontok közötti egyenes vonalú távolság.
- Manhattan: Az abszolút különbségek összege.

### Kulcsfunkciók

- upsert(doc_id, vektor): Vektor beillesztése vagy frissítése. A bemeneti vektort duplikálja az index allokátorába, és előre kiszámítja a normát
- remove(doc_id): Töröl egy vektort, és frissíti a belső id_to_idx térképet a "swap with last" stratégiával a sűrű tömb fenntartása érdekében
- search(allocator, query, top_k): Az összes bejegyzés lineáris átvizsgálását végzi, a pontszámokat a konfigurált távolsági metrika alapján számítja ki, és a legjobb eredményeket MaxHeap

### Tenzorok és számítási integráció

A vektorműveletek mögött egy kifinomult Tensor implementáció áll, amely támogatja a többdimenziós alakzatokat, a lépéseket és a Copy-on-Write (CoW) szemantikájú hivatkozásszámlálást.

### Tensor típus

A Tensor struktúra 32 bájtos igazítással kezeli az f32 adatokat a SIMD optimalizálás megkönnyítése érdekében Tartalmaz egy Shape segédprogramot a műsorszórás és az egybefüggő memória ellenőrzések kezelésére

### GPU és Futhark integráció

A nagyméretű számításokhoz az agdb a GPUContextet használja a GPU-kernelekhez való kapcsolódáshoz. Ezek a kernelek jellemzően a Futharkból (src/compute.fut) vannak fordítva, és nagy teljesítményű implementációkat biztosítanak a következőkhöz:

- dot_product
- euclidean_distance
- cosine_similarity

A GPUContext ezeket dinamikus könyvtárként tölti be, és az eszköz memóriáját a GPUArray segítségével kezeli

Adatáramlás: Keresés a GPU végrehajtásához

### Hash-alapú automatikus beágyazás (hashEmbed)

Ha a nyers vektorok nem állnak rendelkezésre, a rendszer a hashEmbed segítségével stabil beágyazásokat tud generálni a szövegből. Ez a funkció egy feature hashing (hashing trükk) megközelítést használ tetszőleges karakterláncok leképezésére egy fix dimenziós térbe.

| Jellemző | Megvalósítás |
| --- | --- |
| Bemenet | Tetszőleges karakterláncadatok |
| Kimenet | []f32 méretben dim |
| Mechanizmus | Tokenek iteratív hashelése normalizált kimenettel |
| Stabilitás | Determinisztikus; ugyanaz a szöveg mindig ugyanazt a vektort eredményezi |

### Szerializáció

A VectorIndex támogatja a bináris állandóságot, hogy az indexet el lehessen menteni és újra lehessen tölteni a lemezről.

1.   Fejléc: 0x56454330), a verzió, a dimenzió és a távolság metrika
2.   Bejegyzések: Végigmegy a bejegyzéseken, kiírja a doc_id, a norm és a nyers f32 vektor adatokat
3.   Deserializálás: A bejegyzések olvasása közben rekonstruálja az id_to_idx hash-térképet, hogy biztosítsa az O(1) keresések helyreállítását

### SIMD optimalizálás

Az alacsony szintű vektorműveletek (GPU üzemmódon kívül) a Zig @Vector típusait használják a SIMD gyorsításhoz. A simd.zig modul segédprogramokat biztosít a következőkhöz:

- Memória műveletek: simdZero a puffer gyors törléséhez
- Előhívás: prefetchForRead és prefetchForWrite az indexszkennelés során a gyorsítótár kihagyásainak minimalizálása érdekében

## Rekordok és séma

A Record rendszer határozza meg az adattárolás alapvető egységét az agdb-ben. Strukturált adatmodellt biztosít, amely támogatja a teljes szöveges keresést, a vektoros beágyazásokat és a metaadatok címkézését. Ezt egészíti ki a SchemaRegistry, amely egy reflexió-szerű rendszert biztosít a strukturális metaadatok kezelésére, lehetővé téve a típusbiztos objektumérvényesítést és a migrációt összetett adatstruktúrákhoz.

### Rekord adatmodell

A Record egy polimorfikus tároló, amelyet az adatbázis-motoron belül különböző adattípusok számára használnak. Tartalmazza a szabványos metaadatokat (azonosítók, időbélyegek), egy kereshető szöveges testet, egy címke listát és egy opcionális nagydimenziós vektoros beágyazást.

### Rekordszerkezet

A Record struct a következő mezőkkel van definiálva:

| Mező | Típus | Leírás |
| --- | --- | --- |
| id | u64 | A rekord egyedi azonosítója. |
| kind | RecordKind | A rekord kategóriája (pl. dokumentum, személy). |
| created_at_us | i64 | Létrehozási időbélyeg mikroszekundumokban. |
| updated_at_us | i64 | Utolsó frissítés időbélyege mikroszekundumokban. |
| tags | []const []const u8 | A szűréshez és kategorizáláshoz használt stringcímkék listája. |
| body | []const u8 | A BM25 indexeléshez használt elsődleges szöveges tartalom. |
| beágyazás | ?[]const f32 | Választható vektor a hasonlósági keresésekhez. |

### Felvétel fajták

A RecordKind enum kategorizálja az adatokat a magas szintű logika számára:

- dokumentum (0): Általános célú szöveges adatok.
- beszélgetés (1): Interakciós naplók vagy csevegési előzmények.
- jelenet (2): Kontextuális vagy környezeti leírások.
- persona (3): Felhasználói vagy ügynöki profilok.
- custom (255): Felhasználó által meghatározott típusok.

### Bináris kódolási formátum

A rekordok a KvStore-ban való tároláshoz kompakt bináris formátumba kerülnek. Ezt a folyamatot a RecordWriter és a RecordReader kezeli.

### Szerializációs elrendezés

A formátum little-endian kódolást használ, és a RECORD_MAGIC (0x52454331) bűvös számmal kezdődik

| Offset | Méret | Mező | Leírás |
| --- | --- | --- | --- |
| 0 | 4 | Magic | 0x52454331 |
| 4 | 1 | Kind | RecordKind egész érték |
| 5 | 3 | Tömés | Igazításhoz/jövőbeni használatra fenntartva |
| 8 | 8 | 8 | ID | Rekord azonosító (u64) |
| 16 | 8 | Created | Időbélyegző (i64) |
| 24 | 8 | Frissítve | Időbélyeg (i64) |
| 32 | 4 | Címkeszám | Címkék száma |
| 36 | Var | Címkék | u16 hosszúságú + UTF-8 bájtok tömbje |
| Var | 4 | Body Len | A body string hossza |
| Var | Var | Var | Body | UTF-8 bájt |
| Var | 4 | Emb Len | f32 elemek száma (0, ha nincs) |
| Var | Var | Var | Beágyazás | U32 bit-kódolt lebegőszámok sorozata |

### Végrehajtási logika

- Kódolás: ArrayList-et használ a szerializált bájtok pufferelésére.
- Dekódolás: Dekódolás: A RecordReader.decode rekonstruálja a Record struktúrát, elvégzi a bűvös szám érvényesítését, és memóriát rendel a címkék és karakterláncok számára.

### JSON integráció

az agdb megbízható segédprogramokat biztosít a belső Record formátum és a JSON közötti konvertáláshoz, amelyet elsősorban a CLI és a HTTP API használ.

### Konvertálási folyamat: JSON to Code Entities

Ez az ábra azt szemlélteti, hogy a fromJson függvény hogyan képezi le a JSON mezőket a Record struktúrába.

- fromJson: Body mezőbe JSON kulcsokat, mint a body, content vagy text
- toJson: Value objektumba, beleértve az összes metaadatot és beágyazást is

### Séma nyilvántartás

A SchemaRegistry egy mechanizmust biztosít az adatbázisban tárolt adatok szerkezetének meghatározásához, tárolásához és érvényesítéséhez. Lehetővé teszi az agdb számára, hogy az összetett Zig-struktúrákat első osztályú adatbázis-egységként kezelje.

### Főbb összetevők

1.   StructInfo: A regisztrált típusra vonatkozó metaadatokat tartalmazza, beleértve a méretet, az igazítást és a verziószámozáshoz szükséges ellenőrző összeget
2.   FieldInfo: Az egyes mezők leírása a struktúrán belül, rögzítve azok eltolását, méretét és FieldKind (pl. int, float, struct_)
3.   SchemaEntry: A teljes jegyzékbejegyzés, amely a séma_id-t összekapcsolja a séma nevével és szerkezeti meghatározásával

### Regisztráció és érvényesítés

A regiszter a Zig comptime reflexióját használja a registerSchema hívás során a típusinformációk kinyerésére

- validateObject: Ellenőrzi, hogy egy nyers bájt szelet megfelel-e a regisztrált sémának a hossz és a mezőhatárok ellenőrzésével
- migrateObject: Megkönnyíti az adatok átalakítását a különböző séma verziók között a regisztrált MigrationFn hívások segítségével

## Perzisztencia és futásidő réteg

A Perzisztencia és futásidő réteg biztosítja az agdb alapvető infrastruktúráját. Ezt a Runtime struktúra hangszereli, amely a memóriakezelés, a tartósság, az egyidejűség és a biztonság központi kapcsolási pontjaként szolgál.

Ez a réteg biztosítja, hogy az adatok konzisztensek maradjanak az összeomlások során a WAL (Write-Ahead Log) segítségével, nagyméretű adatokat kezel egy memóriával leképezett Persistent Heap segítségével, és tranzakciós garanciákat nyújt a felső szintű adatbázis-motorok számára.

### Rendszerarchitektúra

A Runtime több speciális alrendszert integrál egy egységes felületbe. Kezeli az adatbázis életciklusát a kezdeti helyreállítástól a tiszta leállításig.

Futtatási idejű orchestrációs diagram

### Futásidejű konfiguráció és inicializálás

A futásidő konfigurálása a RuntimeConfig segítségével történik, amely meghatározza a fájlok elérési útvonalait, a halom méretét és a biztonsági paramétereket. A Runtime.init meghívásakor a rendszer a következő sorrendet hajtja végre:

1.   A SecurityManager inicializálása opcionális titkosításhoz
2.   A PersistentHeap leképezése a memóriába
3.   Megnyitja a WAL-t és futtatja a RecoveryEngine-t az elmaradt tranzakciók újrajátszásához
4.   A PersistentAllocator és a TransactionManager beállítása

Entitás leképezés: Konfiguráció a futásidőhöz

### Az alrendszerek áttekintése

### Tartós halom (PHeap)

A PersistentHeap az mmap segítségével kezeli az elsődleges adatfájlt. Biztosítja az alacsony szintű memóriaelrendezést, támogatja a struktúrák közvetlen perzisztenciáját a PersistentPtr és RelativePtr segítségével. Kezeli a gyorsítótár-vonali visszaírásokat (CLWB) és a memória újratelepítését az adatbázis növekedésével.

- Részletek: Lásd

### Write-Ahead napló (WAL)

A WAL biztosítja az atomicitást és a tartósságot (D az ACID-ben). Minden módosítást WALRecordként rögzítünk (allokálás, írás, commit stb.), mielőtt a halomra alkalmaznánk. Az io_uringot használja a nagy teljesítményű aszinkron I/O-hoz, és támogatja a fuzzy checkpointingot, hogy a naplóméretek kezelhetőek maradjanak.

- Részletek: Lásd

### Tranzakciókezelő és párhuzamosság

A TransactionManager koordinálja a többszálú hozzáférést az adatbázishoz. Serializálható pillanatfelvétel-izolációt (SSI) valósít meg, és ahol rendelkezésre áll, a hardveres tranzakciós memóriát (HTM) használja. Nyomon követi az aktív tranzakciókat, és kezeli a tranzakciós objektumok életciklusát a begin() funkciótól a commit() vagy a rollback() funkcióig.

- Részletek: Lásd

### Szemétgyűjtés, pillanatfelvételek és biztonság

Ez a modul kezeli a karbantartást és a biztonságot:

- RefCountGC: Referencia-számláló gyűjtő, amely visszaszerzi az elérhetetlen blokkokat a tartós halomban.
- SnapshotManager: A heap-fájlról készített, pont-időpontos biztonsági mentéseket kezeli.
- SecurityManager: Kezeli a titkosítást (AES-GCM/ChaCha20), és a TPM2-vel integrálódik a biztonságos kulcstároláshoz.
- Részletek: Lásd

### Futásidő-statisztika

A Runtime a RuntimeStats struktúrán keresztül valós idejű telemetriát biztosít, amely lehetővé teszi az operátorok számára a halomhasználat, a tranzakciók teljesítményének és a GC hatékonyságának nyomon követését.

| Metrika | Forrás | Leírás |
| --- | --- | --- |
| heap_used | | | A tartós halomban jelenleg allokált bájtok. |
| wal_size | | | A Write-Ahead naplófájl aktuális mérete. |
| transaction_count | | | Az indítás óta feldolgozott tranzakciók száma. |
| gc_stats | | A RefCountGC alrendszer statisztikái. |

## Tartós halom (PHeap)

A Persistent Heap (PHeap) az agdb alapvető memóriakezelő alrendszere. memória leképezésű interfészt biztosít egy fájlalapú tárolópoolhoz, lehetővé téve az adatbázis számára, hogy a lemezen tárolt adatokat úgy kezelje, mintha azok memóriában lennének, miközben fenntartja az összeomlási konzisztenciát és a perzisztenciát. Kezeli az olyan alacsony szintű problémákat, mint a gyorsítótár-vonali visszaírások, a piszkos oldalak követése és a memóriaképes címfeloldás.

### Memóriaelrendezés és inicializálás

A PersistentHeap struktúra egyetlen egybefüggő memória-leképezett fájlt kezel Az elrendezés a HeapHeaderrel kezdődik, amelyet az AllocatorMetadata és a tényleges adatrégió követ.

A HeapHeader egy 256 bájtos struktúra a fájl elején, amely metaadatokat tartalmaz a halom állapotáról

| Mező | Leírás |
| --- | --- |
| magic | A fájlt érvényes ZIGPHEAP-ként azonosítja |
| pool_uuid | A kupacpéldány 128 bites egyedi azonosítója |
| endianness | A platformok közötti kompatibilitási problémák észlelésére |
| heap_size | A háttértár teljes mérete |
| root_offset | Az adatbázis gyökérobjektumához való eltolás |
| allocator_offset | A PersistentAllocator metaadatainak eltolási értéke |

### Életciklus: Kód-entitás leképezés

A következő ábra azt mutatja, hogyan inicializálódik a PersistentHeap, és hogyan lép kölcsönhatásba a mögöttes fájlrendszerrel.

Heap inicializálási folyamat

### Mutatótípusok: És RelativePtr

Az abszolút memóriacímek (amelyek a folyamatok újraindítása között változnak) és a fájl offsets (amelyek stabilak) közötti eltérés kezelésére az agdb két speciális mutatótípust használ.

### PersistentPtr

Egy objektum globálisan egyedi azonosítója a halomban. Tartalmazza a pool_uuid-et és a halom elejétől való abszolút eltolódást

- Felhasználási eset: Olyan hivatkozások tárolása, amelyeknek akkor is érvényesnek kell maradniuk, ha a kupacot áthelyezik vagy a folyamatot újraindítják.
- Felbontás:A PersistentHeap.resolvePtr ellenőrzi a pool_uuid-et és hozzáadja az offsetet a base_addr-hez

### RelativePtr(T)

Belső adatstruktúrákhoz használt, típusbiztos relatív mutató. Az offsetet és a pool_uuid-et csomagolt formátumban tárolja

- Inline értékek: Támogatja a 15 bites kis értékek tárolását közvetlenül a mutatóban a kiosztások elkerülése érdekében
- Címkék: Tartalmaz egy 16 bites címke mezőt a metaadatokhoz (pl. típusinformáció)

Mutatófelbontási logika

### Piszkos oldalkövetés és perzisztencia

A PersistentHeap oldalszinten követi a módosításokat, hogy optimalizálja a lemezzel való szinkronizálást.

1.   Piszkos jelölés: A markDirty(offset, size) kiszámítja, hogy a dirty_pages bitsetben mely oldalakat kell true-ra állítani
2.   Öblítés: A flush() függvény végigmegy a dirty_pages-en, és msync vagy manuális cache-line visszaírást használ az adatok tartósítására
3.   Cache-soros visszaírás (CLWB): A tartós memóriát támogató hardverek esetében a kupac a CLWB vagy CLFLUSHOPT utasítások segítségével finom szemcsés visszaírásokat végezhet, hogy az adatok teljes msync nélkül is elérjék a tartós tartományt

### Nem időbeli tárolók és előhívás

A nagy tömegű átviteleknél a halom használja:

- Nem időbeli tárolók: Megkerüli a CPU gyorsítótárát, hogy elkerülje a "gyorsítótár szennyezését" a nagyméretű írások során
- Prefetch Pipelining: A _mm_prefetch-et használja a következő adatok betöltésére a gyorsítótárba, miközben az aktuális blokk feldolgozása folyamatban van

### Halom bővítése és kezelése

Amikor a PersistentAllocator kifogy a helyből, a halom dinamikusan bővíthető.

| Funkció | Szerep |
| --- | --- |
| expand(new_size) | Átméretezi a háttértárfájlt az ftruncate segítségével, és újra leképezi a memóriát |
| mremap | Támogatott rendszereken (Linux) az mremap segítségével hatékonyan, adatok másolása nélkül növeli a leképezést |
| allocate(size, alignment) | Alacsony szintű "bump" allokátor, amelyet a kezdeti beállítás során vagy metaadatokhoz használnak; a legtöbb allokáció a PersistentAllocatoron keresztül történik |

Adatáramlás: Kiosztás és perzisztencia

- src/pheap.zig: A PersistentHeap, az msync logika és a fájl leképezés megvalósítása.
- src/header.zig: HeapHeader és ObjectHeader definíciója.
- src/pointer.zig: És RelativePtr definíciói.
- src/allocator.zig: Interakció a heap és a slab allocator között.

## Write-Ahead napló (WAL)

A Write-Ahead Log (WAL) az agdb elsődleges tartóssági mechanizmusa. Atomicitást és tartósságot (ACID) biztosít azáltal, hogy minden változást rögzít, mielőtt azokat a fő adatfájlokra alkalmaznák. A WAL megvalósítása aszinkron csővezetéket, io_uring integrációt és fuzzy checkpointingot használ a kritikus írási útvonal késleltetésének minimalizálása érdekében.

### WAL szerkezet és fejlécek

A WAL egy körkörös naplófájlként tárolódik, alapértelmezés szerint 64 MB méretűre inicializálva <FileRef file-url=" min=15 file-path="src/wal.zig">Hii</FileRef>. Egy WALHeaderrel kezdődik, amely a napló állapotát követi nyomon, beleértve a körkörös puffer fej/farok eltolódásait és a legutóbbi sikeres ellenőrzőpont LSN-jét (Log Sequence Number).

| Mező | Típus | Leírás |
| --- | --- | --- |
| magic | u32 | Constant 0x57414C46<FileRef file-url=" min=10 file-path="src/wal.zig">Hii</FileRef>. |
| verzió | u32 | WAL formátum verzió. |
| file_size | u64 | A WAL-fájl teljes mérete a lemezen. |
| last_checkpoint | u64 | Az utolsó befejezett ellenőrzési pont eltolódása. |
| head_offset | u64 | Az aktív naplóadatok kezdete. |
| tail_offset | u64 | Az aktív naplóadatok vége (ahová az új rekordokat csatolják). |
| checksum | u32 | CRC32C a fejléc mezőinek <FileRef file-url=" min=77 max=88 file-path="src/wal.zig">Hii</FileRef>. |

 <FileRef file-url=" min=38 max=94 file-path="src/wal.zig">Hii</FileRef>

### WAL rekordok és visszavonási adatok

A változásokat WALRecord struktúrákba kapszulázzák. Minden rekord opcionálisan tartalmazhat "visszavonási adatokat", amelyek a módosítás előtti memóriarégió másolatai. Ez lehetővé teszi a RecoveryEngine számára a befejezetlen tranzakciók visszaállítását.

Rekordtípusok (RecordType):

- begin / commit / rollback: Tranzakció életciklusának határai.
- allokálni / felszabadítani: Heap memóriakezelési műveletek.
- írni: Egy memóriatartomány közvetlen módosítása a PHeapben.
- ellenőrzőpont: Jelöli azt a pontot, amikor az összes korábbi adatot a fő tárolóba ürítik.
- ref_count_inc / ref_count_dec: Szemétgyűjtési metaadatok frissítése.

Adattömörítés visszavonása: Ha visszavont adatok vannak jelen, a RECORD_FLAG_UNDO_COMPRESSED jelző <FileRef file-url=" min=17 file-path="src/wal.zig">Hii</FileRef> jelzi, hogy az adatokat tömörítették-e, mielőtt a naplóba írták volna az I/O-sávszélesség megtakarítása érdekében.

 <FileRef file-url=" min=20 max=36 file-path="src/wal.zig">Hii</FileRef>, <FileRef file-url=" min=96 max=128 file-path="src/wal.zig">Hii</FileRef>

### Tranzakció életciklusa

A Transaction struct a WALRecord bejegyzések gyűjteményét kezeli a memóriában, mielőtt a lemezre kerülnének.

### Tranzakcióáramlási diagram

Ez az ábra a memóriarezisztens tranzakcióról a lemezen tárolt WALRecord bejegyzésekre való áttérést szemlélteti.

 <FileRef file-url=" min=193 max=207 file-path="src/wal.zig">Hii</FileRef>, <FileRef file-url=" min=630 max=660 file-path="src/wal.zig">Hii</FileRef>, <FileRef file-url=" min=10 file-path="src/iouring.zig">Hii</FileRef>

### Aszinkron csővezeték és io_uring

Annak megakadályozására, hogy a WAL írások blokkolják a fő végrehajtó szálakat, az agdb egy aszinkron írószálat és egy AsyncQueue-t használ.

1.   Kötegeltetés: A rekordok összegyűjtése az AsyncQueue<FileRef file-url=" min=18 file-path="src/wal.zig">Hii</FileRef>.
2.   Háttéríró: Egy dedikált szál figyeli a várólistát. Amikor a rekordok rendelkezésre állnak, egyetlen I/O műveletbe kötegeli őket.
3.   io_uring Integráció: Linuxon a rendszer az io_uringot használja a nem blokkoló lemezes I/O-hoz. Az IORING_OP_WRITEV-t használja a vektorizált írásokhoz (a WALRecord és a hozzá tartozó adatok írása egyetlen syscallban) és az IORING_OP_FSYNC-et a tartósság biztosítására <FileRef file-url=" min=10 max=11 file-path="src/iouring.zig">Hii</FileRef>.
4.   Várakozási mechanizmus: A Transaction.commit() hívás egy befejezési szemaforra vár, amelyet a háttéríró indít el, amint a hardver visszaigazolja az fsync-et.

 <FileRef file-url=" min=645 max=700 file-path="src/wal.zig">Hii</FileRef>, <FileRef file-url=" min=43 max=63 file-path="src/iouring.zig">Hii</FileRef>

### Helyreállítás és javítás

Ha a rendszer összeomlik, a RecoveryEngine a következő indításkor feldolgozza a WAL-t.

### Helyreállítási fázisok (RecoveryPhase)

1.   Elemzés: <FileRef file-url=" min=163 max=165 file-path="src/recovery.zig">Hii</FileRef>.
2.   Újra: <FileRef file-url=" min=170 max=171 file-path="src/recovery.zig">Hii</FileRef>.
3.   Visszavonás: A WAL-ban lévő visszavonási adatokat használja az "aktív" vagy "előkészített" tranzakciók módosításainak visszaállítására, amelyek soha nem érték el a commit állapotot <FileRef file-url=" min=173 max=174 file-path="src/recovery.zig">Hii</FileRef>.

### Helyreállítási adatáramlás

 <FileRef file-url=" min=7 max=14 file-path="src/recovery.zig">Hii</FileRef>, <FileRef file-url=" min=143 max=181 file-path="src/recovery.zig">Hii</FileRef>

### Ellenőrzés

az agdb a "Fuzzy Checkpointing"-et használja a WAL lefaragására és a végtelen növekedés megakadályozására.

- Az ellenőrzőpont művelet az összes szennyezett oldalt a PersistentHeap-ről a fő adatfájlba üríti.
- A RecordType.checkpoint a WAL-ba íródik.
- A WALHeader.last_checkpoint az aktuális tail_offset<FileRef file-url=" min=42 file-path="src/wal.zig">Hii</FileRef> értékre frissül.
- A head_offset ezután előrébb léphet, és így ténylegesen helyet nyerhetünk a körkörös naplóban.

 <FileRef file-url=" min=35 file-path="src/wal.zig">Hii</FileRef>, <FileRef file-url=" min=54 max=57 file-path="src/wal.zig">Hii</FileRef>

## Tranzakciókezelő és párhuzamosság

Az agdb tranzakciós és párhuzamossági alrendszere biztosítja a sorozatképes pillanatfelvétel-izolációt (SSI), amely a hardveres tranzakciós memória (HTM), a szoftveres konfliktusfelismerés és a topológiatudatos végrehajtás hibrid megközelítését használja a modern többmagos és NUMA rendszereken az átviteli teljesítmény maximalizálása érdekében.

### Tranzakciós állapotgép

Az agdb-ben a tranzakciók szigorú életciklust követnek, amelyet a TransactionManager irányít. Minden tranzakciót egy Transaction struct képvisel, amely nyomon követi az életciklus állapotát, az írási/olvasási készleteket és a kapcsolódó WAL (Write-Ahead Log) kezelőt.

### Életciklus állapotok

Az állapotot a TransactionState enum határozza meg

| Állapot | Leírás |
| --- | --- |
| inaktív | Kezdeti állapot a kezdés előtt. |
| aktív | A tranzakció fut; a műveletek pufferelve vannak. |
| előkészítve | Az átadás 1. fázisa; a konfliktusfelismerés sikeresen lezajlott. |
| commit | A commit 2. fázisa; a módosítások a WAL és a Heap rendszerbe kerültek. |
| rolled_back | Felhasználó által kezdeményezett vagy konfliktus okozta megszakítás. |
| failed | Rendszerhiba a tranzakció végrehajtása során. |

### Regisztráció-lakó állam

A konfliktusfelismerés során a cache kihagyások minimalizálása érdekében az agdb egy RegisterResidentTxState struktúrát használ Ez a struktúra pontosan 64 bájtos (egy cache sor), és a tranzakció olvasási és írási készleteinek kompakt hash-jét tárolja

### Egyidejűség-ellenőrzési mechanizmusok

### Hardveres tranzakciós memória (HTM)

az agdb az xbegin, xend és xabort utasításokon keresztül használja az x86_64 Restricted Transactional Memory (RTM) funkciót

- Spekulatív végrehajtás: A motor először egy HTM-blokkon belüli tranzakciókat próbál lefuttatni. Ha konfliktus lép fel, a hardver automatikusan visszaállítja az architektúra állapotát.
- Visszalépési útvonal: Ha a HTM ismételten meghibásodik (kapacitás vagy tartós konfliktusok miatt), a rendszer visszalép egy szabványos, mutex-védett útvonalra
- Konfliktusfelismerés: A HTMTransaction wrapper biztosítja, hogy ha egy másik szál globális zárat szerez, a spekulatív tranzakció megszakad

### SeqLock (szekvenciazárak)

A versengésmentes olvasáshoz az agdb megvalósítja a SeqLock-ot Ez lehetővé teszi az olvasók számára az adatokhoz való hozzáférést mutex megszerzése nélkül, egy verziószámlálót használva annak észlelésére, hogy történt-e egyidejű írás az olvasás során

- Írók: A szekvenciaszámlálót páratlan számra kell növelni az írás előtt, majd a befejezés után ismét növelni (párosra)
- Olvasók: Olvassa le a számlálót, másolja le az adatokat, és ellenőrizze újra a számlálót

### SSI és konfliktusfelismerés

A sorozatosítható pillanatfelvételek elkülönítése az egyes tranzakciók read_set és write_set követésével valósul meg

- Hashes olvasása/írása: Minden egyes memória-eltolást a RegisterResidentTxState-ba hash-olva kell beírni
- Érvényesítés: A TransactionManager az előkészített fázisban összehasonlítja a tranzakciót végrehajtó tranzakció olvasási készletét az összes olyan párhuzamos tranzakció írási készletével, amely az adott tranzakció elindulása után került végrehajtásra.

### Topológia és NUMA-tudatosság

A nagy teljesítmény elérése érdekében a többszoknyás rendszereken az agdb NUMA-tudatos szálrögzítést és memóriaelosztást valósít meg.

### NUMA topológia észlelése

A NumaTopology struktúra Linuxon a /sys/devices/system/node/ állományt elemzi a felfedezéshez:

1.   CPU-affinitás: Mely magok melyik NUMA csomóponthoz tartoznak
2.   Memória távolság: A távoli csomópontokon lévő memória elérésének késleltetési költsége
3.   HBM észlelés: Nagy sávszélességű memória (HBM) csomópontok azonosítása, amelyeknek nincs helyi CPU-juk

### Szál rögzítése

A szálak a setAffinity használatával meghatározott magokhoz vannak rögzítve, hogy megakadályozzák az operációs rendszer migrációit, amelyek érvénytelenítenék a helyi L1/L2 gyorsítótárakat

### Cache-sor kitöltés

A kritikus párhuzamossági struktúrák ki vannak töltve a False Sharing elkerülése érdekében. A CacheLinePadded segédprogram biztosítja, hogy az olyan változók, mint az atomikus számlálók, a saját 64 bájtos gyorsítótár soraikban legyenek

### Nagy felbontású időzítés

az agdb az időbélyegszámlálót (Time Stamp Counter, TSC) használja a nagy pontosságú méréshez és a tranzakciók rendezéséhez.

- rdtsc / rdtscp: A CPU ciklusszámláló olvasására szolgáló közvetlen assembly wrapperek
- TscSequencer: A nyers TSC és egy szoftveres számláló kombinálásával monoton növekvő 64 bites időbélyegzőket biztosít, hogy ugyanazon cikluson belül gyors ütemű kéréseket tudjon kezelni
- Frekvenciabecslés: A rendszer kalibrálja a TSC frekvenciát a rendszeróra ellenében, hogy megközelítő nanoszekundumos konverziót biztosítson

## Szemétgyűjtés, pillanatfelvételek és biztonság

Ez a szakasz dokumentálja az agdb által az adatok integritásának fenntartására, az időbeli helyreállítás biztosítására és a tárolt adatok titkosságának biztosítására használt mechanizmusokat. Ezek a rendszerek a futásidő-rétegen működnek, közvetlenül a PersistentHeap és a WAL rendszerrel együttműködve kezelik az objektumok életciklusát és a titkosítást.

### Szemétgyűjtés (RefCountGC)

az agdb egy referenciaszámláló szemétgyűjtőt, a RefCountGC-t használja a PersistentHeap-en belüli objektumok életciklusának kezelésére. A szabványos memória GC-kkel ellentétben ez az implementáció a perzisztenciára van tervezve, biztosítva, hogy a referenciaszámlálás az újraindítások során is tartós legyen, a frissítések naplózásával a Write-Ahead Logba.

### A végrehajtás részletei

A GC az objektumokat egy ObjectHeader segítségével követi nyomon, amely egy ref_count-ot tartalmaz Amikor egy objektum referenciaszámának száma eléri a nullát, az objektum egy deferred_frees veremre kerül, hogy aszinkron módon feldolgozzák, minimalizálva a fő végrehajtási útvonal késleltetését.

### Főbb összetevők

- RC Batching: A WAL versengés csökkentése érdekében a referenciaszám frissítései egy MPSC (Multi-Producer Single-Consumer) várólista segítségével kötegelhetők
- Ciklusérzékelés: Bár a rendszer elsősorban a referenciaszámlálást végzi, tartalmaz egy GCContextet, amely képes objektumokat jelölni és letapogatni a referenciaciklusok azonosítása és megszakítása érdekében
- Műveletleírók: Minden GC műveletet (Free, DecRef, Mark) egy GCOperationDescriptor ír le, amely tartalmaz egy CRC32 ellenőrző összeget az integritás érdekében

### GC adatáramlás és kódegységek

A következő ábra azt szemlélteti, hogy a referenciaszám csökkenése hogyan indítja el a tisztítási folyamatot.

GC objektum reklamációs áramlás

### Pillanatkép-kezelés

A SnapshotManager az adatbázis állapotának pont-időpontos biztonsági mentését biztosítja. A DirtyPageTracker segítségével inkrementális pillanatfelvételeket készít, és csak azokat az oldalakat rögzíti, amelyek az utolsó mentés óta megváltoztak.

### Pillanatkép architektúra

- Piszkos oldalkövetés: A DirtyPageTracker egy bitsetet használ a módosított oldalak megfigyelésére Az mprotect segítségével az oldalakat PROT.READ-re állíthatja, az írásokat pedig egy jelkezelőn keresztül elkapja, hogy piszkosnak jelölje őket
- Merkle-fák: Az integritás ellenőrzéséhez a pillanatfelvételek létrehozhatnak egy Merkle-fát a halomoldalakból, a gyökér hash-t a SnapshotHeaderben tárolva
- Pillanatkép fejléc: Tartalmazza a metaadatokat, beleértve a snapshot_id-t, a root_offset-et és a parent_snapshot-ot az inkrementális láncok esetében

### Pillanatfelvétel-generálási folyamat

1.   Nyugalom: A menedzser biztosítja, hogy az összes függőben lévő tranzakciót kiürítse.
2.   Azonosítás: getDirtyPages() a módosított oldalindexek listájának lekérdezése
3.   Kitartás: A SnapshotHeader és a piszkos oldal adatai a pillanatfelvétel-fájlba íródnak.
4.   Újraindítás: A DirtyPageTracker törlődik a következő ciklusra

### Biztonság és titkosítás

A SecurityManager kezeli a nyugalmi adatok titkosítását. Több hitelesített titkosítási algoritmust támogat, és integrálható a hardveres biztonsági modulokkal.

### Titkosítási csomag

- Algoritmusok: AES-256-GCM (AES-NI hardveres gyorsítással, ahol elérhető) és ChaCha20-Poly1305
- A kulcs levezetése: A HKDF (HMAC-alapú kivonatolási és bővítési kulcsderiválási funkció) használata a régió-specifikus kulcsok generálására a főkulcsból
- Hardveres gyorsítás: Automatikusan felismeri a CPU jellemzőit az optimalizált AES-GCM útvonalak engedélyezése érdekében

### TPM2 integráció

A magas biztonságú környezetekben az agdb a tpm2_context_t

- Tömítés: A tpm2_seal függvény titkosítja a mesterkulcsot, így az csak akkor dekódolható, ha a rendszer PCR (Platform Configuration Registers - Platform konfigurációs regiszterek) megfelel egy ismert jó állapotnak
- Pecsételés feloldása: a tpm2_unseal visszaszerzi a kulcsot az adatbázis inicializálása során, feltéve, hogy a hardverkörnyezet sértetlen

### Biztonsági adatáramlás

Ez az ábra a SecurityManager és az alapul szolgáló kriptográfiai implementációk közötti kapcsolatot mutatja.

Biztonsági menedzser és TPM2 integráció

### Cache-kezelés és perzisztencia

A cache_flush.h alacsony szintű gyorsítótárvezérlést biztosít annak biztosítására, hogy a PersistentHeap-re írt adatok valóban a fizikai adathordozóra kerüljenek, ami kritikus mind a GC metaadatok, mind a pillanatfelvételek integritása szempontjából.

| Funkció | Hardveres utasítás | Cél |
| --- | --- | --- |
| _clwb | clwb | Cache Line Write Back (tartós memóriára optimalizált) |
| _clflushopt | clflushopt | Optimalizált gyorsítótár sorok ürítése |
| _sfence | sfence | Kerítés tárolása a rendelés biztosítására |
| persistent_msync | msync(MS_SYNC) | OS-szintű memóriatérkép szinkronizáció |

A flush_and_fence függvény az elsődleges belépési pont, amely biztosítja, hogy egy memóriatartomány tartós legyen a tranzakció lekötése előtt

## Felhő és többszemélyes használat

A felhő alcsomag biztosítja az agdb biztonságos, többszemélyes, felügyelt szolgáltatásként történő futtatásához szükséges infrastruktúrát. Az architektúrát az egyfolyamatos adatbázisról egy olyan elosztott modellre helyezi át, ahol a nem megbízható bérlői munkaterhelések Linux sandboxokon belül vannak elszigetelve, és egy központi nyilvántartó szervezi őket.

A rendszert az "Alapértelmezett erős elszigetelés" elve alapján tervezték, amely kernel-szintű primitíveket (cgroups v2, névterek) használ annak biztosítására, hogy az egyik bérlő erőforrás-fogyasztása vagy a biztonság megsértése ne legyen hatással a többire.

### Magas szintű architektúra

Az alábbi ábra egy kérelem életciklusát mutatja be, ahogyan az a felhőalapú agdb-rendszerbe kerül, a nyilvános útválasztótól egy elszigetelt bérlői folyamatig.

Több bérlőre vonatkozó kérelem áramlása

### Bérlői nyilvántartás és életciklus

A nyilvántartás az összes bérlői metaadat igazságforrása. A KvStore egy speciális példányát használja a három elsődleges kulcstér - email:, tenant:, és apikey: - közötti perzisztencia kezelésére.

A TenantLifecycle orchestrator kezeli a bérlő állapotátmeneteit a kezdeti regisztrációtól és az API-kulcs generálásától a felfüggesztésig vagy visszavonásig. Biztosítja, hogy a bérlő törlésekor a hozzá tartozó PHeap-fájlok és homokdoboz-erőforrások biztonságosan törlődjenek az állomásról.

A részletekért lásd

  58

### API kulcs kezelése

A felhőréteg biztonsága az ApiKey modullal kezdődik. A nyers kulcsok tárolása helyett az agdb a Blake3 kriptográfiai hash-függvényt használó biztonságos hash-csatornát valósít meg.

Minden kérésnek meg kell adnia egy agdb_-prefixed tokent. A rendszer állandó idejű ellenőrzést végez az időzítési támadások megelőzése érdekében, és támogatja a kulcsok rotációját a nyilvántartáson keresztül. Ez a komponens szigorúan el van választva az adatbázis-motortól annak biztosítása érdekében, hogy még egy kompromittált adatbázis-példány sem szivárogtathatja ki a globális hitelesítési hitelesítő adatokat.

A részletekért lásd

### Homokozó elszigetelése és folyamatmenedzsment

A sandbox modul felelős a bérlő adatainak és számítási adatainak fizikai elkülönítéséért. Amikor egy bérlői kérés érkezik, a rendszer vagy egy meglévő homokozóhoz csatlakozik, vagy meghívja a spawnTenantSandbox parancsot.

Az elszigetelés a következőkön keresztül valósul meg:

- Névterek: A PID, Network, IPC, UTS, Mount és User névterek elszigetelik a rendszer folyamatnézetét.
- Cgroups v2: RAM, 50% CPU) a "zajos szomszéd" hatások elkerülése érdekében.
- Klón3: CLONE_INTO_CGROUP-ot használ az atomikus folyamatok korlátozott környezetbe történő elhelyezéséhez.

A részletekért lásd

### Kérés router, IPC és folyamat tábla

Az útválasztó a belépési pont a több bérlőre kiterjedő forgalom számára. A ProcessTable-lel együttműködve követi az aktív SandboxHandle példányokat, és kezeli a futó bérlői folyamatok állományát.

Az állomás és a homokdobozolt adatbázis-példányok közötti kommunikáció egy egyedi bináris IPC protokollon keresztül történik. Ez a protokoll a nagy teljesítményű, alacsony késleltetésű parancsküldés biztosítása érdekében egy IpcHeader-t használ, magic byte érvényesítéssel és little-endian szerializációval. A ProcessTable kezeli az üresjárati kilakoltatást is, amely a konfigurált időkorláton belül forgalmat nem fogadó sandboxokat leállítja, hogy visszaszerezze a hoszt erőforrásait.

Entitás leképezés: Kérelem útválasztás kódhoz

A részletekért lásd

## Bérlői nyilvántartás és életciklus

A bérlői nyilvántartás az agdb központi kezelőrendszere a többszemélyes bérleti jogviszonyok számára. Ez kezeli a bérlői metaadatok, az API-kulcsok hozzárendelésének és a bérlői erőforrások (könyvtárak és homokozók) életciklusát. Egy dedikált agdb motor példányt használ (a KvStore-on keresztül) a nyilvántartási rekordok tárolására.

### Nyilvántartási architektúra és perzisztencia

A Registry struktúra a bérlő adatait három elsődleges kulcstér segítségével kezeli egy KvStore-on belül:

| Kulcstér | Formátum | Érték | Cél |
| --- | --- | --- | --- |
| email: | email:<blake3_hex> | u64 (bérlő azonosítója) | Megakadályozza a kettős regisztrációkat, és az e-maileket azonosítókhoz rendeli. |
| bérlő: | Tenant:<id> | TenantRecord | A bérlő metaadatainak és állapotának elsődleges tárolója. |
| apikey: | apikey:<blake3_hex> | u64 (bérlő azonosítója) | Elősegíti a gyors hitelesítési keresést. |

A regisztrációs adatbázis helyét az AGDB_REGISTRY_PATH környezeti változó határozza meg, amely az építéskori alapértelmezettre esik vissza

### TenantRecord struktúra

A TenantRecord egy extern struktúra, amely biztosítja a bináris kompatibilitást a KvStore-ba történő szerializáláskor:

- tenant_id: Egyedi 64 bites azonosító.
- email_hash: Blake3 hash a normalizált (kisbetűs) e-mail.
- api_key_hash: Blake3 hash az aktív API-kulcsról.
- data_path: A bérlő elszigetelt adatkönyvtárát jelző nullával végződő karakterlánc.
- aktív: Boolean flag (u8) a számla státuszára.

### Bérlő regisztrációs csővezeték

A RegistrationHandler az új bérlők létrehozását a handleRegister függvényen keresztül irányítja.

### Adatáramlás: Bérlő létrehozása

1.   Érvényesítés: Az e-mail hossza (max. 254) és alapformátuma (egyetlen '@', vezérlő karakterek nélkül)
2.   ID kiosztás: Egy véletlenszerű u64 generálódik. A rendszer legfeljebb 64 ütközést kísérel meg, mielőtt kudarcot vallana
3.   Fájlrendszer beállítása: Az AGDB_DATA_ROOT alatt egy külön könyvtár jön létre a tenant_id használatával
4.   Kitartás: Kulcstérbe íródik a TenantRecord, az e-mail hozzárendelés pedig az email címre:
5.   Kulcsgeneráció: Egy 58 karakteres API-kulcs generálása és annak hash-jának tárolása a storeApiKeyHash segítségével történik

### Regisztrációs sorrendi diagram

A következő ábra a HTTP-kérést a belső nyilvántartási logikához kapcsolja.

### API kulcskezelés és rotáció

A storeApiKeyHash függvény a kulcsok rotációját az előző kulcs automatikus visszavonásával valósítja meg.

1.   Keresés: A meglévő bérlőrekord lekérdezése
2.   Visszavonás: Ha létezik egy régi api_key_hash (nem nulla), a megfelelő apikey:<old_hash> bejegyzés törlésre kerül a KvStore-ból
3.   Frissítés: Az új hash elmentésre kerül a TenantRecordban, és létrejön egy új apikey:<new_hash> -> tenant_id hozzárendelés

### Hitelesítési keresés

A hitelesítés a lookupByApiKey segítségével történik A megadott kulcsot hash-olja, az apikey: kulcstérben egyetlen KV keresést végez a tenant_id megtalálásához, majd lekérdezi a teljes TenantRecordot

### Bérlő életciklusa és visszavonása

A bérlő visszavonása egy destruktív művelet, amely magában foglalja a rendszerleíró adatbázis metaadatainak és az aktív futásidejű erőforrásoknak a törlését.

### A visszavonási folyamat

Amikor a handleDeleteAccount meghívása megtörténik

1.   Nyilvántartás visszavonása: a revokeTenant meghívása az aktív jelző 0-ra állítására és az apikey: leképezés eltávolítására szolgál
2.   Sandbox megszüntetése: A ProcessTable zárolt, hogy aktív SandboxHandle-t találjon. Ha talál, a sandbox a sandbox.destroySandbox segítségével megsemmisül
3.   Adattörlés: A bérlő adatkönyvtárát rekurzív módon törlik a fájlrendszerből

### Erőforrás-tisztítási logika

A nyilvántartó alacsony szintű rekurzívDelete implementációt használ, amely elkerüli a magas szintű könyvtári terheket:

- deleteDirContents: Getdents64 syscall-t használ a könyvtárbejegyzések végigjárásához
- recursiveDeleteAt: Openat és unlinkat az AT_REMOVEDIR segítségével fájlok és könyvtárak biztonságos eltávolítására

### Kódex entitás leképezés: Életciklus-orchestrálás

## API kulcs kezelése

Az agdb felhőinfrastruktúra egy speciális API-kulcsrendszert használ a bérlői kérelmek hitelesítésére. Ez a rendszer nagy biztonságot nyújt, és az időzítési támadások megelőzése érdekében állandó idejű ellenőrzést, a Blake3 algoritmust használó kriptográfiai hashinget, valamint a könnyű azonosíthatóság érdekében szabványosított előtagformátumot tartalmaz.

### Az ApiKey struktúra

Az ApiKey struct egy külső struktúra, amely a rendszeren belül a bérlő hitelesítő adatainak metaadatait és biztonsági állapotát reprezentálja. A struktúra fix szélességű mezőkkel és kitöltéssel van kialakítva, hogy stabil memóriaelrendezést biztosítson, amely alkalmas a bináris perzisztenciára vagy a hálózati átvitelre.

| Mező | Típus | Leírás |
| --- | --- | --- |
| tenant_id | u64 | A kulcshoz tartozó bérlő egyedi azonosítója. |
| hash | [32]u8 | A nyers API-kulcs Blake3 kriptográfiai hash-ja. |
| created_at_unix | i64 | Unix időbélyegző, amely jelzi a kulcs létrehozásának időpontját. |
| revoked | u8 | Egy bóluszi jelző (0 vagy 1), amely jelzi, hogy a kulcs már nem érvényes. |
| _pad | [7]u8 | Igazítási kitöltés annak biztosítására, hogy a struktúra mérete 8 bájt többszöröse legyen. |

### Kulcsgenerálás életciklusa

Az új API-kulcsok generálása szigorú formátumot követ: egy 5 karakteres előtag (agdb_), amelyet 58 karakteres hex-kódolt entrópia és egy null terminátor követ.

### generateApiKey Logika

1.   Előtagozás: Agdb_ karakterlánccal kezdődik, hogy a naplókban vagy a kódban könnyen azonosítható legyen
2.   Entropia gyűjtemény: A rendszer 29 bájt kiváló minőségű véletlenszerűséget vesz az std.crypto.random fájlból
3.   Hex kódolás: Ez a 29 bájt 58 hexadecimális karakterre (0-9, a-f) van kiterjesztve
4.   Nulla megszüntetés: A 64. bájt 0-ra van állítva, így biztosítva, hogy a kulcsot szükség esetén C-stringként lehessen kezelni

### Adatáramlás: Kulcs létrehozása

A következő ábra a véletlenszerű bájtoktól a végső [64]u8 pufferig történő átalakulást szemlélteti.

### Zavarás és ellenőrzés

A biztonság érdekében a nyers API-kulcsokat soha nem tároljuk az adatbázisban. Ehelyett csak a kriptográfiai hash-ok maradnak meg.

### hashApiKey Megvalósítás

A hashApiKey funkció a Blake3 hashing algoritmust használja, amelyet nagy teljesítménye és biztonsági tulajdonságai miatt választottunk.

- Nulla végződés kezelése: A függvény ellenőrzi, hogy a bemeneti szelet null terminátorral (0) végződik-e. Ha igen, akkor kizárja ezt a bájtot a hash-számításból, hogy biztosítsa a konzisztenciát a C-stringként és a szabványos Zig szeletekként megadott kulcsok között
- Zavarás: A kapott szeletet átadjuk az std.crypto.hash.Blake3.hash-nak, hogy egy 32 bájtos kivonatot állítson elő

### verifyApiKey (Állandó-idő)

Az ellenőrzés a bejövő kulcs hashelésével és a tárolt_hash-sel való összehasonlításával történik. Az időzítési támadások megelőzése érdekében az összehasonlítás nem a szabványos memória-összehasonlítást használja (amely az első eltérésnél korán visszatér). Ehelyett bitenkénti VAGY halmozót használ.

Azáltal, hogy minden bájton végigmegyünk és a diff |= computed[i] ^ stored_hash[i] segítségével felhalmozzuk a különbségeket, a végrehajtási idő azonos marad, függetlenül attól, hogy hol fordul elő eltérés

### Biztonsági indoklás

Az API-kulcskezelő rendszer kialakítása több gyakori sebezhetőséget is kiküszöböl:

| Design választás | Biztonsági előny |
| --- | --- |
| Prefixing (agdb_) | Lehetővé teszi a titkos szkennelési eszközök használatát a kulcsok verziókezelőbe történő véletlen commitolásának megakadályozására. |
| Blake3 Hashing | Modern, ütközésbiztos hashingelést biztosít, amely jelentősen gyorsabb, mint az SHA-2 vagy az Argon2 rövid idejű hitelesítési ellenőrzésekhez. |
| Állandó idejű összehasonlítás | Kiküszöböli az oldalcsatornás időzítési támadásokat, amelyek során a támadó a válasz késleltetése alapján bájtról-bájtra kitalálhatná a kulcsot. |
| Visszavonási jel | Lehetővé teszi a kompromittált kulcsok azonnali érvénytelenítését a korábbi ApiKey rekord törlése nélkül |
| Fix méretű puffer | A kulcsok kezeléséhez stack-allokált [64]u8 tömböket használva megakadályozza a heap töredezettségét és a lehetséges puffer túlcsordulási problémákat. |

## Homokozó elszigetelése és folyamatmenedzsment

Az agdb felhő alrendszer Linux-natív izolációs primitíveket használ a bérlői kérések szigorúan korlátozott környezetben történő végrehajtásához. Ezt a cgroup v2 erőforrás-korlátozással, a Linux Namespaces láthatósági elszigeteléssel és a Seccomp syscall-szűréssel valósítja meg.

### Homokozó életciklusának áttekintése

A bérlői homokozó életciklusát a spawnTenantSandbox függvény és a sandbox_runner segédprogram kezeli. A rendszer biztosítja, hogy az egyes bérlők adatbázis-műveletei egy dedikált folyamatfára korlátozódjanak, korlátozott hozzáféréssel a CPU-hoz, a memóriához és a fájlrendszerhez.

### Sandbox életciklus adatáramlás

A következő ábra a gazdafolyamatból az izolált homokozó környezetbe való átmenetet szemlélteti.

A homokozó inicializálási sorozata

### Erőforrás-korlátozások (cgroup v2)

az agdb a cgroup v2-t használja a bérlői erőforrás-fogyasztás kemény korlátozásának kikényszerítésére. Ezek a korlátok a sandbox folyamat végrehajtásának megkezdése előtt kerülnek alkalmazásra a /sys/fs/cgroup hierarchiába való írással.

| Erőforrás | Limit | Cgroup File |
| --- | --- | --- |
| Memória | 512 MB | memory.max (beállítva 536870912) |
| Swap | 0 MB | memory.swap.max |
| Folyamatok | 64 PID | pids.max |
| CPU | 50% | cpu.max (500000 1000000-re van beállítva) |

A gazdafolyamat az O_PATH flag segítségével megnyit egy fájlleírót a bérlő cgroup könyvtárához, és a CLONE_INTO_CGROUP flag segítségével átadja a clone3 syscallnak, így biztosítva, hogy a gyermek közvetlenül a korlátozott csoportba szülessen.

### Folyamatszigetelés és névterek

A spawnTenantSandbox függvény a clone3 rendszerhívást használja egy meghatározott zászlós készlet segítségével egy teljesen elszigetelt végrehajtási környezet létrehozásához.

### Névtér konfiguráció

- CLONE_NEWPID: A homokozónak saját PID-tartománya van; a konténerén kívüli folyamatokat nem láthatja és nem jelezheti.
- CLONE_NEWNS: Egy privát mount névtér lehetővé teszi az egyéni fájlrendszer gyökerét a pivot_root segítségével.
- CLONE_NEWNET: Megakadályozza a hálózati alapú kiszivárgást.
- CLONE_NEWIPC: A System V IPC-objektumok és a POSIX üzenetsorok elkülönítése.
- CLONE_NEWUTS: Privát hostnév és domainnév.
- CLONE_NEWUSER: A belső root felhasználót az uid_map és a gid_map segítségével egy nem privilegizált felhasználóhoz képezi le az állomáson.

### Sandbox Runner & Filesystem Jail

A sandbox_runner egy speciális bináris program, amely az adatbázis-motor inicializálása előtt elvégzi az utolsó "lezárási" lépéseket az új névtereken belül.

### A fájlrendszer keményítése

1.   Tmpfs szerelése: Egy 128 MB-os tmpfs fel van szerelve egy ideiglenes útvonalra, amely az új gyökérként szolgál.
2.   Kötés rögzítések: Az alapvető rendszerkönyvtárak (/usr, /lib, /bin) és eszközcsomópontok (/dev/null, /dev/urandom) csak olvashatóan vannak kötve.
3.   Adatok rögzítése: A bérlő specifikus adatkönyvtárát a homokdobozon belül a /data könyvtárba kötik.
4.   Pivot Root: A pivot_root syscallt a gyökér fájlrendszer cseréjére használjuk, majd a régi gyökér umount2-je következik, hogy a homokozó ne tudjon a host fájlrendszerbe menekülni.

### Syscall-szűrés (Seccomp)

A futó a prctl(PR_SET_SECCOMP) paranccsal szigorú Seccomp BPF szűrőt alkalmaz. Ez a szűrő csak az alapvető fájl I/O-hoz, memória leképezéshez és IPC-hez szükséges ~80 syscall fehér listáját engedi meg. Bármely nem engedélyezett syscall hívására tett kísérlet a folyamat azonnali leállítását eredményezi (SECCOMP_RET_KILL_PROCESS).

### Folyamatirányítási entitások

A rendszer a SandboxHandle segítségével követi az aktív homokozókat, és a destroySandbox segítségével kezeli azok eltávolítását.

### Kód Entitás leképezés

A következő ábra a logikai homokozó komponenseket a megvalósítási struktúrákhoz és funkciókhoz rendeli.

Sandbox Management Entitások

### Tisztítás és megsemmisítés

Amikor egy homokozót kilakoltatnak (tétlenség vagy a bérlő törlése miatt), a destroySandbox a következőket hajtja végre:

1.   SIGKILL: Megsemmisítő jelet küld a homokozó PID-jének.
2.   Várj: A zombifolyamat kaszálása.
3.   FD lezárás: Bezárja az IPC és a cgroup fájlleírókat.
4.   Cgroup eltávolítása: Törli a bérlő cgroup könyvtárát a /sys/fs/cgroup/agdb/ könyvtárban.

## Kérés router, IPC és folyamat tábla

Ez a szakasz az agdb többmandátumú kérés-összehangoló rétegét dokumentálja. Ez azt tárgyalja, hogy a Router hogyan érvényesíti a kéréseket, hogyan kezeli a ProcessTable az elszigetelt bérlői homokozókat az epoll-on keresztül, és a bináris IPC protokollt, amelyet a host és a homokozós futók közötti kommunikációhoz használnak.

### Router kérése

Az útválasztó az elsődleges belépési pont a többszemélyes HTTP-kérelmek számára. Hídként működik a külső kiszolgáló és a belső bérlői elszigetelési infrastruktúra között.

### handleHttpRequest Flow

Amikor egy kérés érkezik, az útválasztó a következő lépéseket hajtja végre:

1.   Hitelesítés: Kivonja a Bearer tokent az Authorization fejlécből, és lookupByApiKey segítségével keresést végez a nyilvántartásban
2.   Homokozós felvásárlás: Ellenőrzi a ProcessTable-t a tenant_id-hez tartozó meglévő SandboxHandle után
3.   Lusta szaporodás: Ha nem létezik homokozó, akkor szerez egy spawn_mutexet és meghívja a spawnTenantSandboxot egy új, elszigetelt környezet létrehozásához
4.   IPC Dispatch: Egyedi request_id-t generál, és a kérés testét a bérlő ipc_fd-jén keresztül küldött IPC-üzenetbe szerializálja
5.   Szinkronizálás: Regisztrál egy WaitingRequest-et a ProcessTable-ben, és 30 másodperces időkorlátozással blokkol egy szemaforon
6.   Takarítás: Ha időkorlát következik be, az útválasztó eltávolítja a homokozót a ProcessTable-ből és megsemmisíti azt, hogy megakadályozza az erőforrás-szivárgást

### Kérés szervezési logika

| Komponens | Felelősség |
| --- | --- |
| Router.handleHttpRequest | Magas szintű áramlás: Várakozás |
| spawn_mutex | Megakadályozza, hogy több kérés ugyanazon bérlő homokozóját hozza létre |
| next_request_id | Atomikus számláló az aszinkron IPC-válaszok követéséhez |

### IPC bináris protokoll

Az IPC (Inter-Process Communication) rendszer egy egyedi bináris protokollt használ Unix tartományi aljzatokon vagy csöveken keresztül a homokdobozos folyamatokkal való kommunikációhoz.

### Protokoll specifikáció

A protokoll egy fix méretű fejlécből áll, amelyet egy opcionális, változó hosszúságú hasznos teher követ. Minden több bájtos egész számot little-endian kódolásban kódolnak

| Mező | Típus | Leírás |
| --- | --- | --- |
| magic | u32 | Konstans 0x47444241 (IPC_MAGIC) |
| request_id | u64 | A kérésekhez tartozó válaszok megfeleltetésének korrelációs azonosítója |
| msg_type | u8 | Az üzenet típusa (pl. 0x01 kérés esetén) |
| status | u8 | Állapotkód (0 a siker esetén) |
| payload_len | u32 | A következő adatok hossza |

### Adatáramlás: A fogadó és a homokozó között

A sendMessage függvény kezeli az üzenetek szerializálását és továbbítását Biztosítja a teljes hasznos teher kiírását egy writeAll ciklus segítségével, amely kezeli az EINTR és EAGAIN jeleket

### IPC kommunikációs diagram

Az alábbi ábra az IPC protokoll entitásokat a megvalósítási funkcióikhoz rendeli.

### Process Table & Dispatch Loop

A ProcessTable karbantartja az összes aktív homokozó állapotát, és a Linux epoll segítségével kezeli az aszinkron válaszok életciklusát.

### A diszpécserkör

A runDispatchLoop függvény az IPC-kezelés központi motorja Egy külön szálon fut, és három fő feladatot lát el:

1.   Eseményszavazás: Az epoll_wait használatával figyeli az összes bérlő ipc_fd leíróját a bejövő adatokra vagy a leállásokra
2.   Üzenetfeldolgozás: RecvMessage. A fejlécből származó request_id segítségével megkeresi a megfelelő WaitingRequest-et, lemásolja a hasznos terhet, és a sem.post() segítségével jelzi a Routernek
3.   Karbantartás:
- Zombi aratás: A wait4 hívása WNOHANGgal a befejezett homokozó folyamatok megtisztítására és a függőben lévő kérések elutasítására
- Tétlen kilakoltatás: Minden söprési ciklusban azonosítja azokat a homokozókat, amelyekben 10 percig nem volt aktivitás, és az erőforrások felszabadítása érdekében kilakoltatja őket

### Folyamat tábla architektúra

### Kulcsszerkezetek

- SandboxHandle: Egy aktív izolációs egység pid, ipc_fd és tenant_id adatait tárolja
- VárakozásKérelem: Semaphore-t és egy válaszpuffert tartalmazó szinkronizációs primitív. A Router erre vár, és a ProcessTable teljesíti azt

## Tesztelés és teljesítményértékelés

Az agdb kódbázis egy átfogó, kétrétegű tesztelési stratégiát alkalmaz, amely egy dedikált benchmarking csomaggal kombinálva biztosítja mind a funkcionális helyességet, mind a nagy teljesítményű perzisztenciát. A tesztelés a forrásfájlokba beágyazott granuláris egységtesztektől a végponttól végpontig tartó integrációs tesztekig terjed, amelyek a tartósságot és a keresési pontosságot ellenőrzik.

### Tesztelési stratégia áttekintése

A tesztelési infrastruktúra két fő kategóriára oszlik:

1.   Egységtesztek: Minden modulban a forráskóddal együtt. Ezek felfedezése és végrehajtása a refAllDecls segítségével történik a fő teszt belépési pontokban.
2.   Integrációs tesztek: Ezek a tesztek az src/tests.zig állományban találhatók, és a teljes rendszer stacket gyakorolják, beleértve a fájl I/O-t, a perzisztencia tartósságot és a hibrid keresési logikát.

### Kódex entitás leképezés: Tesztelés

| Rendszer neve | Kódegység | Fájl elérési útvonal |
| --- | --- | --- |
| Unit Test Runner | zig build test | | |
| Integrációs futó | zig build test-integration | | |
| E2E tesztek | teszt "végtől végig keresés és keresés" | | |
| Tartóssági tesztek | "kv tartósság az újranyitás során" | | |
| Index integráció | "bm25 + vektor kombinált" | | |

A részletekért lásd

### Benchmarking és diagnosztika

az agdb tartalmaz egy robusztus benchmarking keretrendszert az src/benchmark.zig-ben és egy diagnosztikai segédprogramot az src/inspect.zig-ben. A benchmarking csomag nagy felbontású időzítéssel méri az olyan műveleteket, mint az allokáció, a nyers heap-írás és a tranzakciók átviteli teljesítménye.

### Rendszeráramlás: Teljesítménymérés

A következő ábra azt szemlélteti, hogy a BenchmarkSuite hogyan lép kölcsönhatásba a motor alapkomponenseivel a mérőszámok gyűjtése érdekében.

"Teljesítménymérési architektúra"

### Diagnosztikai segédprogramok

A HeapInspector mélyreható betekintést nyújt az adatbázis bináris állapotába. Érvényesítheti a fejléceket, kiszámíthatja az ellenőrző összegeket, és bejárhatja a PersistentHeap-et a kiszivárgott vagy sérült objektumok azonosítása érdekében.

| Parancs | Cél | Kódalany |
| --- | --- | --- |
| Fejléc | Érvényesíti a varázslatot, a verziót és az ellenőrző összegeket | inspectHeader |
| Stats | Összes allokált és felszabadított bájt közötti jelentés | inspectStats |
| Objektumok | ObjectHeader és FreeListNode | inspectObjects |
| WAL | A WALHeader és a tranzakciós naplók vizsgálata | inspectWAL |

A részletekért lásd

### Kulcsteljesítmény-mérőszámok

A BenchmarkResult struktúra a motor teljesítményének számos kritikus dimenzióját rögzíti:

- Késleltetés: min_time_ns, max_time_ns és avg_time_ns
- Átviteli teljesítmény: ops_per_sec és throughput_mb_sec
- Munkaterhelés: Támogatja a runMixedWorkloadBenchmarkot a valós verseny szimulálása érdekében

## Unit és integrációs tesztek

az agdb egy kétszintű tesztelési stratégiát alkalmaz, amelynek célja, hogy biztosítsa mind az egyes alacsony szintű komponensek helyességét, mind a magas szintű, összehangolt adatbázis-motor stabilitását. Ez a stratégia a forrásfájlokkal együtt elhelyezett egységtesztekből és egy dedikált integrációs tesztcsomagból áll a végponttól végpontig tartó validáláshoz.

### Teszt architektúra áttekintés

A tesztelési infrastruktúra közvetlenül a Zig build rendszerbe van integrálva. A Zig tesztblokkjait kihasználva azonnali visszajelzést ad a fejlesztés során.

### Teszt elrendezése és végrehajtása

A tesztek két fő csoportba sorolhatók:

1.   Egységtesztek: Az egyes modulok forrásfájljaiban találhatók (pl. src/kv.zig, src/pheap.zig). Ezek a belső logikára, az adatszerkezetek integritására és az egyes alrendszerek éles eseteire összpontosítanak.
2.   Integrációs tesztek: Ezek az alrendszerek közötti kölcsönhatásra összpontosítanak, mint például a KvStore, a Bm25Index és a VectorIndex archiválását végző adatbázis.

### Rendszerintegráció építése

A build.zig fájl meghatározza a tesztek futtatásának konkrét lépéseit.

| Építési lépés | Parancs | Leírás |
| --- | --- | --- |
| test | zig build test | Futtatja az egységteszteket és az integrációs teszteket is |
| test-integráció | zig build test-integration | Csak a src/tests.zig állományban lévő végponttól végpontig tartó tesztek futtatása |

Az építési rendszer kezeli a build_options injektálását is, biztosítva, hogy a teszt binárisok ugyanahhoz a konfigurációhoz (mint például az AGDB_DATA_ROOT) férjenek hozzá, mint a produktív binárisok

### Vizsgálati folyamatábra

A következő ábra azt szemlélteti, hogyan állítja össze és hajtja végre az építési rendszer a különböző tesztcsomagokat.

Rendszer tesztelési csővezeték építése

### Egységtesztek

Az egységtesztek a megvalósítással együtt vannak elhelyezve. Ez lehetővé teszi a fejlesztők számára, hogy teszteljék a privát függvényeket és a belső állapotot, amelyek a nyilvános API-n keresztül nem kerülnek nyilvánosságra.

### Helymegosztás Példák

- KV Store: A FileHeader érvényesítés, a RecordHeader CRC32 integritás és a napló-visszajátszási logika tesztelése.
- Tokenizer: N-grammok generálásának és Unicode normalizálásának validálása. Az src/tests.zig fájlban a tokenizer normalize teszt ellenőrzi, hogy az olyan bemeneti karakterláncok, mint a "Hello, AGDB!" helyesen kerülnek-e kisbetűs tokenekké alakításra
- JSON kezelés: A körkörös szerializációs tesztek biztosítják, hogy a Record objektumok adatvesztés nélkül konvertálhatók JSON-ba és vissza

### Integrációs tesztek

Az integrációs tesztek az src/tests.zig állományban találhatók. A könyvtárat úgy kezelik, mint egy fogyasztó, importálják az agdb modult, és nyilvános API-kat hívnak a magas szintű munkafolyamatok ellenőrzésére.

### Végponttól-végpontig történő eladás és keresés

A végponttól végpontig tartó put and search teszt ellenőrzi az elsődleges adatbázis életciklusát

1.   Inicializálás: Megnyit egy adatbázis-példányt egy adott embedding_dim-mérettel
2.   Lenyelés: PutBytes-ot használ a dokumentumok beszúrásához
3.   Kitartás: Meghívja a db.flush() funkciót az adatok lemezre rögzítésének biztosítására
4.   Visszakeresés: SearchText és db.searchHybrid az indexelés ellenőrzésére
5.   Karbantartás: Futtatja a db.compact() parancsot és ellenőrzi, hogy a rekordok száma konzisztens marad-e

### KV Tartósság

A kv durability across reopen teszt biztosítja, hogy a csak függelékkel rendelkező, naplóstruktúrájú tároló helyesen helyreállítsa az állapotát a leállítás után Elvégzi a put és delete műveletek sorozatát, bezárja a tárolót, újra megnyitja, és megállapítja, hogy a törölt kulcsok hiányoznak, míg az aktív kulcsok fennmaradnak

### Hibrid keresési logika

A bm25 + vektor kombinált teszt ellenőrzi a Bm25Index és a VectorIndex belső koordinációját Manuálisan ad hozzá dokumentumokat mindkét indexhez, és biztosítja, hogy a szöveges keresés a BM25 indexből a helyes azonosítót adja vissza, míg a vektoros keresés a Vector indexből a helyes azonosítót

### Integrációs teszt komponensek kölcsönhatása

Ez az ábra az integrációs teszthívásokat az általuk gyakorolt mögöttes kódegységekhez rendeli hozzá.

Integrációs teszt adatáramlás

### Építési lehetőségek befecskendezése

A tesztelési környezet kritikus szempontja a build_options modul. Ez a modul a készítéskor generálódik, és lehetővé teszi, hogy a tesztek tiszteletben tartsák a környezet-specifikus útvonalakat.

### Konfigurációs folyamat

1.   A build.zig szkript összegyűjti az olyan opciókat, mint az AGDB_REGISTRY_PATH és az AGDB_DATA_ROOT
2.   Ezek egy build_options nevű Zig modulba vannak csomagolva
3.   A modul importként kerül hozzáadásra mind a könyvtári modulhoz, mind az integrációs tesztmodulhoz 77

Ez biztosítja, hogy amikor az src/tests.zig fut, elméletileg ugyanarra a fájlrendszer elrendezésre hivatkozhat, mint amit a produktív agdb-runtime számára konfiguráltunk

### Építési lehetőségek összefoglalása

| Opció | Alapértelmezett érték | Használat a tesztekben |
| --- | --- | --- |
| AGDB_REGISTRY_PATH | /var/lib/agdb/registry.agdb | A bérlői nyilvántartás keresése. |
| AGDB_DATA_ROOT | /var/lib/agdb/tenants | A bérlő-specifikus KV és Index fájlok alapkönyvtára. |
| sandbox_runner_path | /usr/lib/agdb/sandbox_runner | A sandbox izoláció tesztelésénél használt elérési út. |

## Benchmarking és diagnosztika

Ez az oldal az agdb teljesítménymérési infrastruktúráját és az adatbázis-ellenőrző segédprogramokat dokumentálja. A motor alacsony szintű CPU utasításokat használ a nagy felbontású időméréshez, egy dedikált benchmarking csomagot az alapvető alrendszerekhez, valamint egy vizsgálati segédprogramot az adatbázis integritásának és belső állapotának ellenőrzéséhez.

### Nagy felbontású időzítés (TSC)

Az agdb motor az időbélyegszámlálóra (Time Stamp Counter, TSC) támaszkodik a nanoszekundumos pontosságú időzítéshez, elsősorban x86_64 architektúrákon. Ez kritikus fontosságú a PersistentHeap és a WAL modulok alacsony késleltetésű műveleteinek méréséhez.

### Alapvető időzítési funkciók

- rdtsc(): Az rdtsc utasítással olvassa az időbélyegszámlálót
- rdtscp(): Olvassa a TSC-t és a processzor ID-t, hogy biztosítsa az időzítés konzisztenciáját a magok között
- rdtscSerialized(): Az rdtsc-t lfence utasításokkal csomagolja be, hogy megakadályozza a sorrenden kívüli végrehajtás torzítását a mérésekben

### CPU időzítő és frekvenciabecslés

A CpuTimer struktúra kényelmes interfészt biztosít a kódblokkok méréséhez A ciklusok falióra-időre történő konvertálásához az estimateTscFreqHz a TSC-t a rendszer monoton órájával szemben kalibrálja

### Hardveres RNG

A modul az rdrand és rdseed utasításokon keresztül hozzáférést biztosít a hardveres entrópiához is, és ha a hardveres támogatás nem áll rendelkezésre, akkor PRNG-t használ

A következő ábra azt szemlélteti, hogy a CpuTimer hogyan lép kölcsönhatásba a hardverutasításokkal.

### Benchmarking modul

A BenchmarkSuite szabványosított teljesítményteszteket biztosít az adatbázis alapvető összetevőihez: az allokátorhoz, a halomhoz és a tranzakciókezelőhöz.

### Benchmark konfigurációk

A benchmarkok vezérlése a BenchmarkConfig segítségével történik, amely meghatározza:

- iterációk: Időzített futások száma.
- warmup_iterations: A CPU gyorsítótárak és a JIT (ha van ilyen) alapozására szolgáló időzítés nélküli futtatások.
- object_size: Az olvasási/írási tesztek adatainak mérete.
- batch_size: A műveletek száma tranzakciónként vegyes munkaterhelésben.

### Tesztkészletek

1.   Allokációs referenciaérték: A PersistentAllocator.alloc és free késleltetésének mérése
2.   Írási/olvasási referenciaérték: A PersistentHeap nyers átviteli teljesítményét méri
3.   Tranzakciós benchmark: A WAL (Write-Ahead Log) terhelését méri a beginTransaction és a commitTransaction során

### Eredmény számítás

Az eredmények egy BenchmarkResult struktúrában kerülnek összesítésre:

- Átlagos, minimális és maximális késleltetés.
- Műveletek másodpercenként (ops/sec).
- Átviteli sebesség MB/sec-ben

### Ellenőrizze a segédprogramot

A HeapInspector introspection képességeket biztosít az adatbázisfájl belső állapotának vizsgálatához a teljes motor futtatása nélkül.

### Ellenőrzési parancsok

A segédprogram az InspectCommand segítségével több részletességi szintet is támogat

- fejléc: Megjeleníti a FileHeader metaadatokat, beleértve a bűvös számokat, a verziót és az ellenőrző összeg érvényesítését
- statisztikák: AllocatorMetadata: Az AllocatorMetadata allokációs statisztikáit jelenti (Összes allokált vs. felszabadított)
- tárgyak: Az érvényes ObjectHeader bejegyzések és FreeListNode blokkok azonosítása érdekében végigmegy a halmon
- sétáljon: A függőben lévő tranzakciók és naplóbejegyzések megtekintése érdekében a Write-Ahead naplót vizsgálja

### Objektum áthaladási logika

Az inspectObjects függvény a halom lineáris letapogatását végzi. Az OBJECT_MAGIC és NODE_MAGIC konstansokat használja az élő adatok és a szabad hely megkülönböztetésére

Ez az ábra azt mutatja, hogy a HeapInspector hogyan képezi le a nyers fájloffszeteket logikai adatbázis-egységekre.

### Diagnosztikai adatáramlás

A következő táblázat összefoglalja a különböző rendszerállapotokhoz rendelkezésre álló diagnosztikai eszközöket:

| Eszköz | Célkomponens | Cél | Kulcsfunkció/struktúra |
| --- | --- | --- | --- |
| TSC | CPU / Kernel | Nanoszekundumos időzítés és entrópia | CpuTimer |
| Benchmark | PHeap / WAL | Teljesítmény regressziós tesztelés | BenchmarkSuite |
| Inspector | store.dat | Integrity & Fragmentation Analysis | HeapInspector |
| Sequencer | Tranzakciók | Monotonikus azonosító generálás | TscSequencer |

## Fogalomtár

Ez a szójegyzék az agdb kódbázisra jellemző technikai kifejezéseket, adatstruktúrákat és architektúrális fogalmakat határozza meg.

### Alapvető adatbázis fogalmak

### Adatbázis

Az elsődleges orchestrator struktúra, amely integrálja a KvStore, a Bm25Index és a VectorIndex elemeket. Kezeli az adatbevitel és -lehívás magas szintű életciklusát.

- Végrehajtás: Adatbázis struktúra
- Szerep: Koordináták a szöveges rangsorolás, a vektorhasonlóság és a nyers kulcsérték-tárolás között.

### KvStore (Kulcs-érték tároló)

Csak függelékkel rendelkező, naplóstruktúrájú tárolómotor, amelyet az elsődleges rekordok megőrzésére használnak. Egy memórián belüli StringHashMap-ot használ a kulcsok fájloffszetekhez való hozzárendeléséhez.

- Fájlformátum: Használja a FileHeader és RecordHeader
- Kulcsfunkciók:
- open(): Visszajátssza a naplót és javítja a fejléceket
- put(): Új rekordot csatol és frissíti az indexet

-   83

### BM25 index

A Best Matching 25 rangsoroló funkció megvalósítása teljes szöveges kereséshez. Tokenizálót használ a szöveg invertált indexekké történő feldolgozásához.

- Adatszerkezetek: És Bm25Index
- Algoritmus: IDF (Inverse Document Frequency) számításokat hajt végre a search() függvényben

### Vektor Index

Kezeli a nagydimenziós vektorbeágyazásokat hasonlóságkereséshez.

- Távolsági mérőszámok: Euklideszi és Manhattan-távolságok: Támogatja a koszinusz, a belső termék, az euklideszi és a Manhattan-távolságokat.
- Végrehajtás: VectorIndex a

### Perzisztencia és futásidő réteg

### PHeap (tartós halom)

Egy memóriakártyás tárolóréteg, amely tartós memóriaabsztrakciót biztosít. Nyomon követi a "piszkos" oldalakat, hogy optimalizálja a lemezre való lehúzást.

- Végrehajtás: PersistentHeap a
- Kulcsmechanizmus: A mapFile() létrehozza a megosztott memória leképezését, amely követi a módosított szegmenseket a flush() művelethez

### WAL (Write-Ahead Log)

Atomicitást és tartósságot biztosít a műveletek naplózásával, mielőtt azokat a PHeapre alkalmaznák.

- Végrehajtás: WAL struktúra
- Életciklus: A tranzakciók rekordokat csatolnak a WAL-hez, amelyeket a RecoveryEngine az indítás során használ fel.

### Tranzakciós menedzser

Egyidejűséget és elszigetelést szervez a sorozatképes pillanatfelvétel-izoláció (SSI) és a hardveres tranzakciós memória (HTM) tippek segítségével.

- Adatszerkezet: A tranzakció nyomon követi a read_set, write_set és pending_allocations értékeket
- Állapotgép: A tranzakciók aktív, előkészített, lekötött vagy visszavont állapotokon keresztül haladnak

### Mutatótípusok

- PersistentPtr: Egy globálisan egyedi mutató, amely egy pool_uuid-ből és egy PHeap-en belüli eltolásból áll
- RelativePtr: Egy báziscímhez viszonyított mutató, amelyet a hatékony kupacon belüli hivatkozásokhoz használnak

### Felhő és többszemélyes használat

### Nyilvántartás

A globális adatbázis, amely nyomon követi az összes bérlőt, az API-kulcsaikat és a fizikai adataik helyét.

- Végrehajtás: Nyilvántartás
- Kulcsterek: Előtagokat használ, mint például email:, tenant: és apikey: az adatok felosztására a belső KvStore-on belül

### Sandbox

Egy Linux-elszigetelt környezet bérlő-specifikus adatbázis-példányok futtatására.

- Elszigeteltség: Cgroups v2 (memória, CPU, PID korlátok) és Namespaces (PID, Net, IPC, UTS, Mount, User) használata
- Spawn Flow: A sys_clone3-t használja a CLONE_INTO_CGROUP funkcióval

### IPC (folyamatok közötti kommunikáció)

Az útválasztó által a sandbox_runner folyamatokkal való kommunikációra használt bináris protokoll.

- Fejléc: (0x47444241), request_id és payload_len
- Mechanizmus: sendMessage és recvMessage kezeli a little-endian szerializálást Unix domain socketeken keresztül

### Rendszerarchitektúra-diagramok

### Adatáramlás: A kéréstől a tárolásig

Ez az ábra a "Rekord mentése" természetes nyelvi fogalmát a folyamatban részt vevő konkrét kódegységekre vezeti le.

  194 105 77 237

### Bérlő életciklusa és elkülönítése

Ez az ábra a "Multi-tenancy" koncepciót áthidalja a mögöttes Linux primitívekhez és Agdb struktúrákhoz.

   20

### Műszaki kifejezések referenciatáblázata

| Term | Definíció | Fájlmutató |
| --- | --- | --- |
| TSC | Időbélyegszámláló; a tranzakciók nagy felbontású időzítéséhez használatos. | |
| HTM | Hardveres tranzakciós memória; zármentes atomos frissítések megkísérlésére szolgál. | |
| SeqLock | Sequence Lock; a tranzakciókezelőben a versengésmentes olvasáshoz használatos. | |
| Magic | A fájl integritásának ellenőrzésére használt u32 konstans (pl. 0x41474442 a KV esetében). | |
| CRC32 | Ciklikus redundanciaellenőrzés; a KV rekordok integritásának ellenőrzésére szolgál. | |
| Arena | Gyors allokátor, amely egyszerre szabadítja fel az összes memóriát (tranzakciókban használatos). | |
| Blake3 | Az API-kulcsokhoz és e-mailekhez használt kivonatoló algoritmus. | |
