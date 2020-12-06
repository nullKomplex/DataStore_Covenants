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
                SanctumFeatureUnlocked = false, -- Eg: Queen's Conservatory for Night Fae
                GardenData = {  -- as returned by C_ArdenwealdGardening.GetGardenData
                    active = 0,
                    ready = 0,
                    remainingSeconds = 0,
                },
                ConduitNodes = {
                    ['*'] = { -- array index as returned by C_AnimaDiversion.GetAnimaDiversionNodes
                        talentID = 0,
                        name = nil,
                        description = nil,
                        costs = {
                            currencyID = 0,
                            quantity = 0,
                        },
                        currencyID = 0,
                        icon = 0,
                        normalizedPosition = {
                            x = 0,
                            y = 0,
                        },
                        state = 0, -- Enum.AnimaDiversionNodeState, 0-4
                    }
                },
                ConduitReinforceProgress = 0,
                ConduitOriginPosition = { -- as returned by C_AnimaDiversion.GetOriginPosition
                    x = 0,
                    y = 0,
                },
                TalentUnlockWorldQuest = { -- Warcraft. Text. File. is this?
                    ['*'] = 0 -- key: talentID from ConduitNodes, value: worldQuestID as returned by C_Garrison.GetTalentUnlockWorldQuest
                },
                AnimaCurrency = { -- as returned by C_CurrencyInfo.GetCurrencyInfo(1813)
                    currencyID = 0,
                    maxDisplayable = 0,
                    count = 0,
                    icon = 0,
                },
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

    addon.ThisCharacter.lastUpdate = time()
end

local function ScanGarden()
    if addon.ThisCharacter.CovenantID == 3 then
        addon.ThisCharacter.SanctumFeatureUnlocked = C_ArdenwealdGardening.IsGardenAccessible()
        addon.ThisCharacter.GardenData = C_ArdenwealdGardening.GetGardenData()
    else
        wipe(addon.ThisCharacter.GardenData)
    end
end

local function ScanConduit()
    local nodes = C_AnimaDiversion.GetAnimaDiversionNodes()
    if nodes == nil then return end
    for i, node in pairs(nodes) do
        local x = node.normalizedPosition.x
        local y = node.normalizedPosition.y
        nodes[i].normalizedPosition = {["x"] = x, ["y"] = y} -- overwrite Vector2DMixin with just table containing the x,y
        
        addon.ThisCharacter.TalentUnlockWorldQuest[node.talentID] = C_Garrison.GetTalentUnlockWorldQuest(node.talentID)
    end
    
    addon.ThisCharacter.ConduitNodes = nodes
    addon.ThisCharacter.ConduitReinforceProgress = C_AnimaDiversion.GetReinforceProgress()
    
    local originPosition = C_AnimaDiversion.GetOriginPosition()
    local x = originPosition.x
    local y = originPosition.y
    addon.ThisCharacter.ConduitOriginPosition = {["x"] = x, ["y"] = y} -- overwrite Vector2DMixin with just x,y
    
    local currencyID, maxDisplayable = C_CovenantSanctumUI.GetAnimaInfo()
    local info = C_CurrencyInfo.GetCurrencyInfo(currencyID)
    addon.ThisCharacter.AnimaCurrency.currencyID = currencyID
    addon.ThisCharacter.AnimaCurrency.maxDisplayable = maxDisplayable
    addon.ThisCharacter.AnimaCurrency.count = info.quantity
    addon.ThisCharacter.AnimaCurrency.icon = info.iconFileID
end
	
-- *** Event Handlers ***
local function OnRenownChanged()
    ScanRenown()
end

local function OnEnterWorld(event, isInitial, isReload)
    ScanRenown()
    ScanCovenant()
    -- incorrect garden data is loaded during first PLAYER_ENTERING_WORLD
    if not isInitial then
        ScanGarden()
    end
end

local function OnCovenantChosen()
    ScanCovenant()
end

local function OnConduitOpened()
    ScanConduit()
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

local function _IsArdenwealdGardenAccessible(character)
    return (character.CovenantID == 3) and character.SanctumFeatureUnlocked
