--!strict
-- Bundled fallback: verified Monstercat tracks, played when HttpEnabled is off, the API is unreachable
-- or the HTTP budget is spent. Regenerate from the Resona catalog; keep it small (~30).
local Types = require("./Types")

local seed: { Types.Track } = {
	{ id = 5409360995, title = "Shiawase", artist = "Dion Timmer", genre = "electronic", duration = 218 },
	{ id = 7023635858, title = "Vex", artist = "Bensley", genre = "electronic", duration = 235 },
	{ id = 5410080857, title = "Neon", artist = "F.O.O.L & Midranger", genre = "electronic", duration = 256 },
	{ id = 5410083549, title = "Let's Talk", artist = "Rogue", genre = "electronic", duration = 231 },
	{ id = 7023370016, title = "Beginnings", artist = "A.M.R", genre = "electronic", duration = 186 },
	{ id = 7023407320, title = "Sleep (Terry Da Libra Remix)", artist = "A.M.R", genre = "electronic", duration = 393 },
	{ id = 7023435987, title = "Portrait Of You", artist = "A.M.R", genre = "electronic", duration = 226 },
	{ id = 7023445033, title = "About U", artist = "Aiobahn & Vin", genre = "electronic", duration = 175 },
	{ id = 7023459476, title = "Closer", artist = "Anthony Nikita", genre = "electronic", duration = 368 },
	{ id = 7023598688, title = "Clarity", artist = "Bad Computer", genre = "electronic", duration = 201 },
	{ id = 7023617400, title = "Destroy Me", artist = "Bad Computer", genre = "electronic", duration = 240 },
	{ id = 7023650590, title = "Descender", artist = "Case & Point", genre = "electronic", duration = 252 },
	{ id = 7023670701, title = "Wish", artist = "CloudNone", genre = "electronic", duration = 212 },
	{ id = 7023680426, title = "All I Want", artist = "Conro", genre = "electronic", duration = 217 },
	{ id = 7023690024, title = "Labyrinth", artist = "Direct & Essenger", genre = "electronic", duration = 233 },
	{ id = 7023704173, title = "Imprints", artist = "djimboh", genre = "electronic", duration = 379 },
	{
		id = 7023720291,
		title = "You Used To",
		artist = "Duumu & I See Colors feat. Luma",
		genre = "electronic",
		duration = 201,
	},
	{ id = 7023733671, title = "Constellations", artist = "Elypsis", genre = "electronic", duration = 349 },
	{ id = 7023741506, title = "I Miss You", artist = "Elypsis", genre = "electronic", duration = 230 },
	{ id = 7023749823, title = "Mimi", artist = "Eskai", genre = "electronic", duration = 200 },
	{ id = 7023760529, title = "Enough", artist = "Glacier", genre = "electronic", duration = 235 },
	{ id = 7023771708, title = "Still", artist = "Glacier", genre = "electronic", duration = 208 },
	{ id = 7023785633, title = "The Way We Do", artist = "Glaue", genre = "electronic", duration = 176 },
	{ id = 7023800698, title = "Over It", artist = "Glaue", genre = "electronic", duration = 164 },
	{ id = 7023846047, title = "Can You Hear It", artist = "Grant Bowtie", genre = "electronic", duration = 238 },
	{ id = 7023861220, title = "Video Games", artist = "Half an Orange", genre = "electronic", duration = 190 },
	{ id = 7023887630, title = "Expedition", artist = "Hyper Potions & Nokae", genre = "electronic", duration = 286 },
	{
		id = 7024035759,
		title = "Get to Know You",
		artist = "Dexter King feat. Aviella",
		genre = "electronic",
		duration = 198,
	},
	{
		id = 7024101188,
		title = "Same Mistake",
		artist = "Fransis Derelle & Josh Rubin",
		genre = "electronic",
		duration = 216,
	},
	{ id = 7024109415, title = "Insight", artist = "Jay FM", genre = "electronic", duration = 201 },
}

return seed
