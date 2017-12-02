-- FIXME: Add GetTexture and GetMaterial?

local gs_lib_clearpixelbuffer = CreateConVar("gs_lib_clearpixelbuffer", "0", FCVAR_ARCHIVE, "Clears the pixel buffer before rendering starts, preventing tearing when looking at a leak")

hook.Add("PreRender", "gs_lib", function()
	if (gs_lib_clearpixelbuffer:GetBool()) then
		cam.Start2D()
			surface.SetDrawColor(0, 0, 0, 255)
			surface.DrawRect(0, 0, ScrW(), ScrH())
		cam.End2D()
	end
end)

function render.GetViewPortPosition()
	return 0, 0 -- FIXME
end

-- FIXME: Change next update
function render.GetRenderTargetDimensions()
	local texRT = render.GetRenderTarget()
	
	return texRT:Width(), texRT:Height()
end

function render.ViewDrawFade(col, pMaterial)
	pMaterial:AlphaModulate(col.a)
	pMaterial:ColorModulate(col)
	
	-- Attempt to set ignorez; not guarenteed to work
	local PrevIgnoreZ = pMaterial:GetInt("$ignorez")
	
	if (PrevIgnoreZ == nil or PrevIgnoreZ == 0) then
		pMaterial:SetInt("$ignorez", 1)
		pMaterial:Recompute()
		render.SetMaterial(pMaterial)
	end
	
	local flUOffset = 0.5 / pMaterial:GetMappingWidth()
	local flInvUOffset = 1 - flUOffset
	local flVOffset = 0.5 / pMaterial:GetMappingHeight()
	local flInvVOffset = 1 - flVOffset
	
	-- FIXME
	local iWidth, iHeight = render.GetRenderTargetDimensions()
	render.SetViewPort(0, 0, iWidth, iHeight)
	local x, y = render.GetViewPortPosition()
	
	// adjusted xys
	local x1 = x - 0.5
	local x2 = x + iWidth
	local y1 = y - 0.5
	local y2 = y + iHeight
	
	// adjust nominal uvs to reflect adjusted xys
	local u1 = math.FLerp(flUOffset, flInvUOffset, x, x2, x1)
	local u2 = math.FLerp(flUOffset, flInvUOffset, x, x2, x2)
	local v1 = math.FLerp(flVOffset, flInvVOffset, y, y2, y1)
	local v2 = math.FLerp(flVOffset, flInvVOffset, y, y2, y2)
	
	-- Use the dynamic mesh
	mesh.Begin(MATERIAL_QUADS, 1)
	
	-- Top left
	mesh.Position(Vector(x1, y1))
	mesh.TexCoord(0, u1, v1)
	mesh.AdvanceVertex()
	
	-- Top right
	mesh.Position(Vector(x2, y1))
	mesh.TexCoord(0, u2, v1)
	mesh.AdvanceVertex()
	
	-- Bottom right
	mesh.Position(Vector(x2, y2))
	mesh.TexCoord(0, u2, v2)
	mesh.AdvanceVertex()
	
	-- Bottom left
	mesh.Position(Vector(x1, y2))
	mesh.TexCoord(0, u1, v2)
	mesh.AdvanceVertex()
	
	mesh.End()
	
	if (PrevIgnoreZ == nil) then
		pMaterial:SetUndefined("$ignorez")
		pMaterial:Recompute()
		render.SetMaterial(pMaterial)
	elseif (PrevIgnoreZ == 0) then
		pMaterial:SetInt("$ignorez", PrevIgnoreZ)
		pMaterial:Recompute()
		render.SetMaterial(pMaterial)
	end
end

