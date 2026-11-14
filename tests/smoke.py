r"""Smoke-test Stillwater v0.1 under lupa: bars fade to rest/fight opacity and come up under the mouse, a proc
glow opens the ring and its hide closes it, Manabloom's bramble reaching the top sends one ripple, the probe
records, and the slash commands set values."""
from pathlib import Path

import lupa

SRC = (Path(__file__).resolve().parents[1] / "Stillwater.lua").read_text(encoding="utf-8")
lua = lupa.LuaRuntime()
lua.execute(r"""
local noop = function() end
local function stub(t)
  return setmetatable(t, { __index = function(_, k) if k:match("^%u") then return noop end end })
end
function print() end
UIParent = stub({})
SlashCmdList = {}
combat = false
function InCombatLockdown() return combat end
function UnitRace() return "Night Elf", "NightElf" end
function GetBuildInfo() return "x", "y", "z", 16001 end
tickers = {}
C_Timer = { NewTicker = function(_, f) tickers[#tickers + 1] = f end, After = function(_, f) after[#after + 1] = f end }
function tick(n) for _ = 1, n do for _, f in ipairs(tickers) do f() end end end
local function group()
  return stub({ playing = false, plays = 0, scripts = {},
    CreateAnimation = function() return stub({}) end,
    Play = function(g) g.playing = true; g.plays = g.plays + 1 end, Stop = function(g) g.playing = false end,
    IsPlaying = function(g) return g.playing end, SetScript = function(g, k, f) g.scripts[k] = f end })
end
function region(t)  -- global: the chat checks at the end build frames too
  t.shown = t.shown or false
  t.alpha = t.alpha or 1
  t.SetAlpha = function(s, a) s.alpha = a end
  t.GetAlpha = function(s) return s.alpha end
  t.Show = function(s) s.shown = true end
  t.Hide = function(s) s.shown = false end
  t.IsShown = function(s) return s.shown end
  t.SetShown = function(s, v) s.shown = v and true or false end
  t.GetChildren = function() end
  t.IsMouseOver = function(s) return s.mouse == true end
  t.CreateAnimationGroup = function() return group() end
  t.SetVertexColor = function(s, r, g, b) s.rgb = { r, g, b } end
  t.SetSize = function(s, w, h) s.w, s.h = w, h end
  t.SetPoint = function(s, _, _, _, x, y) s.y = y end
  t.CreateTexture = function() return stub(region({})) end
  t.CreateFontString = function()
    local fs = region({})
    fs.SetText = function(s, x) s.text = x end
    fs.GetText = function(s) return s.text end
    fs.SetTextColor = function(s, r, g, b) s.rgb = { r, g, b } end
    fs.GetObjectType = function() return "FontString" end
    fs.GetFont = function(s) return "Fonts/FRIZQT__.TTF", 12, s.flags or "" end
    fs.SetFont = function(s, f, size, flags) s.flags = flags end
    return stub(fs)
  end
  t.SetDesaturated = function(s, v) s.desat = v end
  t.SetPoint = function(s, p, rel, rp, x, y) s.y = y; s.anchor = { p, rel, rp, x, y } end
  t.ClearAllPoints = function(s) s.anchor = nil end
  return stub(t)
end
events = {}
GameTooltip = stub({ lines = {}, AddDoubleLine = function(s, a, b) s.lines[#s.lines + 1] = a .. " " .. b end })
DurabilityFrame = region({ shown = true, scripts = {} })
removed = false
DurabilityFrame.layoutParent = { RemoveManagedFrame = function(_, f) removed = (f == DurabilityFrame) end }
DurabilityFrame.SetParent = function(s, p) s.parentFrame = p end
DurabilityFrame.SetMovable = function() end
DurabilityFrame.RegisterForDrag = function() end
DurabilityFrame.HookScript = function(s, k, fn) s.scripts[k] = fn end
DurabilityFrame.StartMoving = function(s) s.moving = true end
DurabilityFrame.StopMovingOrSizing = function(s) s.moving = false end
DurabilityFrame.GetCenter = function() return 1500, 200 end
after = {}
frames = {}
function CreateFrame(kind, name, parent)
  local f = region({ name = name, scripts = {}, parent = parent })
  f.SetScript = function(s, k, fn) s.scripts[k] = fn end
  f.RegisterEvent = function(s, e) events[e] = s end
  if name then _G[name] = f end
  frames[#frames + 1] = f
  return f
end
MultiBarBottomLeft = region({ shown = true })
full = region({ shown = true, icon = region({ shown = true }) })
empty = region({ shown = true, icon = region({ shown = false }) })
MultiBarBottomLeft.actionButtons = { full, empty }
MainActionBar = region({ shown = true })
BagsBar = region({ shown = true })
hooks = {}
function hooksecurefunc(t, k, f) hooks[k] = f end
ActionButtonSpellAlertManager = { ShowAlert = function() end }
function IsShiftKeyDown() return shift end
local function sized(w, h, sc)
  local f = region({ shown = true })
  f.GetHeight = function() return h end
  f.GetEffectiveScale = function() return sc end
  f.SetScale = function(s, v) s.scale = v end
  f.ClearAllPoints = function(s) s.anchor = nil end
  f.SetPoint = function(s, p, rel, rp, x, y) s.anchor = { p, rel, rp, x, y } end
  return f
end
GameTimeFrame = sized(23, 23, 1)
GameTimeFrame.StateTexture = sized(18, 18, 1)       -- the drawn calendar, smaller than its button
local row = sized(32, 24, 1)
row.Layout = function() end
row.MailFrame = sized(32, 24, 1)
row.MailFrame.MailIcon = sized(36, 27, 1)           -- the drawn envelope
row.MailFrame.GetParent = function() return row end
row.MailFrame.SetMovable = function() end
row.MailFrame.RegisterForDrag = function() end
row.MailFrame.scripts = {}
row.MailFrame.SetScript = function(s, k, fn) s.scripts[k] = fn end
row.MailFrame.StartMoving = function(s) s.moving = true end
row.MailFrame.StopMovingOrSizing = function(s) s.moving = false end
row.MailFrame.GetCenter = function() return 900, 500 end
MinimapCluster = region({ IndicatorFrame = row })
MinimapCluster.GetRegions = function() end
MinimapCluster.GetChildren = function() end
function fire(e, ...) events[e].scripts.OnEvent(events[e], e, ...) end
""")
lua.execute(f"local f = load([==[{SRC}]==], 'Stillwater', 't', _G); f('Stillwater')")
lua.execute("fire('PLAYER_LOGIN')")
G = lua.globals()
close = lambda a, b: abs(a - b) < 0.01
db = G.StillwaterDB
assert db.on and close(db.rest, 0.35) and db.probe.has.issecretvalue is False

