local WEAPON = FindMetaTable("Weapon")

function WEAPON:SetDormant(bDormant)
	// If I'm going from active to dormant and I'm carried by another player, holster me.
	if (bDormant and not self:IsDormant() and not self:IsCarriedByLocalPlayer()) then
		self:Holster(NULL)
	end
	
	ENTITY.SetDormant(self, bDormant) -- Weapon metatable baseclass
end
