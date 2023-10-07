/* for making pretty colors */
array<vec3> GetColorGradient(const int steps, vec3 a, vec3 b) {
	array<vec3> result;
	for(float i = 0; i < steps; ++i) {
		float pct = i/(steps-1); 
		result.InsertLast(vec3(
			a.x + pct * (b.x - a.x),
			a.y + pct * (b.y - a.y),
			a.z + pct * (b.z - a.z)
		));
	}
	return result;
}

/* angelscript formatInt isnt working so here we go */
string ToHex(uint data) {
	string hex = "";
	do {
		hex = "0123456789abcdef".SubStr(data%16, 1)+hex;
		data /= 16;
	} while(data > 0);
	return hex;
}

/* convert 8-bit rgb to 4-bit hex value for TM color codes */
string RgbToHex3(vec3 rgb) {
	return ToHex(int(rgb.x/17))
		+ ToHex(int(rgb.y/17))
		+ ToHex(int(rgb.z/17));
}

/* apply a color gradient to a text, optionally with an offset on the gradient */
string GetTextGradient(const string text, array<vec3> gradient, int offset = 0) {
	string str = "";
	for(int i = 0; i < text.Length; i++) {
		string char = text.SubStr(i, 1);
		if(char == ' ') {
			 offset--;
		}
		uint idx = Math::Min(i+offset, gradient.Length-1);
		str += "\\$" + RgbToHex3(gradient[idx]) + char;
	}
	return str;
}

/* update the cached gradient and text values */
void UpdateGradient() {
	cache.Gradient = GetColorGradient(showDelta ? 19 : 13, vec3(0, 192, 208), vec3(112, 240, 208));
	cache.ColumnTitlePlayer = GetTextGradient("Player", cache.Gradient);
	cache.ColumnTitleRecord = GetTextGradient("Record", cache.Gradient, 7);
	if(showDelta)
		cache.ColumnTitleDelta = GetTextGradient("Delta", cache.Gradient, 14);
}

/* re-create the webid -> player name map for O(1) access to names during render() */
bool UpdatePlayerCache() {
	auto app = cast<CTrackMania>(GetApp());
	if(app.CurrentPlayground is null) return false;
	auto playground = cast<CSmArenaClient@>(app.CurrentPlayground);
	if(playground.Arena is null) return false;
	auto arena = cast<CSmArena>(playground.Arena);
	cache.PlayerMap.DeleteAll();
	for(uint i = 0; i < arena.Players.Length; i++) {
		LobbyPBPlugin::CachedPlayer p;
		p.WebId = arena.Players[i].User.WebServicesUserId;
		p.Name = arena.Players[i].User.Name;
		cache.PlayerMap[p.WebId] = p;
	}
	return true;
}

/* Get TeamNum for a player */
int GetPlayerTeamNum(const string id) {
	auto arena = cast<CSmArena@>(cast<CSmArenaClient@>(cast<CTrackMania@>(GetApp()).CurrentPlayground).Arena);
	if(arena is null || arena.Rules is null) return -1;
	for(uint i = 0; i < arena.Rules.Scores.Length; ++i) {
		if(arena.Rules.Scores[i].User.WebServicesUserId == id) {
			return arena.Rules.Scores[i].TeamNum;
		}
	}
	return -1;
}