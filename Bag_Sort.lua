--Copyright 2006 Ryan Hamshire
--This document may be redistributed as a whole, provided it is unaltered and this copyright notice is not removed.

--================

--GLOBAL VARIABLES

--================

--category constants
--number indicates sort priority (1 is highest)
BS_SOULBOUND   = 1
BS_REAGENT     = 2
BS_CONSUMABLE  = 3
BS_QUEST       = 4
BS_TRADE       = 5
BS_QUALITY     = 6
BS_COMMON      = 7
BS_TRASH       = 8

--bag group definitions
BS_bagGroups = {
	
	--ammo pouches
	{["keywords"] = {"ammo", "shot", "bandolier"}}, 
	
	--arrow quivers
	{["keywords"] = {"quiver", "lamina"}}, 

	--enchanting bags
	{["keywords"] = {"spellfire", "enchant"}}, 

	--soul gem bags (warlock)
    {["keywords"] = {"felcloth", "shadow", "soul"}}, 

	--herbalism bags
    {["keywords"] = {"cenarius", "herb"}}, 
    
	--mining bags
	{["keywords"] = {"mining"}}, 
	
	--engineering bags
    {["keywords"] = {"toolbox"}}, 

	--gem bags
	{["keywords"] = {"jewels", "gem"}},
	
	--all others
	["standard"] = {["keywords"] = {}}
	
	}
	
--grid of item data based on destination inventory location
BS_itemSwapGrid = {}
					
BS_sorting = false     --indicates bag rearrangement is in progress
BS_pauseRemaining = 0  --how much longer to wait before running the OnUpdate code again
BS_guildbank = nil

--order by which categories are placed into bags
--starting from the leftmost bag
BS_categoryOrder = {
    [1] = "soulbound",
    [2] = "reagent",
    [3] = "consumable",
    [4] = "quest",
    [5] = "trade", 
	[6] = "quality",
    [7] = "common",
    [8] = "trash" }
    
--========================

--INTERFACE EVENT HANDLERS

--========================

function BS_OnLoad()

	--register slash commands
	SlashCmdList["BSbagsort"] = BS_slashBagSortHandler
  	SLASH_BSbagsort1 = '/bagsort'

	SlashCmdList["BSbanksort"] = BS_slashBankSortHandler
  	SLASH_BSbanksort1 = '/banksort'

	SlashCmdList["GBSbanksort"] = BS_slashGuildBankSortHandler
	SLASH_GBSbanksort1 = '/guildbanksort'
	SLASH_GBSbanksort2 = '/guildsort'

	--initialize data
	BS_clearData()

end

function BS_OnEvent()

end

function BS_OnUpdate()

	--if true then return end

	if not BS_sorting then return end
	
	BS_pauseRemaining = BS_pauseRemaining - arg1
	
	if BS_pauseRemaining > 0 then return end

	local changesThisRound = false
	local blockedThisRound = false
	
	--for each bag in the grid
	for bagIndex in pairs(BS_itemSwapGrid) do
	
	    --for each slot in this bag
	    for slotIndex in pairs(BS_itemSwapGrid[bagIndex]) do
	    
			--(for readability)
			local destinationBag  = BS_itemSwapGrid[bagIndex][slotIndex].destinationBag
			local destinationSlot = BS_itemSwapGrid[bagIndex][slotIndex].destinationSlot

			--see if either item slot is currently locked
	        local _, _, locked1 = GetContainerItemInfoOverride(bagIndex, slotIndex, BS_guildbank)
	        local _, _, locked2 = GetContainerItemInfoOverride(destinationBag, destinationSlot, BS_guildbank)
	        
	        if locked1 or locked2 then
	        
	            blockedThisRound = true
	            
			--if item not already where it belongs, move it
			elseif bagIndex ~= destinationBag or slotIndex ~= destinationSlot then
			
				PickupContainerItemOverride(bagIndex, slotIndex, BS_guildbank)
				PickupContainerItemOverride(destinationBag, destinationSlot, BS_guildbank)
				
				local tempItem = BS_itemSwapGrid[destinationBag][destinationSlot]
				BS_itemSwapGrid[destinationBag][destinationSlot] = BS_itemSwapGrid[bagIndex][slotIndex]
				BS_itemSwapGrid[bagIndex][slotIndex] = tempItem

				changesThisRound = true
	        
	        end
	        
		end
		
	end
	
	if not changesThisRound and not blockedThisRound then
	
		BS_sorting = false
		BS_guildbank = nil
	    BS_clearData()

	end
	
	BS_pauseRemaining = .05

