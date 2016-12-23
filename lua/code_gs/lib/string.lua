local tValidSoundExtensions = {
	wav = true,
	mp3 = true,
	ogg = true,
	-- mid = false,
	-- flac = false
}

-- Since only three-letter sound extensions are valid
-- This function can get away with only checking the last three characters of the string
function string.IsSoundFile(str)
	return tValidSoundExtensions[string.sub(str, -3)] or false
end
