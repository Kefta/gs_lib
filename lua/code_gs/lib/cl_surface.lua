local tTextureType = {TYPE_STRING, TYPE_MATERIAL, TYPE_TEXTURE, TYPE_NUMBER}

-- Credits to thejjokerr: http://facepunch.com/showthread.php?t=1026117
-- Texture can be IMaterial, ITexture, or texture number returned by surface.GetTextureID
function surface.DrawPartialTexturedRect(x, y, iWidth, iHeight, iTexX, iTexY, iTexWidth, iTexHeight, Texture)
	gs.CheckType(x, 1, TYPE_NUMBER)
	gs.CheckType(y, 2, TYPE_NUMBER)
	gs.CheckType(iWidth, 3, TYPE_NUMBER)
	gs.CheckType(iHeight, 4, TYPE_NUMBER)
	gs.CheckType(iTexX, 5, TYPE_NUMBER)
	gs.CheckType(iTexY, 6, TYPE_NUMBER)
	gs.CheckType(iTexWidth, 7, TYPE_NUMBER)
	gs.CheckType(iTexHeight, 8, TYPE_NUMBER)
	local nType = gs.CheckTypes(Texture, 9, tTextureType)
	
	local iTexTotalWidth, iTexTotalHeight
	
	if (nType == TYPE_STRING) then
		local iTexID = surface.GetTextureID(Texture)
		surface.SetTexture(iTexID)
		iTexTotalWidth, iTexTotalHeight = surface.GetTextureSize(iTexID)
	elseif (nType == TYPE_MATERIAL) then
		surface.SetMaterial(Texture)
		iTexTotalWidth, iTexTotalHeight = Texture:GetMappingWidth(), Texture:GetMappingHeight()
	elseif (nType == TYPE_TEXTURE) then
		surface.SetTexture(surface.GetTextureID(Texture:GetName()))
		iTexTotalWidth, iTexTotalHeight = Texture:GetMappingWidth(), Texture:GetMappingHeight()
	else
		surface.SetTexture(Texture)
		iTexTotalWidth, iTexTotalHeight = surface.GetTextureSize(Texture)
	end
	
	-- Get the positions and sizes as percentages / 100
	local flPercentX = iTexX / iTexTotalWidth
	local flPercentY = iTexY / iTexTotalHeight
	local flPercentWidth = iTexWidth / iTexTotalWidth
	local flPercentHeight = iTexHeight / iTexTotalHeight
	
	surface.DrawPoly({
		{
			x = x,
			y = y,
			u = flPercentX,
			v = flPercentY
		},
		{
			x = x + iWidth,
			y = y,
			u = flPercentX + flPercentWidth,
			v = flPercentY
		},
		{
			x = x + iWidth,
			y = y + iHeight,
			u = flPercentX + flPercentWidth,
			v = flPercentY + flPercentHeight
		},
		{
			x = x,
			y = y + iHeight,
			u = flPercentX,
			v = flPercentY + flPercentHeight
		}
	})
end