end

function BS_slashGuildBankSortHandler()
	local guildbankTabs = {}
	for i=1, GetNumGuildBankTabs() do
		table.insert(guildbankTabs, i)
	end

	sortBagRange(guildbankTabs, true)
end

function BS_slashBankSortHandler()

	sortBagRange({-1, 11, 10, 9, 8, 7, 6, 5})

end

function BS_slashBagSortHandler()

	sortBagRange({4, 3, 2, 1, 0})
	
end

function BS_slashBagSortHandler()

	sortBagRange({4, 3, 2, 1, 0})
	
end

function GetContainerItemInfoOverride(bagIndex, slotIndex, guildbank)
	if guildbank == nil then
		return GetContainerItemInfo(bagIndex, slotIndex)
	else
		return GetGuildBankItemInfo(bagIndex, slotIndex)
	end
end

function PickupContainerItemOverride(bagIndex, slotIndex, guildbank)
	if guildbank == nil then
		return PickupContainerItem(bagIndex, slotIndex)
	else
		return PickupGuildBankItem(bagIndex, slotIndex)
	end
end

function GetContainerNumSlotsOverride(bagIndex, guildbank)
	if guildbank == nil then
		return GetContainerNumSlots(bagIndex)
	else
		return 98 -- 98 slots in guild bank per tab, static.
	end
end

function GetBagNameOverride(bagIndex, guildbank)
	if guildbank == nil then
		return GetBagName(bagIndex)
	else
		return string.format("guildbank-%d", bagIndex)
	end
end

function GetContainerItemLinkOverride(bagIndex, slotIndex, guildbank)
	if guildbank == nil then
		return GetContainerItemLink(bagIndex, slotIndex)
	else
		return GetGuildBankItemLink(bagIndex, slotIndex)
	end
end

