-- Stillwater: a calmer screen. The action bars rest quietly and come up when you need them; the moments that
-- matter show as light on the ground round your character instead of as another icon at the bottom.
--
-- Why (docs/ui_research/references.md): under high load, things at the screen's edge stop being seen (Lavie,
-- 1995); a busy display pulls the eyes off the world (Wickens & Alexander, 2009); irrelevant clutter costs more
-- the more of it there is (Yeh et al., 2003). So: little on screen, the important things near the character,
-- each said by shape and motion as well as colour, and never "press this next".
--
-- v0.1:
--   * Quiet bars. The action bars sit at `rest` opacity out of combat and `fight` in combat, and come to full
--     when the mouse is over them. The micro menu and bags sit fainter still (`edges`). Edit Mode shows all.
--   * The ring. When Blizzard's own proc glow lights a button (SPELL_ACTIVATION_OVERLAY_GLOW_SHOW), a ring of
--     light opens on the ground round you, in your race's homeland colour, breathes while the proc is up and
--     closes when it goes. It doesn't say which spell: the glowing button does that. On this client addons
--     can't read auras in combat (Manabloom's lastError, 9 Nov 2026), so Blizzard's signal is the one we use.
--   * The ripple. If Manabloom is loaded, its bramble reaching the top step (efficient casting, sustained)
--     sends one ripple out across the ground. Earned, rare, then gone.
--   * The mail icon is made the calendar's size and sits just under it.
--   * A probe. On login it records which of Blizzard's combat tools this client has, and counts proc glows
--     and secret spell IDs, so the next version is built on what the client really allows. /still probe.
-- /still for commands.
local ADDON = ...
local DIR = "Interface\\AddOns\\Stillwater\\"

local BARS = { "MainActionBar", "MainMenuBar", "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight",
               "MultiBarLeft", "MultiBar5", "MultiBar6", "MultiBar7", "StanceBar", "PetActionBar" }
local EDGES = { "MicroMenuContainer", "BagsBar", "MicroButtonAndBagsBar" }

-- the flower colour of each race's homeland (tools/homeland_nouveau.py PALETTE), by UnitRace's file name
local RACE = {
    NightElf = { 240, 236, 255 }, Human = { 244, 196, 206 }, Dwarf = { 196, 136, 206 }, Gnome = { 124, 172, 240 },
    Orc = { 244, 130, 70 }, Scourge = { 156, 116, 186 }, Tauren = { 244, 212, 96 }, Troll = { 232, 112, 200 },
}

local DEFAULTS = { on = true, rest = 0.35, fight = 0.75, edges = 0.2, y = -110, size = 260 }
local STEP = 0.08      -- how far an opacity moves towards its target each tick (0.05 s): about half a second
local FLAT = 0.38      -- the ring's height over its width: a circle seen lying on the ground

local db
local function Secret(v) return issecretvalue and issecretvalue(v) or false end
local function Print(msg) print("|cffb8c8f0Stillwater|r: " .. msg) end

---------------------------------------------------------------------------------------------- quiet bars
local function Target(frame, quiet)
    if not db.on or (EditModeManagerFrame and EditModeManagerFrame:IsShown()) then return 1 end
    if frame:IsMouseOver() then return 1 end
    return quiet
end

local function Fade()
    local fighting = InCombatLockdown and InCombatLockdown()
    local bars = fighting and db.fight or db.rest
    for _, list in ipairs({ { BARS, bars }, { EDGES, db.edges } }) do
        for _, name in ipairs(list[1]) do
            local f = _G[name]
            if f and f.SetAlpha and f:IsShown() then
                local want, now = Target(f, list[2]), f:GetAlpha()
                if math.abs(want - now) > 0.005 then
                    f:SetAlpha(now + math.max(-STEP, math.min(STEP, want - now)))
                end
            end
        end
    end
end

