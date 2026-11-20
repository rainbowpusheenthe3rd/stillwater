# Changelog

## 0.1.0 (2026-11-20)

- Quiet action bars: faint out of combat (35%), stronger in combat (75%), full under the mouse; the micro menu and bags fainter still (20%); everything at full in Edit Mode. `/still rest | fight | edges <0-1>`.
- Procs as a ring of light on the ground below your character, in your race's homeland colour: it opens when Blizzard lights a proc glow, breathes while the proc is up and closes when it goes. `/still y <px>`, `/still size <px>`, `/still test`.
- A proc-highlighted button keeps its glow at full strength on a quiet bar.
- A thin outline round each filled action button at its own opacity, so quiet bars never vanish. `/still border <0-1>` (0 for none).
- With Manabloom loaded, one ripple goes out across the ground when its bramble reaches the top step.
- The new-mail icon drawn the calendar's size, just right of it; shift-drag to move it, `/still mail reset` to put it back.
- Blizzard's durability doll moves from under the minimap to the bottom-right corner and stays faint until the mouse is over it. `/still doll <0-1>`, shift-drag to move it, `/still doll reset`.
- Quiet chat, folded in from the Hush addon: chat tabs, buttons and backgrounds hidden, the edit box border faint; whispers still show and Enter still opens the edit box. `/still chat [on | off]`; `/hush` still works.
- A minimap button that opens the options: Stillwater, Quiet chat and Button outlines toggles, and sliders for the bars at rest and in combat.
- `/still off` gives Blizzard's bars and chat back; `/still on` brings the quiet back.
- `/still probe` reports which of Blizzard's combat tools this client has and how many proc glows it has seen.