function sortBagRange(bagList, guildbank)

	--clear any data from previous sorts
	BS_clearData()

	--assign bags to bag groups
	for slotNumIndex, slotNum in pairs(bagList) do
	
		--if bag exists
		if GetContainerNumSlotsOverride(slotNum, guildbank) > 0 then
		
			--initialize the item grid for this bag (used later)
			BS_itemSwapGrid[slotNum] = {}

			local bagName

			--watch for special case for bank contents, which doesn't have a bag name
			if slotNum > -1 then

				bagName = string.lower(GetBagNameOverride(slotNum, guildbank))
				
			else
			
			    bagName = ""
			    
			end
			
			--for each bag group
			local assigned = false
			for groupKey, groupData in pairs(BS_bagGroups) do

				--for each keyword in the bag group definition
				for keywordKey, keywordData in pairs(groupData.keywords) do
				
					--if the keyword is a substring of the bag name
					if string.find(bagName, keywordData) then
					
						--assign it to the current group
						table.insert(groupData.bagSlotNumbers, slotNum)
						--say("assigned " .. bagName .. " to group with[" .. keywordData .. "]")
						assigned = true
						break
						
					end
					
				end
				
			end
				
			--if not assigned, assign it to the standard bag group
			if not assigned then
				
				table.insert(BS_bagGroups["standard"].bagSlotNumbers, slotNum)
				--say("assigned " .. bagName .. " to standard bag group")
					
			end

		end
		
	end
	
	--for each bag group
	for groupKey, group in pairs(BS_bagGroups) do
	
		--initialize the list of items for this bag group
		group.itemList = {}

		--for each bag in this group
		for bagKey, bagSlot in pairs(group.bagSlotNumbers) do
		
			--for each item slot in this bag
			for itemSlot=1, GetContainerNumSlotsOverride(bagSlot, guildbank) do
			
				--get a reference for the item in this location
				local itemLink = GetContainerItemLinkOverride(bagSlot, itemSlot, guildbank)
				
				--if this slot is non-empty
				if itemLink ~= nil then
				
					--collect important data about the item
					local newItem   = {}
					
					--initialize the sorting string for this item
					newItem.sortString = ""
					
					--use reference from above to request more detailed information
					local itemName, _, itemRarity, _, _, itemType, itemSubType, _, itemEquipLoc, _ = GetItemInfo(itemLink)
					newItem.name = itemName
					
					--determine category
					
					--soulbound items
                   	local tooltip = getglobal("BS_toolTip")
					local owner = getglobal("Bag_Sort_Core")
                    tooltip:SetOwner(owner, ANCHOR_NONE)
					tooltip:ClearLines()
					tooltip:SetBagItem(bagSlot, itemSlot)
					local tooltipLine2 = getglobal("BS_toolTipTextLeft2"):GetText()
					tooltip:Hide()
					
					if tooltipLine2 and tooltipLine2 == "Soulbound" then
						newItem.sortString = newItem.sortString .. BS_SOULBOUND
						
					--consumable items
					elseif itemType == "Consumable" then
						newItem.sortString = newItem.sortString .. BS_CONSUMABLE
				
					--reagents
					elseif itemType == "Reagent" then
						newItem.sortString = newItem.sortString .. BS_REAGENT
				
					--trade goods
					elseif itemType == "Trade Goods" then
						newItem.sortString = newItem.sortString .. BS_TRADE
					
					--quest items
					elseif itemType == "Quest" then
						newItem.sortString = newItem.sortString .. BS_QUEST
					
					--junk
					elseif itemRarity == 0 then
						newItem.sortString = newItem.sortString .. BS_TRASH
					
					--common quality
					elseif itemRarity == 1 then
						newItem.sortString = newItem.sortString .. BS_COMMON

					--higher quality
					else
						newItem.sortString = newItem.sortString .. BS_QUALITY
						
					end
					
					--finish the sort string, placing more important information
					--closer to the start of the string
					
					newItem.sortString = newItem.sortString .. itemType .. itemSubType .. itemEquipLoc .. itemName
					
					--add this item's accumulated data to the item list for this bag group
					tinsert(group.itemList, newItem)

					--record location
					BS_itemSwapGrid[bagSlot][itemSlot] = newItem
					newItem.startBag = bagSlot
					newItem.startSlot = itemSlot
					
				end
				
			end
			
		end
		
		--sort the item list for this bag group by sort strings
		table.sort(group.itemList, function(a, b) return a.sortString < b.sortString end)
		
		--show the results for this group
		--say(group.keywords[1])
		for index, item in pairs(group.itemList) do
		
			local gridSlot = index
		
   			--record items in a grid according to their intended final placement
			for bagSlotNumberIndex, bagSlotNumber in pairs(group.bagSlotNumbers) do
		
				if gridSlot <= GetContainerNumSlotsOverride(bagSlotNumber, guildbank) then
				
					BS_itemSwapGrid[item.startBag][item.startSlot].destinationBag  = bagSlotNumber
					BS_itemSwapGrid[item.startBag][item.startSlot].destinationSlot = gridSlot
					--say(BS_itemSwapGrid[item.startBag][item.startSlot].sortString .. bagSlotNumber .. ' ' .. gridSlot)
					break

				else
				
					gridSlot = gridSlot - GetContainerNumSlotsOverride(bagSlotNumber, guildbank)
					
				end
	
	        end
	
	    end
	
	end
	
	--signal for sorting to begin
	BS_sorting = true
	BS_guildbank = guildbank
	
end

--=================

--UTILITY FUNCTIONS

--=================

function BS_clearData()

 	BS_itemSwapGrid = {}
	for groupKey, groupData in pairs(BS_bagGroups) do

    	groupData.bagSlotNumbers = {}
    	groupData.itemList = {}

	end

end

function say(text)

  DEFAULT_CHAT_FRAME:AddMessage(text)

end