# quiet bars: down to rest out of combat, the edges fainter, up to fight in combat, full under the mouse
lua.execute("tick(20)")
assert close(G.MainActionBar.alpha, 0.35) and close(G.BagsBar.alpha, 0.2), (G.MainActionBar.alpha, G.BagsBar.alpha)
lua.execute("combat = true; tick(20)")
assert close(G.MainActionBar.alpha, 0.75), G.MainActionBar.alpha
lua.execute("MultiBarBottomLeft.mouse = true; tick(20)")
assert close(G.MultiBarBottomLeft.alpha, 1) and close(G.MainActionBar.alpha, 0.75)
lua.execute("combat = false; MultiBarBottomLeft.mouse = false")

# outlines: on the filled button only, at their own opacity whatever the bar's, gone with "border 0" or "off"
o = lua.eval("(function() for _, f in ipairs(frames) do if f.parent == full then return f end end end)()")
assert o.shown and close(o.alpha, 0.5)
assert lua.eval("(function() for _, f in ipairs(frames) do if f.parent == empty and f.shown then return false end end return true end)()")
lua.execute("SlashCmdList.STILLWATER('border 0.8')")
assert close(o.alpha, 0.8)
lua.execute("full.icon.shown = false; tick(1)")
assert not o.shown
lua.execute("full.icon.shown = true; SlashCmdList.STILLWATER('border 0')")
assert not o.shown
lua.execute("SlashCmdList.STILLWATER('border 0.5')")
assert o.shown

# the ring: tinted moonflower, on the ground below centre; two procs, it closes only when both have gone
ring = G.StillwaterRing
assert close(ring.tex.rgb[1], 240 / 255) and ring.y == -110 and close(ring.h, 260 * 0.38)
lua.execute("fire('SPELL_ACTIVATION_OVERLAY_GLOW_SHOW', 16870)")
assert ring.shown and ring.open.playing
lua.execute("StillwaterRing.open.scripts.OnFinished()")
assert ring.tex and G.StillwaterRing.breathe.playing
lua.execute("fire('SPELL_ACTIVATION_OVERLAY_GLOW_SHOW', 12536); fire('SPELL_ACTIVATION_OVERLAY_GLOW_HIDE', 16870)")
assert not ring.close.playing
lua.execute("fire('SPELL_ACTIVATION_OVERLAY_GLOW_HIDE', 12536)")
assert ring.close.playing and not ring.breathe.playing
assert db.probe.glows == 2

# Manabloom: one ripple when the bramble reaches the top, none while it stays there, one again after a fall
rip = G.StillwaterRipple
lua.execute("for _, s in ipairs({1,2,3,4,5,6,6,5,6}) do for _, f in ipairs(ManabloomEvents) do f('bramble', s, 6) end end")
assert rip.go.plays == 2, rip.go.plays

