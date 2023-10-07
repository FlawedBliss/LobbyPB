[Setting hidden category="Display" name="Window Position"]
vec2 pos = vec2(0, 50);
[Setting category="Display" name="Freeze Position" description="Prevents you from moving the window"]
bool freezePosition = false;
[Setting category="Display" name="Toggle Mode" description="When enabled, the window will only be displayed when the display key (default: Tab) is held"]
bool toggleMode = true;
[Setting category="Display" name="Display Key"]
VirtualKey displayKey = VirtualKey(9);
[Setting category="Display" name="Number of Records" description="How many of the top records to show in the window."]
uint numRecords = 6;
[Setting category="Features" name="Show Delta" description="When enabled, shows how much slower everyone is compared to the fastest player"]
bool showDelta;
[Setting category="Features" name="Personal Delta" description="When enabled, other players timed will be compared to your own instead of the fastest player. Required Show Delta to be enabled."]
bool showDeltaPersonal;


const array<string> disabledGamemodes = {"TM_Royal_Online", "TM_RoyalTimeAttack_Online", "TM_RoyalValidationLocal"};
bool g_visible = false;
LobbyPBPlugin::Cache cache;

/* refresh the cache with player pbs */
bool UpdatePlayerTimes() {
	auto app = cast<CTrackMania>(GetApp());
	auto network = cast<CTrackManiaNetwork>(app.Network);
	auto playground = cast<CSmArenaClient@>(app.CurrentPlayground);
	auto arena = cast<CSmArena>(playground.Arena);
	if(app.Editor !is null || playground is null || playground.Map is null || network is null || network.ServerInfo is null) {
		return false;
	}
	string mapUid = playground.Map.MapInfo.MapUid;
	string mapId;
	//if the map hasn't changed since last update, no need to re-convert the id
	if (cache.LastMap.Uid != mapUid) {
		auto mapReq = LobbyPBPlugin::MakeMapInfoRequest(mapUid);
		if(mapReq is null) {
			return false;
		}
		auto mapResponse = LobbyPBPlugin::DoRequest(mapReq);
		mapId = mapResponse[0].Get("mapId");
		cache.LastMap.Id = mapId;
		cache.LastMap.Uid = mapUid;
	} else {
		mapId = cache.LastMap.Id;
	}

	auto scoreReq = LobbyPBPlugin::MakeScoreRequest(mapId, arena.Players);
	if(scoreReq is null) {
		return false;
	}
	auto response = LobbyPBPlugin::DoRequest(scoreReq);
	cache.PBs = array<LobbyPBPlugin::PB>();
	// noone in the lobby has a record on the map
	if(response.Length < 1) {
		return true;
	}
	auto localPlayer = cast<CGamePlayerInfo>(app.LocalPlayerInfo);
	
	@cache.OwnPB = null;
	for(uint i=0;i<response.Length;i++) {
		cache.PBs.InsertLast(LobbyPBPlugin::PB(response[i].Get("accountId"), response[i].Get("recordScore").Get("time")));
		if(response[i].Get("accountId") == localPlayer.WebServicesUserId)
			@cache.OwnPB = cache.PBs[cache.PBs.Length-1];
	}
	cache.PBs.SortAsc();
	UpdatePlayerCache();
	return true;
}

void Main() {
	if(!Permissions::ViewRecords()) {
		warn("You need at least standard access to use this plugin.");
		return;
	}
	NadeoServices::AddAudience("NadeoServices");
	UpdateGradient();
	auto app = cast<CTrackMania>(GetApp());
	cache.LastTime = Time::get_Stamp();

	while(true) {
		auto network = cast<CTrackManiaNetwork>(app.Network);
		if(disabledGamemodes.Find(cast<CTrackManiaNetworkServerInfo>(network.ServerInfo).CurGameModeStr) != -1) {
			sleep(2000);
			continue;
		};

		auto map = app.RootMap;

		// if the update fails too often, sleep until map changes
		if(cache.FailCount >= 3) {
			if(map !is null && map.MapInfo.MapUid != cache.LastMap.Uid) {
				cache.FailCount = 0;
			} else {
				sleep(2000);
				continue;
			}
		}
		
		auto@ playground = cast<CSmArenaClient@>(app.CurrentPlayground);
		if(map !is null && playground !is null && app.Editor is null) {
			// update player cache if needed
			// might not detect if the players change but count stays the same, but good enough
			if(cache.PlayerMap.GetKeys().Length != playground.Players.Length) {
				UpdatePlayerCache();
			}
			// if map changed or players changed, update the pb cache
			// also update once a minute
			if(map.MapInfo.MapUid != cache.LastMap.Uid || playground.Players.Length != cache.LastPlayerCount || (Time::get_Stamp() - cache.LastTime) > 60) {
				if(UpdatePlayerTimes()) {
					cache.LastPlayerCount = playground.Players.Length;
					cache.LastTime = Time::get_Stamp();
				} else {
					if(++cache.FailCount > 3) {
						warn("Too many failures, pausing plugin until next map");
					}
				}
			}
		} else {
			// not on a map, reset this so the pbs are updated should we load into the same map again
			cache.LastMap.Uid = "";
			cache.LastPlayerCount = 0;
		}
		// zzzz
		sleep(2000);
	}
}