end

local function _GetArdenwealdGardenData(character)
    -- Update remaining seconds first
    local data = character.GardenData
    local lastUpdate = character.lastUpdate
    if data and type(data) == "table" then
        data.remainingSeconds = lastUpdate + data.remainingSeconds - time()
        if data.remainingSeconds < 0 then
            data.remainingSeconds = 0
        end
    end
    
    return data
end

local function _GetAnimaDiversionNodes(character)
    local nodes = character.ConduitNodes
    for i, node in pairs(nodes) do
        local x = node.normalizedPosition.x
        local y = node.normalizedPosition.y
        nodes[i].normalizedPosition = CreateVector2D(x, y)
    end
    
    return nodes
end

local function _GetReinforceProgress(character)
    return character.ConduitReinforceProgress
end

local function _GetAnimaDiversionOriginPosition(character)
    local originPosition = character.ConduitOriginPosition
    local x = originPosition.x
    local y = originPosition.y
    return CreateVector2D(x, y)
end

local function _GetTalentUnlockWorldQuest(character, talentID)
    return character.TalentUnlockWorldQuest[talentID]
end

local function _GetAnimaCurrencyInfo(character)
    return character.AnimaCurrency
end

-- ** Setup **

local PublicMethods = {
    GetRenownLevel = _GetRenownLevel,
    GetCovenantID = _GetCovenantID,
    GetActiveSoulbindID = _GetActiveSoulbindID,
    IsArdenwealdGardenAccessible = _IsArdenwealdGardenAccessible,
    GetArdenwealdGardenData = _GetArdenwealdGardenData,
    GetAnimaDiversionNodes = _GetAnimaDiversionNodes,
    GetReinforceProgress = _GetReinforceProgress,
    GetAnimaDiversionOriginPosition = _GetAnimaDiversionOriginPosition,
    GetTalentUnlockWorldQuest = _GetTalentUnlockWorldQuest,
    GetAnimaCurrencyInfo = _GetAnimaCurrencyInfo,
}

function addon:OnInitialize()
	addon.db = LibStub("AceDB-3.0"):New(addonName .. "DB", AddonDB_Defaults)

	DataStore:RegisterModule(addonName, addon, PublicMethods)
    DataStore:SetCharacterBasedMethod("GetRenownLevel")
    DataStore:SetCharacterBasedMethod("GetCovenantID")
    DataStore:SetCharacterBasedMethod("GetActiveSoulbindID")
    DataStore:SetCharacterBasedMethod("IsArdenwealdGardenAccessible")
    DataStore:SetCharacterBasedMethod("GetArdenwealdGardenData")
    DataStore:SetCharacterBasedMethod("GetAnimaDiversionNodes")
    DataStore:SetCharacterBasedMethod("GetReinforceProgress")
    DataStore:SetCharacterBasedMethod("GetAnimaDiversionOriginPosition")
    DataStore:SetCharacterBasedMethod("GetTalentUnlockWorldQuest")
    DataStore:SetCharacterBasedMethod("GetAnimaCurrencyInfo")
end

function addon:OnEnable()	
    addon:RegisterEvent("COVENANT_SANCTUM_RENOWN_LEVEL_CHANGED", OnRenownChanged)
    addon:RegisterEvent("PLAYER_ENTERING_WORLD", OnEnterWorld)
    addon:RegisterEvent("COVENANT_CHOSEN", OnCovenantChosen)
    addon:RegisterEvent("SOULBIND_ACTIVATED", OnCovenantChosen)
    addon:RegisterEvent("ANIMA_DIVERSION_OPEN", OnConduitOpened)
end

function addon:OnDisable()
    addon:UnregisterEvent("COVENANT_SANCTUM_RENOWN_LEVEL_CHANGED")
    addon:UnregisterEvent("PLAYER_ENTERING_WORLD")
    addon:UnregisterEvent("COVENANT_CHOSEN")
    addon:UnregisterEvent("SOULBIND_ACTIVATED")
    addon:UnregisterEvent("ANIMA_DIVERSION_OPEN")
end
