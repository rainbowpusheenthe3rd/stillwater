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
--   * A thin outline round each filled button keeps its own opacity (`border`), so quiet bars never vanish.
--   * The mail icon is drawn the calendar's size and sits just right of it; shift-drag moves it.
--   * A proc-highlighted button's glow stays at full strength on a quiet bar.
--   * Armour as one line under the character, in words and a symbol, only while something is worn or broken;
--     Blizzard's colour-only doll under the minimap is hidden. "All mended" after a repair, then quiet.
--   * The minimap's coordinates get an outline and a faint plate, so they read over Homeland's frame.
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

local DEFAULTS = { on = true, rest = 0.35, fight = 0.75, edges = 0.2, border = 0.5, y = -110, size = 260,
                   armour = true }
local STEP = 0.08      -- how far an opacity moves towards its target each tick (0.05 s): about half a second
local FLAT = 0.38      -- the ring's height over its width: a circle seen lying on the ground

-- armour: one line under the character, only when something is worn or broken, said in words and a symbol
local ARMOUR_SLOTS = {  -- inventory slot -> name (slots with durability; rings, neck and trinkets have none)
    { 1, "Head" }, { 3, "Shoulders" }, { 5, "Chest" }, { 6, "Waist" }, { 7, "Legs" }, { 8, "Feet" },
    { 9, "Wrists" }, { 10, "Hands" }, { 16, "Main hand" }, { 17, "Off hand" }, { 18, "Ranged" },
}
local WORN = 0.25                          -- at or under this share of durability a piece counts as worn
local ARMOUR_ICON = "Interface\\Icons\\Trade_BlackSmithing"
local ARMOUR_ICON_SIZE = 18
local ARMOUR_W, ARMOUR_H, ARMOUR_GAP = 220, 22, 6         -- the line's frame, and icon-to-text gap
local ARMOUR_Y = -150                      -- under the character, from the screen's centre (shift-drag moves it)
local ARMOUR_COLOUR = {                    -- text colour; the words carry the state, colour only backs them up
    worn = { 1, 0.80, 0.35 },              -- amber
    broken = { 1, 0.50, 0.40 },            -- coral, a different lightness from amber for colour-blind eyes
    mended = { 0.80, 0.95, 0.85 },         -- soft moonlit green-white
}
local MENDED_FOR = 3                       -- seconds "All mended" stays before it fades
local ARMOUR_FADE = 1                      -- seconds to fade in or out

-- the minimap's coordinates: an outline and a faint plate behind, so they read over the frame's art
local COORDS_PATTERN = "^%s*%-?%d+%.%d+,%s*%-?%d+%.%d+%s*$"
local COORDS_PLATE = { 0, 0, 0, 0.45 }
local COORDS_PAD = 3                       -- pixels of plate round the text
local COORDS_SEARCH_EVERY = 2              -- seconds between looks until the text is found

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

