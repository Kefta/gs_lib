local ENTITY = FindMetaTable("Entity")

local tTypeNilFunction = {TYPE_NIL, TYPE_FUNCTION}

-- FIXME: Implement this on the client
local tMetaClasses = {}

-- Create can be a function or table
-- FIXME: Add meta support
function ents.RegisterWrapperClass(sName, sClass, tWrapper, fCreate --[[= nil]])
	gs.CheckType(sName, 1, TYPE_STRING)
	gs.CheckType(sClass, 2, TYPE_STRING)
	gs.CheckType(tWrapper, 3, TYPE_TABLE)
	
	local bCreate = gs.CheckTypes(fCreate, 4, tTypeNilFunction) == TYPE_FUNCTION
	
	tMetaClasses[sName:lower()] = {sClass, setmetatable(tWrapper, {__index = ENTITY}), bCreate, fCreate}
end

function ents.CreateWrapper(sName, ...)
	local tClass = tMetaClasses[sName:lower()]
	
	if (tClass == nil) then
		gs.ArgError(1, "class does not exist")
	end
	
	local pEntity = ents.Create(tClass[1])
	
	-- Vehicles can return false initially with IsValid
	-- FIXME: Check this
	if (pEntity ~= NULL) then
		ents.SetupInheritance(pEntity, nil, setmetatable(pEntity:GetTable(), {__index = tClass[2]}))
		
		if (tClass[3]) then
			tClass[4](pEntity, ...)
		end
	end
	
	return pEntity
end

do
	SF_SPRITE_ONCE = 0x0002
	local nDirtyFlags = bit.bor(EFL_DIRTY_SPATIAL_PARTITION, EFL_DIRTY_SURROUNDING_COLLISION_BOUNDS)
	
	ents.RegisterWrapperClass("env_sprite", "env_sprite", {
		SpriteInit = function(self, sMaterial, vOrigin)
			self:SetModelName(sMaterial)
			self:SetLocalPos(vOrigin)
			self:Spawn() -- FIXME, right?
		end,
		TurnOn = function(self)
			self:RemoveEffects(EF_NODRAW)
			
			if (bit.band(self:GetSpawnFlags(), SF_SPRITE_ONCE) ~= 0 or self:GetSaveValue("framerate") ~= 0 and self:GetSaveValue("m_flMaxFrame") > 1) then
				hook.Add("Think", self, self.AnimateThink)
				self:SetSaveValue("m_flLastTime", CurTime())
			end
			
			self:SetSaveValue("frame", 0) -- FIXME
		end,
		AnimateThink = function(self)
			local flCurTime = CurTime()
			self:Animate(self:GetSaveValue("framerate") * (flCurTime - self:GetSaveValue("m_flLastTime")))
			ents.SetNextThink(self, flCurTime)
			self:SetSaveValue("m_flLastTime", flCurTime)
		end,
		Animate = function(self, flFrames)
			flFrames = self:GetSaveValue("frame") + flFrames
			local flMaxFrame = self:GetSaveValue("m_flMaxFrame")
			
			if (flFrames > flMaxFrame) then
				if (SERVER and bit.band(self:GetSpawnFlags(), SF_SPRITE_ONCE) ~= 0) then
					self:TurnOff()
				elseif (flMaxFrame > 0) then
					flFrames = math.fmod(flFrames, flMaxFrame)
				end
			end
			
			self:SetSaveValue("frame", flFrames)
		end,
		TurnOff = function(self)
			self:AddEffects(EF_NODRAW)
			ents.SetNextThink(self, -1)
		end,
		SetTransparency = function(self, nRenderMode, col, nFX)
			self:SetRenderMode(nRenderMode)
			self:SetColor(Color(col.r, col.g, col.b))
			self:SetBrightness(col.a)
			self:SetRenderFX(nFX)
		end,
		SetBrightness = function(self, flBrightness, flDuration --[[= 0]])
			self:SetSaveValue("m_nBrightness", flBrightness)
			self:SetSaveValue("m_flBrightnessTime", flDuration or 0)
		end,
		SetScale = function(self, flScale, flTime --[[= 0]])
			self:SetSaveValue("m_flScaleTime", flTime or 0)
			self:SetSpriteScale(flScale)
		end,
		SetSpriteScale = function(self, flScale)
			if (flScale ~= self:GetSaveValue("scale")) then
				self:SetSaveValue("scale", flScale) //Take our current position as our new starting position
				// The surrounding box is based on sprite scale... it changes, box is dirty
				self:AddEFlags(nDirtyFlags)
				
				if (CLIENT) then
					self:MarkShadowAsDirty()
				end
			end
		end,
		FadeAndDie = function(self, flDuration)
			self:SetBrightness(0, flDuration)
			hook.Add("Think", self, self.AnimateUntilDead)
			self:SetSaveValue("m_flDieTime", CurTime() + flDuration)
		end,
		AnimateUntilDead = function(self)
			if (CurTime() > self:GetSaveValue("m_flDieTime")) then
				self:Remove()
			else
				self:AnimateThink()
				--SetNextThink(self, CurTime())
			end
		end,
		SetGlowProxySize = function(self, flSize)
			self:SetSaveValue("GlowProxySize", flSize)
		end
	},
	function(pEntity, sMaterial, vOrigin, bAnimate --[[= false]])
		pEntity:SpriteInit(sMaterial, vOrigin)
		pEntity:SetSolid(SOLID_NONE)
		pEntity:SetCollisionBounds(vector_origin, vector_origin)
		pEntity:SetMoveType(MOVETYPE_NONE)
		
		if (bAnimate) then
			pEntity:TurnOn()
		end
	end)
end

do
	local vDefaultMax = Vector(50, 50, 50)
	local vDefaultMin = -vDefaultMax
	
	ents.RegisterWrapperClass("env_particlesmokegrenade", "env_particlesmokegrenade", {
		FillVolume = function(self, vMin --[[= vDefaultMin]], vMax --[[= vDefaultMax]])
			self:SetSaveValue("m_CurrentStage", 1)
			self:SetCollisionBounds(vMin or vDefaultMin, vMax or vDefaultMax)
		end,
		SetFadeTime = function(self, flStartTime, flEndTime)
			self:SetSaveValue("m_FadeStartTime", flStartTime)
			self:SetSaveValue("m_FadeEndTime", flEndTime)
		end,
		// Fade start and end are relative to current time
		SetRelativeFadeTime = function(self, flStartTime, flEndTime)
			local flTime = CurTime() - self:GetSaveValue("m_flSpawnTime")
			
			self:SetSaveValue("m_FadeStartTime", flTime + flStartTime)
			self:SetSaveValue("m_FadeEndTime", flTime + flEndTime)
		end
	},
	function(pEntity)
		pEntity:SetSaveValue("m_flSpawnTime", CurTime())
	end)
end

