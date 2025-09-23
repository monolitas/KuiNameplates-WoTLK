--[[
-- Kui_Nameplates - Titles module
-- Displays cached guild names for players & NPC subtitles under the name.
-- Caches are stored globally in addon.db.global.
]]
local addon = LibStub("AceAddon-3.0"):GetAddon("KuiNameplates")
local mod = addon:NewModule("Titles", addon.Prototype, "AceEvent-3.0", "AceTimer-3.0")
mod.uiName = "Titles"

local separators = {
    ANGLED = "<%s>",
    NONE = "%s",
    SPACE = " %s",
    PAREN = "(%s)",
    BRACK = "[%s]",
    CURLY = "{%s}"
}

local iconPositions = {
    LEFT = "LEFT",
    RIGHT = "RIGHT", 
    TOP = "TOP",
    BOTTOM = "BOTTOM"
}

-- Class textures mapping (WoTLK class coordinates)
local classTextures = {
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

local tooltip
local wipe = wipe
local levelPattern = UNIT_LEVEL_TEMPLATE:gsub("%%d","%%d+")

local function EnsureTooltip()
    if not tooltip then
        tooltip = CreateFrame("GameTooltip", "KuiNP_TitleScanTooltip", nil, "GameTooltipTemplate")
        tooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
    end
end

-- Safe fontstring creator (defensive)
local function SafeFontString(frame, key, opts)
    if frame[key] and frame[key].GetObjectType and frame[key]:GetObjectType()=="FontString" then
        return frame[key]
    end
    local parent = frame.overlay or frame
    frame[key] = frame:CreateFontString(parent, opts or { size = "title" })
    return frame[key]
end

-- local reference to profile table (set in OnEnable so profile switch updates)
local P

local partyNames = {}
local raidNames = {}

local function DPrint(...)
    local db = mod.db and mod.db.profile
    if db and db.debug then
        print('[Kui-Titles]', ...)
    end
end

local function BuildGroupCaches()
    wipe(partyNames)
    wipe(raidNames)
    local numParty = GetNumPartyMembers and GetNumPartyMembers() or 0
    local numRaid = GetNumRaidMembers and GetNumRaidMembers() or 0
    if numRaid > 0 then
        for i=1,numRaid do
            local n = GetUnitName("raid"..i)
            if n then raidNames[n] = true end
        end
    elseif numParty > 0 then
        for i=1,numParty do
            local n = GetUnitName("party"..i)
            if n then partyNames[n] = true end
        end
    end
end

local function CacheGuild(unit)
    if not P.showGuild then return end
    if not UnitIsPlayer(unit) then return end
    local name = GetUnitName(unit)
    if not name then return end
    local guild = GetGuildInfo(unit)
    local g = addon.db.global
    
    -- Debug output
    DPrint("CacheGuild", unit, name, guild or 'nil')
    
    -- Only cache actual guild names, ignore "NOT FRIENDLY" and empty strings
    if guild and guild ~= "" and guild ~= "NOT FRIENDLY" then
        local index
        for i, gn in ipairs(g.GuildList) do
            if gn == guild then index = i break end
        end
        if not index then
            table.insert(g.GuildList, guild)
            index = #g.GuildList
            DPrint("Added guild", guild, index)
        end
        if g.UnitGuild[name] ~= index then
            g.UnitGuild[name] = index
            DPrint("Cached guild", name, guild)
            mod:UpdateVisibleNameplate(name)
        end
    else
        -- Clear guild if player has no valid guild info
        if g.UnitGuild[name] then
            g.UnitGuild[name] = nil
            DPrint("Cleared guild", name)
            mod:UpdateVisibleNameplate(name)
        end
    end
end

local function CacheNPCTitle(unit)
    if not P.showNPC then return end
    if UnitIsPlayer(unit) then return end
    local name = GetUnitName(unit)
    if not name then return end
    EnsureTooltip()
    tooltip:ClearLines()
    tooltip:SetUnit(unit)
    local line2 = _G["KuiNP_TitleScanTooltipTextLeft2"]
    if not line2 then return end
    local text = line2:GetText()
    if not text or text == "" then return end
    if text:match(levelPattern) then return end
    local g = addon.db.global
    local index
    for i, t in ipairs(g.NPCList) do if t == text then index = i break end end
    if not index then
        table.insert(g.NPCList, text)
        index = #g.NPCList
    end
    if g.UnitNPCTitle[name] ~= index then
        g.UnitNPCTitle[name] = index
        mod:UpdateVisibleNameplate(name)
    end
end

local function CacheClass(unit)
    -- Always cache class info for player units. Display of the class icon
    -- is now handled exclusively by the NameOnly module, so we no longer
    -- gate caching behind a Titles option. This prevents missed icons when
    -- the user has disabled the (now redundant) Titles class icon toggle.
    if not UnitIsPlayer(unit) then return end
    local name = GetUnitName(unit)
    if not name then return end
    local _, class = UnitClass(unit)
    if not class then return end
    local g = addon.db.global
    -- Debug output
    DPrint("CacheClass", unit, name, class or 'nil')
    if g.UnitClass[name] ~= class then
        g.UnitClass[name] = class
    DPrint("Cached class", name, class)
        mod:UpdateVisibleNameplate(name)
    end
end

function mod:UpdateVisibleNameplate(name)
    DPrint("UpdateVisibleNameplate", name)
    for _, frame in pairs(addon.frameList) do
        if frame.kui and frame.kui.name then
            local currentName = frame.kui.name.text or frame.kui.name:GetText()
            if currentName == name then
                DPrint("Match frame", name)
                self:ApplyTitle(frame.kui)
                -- class icon now handled exclusively by NameOnly module
            end
        end
    end
end

local function SafeGetFrameName(f)
    if not f or not f.name then return end
    return f.name.text or f.name:GetText()
end

-- periodic refresh timer handle
local refreshTimer

local function GetAffiliationColour(f)
    -- Legacy function retained (titles now inherit name colour); no-op colour source
end

function mod:ApplyTitle(f)
    if not P or not P.enabled then return end
    if P.onlyNameOnly and not f.nameonly then
        if f.titleFS then f.titleFS:Hide() end
        return
    end
    local name = SafeGetFrameName(f)
    if not name then return end
    local global = addon.db.global
    -- ensure required global tables exist (defensive)
    global.GuildList = global.GuildList or {}
    global.UnitGuild = global.UnitGuild or {}
    global.NPCList = global.NPCList or {}
    global.UnitNPCTitle = global.UnitNPCTitle or {}
    local titleText
    
    -- Enhanced debug output
    DPrint("ApplyTitle", name, f.player, f.friend, f.enemy)
    
    -- Check for players (both friendly and enemy)
    if P.showGuild and (f.player or f.enemy) then
        local idx = global.UnitGuild[name]
        if idx then 
            local guildName = global.GuildList[idx]
            -- Filter out invalid guild names
            if guildName and guildName ~= "NOT FRIENDLY" and guildName ~= "" then
                titleText = guildName
                DPrint("Guild title", name, titleText)
            else
                DPrint("Invalid guild", name, guildName or 'nil')
                -- Clean up invalid entry
                global.UnitGuild[name] = nil
            end
        else
            DPrint("No guild cached", name)
            -- Debug cache contents
            local cacheSize = 0
            for k,v in pairs(global.UnitGuild) do 
                cacheSize = cacheSize + 1
                if cacheSize <= 5 then -- Show first 5 entries
                    DPrint("cache", k, global.GuildList[v] or 'nil')
                end
            end
            if cacheSize > 5 then
                DPrint("cache more", cacheSize-5)
            end
        end
    else
        if P.showGuild then
            DPrint("Skip guild (flags)", name)
        end
    end
    if (not titleText) and P.showNPC and not f.player and not f.enemy then
        local idx = global.UnitNPCTitle[name]
        if idx then titleText = global.NPCList[idx] end
    end
    if not titleText then
        if f.titleFS then f.titleFS:Hide() end
    DPrint("No title", name)
        return
    end
    if not f.titleFS then
        f.titleFS = SafeFontString(f, 'titleFS', { size = 'title' })
        DPrint("Create FS", name)
    end
    -- Reparent when name-only mode is active (overlay hidden) so the title remains visible.
    local desiredParent = (f.nameonly and f) or (f.overlay or f)
    if f.titleFS:GetParent() ~= desiredParent then
        f.titleFS:SetParent(desiredParent)
    end
    local fmt = separators[P.separator] or "%s"
    f.titleFS:SetText(fmt:format(titleText))
    -- Copy colour directly from the name text so titles always match name colour
    if f.name and f.name.GetTextColor then
        local r,g,b = f.name:GetTextColor()
        if r then f.titleFS:SetTextColor(r,g,b) end
    end
    -- In name-only mode name width can change; keep anchor consistent
    -- Re-apply point in case name fontstring was rebuilt
    f.titleFS:ClearAllPoints()
    local ox = P.offsetX or 0
    local oy = P.offsetY or -3
    if P.position == 'ABOVE' then
        f.titleFS:SetPoint('BOTTOM', f.name, 'TOP', ox, oy)
    else
        f.titleFS:SetPoint('TOP', f.name, 'BOTTOM', ox, oy)
    end
    f.titleFS:Show()
    DPrint("Show title", name, titleText)
end


-- Messages
function mod:PostShow(_, f) 
    self:ApplyTitle(f)
end
function mod:PostTarget(_, f) 
    self:ApplyTitle(f)
end
function mod:PostCreate(_, f) 
    self:ApplyTitle(f)
end
function mod:PostHide(_, f) 
    if f.titleFS then f.titleFS:Hide() end
end

function mod:UPDATE_MOUSEOVER_UNIT() 
    CacheGuild("mouseover")
    CacheNPCTitle("mouseover")
    CacheClass("mouseover")
    -- Force immediate refresh for mouseover unit
    local name = GetUnitName("mouseover")
    if name then
        self:UpdateVisibleNameplate(name)
    end
end

function mod:PLAYER_TARGET_CHANGED() 
    CacheGuild("target")
    CacheNPCTitle("target")
    CacheClass("target")
    -- Force immediate refresh for target
    local name = GetUnitName("target")
    if name then
        self:UpdateVisibleNameplate(name)
    end
end
function mod:PARTY_MEMBERS_CHANGED() BuildGroupCaches() end
function mod:RAID_ROSTER_UPDATE() BuildGroupCaches() end

-- Config change callbacks
-- We rely on root options; keep a simple listener pattern.
function mod:RefreshAllTitles()
    for _, frame in pairs(addon.frameList) do
        if frame.kui then 
            self:ApplyTitle(frame.kui)
            -- class icon now handled exclusively by NameOnly module
        end
    end
end

function mod:configChangedListener()
    P = self.db.profile
    addon:RegisterFontSize("title", P.fontSize)
    self:RefreshAllTitles()
end

function mod:GetOptions()
    return {
        enabled = {
            type = "toggle",
            name = "Enable titles",
            order = 0
        },
        debug = {
            type = 'toggle',
            name = 'Enable Debug',
            order = 5,
            get = function() return P and P.debug end,
            set = function(_,v) if P then P.debug = v end end
        },
        display = {
            type = "group",
            name = "Display",
            inline = true,
            order = 10,
            args = {
                showGuild = { type = "toggle", name = "Guild names", order = 1 },
                showNPC = { type = "toggle", name = "NPC subtitles", order = 2 },
                separator = { type = "select", name = "Separator", order = 3, values = { ANGLED = "<text>", NONE = "text", SPACE = " text", PAREN = "(text)", BRACK = "[text]", CURLY = "{text}" } },
                fontSize = { type = "range", name = "Font size", order = 4, min = 1, softMax = 30, step = 1, disabled = function() return addon.db.profile.fonts.options.onesize end }
                , onlyNameOnly = { type = 'toggle', name = 'Only in name-only', order = 5 }
            }
        },
        positioning = {
            type = 'group',
            name = 'Positioning',
            inline = true,
            order = 11,
            args = {
                position = { type = 'select', name = 'Anchor', order = 1, values = { BELOW = 'Below name', ABOVE = 'Above name' } },
                offsetX = { type = 'range', name = 'X Offset', order = 2, min = -100, max = 100, step = 1 },
                offsetY = { type = 'range', name = 'Y Offset', order = 3, min = -100, max = 100, step = 1 }
            }
        }
    }
end

function mod:OnInitialize()
    -- Ensure addon.db.global exists and has required tables
    if not addon.db.global.UnitClass then
        addon.db.global.UnitClass = {}
    end
    
    -- migrate old root profile.titles if exists
    local root = addon.db.profile.titles
    self.db = addon.db:RegisterNamespace(self.name, { profile = {
        enabled = root and root.enabled ~= nil and root.enabled or true,
        showGuild = root and root.showGuild ~= nil and root.showGuild or true,
        showNPC = root and root.showNPC ~= nil and root.showNPC or true,
        separator = root and root.separator or "ANGLED",
        fontSize = root and root.fontSize or 9,
        position = 'BELOW',
        offsetX = 0,
        offsetY = -3,
        onlyNameOnly = false,
        debug = false
    }})

    addon:InitModuleOptions(self)
    P = self.db.profile
    addon:RegisterFontSize("title", P.fontSize)
end

function mod:OnEnable()
    P = self.db.profile
    if not P.enabled then return end
    self:RegisterMessage("KuiNameplates_PostShow", "PostShow")
    self:RegisterMessage("KuiNameplates_PostTarget", "PostTarget")
    self:RegisterMessage("KuiNameplates_PostCreate", "PostCreate")
    self:RegisterMessage("KuiNameplates_PostHide", "PostHide")
    self:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
    self:RegisterEvent("PLAYER_TARGET_CHANGED")
    self:RegisterEvent("PARTY_MEMBERS_CHANGED")
    self:RegisterEvent("RAID_ROSTER_UPDATE")
    BuildGroupCaches()
    self:RefreshAllTitles()
    if refreshTimer then self:CancelTimer(refreshTimer) end
    refreshTimer = self:ScheduleRepeatingTimer(function() mod:RefreshAllTitles() end, 0.5)
end

function mod:OnDisable()
    self:UnregisterAllEvents()
    self:UnregisterAllMessages()
    if refreshTimer then self:CancelTimer(refreshTimer); refreshTimer = nil end
    for _, frame in pairs(addon.frameList) do
        if frame.kui then
            if frame.kui.titleFS then frame.kui.titleFS:Hide() end
            if frame.kui.classIcon then frame.kui.classIcon:Hide() end
        end
    end
end
