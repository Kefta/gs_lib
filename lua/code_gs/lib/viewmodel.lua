do return end

local PLAYER = FindMetaTable("Player")

local tViewModels = {}
local fGetViewModel = PLAYER.GetViewModel

function PLAYER:GetViewModel(iIndex --[[= 0]])
	if (iIndex == nil) then
		iIndex = 0
	end
	
	local tbl = tViewModels[self]
	
	if (tbl == nil) then
		tbl = {}
		tViewModels[self] = tbl
	end
	
	return tbl[iIndex] or fGetViewModel(self, iIndex)
end

function PLAYER:SetupViewModel(iIndex, Entity --[[= nil]])
	local tbl = tViewModels[self]
	
	if (tbl == nil) then
		tbl = {}
		tViewModels[self] = tbl
	end
	
	local pOldViewModel = tbl[iIndex] or fGetViewModel(self, iIndex)
	
	if (pOldViewModel:IsValid()) then
		if (Entity == pOldViewModel) then
			return pOldViewModel
		end
		
		pOldViewModel:Remove()
	end
	
	local pEntity = IsEntity(Entity) and Entity or ents.Create(Entity or "predicted_viewmodel")
	
	if (pEntity:IsValid()) then
		pEntity:SetViewModelIndex(iIndex)
	end
	
	tbl[iIndex] = pEntity
	
	return pEntity
end
