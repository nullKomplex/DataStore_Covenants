--[[	*** DataStore_Covenants ***
Author: Teelo
29 November 2020
--]]

if WOW_PROJECT_ID == WOW_PROJECT_CLASSIC then
    print("DataStore_Covenants does not support Classic WoW")
    return
end

if not DataStore then return end

local addonName = "DataStore_Covenants"
_G[addonName] = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0")
local addon = _G[addonName]

local THIS_ACCOUNT = "Default"

local AddonDB_Defaults = {
	global = {
		Characters = {
			['*'] = {				-- ["Account.Realm.Name"] 
				lastUpdate = nil,
                RenownLevel = 0,
                CovenantID = 0,
                ActiveSoulbindID = 0,
			}
		}
	}
}


-- *** Utility functions ***

-- *** Scanning functions ***
local function ScanRenown()
    addon.ThisCharacter.RenownLevel = C_CovenantSanctumUI.GetRenownLevel()
    addon.ThisCharacter.lastUpdate = time()
end

local function ScanCovenant()
    addon.ThisCharacter.CovenantID = C_Covenants.GetActiveCovenantID()
    addon.ThisCharacter.ActiveSoulbindID = C_Soulbinds.GetActiveSoulbindID()
end
	
-- *** Event Handlers ***
local function OnRenownChanged()
    ScanRenown()
end

local function OnEnterWorld()
    ScanRenown()
    ScanCovenant()
end

local function OnCovenantChosen()
    ScanCovenant()
end

-- ** Mixins **
local function _GetRenownLevel(character)
    return character.RenownLevel
end

local function _GetCovenantID(character)
    return character.CovenantID
end

local function _GetActiveSoulbindID(character)
    return character.ActiveSoulbindID
end

-- ** Setup **

local PublicMethods = {
    GetRenownLevel = _GetRenownLevel,
    GetCovenantID = _GetCovenantID,
    GetActiveSoulbindID = _GetActiveSoulbindID,
}

function addon:OnInitialize()
	addon.db = LibStub("AceDB-3.0"):New(addonName .. "DB", AddonDB_Defaults)

	DataStore:RegisterModule(addonName, addon, PublicMethods)
    DataStore:SetCharacterBasedMethod("GetRenownLevel")
    DataStore:SetCharacterBasedMethod("GetCovenantID")
    DataStore:SetCharacterBasedMethod("GetActiveSoulbindID")
end

function addon:OnEnable()	
    addon:RegisterEvent("COVENANT_SANCTUM_RENOWN_LEVEL_CHANGED", OnRenownChanged)
    addon:RegisterEvent("PLAYER_ENTERING_WORLD", OnEnterWorld)
    addon:RegisterEvent("COVENANT_CHOSEN", OnCovenantChosen)
    addon:RegisterEvent("SOULBIND_ACTIVATED", OnCovenantChosen)
end

function addon:OnDisable()
    addon:UnregisterEvent("COVENANT_SANCTUM_RENOWN_LEVEL_CHANGED")
    addon:UnregisterEvent("PLAYER_ENTERING_WORLD")
    addon:UnregisterEvent("COVENANT_CHOSEN")
    addon:UnregisterEvent("SOULBIND_ACTIVATED")
end