void OnKeyPress(bool down, VirtualKey key) {
	if(key == displayKey) {
		g_visible = down;
	}
}

void OnSettingsChanged() {
	UpdateGradient();
}

void Render() {
	auto app = cast<CTrackMania>(GetApp());
	auto network = cast<CTrackManiaNetwork>(app.Network);
    auto serverInfo = cast<CTrackManiaNetworkServerInfo>(network.ServerInfo);
	if(disabledGamemodes.Find(cast<CTrackManiaNetworkServerInfo>(network.ServerInfo).CurGameModeStr) != -1) return;
	if(app.Editor !is null || app.CurrentPlayground is null || (toggleMode && !g_visible)) {
		return;
	}
	if(freezePosition) {
		UI::SetNextWindowPos(int(pos.x), int(pos.y), UI::Cond::Always);
	} else {
		UI::SetNextWindowPos(int(pos.x), int(pos.y), UI::Cond::FirstUseEver);
	}

	int flags = UI::WindowFlags::NoTitleBar | UI::WindowFlags::NoCollapse | UI::WindowFlags::NoDocking | UI::WindowFlags::AlwaysAutoResize;
	if(!UI::IsOverlayShown()) {
		flags |= UI::WindowFlags::NoInputs;
	}

	UI::Begin("LobbyPB", flags);
	pos = UI::GetWindowPos();
	UI::BeginGroup();
	if(UI::BeginTable("table", showDelta ? 4 : 3, UI::TableFlags::SizingFixedFit)) {
		// only used for team colors in ranked and update timer in header
		int timeleft = (60 - (Time::get_Stamp() - cache.LastTime));
		UI::TableSetupColumn(" " + (timeleft > 0 ? ""+timeleft : Icons::Refresh), UI::TableColumnFlags::None, 20.0f);
		// player names
		UI::TableSetupColumn(cache.ColumnTitlePlayer, UI::TableColumnFlags::WidthStretch);
		// times
		UI::TableSetupColumn(cache.ColumnTitleRecord, UI::TableColumnFlags::IndentEnable);
		if(showDelta) {
			// time diffs
			UI::TableSetupColumn(cache.ColumnTitleDelta, UI::TableColumnFlags::WidthStretch);
		}
		UI::TableHeadersRow();
		if(cache.PBs.Length == 0) {
			UI::TableNextRow();
			UI::TableNextColumn();
			UI::TableNextColumn();
			UI::Text("No Records");
		}
		for(uint i=0; i < cache.PBs.Length && i < numRecords; i++) {
			auto@ player = cast<LobbyPBPlugin::CachedPlayer@>(cache.PlayerMap[cache.PBs[i].PlayerId]);
			UI::TableNextRow();
			UI::TableNextColumn();
			// show team colors in ranked
			if(serverInfo.CurGameModeStr == "TM_Teams_Matchmaking_Online" && player !is null) {
				string color = "\\$37f";
				if (GetPlayerTeamNum(player.WebId) == 2) 
					color = "\\$e22";
				UI::Text(color + Icons::Circle);
			}
			UI::TableNextColumn();
			string name = "Unknown";
			if(player !is null) {
				name = player.Name;
			}
			UI::Text(name);
			UI::TableNextColumn();
			UI::Text(Time::Format(cache.PBs[i].Time));
			if(showDelta) {
				UI::TableNextColumn();
				int delta = 0;
				if(showDeltaPersonal && cache.OwnPB !is null) {
					delta = cache.PBs[i].Time - cache.OwnPB.Time;
				} else {
					delta = cache.PBs[i].Time - cache.PBs[0].Time;
				}
				
				string color = delta == 0 ? "\\$7ec+" : delta > 0 ? "\\$d00+" : "\\$0d0-";
				if(delta <= 0) {
					delta *= -1;
				}
				UI::Text(color + Time::Format(delta));
			}
		}
		UI::EndTable();
	}
	UI::EndGroup();
	UI::End();
}

