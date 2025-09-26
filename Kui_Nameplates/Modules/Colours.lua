--[[
-- Kui_Nameplates - Colours module
-- Custom priority colouring of player name text based on relationship:
-- Priority: Party > Guild > Friendlist > Raid
-- Overrides ClassColours friendly name colouring when enabled.
-- Applies in both normal and name-only modes.
]]
local addon = LibStub("AceAddon-3.0"):GetAddon("KuiNameplates")
local mod = addon:NewModule("Colours", addon.Prototype, "AceEvent-3.0")
mod.uiName = "|cff55aaffColours|r"

local IsInRaid = IsInRaid
local UnitIsInMyGuild = UnitIsInMyGuild
local UnitInParty = UnitInParty or function(unit) return false end
local UnitInRaid = UnitInRaid or function(unit) return false end
local UnitName = UnitName
local GetNumPartyMembers = GetNumPartyMembers
local GetNumRaidMembers = GetNumRaidMembers
local GetGuildInfo = GetGuildInfo
local UnitIsFriend = UnitIsFriend

local FRIEND_CACHE = {}

local P

-- Decide category for a frame (player unit only)
local function GetCategory(f)
    if not f.player or not f.friend then return end
    -- We need a unit token; GUID mapping exists on frame when cached
    -- We'll iterate possible unit tokens: party/raid/target/mouseover
    -- Fast path: use stored guid comparisons via addon.guidToFrame name store if needed.
    -- Since the default frames don't give us direct party/raid tokens here reliably,
    -- we'll attempt name matching against party/raid rosters (acceptable for addon use).
    local name = f.name and (f.name.text or f.name:GetText())
    if not name or name == "" then return end

    -- Party (excluding the player)
    if UnitInParty("target") and UnitName("target") == name then return "party" end
    for i=1,(GetNumPartyMembers() or 0) do
        if UnitName("party"..i) == name then return "party" end
    end

    -- Guild
    if UnitIsInMyGuild and UnitIsInMyGuild("target") and UnitName("target") == name then
        return "guild"
    end
    -- name-only guild check fallback: we can’t enumerate whole guild; rely on seeing them targeted/moused-over
    if FRIEND_CACHE[name] and FRIEND_CACHE[name].guild then
        return "guild"
    end

    -- Friend list cache marker
    if FRIEND_CACHE[name] and FRIEND_CACHE[name].isFriend then
        return "friend"
    end

    -- Raid (lower priority than the above)
    if UnitInRaid("target") and UnitName("target") == name then return "raid" end
    for i=1,(GetNumRaidMembers() or 0) do
        if UnitName("raid"..i) == name then return "raid" end
    end
end

local CATEGORY_ORDER = { party = 1, guild = 2, friend = 3, raid = 4 }

local function ApplyColour(f)
    if not P or not P.enabled then return end
    if not f or not f.name or not f.player or not f.friend then return end

    local cat = GetCategory(f)
    if not cat then return end

    -- honour priority; we already resolved to one cat using priority search order
    local conf = P[cat]
    if conf and conf.enabled and conf.colour then
        local r,g,b = conf.colour[1], conf.colour[2], conf.colour[3]
        if r and g and b then
            f.name:SetTextColor(r,g,b)
            f.name.colours_overridden = true
        end
    end
end

function mod:PostShow(_, f)
    ApplyColour(f)
end
function mod:PostTarget(_, f)
    ApplyColour(f)
end
function mod:GUIDStored(_, f)
    -- capture guild & friend information when possible
    if not f or not f.guid or not f.player or not f.friend then return end
    local name = f.name and (f.name.text or f.name:GetText())
    if not name or name == "" then return end
    FRIEND_CACHE[name] = FRIEND_CACHE[name] or {}
    local gname = GetGuildInfo("target")
    if gname and UnitName("target") == name then
        FRIEND_CACHE[name].guild = true
    end
    -- Friend detection via UnitIsFriend with "player" when we have target
    if UnitIsFriend("player","target") and UnitName("target") == name then
        FRIEND_CACHE[name].isFriend = true
    end
end

function mod:PostHide(_, f)
    if f and f.name and f.name.colours_overridden then
        f.name:SetTextColor(1,1,1)
        f.name.colours_overridden = nil
    end
end

function mod:RefreshAll()
    for _, frame in pairs(addon.frameList) do
        if frame.kui then
            ApplyColour(frame.kui)
        end
    end
end

function mod:configChangedListener()
    P = self.db.profile
    self:RefreshAll()
end

function mod:GetOptions()
    return {
        enabled = { type = 'toggle', name = 'Enable custom colours', order = 0 },
        party = { type='group', name='Party', inline=true, order=10, args={
            enabled = { type='toggle', name='Enable', order=1 },
            colour = { type='color', name='Colour', order=2 },
        }},
        guild = { type='group', name='Guild', inline=true, order=20, args={
            enabled = { type='toggle', name='Enable', order=1 },
            colour = { type='color', name='Colour', order=2 },
        }},
        friend = { type='group', name='Friend list', inline=true, order=30, args={
            enabled = { type='toggle', name='Enable', order=1 },
            colour = { type='color', name='Colour', order=2 },
        }},
        raid = { type='group', name='Raid', inline=true, order=40, args={
            enabled = { type='toggle', name='Enable', order=1 },
            colour = { type='color', name='Colour', order=2 },
        }},
    }
end

function mod:OnInitialize()
    self.db = addon.db:RegisterNamespace(self.moduleName, { profile = {
        enabled = true,
        party = { enabled = true, colour = {0.55,0.8,1} }, -- light blue
        guild = { enabled = true, colour = {0.6,1,0.6} }, -- soft green
        friend = { enabled = true, colour = {1,0.82,0} }, -- friendly gold
        raid = { enabled = false, colour = {1,1,1} }, -- off by default
    }})
    addon:InitModuleOptions(self)
    P = self.db.profile
end

function mod:OnEnable()
    P = self.db.profile
    self:RegisterMessage('KuiNameplates_PostShow','PostShow')
    self:RegisterMessage('KuiNameplates_PostTarget','PostTarget')
    self:RegisterMessage('KuiNameplates_GUIDStored','GUIDStored')
    self:RegisterMessage('KuiNameplates_PostHide','PostHide')
    self:RefreshAll()
end

function mod:OnDisable()
    self:UnregisterAllMessages()
    for _, frame in pairs(addon.frameList) do
        if frame.kui and frame.kui.name and frame.kui.name.colours_overridden then
            frame.kui.name:SetTextColor(1,1,1)
            frame.kui.name.colours_overridden = nil
        end
    end
end
