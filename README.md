# gamestream – Steam + Sunshine + noVNC (TrueNAS custom app)

Egy konténer, benne teljes Linux desktop (labwc + LXQt) headless Wayland-módban.
Minden renderelés és kódolás egyetlen, kiválasztott AMD GPU render node-ján fut, PRIME és `card` node nélkül.
A `compose.yaml` az `ÁTÍRANDÓ` megjegyzésű sorokban saját értékeket vár.

| Elérés | Cím |
|---|---|
| noVNC (böngészős desktop) | http://<NAS-IP>:31100 |
| Sunshine admin | https://<NAS-IP>:47990 (önaláírt tanúsítvány) |
| Moonlight | host hozzáadása kézzel: `<NAS-IP>` |

## 1. Előkészítés a hoston (egyszer)

```bash
# régi image maradéka a home-ból
find <home-mappa> -mindepth 1 -delete

# az apps (568) írási joga a két gaming mappára – ACL-bejegyzéssel, a mappák tulajdonosa változatlan marad
setfacl -R -m u:568:rwX,d:u:568:rwX,d:g:<megosztás-GID>:rwX <home-mappa> <games-mappa>
```

A konténer az `apps` felhasználóként (568:568) fut, a TrueNAS appokhoz hasonlóan. Írási jogot
**csak a két gaming mappára** kap, ACL-bejegyzésen keresztül; a mappák tulajdonosa és az SMB-hozzáférés
nem változik. Az alapértelmezett (default) ACL miatt az új fájlokat is örökölten írhatja az `apps`
és a megosztás csoportja, így SMB-n a megosztás tulajdonosaként is módosíthatók. A megosztás többi része a konténer
(és egy esetleges kitörés) számára csak olvasható marad.

## 2. Image (GitHub Actions)

Az image-et a `.github/workflows/build.yml` építi és tölti fel: `ghcr.io/csaki89/amd-game-stream`.
Fut minden `main`-re pusholáskor (a README-módosítás kivételével), hetente egyszer, és kézzel az
Actions fülön (*Run workflow*). A szerveren nincs build és nincs forráskód.

Címkék: `latest`, dátum (`YYYYMMDD`) és rövid commit-hash. Ha egy új build hibás,
a compose-ban egy korábbi dátumos címkére lehet visszaállni.

**Láthatóság:** az első build után nézd meg a GitHub-profilod *Packages* fülén. Ha a csomag privát,
vagy állítsd publikusra (az image-ben nincs jelszó, mindent a compose ad), vagy a TrueNAS-nak
kell egy `read:packages` jogú tokennel bejelentkeznie a `ghcr.io`-ra.

**Frissítés:** TrueNAS-on az app leállítása, majd indítása – a `pull_policy: always` miatt
indításkor letölti a legfrissebb `latest`-et.

## 3. Telepítés

Apps → Discover Apps → ⋮ → **Install via YAML**, név: `gamestream`, tartalom: `compose.yaml`.
Előtte írd át a `SUNSHINE_PASS`-t, és ha kell, add meg a `VNC_PASSWORD`-öt.

A konténerben nincs sudo. Rootként a hostról lehet belépni: `docker exec -it <konténer> bash`.
A rendszerszintű változtatás helye a `Dockerfile` (a konténer minden indításkor az image-ből jön).

## 4. Első indítás

1. Log: az `[gamestream] GPU rendben: /dev/dri/renderD… -> <PCI-cím>` sornak meg kell jelennie.
2. noVNC → asztal → Steam ikon → bejelentkezés (Steam Guard).
3. Steam → Beállítások → Tárhely → új könyvtár: **`/mnt/games`**.
4. Moonlight → host hozzáadása `<NAS-IP>` → a PIN-t a Sunshine admin felületén add meg
   (a desktopon a „Sunshine admin” ikon, vagy bármelyik böngészőből a LAN-on).

Sunshine-alkalmazások: **Desktop** (a teljes asztal), **Steam Big Picture**, **RetroArch** és **Heroic** (GOG).
Mindegyik a kliens felbontására állítja a kimenetet, kilépéskor visszaáll az alapra (`DISPLAY_*`).
A Steam Big Picture és a Heroic leválasztva indul (ha már fut, csak előtérbe kerül): a programból kilépve
a stream az asztallal folytatódik, a Moonlightban kell befejezni.


## RetroArch + RomM mentésszinkron

A ROM-ok csak olvashatóan a `/mnt/roms` alatt (RomM `roms/roms`). A RetroArch az image-ben be van állítva
a gamestreamhez – **csak a core-ok nincsenek előre kiválasztva/letöltve**: ezeket a
**Main Menu → Online Updater → Core Downloader** tölti le a `~/.config/retroarch/cores` mappába.

Előre beállítva (új konfignál; a felhasználó utána módosíthatja): core-mappa a home-ban, Core Downloader látható,
Load Content a `/mnt/roms`-nál, Vulkan videódriver, Ozone menü, SDL2 kontroller-driver.
Minden induláskor kikényszerítve (a működéshez kell): **Network Commands be** (port 55355, erre figyel a
szinkron) és **Pause when not active ki** (streaming közben ne álljon meg).
A mentések alapból a `~/.config/retroarch/saves` és `states` mappába kerülnek.