---------------------------------------------------------------------------------------------- outlines
-- A 1-pixel pale edge round each filled button's icon, at its own opacity (`border`) whatever the bar's fade, so
-- the buttons on a quiet bar never vanish entirely. Empty slots get none. Made out of combat only, since the
-- buttons are secure; shown, hidden and re-faded at any time.
local outlined = {}
local function Buttons(bar)
    if bar.actionButtons then return bar.actionButtons end
    local list = {}
    for _, c in ipairs({ bar:GetChildren() }) do if c.icon then list[#list + 1] = c end end
    return list
end

local function Edge(o, a, b, ax, ay, bx, by, wide)
    local t = o:CreateTexture(nil, "OVERLAY")
    t:SetColorTexture(0.92, 0.92, 0.88)
    t:SetPoint(a[1], o, a[2], ax, ay)
    t:SetPoint(b[1], o, b[2], bx, by)
    local set = wide and "SetHeight" or "SetWidth"
    if PixelUtil and PixelUtil[set] then PixelUtil[set](t, 1) else t[set](t, 1) end
end

local function Outline(btn)
    local o = CreateFrame("Frame", nil, btn)
    o:SetAllPoints(btn.icon)
    o:SetIgnoreParentAlpha(true)
    Edge(o, { "BOTTOMLEFT", "TOPLEFT" }, { "BOTTOMRIGHT", "TOPRIGHT" }, -1, 0, 1, 0, true)
    Edge(o, { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" }, -1, 0, 1, 0, true)
    Edge(o, { "TOPRIGHT", "TOPLEFT" }, { "BOTTOMRIGHT", "BOTTOMLEFT" }, 0, 0, 0, 0, false)
    Edge(o, { "TOPLEFT", "TOPRIGHT" }, { "BOTTOMLEFT", "BOTTOMRIGHT" }, 0, 0, 0, 0, false)
    outlined[btn] = o
    return o
end

local function Outlines()
    local on = db.on and db.border > 0
    local fighting = InCombatLockdown and InCombatLockdown()
    for _, name in ipairs(BARS) do
        local bar = _G[name]
        if bar then
            for _, btn in ipairs(Buttons(bar)) do
                local o = outlined[btn]
                if not o and on and not fighting and btn.icon then o = Outline(btn) end
                if o then
                    o:SetShown(on and btn:IsShown() and btn.icon:IsShown())
                    o:SetAlpha(db.border)
                end
            end
        end
    end
end

---------------------------------------------------------------------------------------------- the mail icon
-- The new-mail icon, drawn the calendar's size and set just right of it. Forever's UI (wow-ui-source "forever"
-- branch, Blizzard_Minimap/Camelot): the calendar is GameTimeFrame, 23 x 23, at the right end of the zone bar,
-- and Blizzard anchors the addon compartment under it; the mail is MinimapCluster.IndicatorFrame.MailFrame,
-- 32 x 24, in a layout row under the zone text that Blizzard re-lays whenever mail comes or goes, so the move is
-- made again after every Layout. Shift-drag the icon to put it anywhere; /still mail reset puts it back.
local function MailFrame()
    local row = MinimapCluster and MinimapCluster.IndicatorFrame
    return (row and row.MailFrame) or _G.MiniMapMailFrame
end
local function Mail()
    local cal, mail = _G.GameTimeFrame, MailFrame()
    if not (cal and mail) then return end
    -- match the drawn icons, not the frames round them (the mail's frame is wider than its envelope)
    local ch = (cal.StateTexture or cal):GetHeight() * cal:GetEffectiveScale()
    local mh = (mail.MailIcon or mail):GetHeight() * mail:GetParent():GetEffectiveScale()
    if ch <= 0 or mh <= 0 then return end
    local s = ch / mh
    mail:SetScale(s)
    mail:ClearAllPoints()
    if db and db.mail then
        mail:SetPoint("CENTER", UIParent, "BOTTOMLEFT", db.mail[1] / mail:GetEffectiveScale(),
            db.mail[2] / mail:GetEffectiveScale())
    else
        mail:SetPoint("LEFT", cal, "RIGHT", 1 / s, 0)
    end
end
local function HookMail()
    local row = MinimapCluster and MinimapCluster.IndicatorFrame
    if row and row.Layout then hooksecurefunc(row, "Layout", Mail) end
    local mail = MailFrame()
    if mail and mail.RegisterForDrag then
        mail:SetMovable(true)
        mail:RegisterForDrag("LeftButton")
        mail:SetScript("OnDragStart", function(self) if IsShiftKeyDown() then self:StartMoving() end end)
        mail:SetScript("OnDragStop", function(self)
            self:StopMovingOrSizing()
            local x, y = self:GetCenter()
            local s = self:GetEffectiveScale()
            db.mail = { x * s, y * s }          -- screen pixels, so a later change of scale doesn't move it
            Mail()
        end)
    end
    Mail()
end

---------------------------------------------------------------------------------------------- armour
-- Blizzard's durability doll sits under the minimap, behind other art, and says "breaking" or "broken" only by
-- yellow or red. This hides it and puts one line just under the character instead, where the eye already is:
-- a hammer and "Armour 62% · 2 worn" or "1 broken · repair". It shows only while something needs doing, and the
-- words carry the state, so it reads for colour-blind eyes. Hover lists every piece, worst first. After a repair
-- it says "All mended" softly and fades. Shift-drag moves it; /still armour off brings back Blizzard's doll.
local armour = CreateFrame("Frame", "StillwaterArmour", UIParent)
armour:SetSize(ARMOUR_W, ARMOUR_H)
armour:SetFrameStrata("LOW")
armour:EnableMouse(true)
armour:SetMovable(true)
armour:RegisterForDrag("LeftButton")
armour:SetAlpha(0)
armour:Hide()
armour.icon = armour:CreateTexture(nil, "ARTWORK")
armour.icon:SetSize(ARMOUR_ICON_SIZE, ARMOUR_ICON_SIZE)
armour.icon:SetPoint("LEFT")
armour.icon:SetTexture(ARMOUR_ICON)
armour.text = armour:CreateFontString(nil, "OVERLAY", "GameFontNormal")
armour.text:SetPoint("LEFT", armour.icon, "RIGHT", ARMOUR_GAP, 0)
local function ArmourPlace()
    armour:ClearAllPoints()
    if db and db.armourAt then
        armour:SetPoint("CENTER", UIParent, "BOTTOMLEFT", db.armourAt[1], db.armourAt[2])
    else
        armour:SetPoint("CENTER", UIParent, "CENTER", 0, ARMOUR_Y)
    end
end

-- every piece with durability: { name, share 0-1 }, worst first
function Stillwater_ArmourPieces()
    local out = {}
    for _, s in ipairs(ARMOUR_SLOTS) do
        local cur, max = GetInventoryItemDurability(s[1])
        if cur and max and max > 0 then out[#out + 1] = { s[2], cur / max } end
    end
    table.sort(out, function(a, b) return a[2] < b[2] end)
    return out
end

-- the line: text and colour key, or nil when nothing needs doing
function Stillwater_ArmourLine()
    local broken, worn, cur, max = 0, 0, 0, 0
    for _, s in ipairs(ARMOUR_SLOTS) do
        local c, m = GetInventoryItemDurability(s[1])
        if c and m and m > 0 then
            cur, max = cur + c, max + m
            if c == 0 then broken = broken + 1 elseif c / m <= WORN then worn = worn + 1 end
        end
    end
    if broken > 0 then return ("%d broken · repair"):format(broken), "broken" end
    if worn > 0 then return ("Armour %d%% · %d worn"):format(math.floor(100 * cur / max + 0.5), worn), "worn" end
    return nil
end

local function ArmourFade(to, after)
    armour.fading = { from = armour:GetAlpha(), to = to, t0 = GetTime(), after = after }
    armour:Show()
end
armour:SetScript("OnUpdate", function(self)
    local f = self.fading
    if not f then return end
    local p = math.min(1, (GetTime() - f.t0) / ARMOUR_FADE)
    self:SetAlpha(f.from + (f.to - f.from) * p)
    if p >= 1 then
        self.fading = nil
        if f.to == 0 then self:Hide() end
        if f.after then f.after() end
    end
end)

local function Armour()
    if not db then return end
    local doll = _G.DurabilityFrame
    if doll then doll:SetAlpha(db.armour and 0 or 1); if doll.EnableMouse then doll:EnableMouse(not db.armour) end end
    if not db.armour then armour:Hide(); armour.showing = nil; return end
    local text, kind = Stillwater_ArmourLine()
    if text then
        local c = ARMOUR_COLOUR[kind]
        armour.text:SetText(text)
        armour.text:SetTextColor(c[1], c[2], c[3])
        armour.icon:SetDesaturated(kind == "worn")      -- broken: the hammer in full colour, a second cue
        if not armour.showing then ArmourFade(1) end
        armour.showing = true
    elseif armour.showing then                         -- the good ending: say so, then go quiet
        armour.showing = nil
        local c = ARMOUR_COLOUR.mended
        armour.text:SetText("All mended")
        armour.text:SetTextColor(c[1], c[2], c[3])
        armour.icon:SetDesaturated(false)
        C_Timer.After(MENDED_FOR, function() if not armour.showing then ArmourFade(0) end end)
    end
end

armour:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine("Armour")
    for _, p in ipairs(Stillwater_ArmourPieces()) do
        local state = p[2] == 0 and "broken" or p[2] <= WORN and "worn" or ""
        local c = ARMOUR_COLOUR[state] or { 0.85, 0.85, 0.85 }
        GameTooltip:AddDoubleLine(p[1], ("%d%%%s"):format(math.floor(100 * p[2] + 0.5), state ~= "" and (" " .. state) or ""),
            0.85, 0.85, 0.85, c[1], c[2], c[3])
    end
    GameTooltip:AddLine("Shift-drag to move", 0.6, 0.6, 0.6)
    GameTooltip:Show()
end)
armour:SetScript("OnLeave", function() GameTooltip:Hide() end)
armour:SetScript("OnDragStart", function(self) if IsShiftKeyDown() then self:StartMoving() end end)
armour:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local x, y = self:GetCenter()
    db.armourAt = { x, y }
    ArmourPlace()
end)

---------------------------------------------------------------------------------------------- coordinates
-- The minimap's coordinate text isn't ours (it isn't in Blizzard's Camelot minimap code either), so it is found by
-- its look: a FontString under the minimap cluster reading "37.6, 73.4". Once found it gets an outline and a faint
-- plate behind it, so it reads over the frame's vines.
local coords
local function FindCoords(frame, depth)
    if not frame or depth > 6 then return nil end
    for _, r in ipairs({ frame:GetRegions() }) do
        if r.GetObjectType and r:GetObjectType() == "FontString" then
            local t = r:GetText()
            if type(t) == "string" and not Secret(t) and t:match(COORDS_PATTERN) then return r end
        end
    end
    for _, c in ipairs({ frame:GetChildren() }) do
        local found = FindCoords(c, depth + 1)
        if found then return found end
    end
end
local function Coords()
    if coords then return true end
    local fs = FindCoords(_G.MinimapCluster, 0) or FindCoords(_G.Minimap, 0)
    if not fs then return false end
    coords = fs
    local font, size, flags = fs:GetFont()
    if font then fs:SetFont(font, size, (flags or ""):find("OUTLINE") and flags or "OUTLINE") end
    fs:SetShadowColor(0, 0, 0, 1)
    fs:SetShadowOffset(1, -1)
    local plate = fs:GetParent():CreateTexture(nil, "BACKGROUND")
    plate:SetColorTexture(COORDS_PLATE[1], COORDS_PLATE[2], COORDS_PLATE[3], COORDS_PLATE[4])
    plate:SetPoint("TOPLEFT", fs, "TOPLEFT", -COORDS_PAD, COORDS_PAD)
    plate:SetPoint("BOTTOMRIGHT", fs, "BOTTOMRIGHT", COORDS_PAD, -COORDS_PAD)
    return true
end
local function SeekCoords()
    if Coords() then return end
    local t
    t = C_Timer.NewTicker(COORDS_SEARCH_EVERY, function() if Coords() and t then t:Cancel() end end)
end

-- Blizzard's proc highlight on a button (the alert frame ActionButtonSpellAlertManager puts on it) stays at full
-- strength while the bar is quiet, so the one button that matters stands out from the rest.
if ActionButtonSpellAlertManager and ActionButtonSpellAlertManager.ShowAlert then
    hooksecurefunc(ActionButtonSpellAlertManager, "ShowAlert", function(_, button)
        local alert = button and button.SpellActivationAlert
        if alert and alert.SetIgnoreParentAlpha then alert:SetIgnoreParentAlpha(db == nil or db.on) end
    end)
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
                     "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE", "UPDATE_INVENTORY_DURABILITY", "UPDATE_INVENTORY_ALERTS" }) do
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
        Outlines()
        C_Timer.NewTicker(0.5, Outlines)
        ArmourPlace()
        Armour()
        SeekCoords()
    elseif event == "PLAYER_ENTERING_WORLD" then
        procs = 0
        Close()
        Mail()
        Armour()
    elseif event == "UPDATE_INVENTORY_DURABILITY" or event == "UPDATE_INVENTORY_ALERTS" then
        Armour()
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
    elseif (cmd == "rest" or cmd == "fight" or cmd == "edges" or cmd == "border") and n then
        db[cmd] = math.max(0, math.min(1, n))
        Outlines()
        Print(("%s opacity %.2f."):format(cmd, db[cmd]))
    elseif (cmd == "y" or cmd == "size") and n then
        db[cmd] = n
        Place()
        Open()
        C_Timer.After(2.5, function() if procs == 0 then Close() end end)
        Print(("%s %d."):format(cmd, n))
    elseif cmd == "mail" and arg == "reset" then
        db.mail = nil
        Mail()
        Print("the mail icon is back beside the calendar.")
    elseif cmd == "armour" or cmd == "armor" then
        if arg == "reset" then
            db.armourAt = nil
            ArmourPlace()
            Print("the armour line is back under your character.")
        else
            db.armour = arg ~= "off"
            Armour()
            Print(db.armour and "armour shows as one line under your character when something needs mending."
                or "armour line off: Blizzard's doll is back.")
        end
    elseif cmd == "test" then
        Open()
        C_Timer.After(3, function() if procs == 0 then Close() end; Ripple() end)
        Print("the ring for three seconds, then a ripple.")
    elseif cmd == "probe" then
        local p = db.probe
        local have = {}
        for k, v in pairs(p.has) do have[#have + 1] = k .. (v and " yes" or " no") end
        table.sort(have)
        Print(("client %s; %s; proc glows seen %d, secret IDs %d; minimap coordinates %s."):format(
            tostring(p.client), table.concat(have, ", "), p.glows, p.secretIds, coords and "found" or "not found"))
    else
        Print("/still on|off, rest|fight|edges <0-1> (bar opacity out of combat, in combat, micro menu and"
            .. " bags), border <0-1> (the outline round each button; 0 for none), y <px> and size <px> (the ring), mail reset (shift-drag the mail icon to move it), armour on|off|reset, test,"
            .. " probe.")
    end
end
