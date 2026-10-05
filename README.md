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

Sunshine-alkalmazások: **Desktop** (a teljes asztal) és **Steam Big Picture**. Mindkettő a kliens
felbontására állítja a kimenetet, kilépéskor visszaáll az alapra (`DISPLAY_*`).


## RetroArch + RomM mentésszinkron

A ROM-ok csak olvashatóan a `/mnt/roms` alatt (RomM `roms/roms`). A RetroArch előre nincs beállítva,
core-ok nincsenek előre letöltve. Az Arch RetroArch-csomagja a Core Downloadert elrejti, és a core-mappája
(`/usr/lib/libretro`) nem írható – ezért első alkalommal (bezárt RetroArch mellett):

```bash
sudo docker exec -u gamer <konténer> mkdir -p /home/gamer/.config/retroarch/cores
sudo docker exec -u gamer <konténer> sed -i -e 's|^menu_show_core_updater = .*|menu_show_core_updater = "true"|' -e 's|^libretro_directory = .*|libretro_directory = "~/.config/retroarch/cores"|' /home/gamer/.config/retroarch/retroarch.cfg
```

Utána a RetroArch felületén:

- A mentések (`~/.config/retroarch/saves`, `states`) alapból a home-ban vannak, ezt nem kell állítani.
- **Settings → Network → Network Commands**: be – erre figyel a szinkron.
- **Settings → User Interface → Pause when not active**: ki – streaming közben ne álljon meg.

Szinkron párosítása (egyszer; a RomM-ben előtte Client API Token + párosító kód):

```bash
sudo docker exec -it -u gamer <konténer> romm-sync pair --url http://<NAS-IP>:<romm-port> --code ABCD1234
```

Utána a `~/.config/romm-retroarch-sync/config.ini`-ben a `saves_dir` és `states_dir` legyen ugyanaz,
mint a RetroArch-ban beállított két mappa. A `romm-sync` supervisord-program magától elindul,
és csak akkor szinkronizál, amikor a RetroArch-ban nincs játék betöltve. Napló: `docker logs`.

## Hibakeresés

| Tünet | Teendő |
|---|---|
| A konténer azonnal leáll „név/minor eltérés” vagy „rossz kártya” hibával | Bootkor átszámozódtak a node-ok: `ls -l /dev/dri/by-path/`, és a compose-ban a GPU PCI-címéhez tartozó `renderD…` nevet add meg (devices + `GPU_RENDER_NODE`). |
| A desktop nem indul, a logban libinput/seat hiba | `GS_LIBINPUT: "0"` a környezetbe → indul, de a Sunshine-ből érkező egér/kontroller nem működik; a logot küldd el. |
| Moonlightban nincs egér/gamepad | `docker exec -it <konténer> ls -l /dev/input` – látszanak-e új `event*` eszközök stream közben. |
| A Sunshine csomag nem települ build közben (függőségi hiba) | Az Arch gördülő frissítései elhúztak a csomag alól: a `Dockerfile` `SUNSHINE_VERSION` értékét állítsd a legújabb release-re. |
| Szolgáltatások állapota | `docker exec -it <konténer> supervisorctl status` |