---------------------------------------------------------------------------------------------- the mail icon
-- The new-mail icon, made the calendar's size and tucked under it at the top right. On this client it sits in
-- MinimapCluster.IndicatorFrame, a layout row that Blizzard re-lays whenever mail comes or goes, so the move is
-- made again after every Layout. Older clients have MiniMapMailFrame on the rim instead; that's moved once.
local function Mail()
    local cal = _G.GameTimeFrame
    local row = MinimapCluster and MinimapCluster.IndicatorFrame
    local mail = (row and row.MailFrame) or _G.MiniMapMailFrame
    if not (cal and mail and cal:GetHeight() > 0 and mail:GetHeight() > 0) then return end
    local s = cal:GetHeight() * cal:GetEffectiveScale() / (mail:GetHeight() * mail:GetParent():GetEffectiveScale())
    mail:SetScale(s)
    mail:ClearAllPoints()
    mail:SetPoint("TOP", cal, "BOTTOM", 0, -2 / s)
end
local function HookMail()
    local row = MinimapCluster and MinimapCluster.IndicatorFrame
    if row and row.Layout then hooksecurefunc(row, "Layout", Mail) end
    Mail()
end

---------------------------------------------------------------------------------------------- the ring
local ring = CreateFrame("Frame", "StillwaterRing", UIParent)
ring:SetFrameStrata("BACKGROUND")     -- above the world, under every other piece of UI
ring:Hide()
ring.tex = ring:CreateTexture(nil, "ARTWORK")
ring.tex:SetAllPoints()
ring.tex:SetTexture(DIR .. "ring")
ring.tex:SetBlendMode("ADD")          -- light, not paint

local function Group(frame, specs, loop)
    local g = frame:CreateAnimationGroup()
    for _, s in ipairs(specs) do
        local a = g:CreateAnimation(s[1])
        a:SetDuration(s[2])
        if s[1] == "Alpha" then a:SetFromAlpha(s[3]); a:SetToAlpha(s[4]) end
        if s[1] == "Scale" then a:SetScaleFrom(s[3], s[3]); a:SetScaleTo(s[4], s[4]) end
        a:SetSmoothing(s[5] or "IN_OUT")
    end
    if loop then g:SetLooping(loop) end
    return g
end

-- open: it grows out from a little smaller and brightens; breathe: a slow swell while it's up; close: it
-- widens and fades, the way a ripple leaves
ring.open = Group(ring, { { "Alpha", 0.45, 0, 1, "OUT" }, { "Scale", 0.45, 0.82, 1, "OUT" } })
ring.breathe = Group(ring.tex, { { "Alpha", 1.6, 1, 0.55 } }, "BOUNCE")
ring.close = Group(ring, { { "Alpha", 0.6, 1, 0, "IN" }, { "Scale", 0.6, 1, 1.12, "OUT" } })
ring.open:SetScript("OnFinished", function() ring:SetAlpha(1); ring.breathe:Play() end)
ring.close:SetScript("OnFinished", function() ring:Hide() end)

local ripple = CreateFrame("Frame", "StillwaterRipple", UIParent)
ripple:SetFrameStrata("BACKGROUND")
ripple:Hide()
ripple.tex = ripple:CreateTexture(nil, "ARTWORK")
ripple.tex:SetAllPoints()
ripple.tex:SetTexture(DIR .. "ring")
ripple.tex:SetBlendMode("ADD")
ripple.go = Group(ripple, { { "Alpha", 1.3, 0.9, 0, "IN" }, { "Scale", 1.3, 0.5, 1.45, "OUT" } })
ripple.go:SetScript("OnFinished", function() ripple:Hide() end)

local function Place()
    local _, race = UnitRace("player")
    local c = RACE[race] or { 230, 236, 245 }
    for _, f in ipairs({ ring, ripple }) do
        f:ClearAllPoints()
        f:SetPoint("CENTER", UIParent, "CENTER", 0, db.y)
        f:SetSize(db.size, db.size * FLAT)
        f.tex:SetVertexColor(c[1] / 255, c[2] / 255, c[3] / 255)
    end
end

local procs = 0      -- glows up now; counted, not keyed, because a spell ID may come in secret
local function Open()
    if not db.on then return end
    if ring.close:IsPlaying() then ring.close:Stop() end
    if ring:IsShown() and not ring.open:IsPlaying() then return end
    ring:SetAlpha(0)
    ring:Show()
    ring.open:Play()
