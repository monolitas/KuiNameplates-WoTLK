--[[
-- Kui_Nameplates - Class Icons module
-- Displays class icons for player nameplates (friendly/enemy configurable)
-- Uses global cache addon.db.global.UnitClass populated on-demand.
]]
local addon = LibStub("AceAddon-3.0"):GetAddon("KuiNameplates")
local mod = addon:NewModule("ClassIcons", addon.Prototype, "AceEvent-3.0", "AceTimer-3.0")
-- use raw module.moduleName as key; we'll inject coloured label manually
mod.uiName = "|cff55aaffClass Icons|r"

-- Fallback grid coordinates (used only if CLASS_ICON_TCOORDS is unavailable)
local GRID_TCOORDS = {
    WARRIOR = {0, 0.25, 0, 0.25},
    MAGE = {0.25, 0.5, 0, 0.25},
    ROGUE = {0.5, 0.75, 0, 0.25},
    DRUID = {0.75, 1, 0, 0.25},
    HUNTER = {0, 0.25, 0.25, 0.5},
    SHAMAN = {0.25, 0.5, 0.25, 0.5},
    PRIEST = {0.5, 0.75, 0.25, 0.5},
    WARLOCK = {0.75, 1, 0.25, 0.5},
    PALADIN = {0, 0.25, 0.5, 0.75},
    DEATHKNIGHT = {0.25, 0.5, 0.5, 0.75}
}

local P

local function DPrint(...)
    local db = mod.db and mod.db.profile
    if db and db.debug then
        print('[Kui-ClassIcons]', ...)
    end
end

local function CacheClass(unit)
    if not UnitIsPlayer(unit) then return end
    local name = GetUnitName(unit)
    if not name then return end
    local _, class = UnitClass(unit)
    if not class then return end
    local g = addon.db.global
    if g.UnitClass[name] ~= class then
        g.UnitClass[name] = class
        DPrint('Cached class', name, class)
        mod:UpdateVisibleNameplate(name)
    end
end

function mod:UpdateVisibleNameplate(name)
    for _, frame in pairs(addon.frameList) do
        if frame.kui and frame.kui.name then
            local currentName = frame.kui.name.text or frame.kui.name:GetText()
            if currentName == name then
                self:ApplyClassIcon(frame.kui)
            end
        end
    end
end

local function SafeGetFrameName(f)
    if not f or not f.name then return end
    return f.name.text or f.name:GetText()
end

function mod:ApplyClassIcon(f)
    if not P or not P.enabled then return end
    -- Show in both modes; respect toggle only if user explicitly set it
    if P.onlyNameOnly and not f.nameonly then
        -- if user set Only in name-only, hide in bar mode
        if f.classIcon then f.classIcon:Hide() end
        return
    end
    local name = SafeGetFrameName(f)
    if not name or not f.player then
        if f.classIcon then f.classIcon:Hide() end
        return
    end
    -- Friendly / enemy filters (defensive: if flags are nil, derive from health colour classification)
    local isFriendly = f.friend == true
    local isEnemy = f.enemy == true or (not isFriendly and not f.tapped and not f.player)
    if isFriendly and not P.showFriendly then
        if f.classIcon then f.classIcon:Hide() end
        return
    end
    if isEnemy and not P.showEnemy then
        if f.classIcon then f.classIcon:Hide() end
        return
    end
    local class = addon.db.global.UnitClass[name]
    -- Ensure we have coords available (prefer round CLASS_ICON_TCOORDS, fallback to GRID_TCOORDS)
    if not class or (not (CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class]) and not GRID_TCOORDS[class]) then
        if f.classIcon then f.classIcon:Hide() end
        return
    end
    if not f.classIcon then
        f.classIcon = f:CreateTexture(nil, 'OVERLAY')
    end
    f.classIcon:SetSize(P.size, P.size)
    -- Prefer Blizzard round class icons and coord table
    if CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class] then
        f.classIcon:SetTexture('Interface\\TargetingFrame\\UI-Classes-Circles')
        local c = CLASS_ICON_TCOORDS[class]
        f.classIcon:SetTexCoord(c[1], c[2], c[3], c[4])
    else
        -- Fallback to character creation grid
        f.classIcon:SetTexture('Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes')
        local g = GRID_TCOORDS[class]
        if g then f.classIcon:SetTexCoord(g[1], g[2], g[3], g[4]) end
    end

    f.classIcon:ClearAllPoints()
    local ox = P.offsetX or 0
    local oy = P.offsetY or 0
    -- Consistent placement next to the rendered text, regardless of healthbar/name-only
    local anchorFrame = f.name
    local spacing = 2
    local tw = (anchorFrame and anchorFrame.GetStringWidth and anchorFrame:GetStringWidth()) or 0
    local th = (anchorFrame and anchorFrame.GetStringHeight and anchorFrame:GetStringHeight()) or 0

    if P.position == 'LEFT' then
        -- place icon just to the left of the visible text
        if tw > 0 then
            f.classIcon:SetPoint('RIGHT', anchorFrame, 'CENTER', -(tw/2) - spacing + ox, oy)
        else
            -- fallback if width not available
            f.classIcon:SetPoint('RIGHT', anchorFrame, 'LEFT', -spacing + ox, oy)
        end
    elseif P.position == 'RIGHT' then
        -- place icon just to the right of the visible text
        if tw > 0 then
            f.classIcon:SetPoint('LEFT', anchorFrame, 'CENTER', (tw/2) + spacing + ox, oy)
        else
            f.classIcon:SetPoint('LEFT', anchorFrame, 'RIGHT', spacing + ox, oy)
        end
    elseif P.position == 'TOP' then
        -- place icon just above the visible text
        if th > 0 then
            f.classIcon:SetPoint('BOTTOM', anchorFrame, 'CENTER', ox, (th/2) + spacing + oy)
        else
            f.classIcon:SetPoint('BOTTOM', anchorFrame, 'TOP', ox, spacing + oy)
        end
    elseif P.position == 'BOTTOM' then
        -- place icon just below the visible text
        if th > 0 then
            f.classIcon:SetPoint('TOP', anchorFrame, 'CENTER', ox, -(th/2) - spacing + oy)
        else
            f.classIcon:SetPoint('TOP', anchorFrame, 'BOTTOM', ox, -spacing + oy)
        end
    else
        -- default to LEFT behavior
        if tw > 0 then
            f.classIcon:SetPoint('RIGHT', anchorFrame, 'CENTER', -(tw/2) - spacing + ox, oy)
        else
            f.classIcon:SetPoint('RIGHT', anchorFrame, 'LEFT', -spacing + ox, oy)
        end
    end
    f.classIcon:Show()