# the mail icon: the envelope scaled to the drawn calendar, right of it, and put back after Blizzard re-lays the row
mail = G.MinimapCluster.IndicatorFrame.MailFrame
assert close(mail.scale, 18 / 27) and mail.anchor[1] == "LEFT" and mail.anchor[3] == "RIGHT"
assert lua.eval("MinimapCluster.IndicatorFrame.MailFrame.anchor[2] == GameTimeFrame")
lua.execute("MinimapCluster.IndicatorFrame.MailFrame:ClearAllPoints(); hooks.Layout()")
assert mail.anchor is not None and mail.anchor[3] == "RIGHT"
# a plain drag does nothing, shift-drag moves it and the place is kept through re-lays, reset puts it back
lua.execute("local m = MinimapCluster.IndicatorFrame.MailFrame; m.scripts.OnDragStart(m)")
assert not mail.moving
lua.execute("shift = true; local m = MinimapCluster.IndicatorFrame.MailFrame; m.scripts.OnDragStart(m); m.scripts.OnDragStop(m); hooks.Layout()")
assert mail.anchor[1] == "CENTER" and mail.anchor[4] == 900 and mail.anchor[5] == 500 and db.mail[1] == 900
lua.execute("SlashCmdList.STILLWATER('mail reset')")
assert db.mail is None and mail.anchor[1] == "LEFT"
# a proc highlight on a quiet bar ignores the bar's opacity
lua.execute("btn = { SpellActivationAlert = { SetIgnoreParentAlpha = function(s, v) s.ignore = v end } }; hooks.ShowAlert(nil, btn)")
assert lua.eval("btn.SpellActivationAlert.ignore") is True

# slash commands
lua.execute("SlashCmdList.STILLWATER('rest 0.5'); SlashCmdList.STILLWATER('y -80'); SlashCmdList.STILLWATER('fight 7')")
assert close(db.rest, 0.5) and ring.y == -80 and close(db.fight, 1)
lua.execute("SlashCmdList.STILLWATER('off'); tick(20)")
assert close(G.MainActionBar.alpha, 1)
lua.execute("SlashCmdList.STILLWATER('probe'); SlashCmdList.STILLWATER('test'); SlashCmdList.STILLWATER('on')")

# the durability doll: out of the stack under the minimap, in the bottom-right corner, faint until mouseover
D = G.DurabilityFrame
assert lua.eval("removed") and D.ignoreFramePositionManager and lua.eval("DurabilityFrame.parentFrame == UIParent")
assert D.anchor[1] == "BOTTOMRIGHT" and D.anchor[4] == -30 and D.anchor[5] == 80, list(D.anchor.values())
lua.execute("tick(20)")
assert close(D.alpha, 0.35), D.alpha
lua.execute("DurabilityFrame.mouse = true; tick(20)")
assert close(D.alpha, 1), D.alpha
lua.execute("DurabilityFrame.mouse = false; SlashCmdList.STILLWATER('doll 0.2'); tick(20)")
assert close(D.alpha, 0.2) and close(db.doll, 0.2)
# shift-drag moves it and the place is kept; reset puts it back
lua.execute("shift = true; DurabilityFrame.scripts.OnDragStart(DurabilityFrame); DurabilityFrame.scripts.OnDragStop(DurabilityFrame)")
assert db.dollAt[1] == 1500 and D.anchor[1] == "CENTER" and D.anchor[4] == 1500
lua.execute("SlashCmdList.STILLWATER('doll reset')")
assert db.dollAt is None and D.anchor[1] == "BOTTOMRIGHT"
# placed in Edit Mode: left where it is
lua.execute("DurabilityFrame.anchor = { 'TOP', nil, 'TOP', 5, 5 }; DurabilityFrame.IsInDefaultPosition = function() return false end; fire('PLAYER_ENTERING_WORLD')")
assert D.anchor[1] == "TOP", "Edit Mode's place wins"

print("stillwater checks pass")

# quiet chat (was Hush): tabs and buttons hidden, backgrounds clear, edit box faint; Blizzard re-showing a tab is
# undone; /still chat and /hush toggle it; /still off gives Blizzard's chat back
lua.execute(r"""
GeneralDockManager = region({ shown = true, scripts = {} })
GeneralDockManager.HookScript = function(s, k, fn) s.scripts[k] = fn end
ChatFrame1 = region({ shown = true })
ChatFrame1EditBoxMid = region({ shown = true })
winAlpha = {}
function FCF_SetWindowAlpha(cf, a) winAlpha[cf] = a end
SlashCmdList.STILLWATER('on')
fire('PLAYER_LOGIN')
""")
assert G.StillwaterDB.chat is True and not G.GeneralDockManager.shown
assert lua.eval("winAlpha[ChatFrame1]") == 0 and close(G.ChatFrame1EditBoxMid.alpha, 0.3)
lua.execute("GeneralDockManager:Show(); GeneralDockManager.scripts.OnShow(GeneralDockManager)")
assert not G.GeneralDockManager.shown
lua.execute("SlashCmdList.STILLWATERHUSH('')")
assert G.StillwaterDB.chat is False and G.GeneralDockManager.shown and close(G.ChatFrame1EditBoxMid.alpha, 1)
assert close(lua.eval("winAlpha[ChatFrame1]"), 0.25)
lua.execute("SlashCmdList.STILLWATER('chat on')")
assert not G.GeneralDockManager.shown
lua.execute("SlashCmdList.STILLWATER('off')")
assert G.GeneralDockManager.shown
lua.execute("SlashCmdList.STILLWATER('on')")
assert not G.GeneralDockManager.shown
print("smoke ok")
