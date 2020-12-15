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
                    currencyID = 1813,
                    maxDisplayable = 35000,
                    count = 0,
                    icon = 3528288,
                },
                ConduitCollection = { -- as returned by C_Soulbinds.GetConduitCollection
                    ['*'] = { -- conduitID
                        conduitRank = 0,
                        conduitItemLevel = 0,
                        conduitType = 0,
                        conduitSpecSetID = 0,
                        conduitSpecIDs = {},
                        conduitSpecName = nil,
                        covenantID = 0,
                        conduitItemID = 0,
                    }
                },
                InstalledConduits = {
                    ['*'] = 0 -- nodeID = conduitID
                },
                Torghast = {
                    ['*'] = { -- Texture Kit Name, as written in CustomGossipFrameBase
                        name = nil, -- Localised name as retrieved from C_GossipInfo.GetText()
                        nextReset = 0, -- from C_DateAndTime.GetSecondsUntilWeeklyReset(). Do NOT reset this at the weekly, use this to know if the availability is from a previous week.
                        levels = { -- all of this from C_GossipInfo.GetOptions()
                            ['*'] = { -- level number, remember to cast this from string to number 
                                status = 0, -- From Enum.GossipOptionStatus: 0 = Available, 1 = Unavailable, 2 = Locked, 3 = AlreadyComplete
                                rewards = {
                                    ['*'] = { -- indexed array
                                        id = 0,
                                        quantity = 0, -- includes rewards from lower layers
                                        rewardType = 0,
                                    }
                                },
                            }
                        },
                    }
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
end

local function ScanSoulbinds()
    for i = 0, 3 do
        local collectionData = C_Soulbinds.GetConduitCollection(i)
        for _, data in pairs(collectionData) do
            addon.ThisCharacter.ConduitCollection[data.conduitID] = data
        end
    end
    
    local data = C_Soulbinds.GetSoulbindData(C_Soulbinds.GetActiveSoulbindID())
    local tree = data.tree
    local nodes = tree.nodes
    for _, node in pairs(nodes) do
        local nodeID = node.ID
        local conduitID = node.conduitID
        addon.ThisCharacter.InstalledConduits[nodeID] = conduitID
    end
end

local function ScanTorghast(uiTextureKit)
    local torghast = addon.ThisCharacter.Torghast[uiTextureKit]
    torghast.name = C_GossipInfo.GetText()
    torghast.nextReset = C_DateAndTime.GetSecondsUntilWeeklyReset() + time()
    
    local options = C_GossipInfo.GetOptions()
    for i, option in pairs(options) do
        torghast.levels[tonumber(option.name)] = {
            ["status"] = option.status,
            ["rewards"] = option.rewards,
        }
    end
end

local function ScanAnima()
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
    ScanAnima()
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

local function OnSoulbindForgeOpened()
    ScanSoulbinds()
end

local function OnGossipShow(event, uiTextureKit)
    -- Update this list from CustomGossipFrameBase.lua, in function CustomGossipManagerMixin:OnLoad()
	local torghastTextureKits = {"skoldushall", "mortregar", "coldheartinterstitia", "fracturechambers", "soulforges", "theupperreaches", "twistingcorridors"}
    
    if not uiTextureKit then return end
    for _, name in pairs(torghastTextureKits) do
        if uiTextureKit == name then
            ScanTorghast(uiTextureKit)
        end
    end
end

local function OnCurrencyDisplayUpdate()
    ScanAnima()
end

-- ** Mixins **

-- Generic

local function _GetCovenantID(character)
    return character.CovenantID
end

-- Renown

local function _GetRenownLevel(character)
    return character.RenownLevel
end

-- Sanctum Features

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

-- Anima Diversion

local function _GetAnimaDiversionNodes(character)
    local nodes = character.ConduitNodes
    local replacementNodes = CopyTable(nodes)
    for i, node in pairs(nodes) do
        local x = node.normalizedPosition.x
        local y = node.normalizedPosition.y
        replacementNodes[i].normalizedPosition = CreateVector2D(x, y)
    end
    
    return replacementNodes
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

-- Soulbinds

local function _GetActiveSoulbindID(character)
    return character.ActiveSoulbindID
end

local function _GetConduitRankFromCollection(character, conduitID)
    return character.ConduitCollection[conduitID].conduitRank
end

local function _GetInstalledConduitID(character, nodeID)
    return character.InstalledConduits[nodeID]
end

-- Torghast

local function _GetTorghastData(character)
    return character.Torghast
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
    GetConduitRankFromCollection = _GetConduitRankFromCollection,
    GetInstalledConduitID = _GetInstalledConduitID,
    GetTorghastData = _GetTorghastData,
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
    DataStore:SetCharacterBasedMethod("GetConduitRankFromCollection")
    DataStore:SetCharacterBasedMethod("GetInstalledConduitID")
    DataStore:SetCharacterBasedMethod("GetTorghastData")
end

function addon:OnEnable()	
    addon:RegisterEvent("COVENANT_SANCTUM_RENOWN_LEVEL_CHANGED", OnRenownChanged)
    addon:RegisterEvent("PLAYER_ENTERING_WORLD", OnEnterWorld)
    addon:RegisterEvent("COVENANT_CHOSEN", OnCovenantChosen)
    addon:RegisterEvent("SOULBIND_ACTIVATED", OnCovenantChosen)
    addon:RegisterEvent("ANIMA_DIVERSION_OPEN", OnConduitOpened)
    addon:RegisterEvent("SOULBIND_FORGE_INTERACTION_STARTED", OnSoulbindForgeOpened)
    addon:RegisterEvent("GOSSIP_SHOW", OnGossipShow)
	addon:RegisterEvent("CURRENCY_DISPLAY_UPDATE", OnCurrencyDisplayUpdate)
end

function addon:OnDisable()
    addon:UnregisterEvent("COVENANT_SANCTUM_RENOWN_LEVEL_CHANGED")
    addon:UnregisterEvent("PLAYER_ENTERING_WORLD")
    addon:UnregisterEvent("COVENANT_CHOSEN")
    addon:UnregisterEvent("SOULBIND_ACTIVATED")
    addon:UnregisterEvent("ANIMA_DIVERSION_OPEN")
    addon:UnregisterEvent("SOULBIND_FORGE_INTERACTION_STARTED")
    addon:UnregisterEvent("GOSSIP_SHOW")
	addon:UnregisterEvent("CURRENCY_DISPLAY_UPDATE")    
end