end

-- Messages
function mod:PostShow(_, f) self:ApplyClassIcon(f) end
function mod:PostTarget(_, f) self:ApplyClassIcon(f) end
function mod:PostCreate(_, f) self:ApplyClassIcon(f) end
function mod:PostHide(_, f)
    if f.classIcon then f.classIcon:Hide() end
end

function mod:UPDATE_MOUSEOVER_UNIT()
    CacheClass('mouseover')
end
function mod:PLAYER_TARGET_CHANGED()
    CacheClass('target')
end
function mod:PARTY_MEMBERS_CHANGED()
    for i=1,(GetNumPartyMembers() or 0) do CacheClass('party'..i) end
end
function mod:RAID_ROSTER_UPDATE()
    for i=1,(GetNumRaidMembers() or 0) do CacheClass('raid'..i) end
end

function mod:RefreshAllIcons()
    for _, frame in pairs(addon.frameList) do
        if frame.kui then
            self:ApplyClassIcon(frame.kui)
        end
    end
end

function mod:configChangedListener()
    P = self.db.profile
    self:RefreshAllIcons()
end

function mod:GetOptions()
    return {
        enabled = { type='toggle', name='Enable class icons', order=0 },
        debug = { type='toggle', name='Debug', order=1, get=function() return P and P.debug end, set=function(_,v) if P then P.debug=v end end },
        display = { type='group', name='Display', inline=true, order=10, args={
            showFriendly = { type='toggle', name='Show friendly', order=1 },
            showEnemy = { type='toggle', name='Show enemy', order=2 },
            onlyNameOnly = { type='toggle', name='Only in name-only', order=3 },
            position = { type='select', name='Position', order=4, values={ LEFT='Left', RIGHT='Right', TOP='Top', BOTTOM='Bottom' } },
            size = { type='range', name='Size', order=5, min=8, max=64, step=1 },
            offsetX = { type='range', name='X Offset', order=6, min=-50, max=50, step=1 },
            offsetY = { type='range', name='Y Offset', order=7, min=-50, max=50, step=1 },
        }}
    }
end

function mod:OnInitialize()
    if not addon.db.global.UnitClass then
        addon.db.global.UnitClass = {}
    end
    -- create namespace similar to Titles
    self.db = addon.db:RegisterNamespace(self.name, { profile = {
        enabled = true,
        debug = false,
        showFriendly = true,
        showEnemy = true,
        onlyNameOnly = false,
        position = 'LEFT',
        size = 16,
        offsetX = 0,
        offsetY = 0
    }})
    -- remove any legacy uncoloured entry using moduleName as key
    if addon.options and addon.options.args and addon.options.args[self.moduleName] then
        addon.options.args[self.moduleName] = nil
    end
    -- standard registration; uiName is colored and spaced
    addon:InitModuleOptions(self)
    P = self.db.profile
end

function mod:OnEnable()
    P = self.db.profile
    if not P or not P.enabled then return end
    self:RegisterMessage('KuiNameplates_PostShow', 'PostShow')
    self:RegisterMessage('KuiNameplates_PostTarget', 'PostTarget')
    self:RegisterMessage('KuiNameplates_PostCreate', 'PostCreate')
    self:RegisterMessage('KuiNameplates_PostHide', 'PostHide')
    self:RegisterEvent('UPDATE_MOUSEOVER_UNIT')
    self:RegisterEvent('PLAYER_TARGET_CHANGED')
    self:RegisterEvent('PARTY_MEMBERS_CHANGED')
    self:RegisterEvent('RAID_ROSTER_UPDATE')
    -- fallback: ensure options group exists (if user loaded mid-session)
    -- AceConfig stores at addon internal options; we can re-call InitModuleOptions harmlessly
    addon:InitModuleOptions(self)
    -- prime target & mouseover if exist
    if UnitExists('target') then CacheClass('target') end
    if UnitExists('mouseover') then CacheClass('mouseover') end
    self:RefreshAllIcons()
end

function mod:OnDisable()
    self:UnregisterAllEvents()
    self:UnregisterAllMessages()
    for _, frame in pairs(addon.frameList) do
        if frame.kui and frame.kui.classIcon then
            frame.kui.classIcon:Hide()
        end
    end
end