function render.DrawScreenSpaceRectangle(
	iDestX, iDestY, iWidth, iHeight,		// Rect to draw into in screen space
	flSrcTextureX0, flSrcTextureY0,			// which texel you want to appear at destx/y
	flSrcTextureX1, flSrcTextureY1,			// which texel you want to appear at destx+width-1, desty+height-1
	iSrcTextureWidth, iSrcTextureHeight,	// needed for fixup
	iXDice --[[= 1]], iYDice --[[= 1]])		// Amount to tessellate the ... -- I believe the correct answer is "quad." Some programmer went on a lunch break and couldn't finish the fucking comment
	
	if (iXDice == nil) then
		iXDice = 1
	end
	
	if (iYDice == nil) then
		iYDice = 1
	end
	
	render.DrawScreenQuad()
	
	local iScreenWidth, iScreenHeight = render.GetRenderTargetDimensions()
	
	// Get the current viewport size
	local iViewWidth = ScrW()
	local iViewHeight = ScrH()
	
	// map from screen pixel coords to -1..1
	local flLeftX = math.FLerp(-1, 1, 0, iViewWidth, iDestX - 0.5)
	local flRightX = math.FLerp(-1, 1, 0, iViewWidth, iDestX + iWidth - 0.5)
	local flTopY = math.FLerp(-1, 1, 0, iViewHeight, iDestY - 0.5)
	local flBottomY = math.FLerp(-1, 1, 0, iViewHeight, iDestY + iHeight - 0.5)
	
	local flTexelsPerPixelX = iWidth > 1 and 0.5 * ((flSrcTextureX1 - flSrcTextureX0) / (iWidth - 1)) or 0
	local flTexelsPerPixelY = iHeight > 1 and 0.5 * ((flSrcTextureY1 - flSrcTextureY0) / (iHeight - 1)) or 0
	
	local flOOTexWidth = 1 / iSrcTextureWidth
	local flOOTexHeight = 1 / iSrcTextureHeight
	
	local flLeftU = (flSrcTextureX0 + 0.5 - flTexelsPerPixelX) * flOOTexWidth
	local flRightU = (flSrcTextureX1 + 0.5 + flTexelsPerPixelX) * flOOTexWidth
	local flTopV = (flSrcTextureY0 + 0.5 - flTexelsPerPixelY) * flOOTexHeight
	local flBottomV = (flSrcTextureY1 + 0.5 + flTexelsPerPixelY) * flOOTexHeight
	
	mesh.Begin(MATERIAL_QUADS, iXDice * iYDice)
	
	// Dice the quad up...
	if (iXDice > 1 or iYDice > 1) then
		// Screen height and width of a subrect
		local flWidth = (flRightX - flLeftX) / iXDice
		local flHeight = (flTopY - flBottomY) / iYDice
		
		// UV height and width of a subrect
		local flUWidth = (flRightU - flLeftU) / iXDice
		local flVHeight = (flBottomV - flTopV) / iYDice
		
		for x = 1, iXDice do
			for y = 1, iYDice do
				local xprev = x-1
				local yprev = y-1
				
				// Top left
				mesh.Position(Vector(flLeftX + xprev * flWidth, flTopY - yprev * flHeight))
				mesh.Normal(vector_up)
				mesh.TexCoord(0, flLeftU + xprev * flUWidth, flTopV + yprev * flVHeight)
				mesh.TangentS(vector_left)
				mesh.TangentT(vector_forward)
				mesh.AdvanceVertex()
				
				// Top right (x+1)
				mesh.Position(Vector(flLeftX + x * flWidth, flTopY - yprev * flHeight))
				mesh.Normal(vector_up)
				mesh.TexCoord(0, flLeftU + x * flUWidth, flTopV + yprev * flVHeight)
				mesh.TangentS(vector_left)
				mesh.TangentT(vector_forward)
				mesh.AdvanceVertex()
				
				// Bottom right (x+1), (y+1)
				mesh.Position(Vector(flLeftX + x * flWidth, flTopY - y * flHeight))
				mesh.Normal(vector_up)
				mesh.TexCoord(0, flLeftU + x * flUWidth, flTopV + y * flVHeight)
				mesh.TangentS(vector_left)
				mesh.TangentT(vector_forward)
				mesh.AdvanceVertex()
				
				// Bottom left (y+1)
				mesh.Position(Vector(flLeftX + xprev * flWidth, flTopY - y * flHeight))
				mesh.Normal(vector_up)
				mesh.TexCoord(0, flLeftU + xprev * flUWidth, flTopV + y * flVHeight)
				mesh.TangentS(vector_left)
				mesh.TangentT(vector_forward)
				mesh.AdvanceVertex()
			end
		end
	else // just one quad
		-- Top left
		mesh.Position(Vector(flLeftX, flTopY))
		mesh.Normal(vector_up)
		mesh.TexCoord(0, flLeftU, flTopV)
		mesh.TangentS(vector_left)
		mesh.TangentT(vector_forward)
		mesh.AdvanceVertex()
		
		-- Top right
		mesh.Position(Vector(flRightX, flTopY))
		mesh.Normal(vector_up)
		mesh.TexCoord(0, flRightU, flTopV)
		mesh.TangentS(vector_left)
		mesh.TangentT(vector_forward)
		mesh.AdvanceVertex()
		
		-- Bottom left
		mesh.Position(Vector(flRightX, flBottomY))
		mesh.Normal(vector_up)
		mesh.TexCoord(0, flRightU, flBottomV)
		mesh.TangentS(vector_left)
		mesh.TangentT(vector_forward)
		mesh.AdvanceVertex()
		
		-- Bottom right
		mesh.Position(Vector(flLeftX, flBottomY))
		mesh.Normal(vector_up)
		mesh.TexCoord(0, flLeftU, flBottomV)
		mesh.TangentS(vector_left)
		mesh.TangentT(vector_forward)
		mesh.AdvanceVertex()
	end
	
	mesh.End()
end
