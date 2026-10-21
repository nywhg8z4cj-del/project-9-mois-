--[[
	Format.luau
	===========
	Petites fonctions pour AFFICHER joliment les nombres et les durées.
	Exemple : 1500 → "1.5K", 2300000 → "2.3M"
]]

local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

-- Transforme un grand nombre en texte court : 12345 → "12.3K"
function Format.number(value: number): string
	value = math.floor(value)
	if math.abs(value) < 1000 then
		return tostring(value)
	end

	local index = 1
	local shortValue = value
	while math.abs(shortValue) >= 1000 and index < #SUFFIXES do
		shortValue /= 1000
		index += 1
	end

	-- Une décimale seulement si le nombre est petit (ex: 1.5K mais 150K)
	local text
	if math.abs(shortValue) < 100 then
		text = string.format("%.1f", math.floor(shortValue * 10) / 10)
		text = string.gsub(text, "%.0$", "") -- "2.0K" devient "2K"
	else
		text = tostring(math.floor(shortValue))
	end
	return text .. SUFFIXES[index]
end

-- Affiche un multiplicateur : 1.5 → "x1.5", 2 → "x2"
function Format.multiplier(value: number): string
	local text = string.format("%.2f", value)
	text = string.gsub(text, "0+$", "")
	text = string.gsub(text, "%.$", "")
	return "x" .. text
end

-- Transforme des secondes en texte : 75 → "1:15"
function Format.time(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

return Format
