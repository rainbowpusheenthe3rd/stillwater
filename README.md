# Stillwater

A calmer screen: quiet action bars that come up when you need them, and procs shown as a ring of light on the ground round you, in your homeland's colour. /still

Armour shows as one line under your character ("Armour 62% · 2 worn", "1 broken · repair") only while something needs mending, in words and a symbol rather than the old colour-only doll; hover for each piece, shift-drag to move, `/still armour off` for Blizzard's doll. The minimap's coordinates get an outline and a faint plate so they read over the frame art.

## Install

From a release zip: unzip the `Stillwater` folder into `World of Warcraft\_forever_\Interface\AddOns`.

For development, link the game's folder to this repo (a directory junction, run once):

```powershell
New-Item -ItemType Junction -Path "<WoW folder>\_forever_\Interface\AddOns\Stillwater" -Target "<this repo>"
```

`tools/` holds the generators for its art, `tests/` its smoke tests (`uv run --with lupa python tests/<file>.py`).

## Talks to

Listens on Manabloom's `ManabloomEvents` (optional); uses Homeland's race palette, copied in.

## Releasing

```sh
git tag -a v1.2.0 -m "1.2.0" && git push origin v1.2.0      # builds the zip, makes the GitHub Release
```

CurseForge uploads are by hand for now, from the zip on the GitHub Release; nothing uploads there automatically.
