local WEAPON = FindMetaTable("Weapon")

function WEAPON:GetPrimaryAmmoName()
	return game.GetAmmoName(self:GetPrimaryAmmoType())
end

function WEAPON:GetSecondaryAmmoName()
	return game.GetAmmoName(self:GetSecondaryAmmoType())
end

-- FIXME
function WEAPON:GetDefaultClip1()
	return self:IsScripted() and self.Primary.DefaultClip or -1
end

function WEAPON:GetDefaultClip2()
	return self:IsScripted() and self.Secondary.DefaultClip -1
end

-- https://github.com/Facepunch/garrysmod-issues/issues/2543
function WEAPON:GetActivityBySequence(iIndex)
	local pOwner = self:GetOwner()
	
	if (pOwner:IsValid()) then
		local pViewModel = pOwner:GetViewModel(iIndex)
		
		if (pViewModel:IsValid()) then
			return pViewModel:GetSequenceActivity(pViewModel:GetSequence())
		end
	end
	
	return ACT_INVALID
end

-- https://github.com/Facepunch/garrysmod-requests/issues/703
function WEAPON:GetPrimaryAmmoCount()
	return 1
end

function WEAPON:GetSecondaryAmmoCount()
	return 1
end

--[[function WEAPON:HasAmmo()
	return self:HasPrimaryAmmo() or self:HasSecondaryAmmo()
end]]

function WEAPON:HasPrimaryAmmo()
	-- Melee/utility weapons always have ammo
	if (self:GetMaxClip1() == -1 and self:GetMaxClip2() == -1) then
		return true
	end
	
	// If I use a clip, and have some ammo in it, then I have ammo
	if (self:Clip1() ~= 0) then
		return true
	end
	
	// Otherwise, I have ammo if I have some in my ammo counts
	local pPlayer = self:GetOwner()
	
	if (pPlayer:IsValid()) then
		return pPlayer:GetAmmoCount(self:GetPrimaryAmmoType()) > 0
	end
	
	// No owner, so return how much primary ammo I have along with me
	if (self:GetPrimaryAmmoCount() > 0) then
		return true
	end
	
	return false 
end

function WEAPON:HasSecondaryAmmo()
	if (self:GetMaxClip2() == -1 and self:GetMaxClip1() == -1) then
		return true
	end
	
	if (self:Clip2() ~= 0) then
		return true
	end
	
	local pPlayer = self:GetOwner()
	
	if (pPlayer:IsValid()) then
		return pPlayer:GetAmmoCount(self:GetSecondaryAmmoType()) > 0
	end
	
	if (self:GetSecondaryAmmoCount() > 0) then
		return true
	end
	
	return false
end

function WEAPON:IsActiveWeapon()
	local pPlayer = self:GetOwner()
	
	return pPlayer:IsValid() and pPlayer:GetActiveWeapon() == self
end

function WEAPON:IsViewModelSequenceFinished(iIndex)
	local pPlayer = self:GetOwner()
	
	if (pPlayer:IsValid()) then
		local pViewModel = pPlayer:GetViewModel(iIndex)
		
		if (pViewModel:IsValid()) then
			if (pViewModel:GetSaveValue("m_bSequenceFinished")) then
				return true
			end
			
			local iActivity = self:GetActivityBySequence(iIndex)
			
			// These are not valid activities and always complete immediately
			return iActivity == ACT_INVALID or iActivity == ACT_RESET
		end
	end
	
	-- https://github.com/Facepunch/garrysmod-requests/issues/704
	return false
end