Szinkron párosítása (egyszer; a RomM-ben előtte Client API Token + párosító kód):

```bash
sudo docker exec -it -u gamer <konténer> romm-sync pair --url http://<NAS-IP>:<romm-port> --code ABCD1234
```

Utána a `~/.config/romm-retroarch-sync/config.ini`-ben a `saves_dir` és `states_dir` legyen ugyanaz,
mint a RetroArch-ban beállított két mappa. A `romm-sync` supervisord-program magától elindul,
és csak akkor szinkronizál, amikor a RetroArch-ban nincs játék betöltve. Napló: `docker logs`.

## Windows-programok és játékok Steam nélkül

A futtató a `umu-run` (Proton Steam nélkül). Az első indításkor letölti a Protont és a Steam
futtatókörnyezetét a home-ba (pár száz MB, egyszer).

| Művelet | Mit csinál |
|---|---|
| Dupla klikk egy `.exe`-n | `gs-exe-run`: Protonnal indítja |
| Jobb klikk egy `.iso`-n vagy telepítő `.exe`-n → **Telepítés (Proton)** | `gs-exe-install`: kibontás, prefix, D: CD-meghajtó, telepítő, asztali ikon |

Mappák a `/mnt/games` alatt:

- `prefixes/<név>/` – játékonként külön Wine-prefix (a játék a `drive_c` alá települ)
- `media/<név>/` – a kibontott lemezkép; a prefixben D: meghajtó, CD-ROM típussal, a lemez címkéjével.
  **Megmarad**, ha a játék indításkor nem kéri a CD-t, kézzel törölhető.
- `prefixes/default/` – a máshonnan (pl. letöltésekből) indított `.exe`-k közös prefixe

A `<név>` az ISO címkéje, ennek hiányában a fájlnév. Napló: `~/.local/state/gs-exe/<név>.log`.

A `gs-exe-prefix` minden prefixben beállítja a Wine `UseTakeFocus=N` értékét: a labwc a Wine alapértelmezett
(`WM_TAKE_FOCUS`) fókuszkérésére nem adja át a billentyűzetet, enélkül a Windows-programokba nem lehet írni.
A Proton `xalia` segédje alapból ki van kapcsolva (`PROTON_USE_XALIA=0`).
Egy játékhoz tartozó javítások a umu adatbázisából: `GAMEID=<umu-azonosító> gs-exe-run <exe>`.

### GOG: Heroic Games Launcher

GOG-könyvtár, letöltés, frissítés és **GOG-felhőmentés** (szabályos indításkor és kilépéskor szinkronizál).
A GOG offline telepítői (`setup_*.exe`) Heroic nélkül is telepíthetők a fenti módon, felhőmentés nélkül.

Első indításkor, egyszer (asztal → *Heroic (GOG)*):

1. Bejelentkezés: *Store-ok kezelése* → GOG.
2. Beállítások → Általános: alapértelmezett telepítési mappa **`/mnt/games/heroic`**,
   prefixek mappája **`/mnt/games/heroic/prefixes`** (különben a home-ba települ).
3. Beállítások → Játékok alapértelmezett beállításai:
   - Wine: Proton (a *Wine Manager*-ben letölthető GE-Proton), umu bekapcsolva;
   - Egyéb → **Wrapper: `gs-heroic-wrap`** – enélkül a Heroicból indított Windows-játékokba nem lehet írni
     (ugyanaz a `UseTakeFocus` beállítás, amit a `gs-exe-prefix` ad; ha a prefix még nem létezik, előbb létrehozza).
4. Játékonként: Beállítások → *Felhőmentés szinkronizálása* bekapcsolva (csak a GOG-felhőt támogató játékoknál).

A Heroic verzióját a `Dockerfile` `HEROIC_VERSION` értéke rögzíti.

Korlátok: BIN/CUE lemezkép egyelőre nem támogatott; a régi másolásvédelmek (SafeDisc, SecuROM,
StarForce) Wine/Proton alatt nem működnek.

## Hibakeresés

| Tünet | Teendő |
|---|---|
| A konténer azonnal leáll „név/minor eltérés” vagy „rossz kártya” hibával | Bootkor átszámozódtak a node-ok: `ls -l /dev/dri/by-path/`, és a compose-ban a GPU PCI-címéhez tartozó `renderD…` nevet add meg (devices + `GPU_RENDER_NODE`). |
| A desktop nem indul, a logban libinput/seat hiba | `GS_LIBINPUT: "0"` a környezetbe → indul, de a Sunshine-ből érkező egér/kontroller nem működik; a logot küldd el. |
| Moonlightban nincs egér/gamepad | `docker exec -it <konténer> ls -l /dev/input` – látszanak-e új `event*` eszközök stream közben. |
| A Sunshine csomag nem települ build közben (függőségi hiba) | Az Arch gördülő frissítései elhúztak a csomag alól: a `Dockerfile` `SUNSHINE_VERSION` értékét állítsd a legújabb release-re. |
| Szolgáltatások állapota | `docker exec -it <konténer> supervisorctl status` |
