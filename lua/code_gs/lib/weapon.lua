local WEAPON = FindMetaTable("Weapon")

-- https://github.com/Facepunch/garrysmod-issues/issues/2543
function WEAPON:GetActivityBySequence(iIndex)
	local pViewModel = self:GetOwner():GetViewModel(iIndex)
	
	return pViewModel == NULL and ACT_INVALID or pViewModel:GetSequenceActivity(pViewModel:GetSequence())
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
	
	if (pPlayer == NULL) then
		// No owner, so return how much primary ammo I have along with me
		if (self:GetPrimaryAmmoCount() > 0) then
			return true
		end
	elseif (pPlayer:GetAmmoCount(self:GetPrimaryAmmoType()) > 0) then
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
	
	if (pPlayer == NULL) then
		// No owner, so return how much secondary ammo I have along with me
		if (self:GetSecondaryAmmoCount() > 0) then
			return true
		end
	elseif (pPlayer:GetAmmoCount(self:GetSecondaryAmmoType()) > 0) then
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
	
	if (pPlayer == NULL) then
		return false
	end
	
	local vm = pPlayer:GetViewModel(iIndex)
	
	if (vm == NULL) then
		return false
	end
	
	local iActivity = self:GetActivityBySequence()
	
	// These are not valid activities and always complete immediately
	if (iActivity == ACT_RESET or iActivity == ACT_INVALID or vm:GetInternalVariable("m_bSequenceFinished")) then
		return true
	end
	
	-- https://github.com/Facepunch/garrysmod-requests/issues/704
	return false
end
