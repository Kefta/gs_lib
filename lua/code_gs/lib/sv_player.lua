local PLAYER = FindMetaTable("Player")

function PLAYER:GetAmountVisible(vSrc)
	local vChest = self:BodyTarget(vSrc)
	local flChestZ = vChest[3]
	local vFeet = self:GetPos()
	local flPosX = vFeet[1]
	local flPosY = vFeet[2]
	local flPosZ = vFeet[3]
	local vMin, vMax = self:GetHull()
	local vHead = Vector(flPosX, flPosY, vMax[3] - vMin[3] + flPosZ)
	local vRightFacing = (vMax[2] - vMin[2]) / 2 * self:GetAngles():Right()
	local flFacingX = vRightFacing[1]
	local flFacingY = vRightFacing[2]
	local flFacingZ = vRightFacing[3]
	local vLeft = Vector(flPosX - flFacingX, flPosY - flFacingY, flChestZ)
	local vRight = Vector(flPosX + flFacingX, flPosY + flFacingY, flChestZ)
	
		// check chest
	return 0.4 * util.GetExplosionDamageAdjustment(vSrc, vChest, self)
		// check top of head
		+ 0.2 * util.GetExplosionDamageAdjustment(vSrc, vHead, self)
		// check feet
		+ 0.2 * util.GetExplosionDamageAdjustment(vSrc, vFeet, self)
		// check left "edge"
		+ 0.1 * util.GetExplosionDamageAdjustment(vSrc, vLeft, self)
		// check right "edge"
		+ 0.1 * util.GetExplosionDamageAdjustment(vSrc, vRight, self)
end