end
local function Close()
    ring.breathe:Stop()
    ring.open:Stop()
    if ring:IsShown() then ring.close:Play() end
end
local function Ripple()
    if not db.on then return end
    ripple.go:Stop()
    ripple:Show()
    ripple.go:Play()
end

---------------------------------------------------------------------------------------------- Manabloom
-- Manabloom calls everything in ManabloomEvents with ("bramble", step, top) when its bramble moves.
ManabloomEvents = ManabloomEvents or {}
local lastStep = 0
table.insert(ManabloomEvents, function(what, step, top)
    if what ~= "bramble" then return end
    step = step or 0
    if step >= top and lastStep < top then Ripple() end
    lastStep = step
end)

---------------------------------------------------------------------------------------------- probe
local function Probe()
    local p = db.probe or {}
    db.probe = p
    p.client = (GetBuildInfo and select(4, GetBuildInfo())) or "?"
    p.has = {
        SpellActivationOverlayFrame = _G.SpellActivationOverlayFrame ~= nil,
        C_SpellActivationOverlay = _G.C_SpellActivationOverlay ~= nil,
        EssentialCooldownViewer = _G.EssentialCooldownViewer ~= nil,
        C_AssistedCombat = _G.C_AssistedCombat ~= nil,
        issecretvalue = _G.issecretvalue ~= nil,
        Manabloom = (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Manabloom")) or false,
    }
    p.glows, p.secretIds = p.glows or 0, p.secretIds or 0
end

---------------------------------------------------------------------------------------------- events
local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW",
                     "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE" }) do
    pcall(ev.RegisterEvent, ev, e)    -- a client without one of these just doesn't send it
end
ev:SetScript("OnEvent", function(_, event, spellID)
    if event == "PLAYER_LOGIN" then
        StillwaterDB = StillwaterDB or {}
        db = StillwaterDB
        for k, v in pairs(DEFAULTS) do if db[k] == nil then db[k] = v end end
        Probe()
        Place()
        HookMail()
        C_Timer.NewTicker(0.05, Fade)
    elseif event == "PLAYER_ENTERING_WORLD" then
        procs = 0
        Close()
        Mail()
    elseif event == "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW" then
        db.probe.glows = db.probe.glows + 1
        if Secret(spellID) then db.probe.secretIds = db.probe.secretIds + 1 end
        procs = procs + 1
        Open()
    elseif event == "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE" then
        procs = math.max(0, procs - 1)
        if procs == 0 then Close() end
    end
end)

---------------------------------------------------------------------------------------------- /still
SLASH_STILLWATER1 = "/still"
SLASH_STILLWATER2 = "/stillwater"
SlashCmdList.STILLWATER = function(msg)
    local cmd, arg = (msg or ""):lower():match("^%s*(%S*)%s*(.-)%s*$")
    local n = tonumber(arg)
    if cmd == "on" or cmd == "off" then
        db.on = cmd == "on"
        if not db.on then Close() end
        Print(db.on and "on." or "off: bars at full, no ring.")
    elseif (cmd == "rest" or cmd == "fight" or cmd == "edges") and n then
        db[cmd] = math.max(0, math.min(1, n))
        Print(("%s opacity %.2f."):format(cmd, db[cmd]))
    elseif (cmd == "y" or cmd == "size") and n then
        db[cmd] = n
        Place()
        Open()
        C_Timer.After(2.5, function() if procs == 0 then Close() end end)
        Print(("%s %d."):format(cmd, n))
    elseif cmd == "test" then
        Open()
        C_Timer.After(3, function() if procs == 0 then Close() end; Ripple() end)
        Print("the ring for three seconds, then a ripple.")
    elseif cmd == "probe" then
        local p = db.probe
        local have = {}
        for k, v in pairs(p.has) do have[#have + 1] = k .. (v and " yes" or " no") end
        table.sort(have)
        Print(("client %s; %s; proc glows seen %d, secret IDs %d."):format(
            tostring(p.client), table.concat(have, ", "), p.glows, p.secretIds))
    else
        Print("/still on|off, rest|fight|edges <0-1> (bar opacity out of combat, in combat, micro menu and"
            .. " bags), y <px> and size <px> (the ring), test, probe.")
    end
end
