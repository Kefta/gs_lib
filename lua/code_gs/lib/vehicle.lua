local VEHICLE = FindMetaTable("Vehicle")

function VEHICLE:IsOverturned()
	// Tweak this number to adjust what's considered "overturned"
	return vector_up:Dot(self:GetAngles():Up()) < 0
end
