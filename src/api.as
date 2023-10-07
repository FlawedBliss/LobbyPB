namespace LobbyPBPlugin {
    const string recordUrl = "https://prod.trackmania.core.nadeo.online/mapRecords?";
    const string mapInfoUrl = "https://prod.trackmania.core.nadeo.online/maps/?";

    /* request pb for provided players on the given map */
    Net::HttpRequest@ MakeScoreRequest(const string mapId, const MwFastBuffer<CSmPlayer@> players) {
        if(mapId == "") {
            warn("No mapId provided for ScoreRequest");
            return null;
        }
        if(players.Length < 1) {
            return null;
        }
        if(!NadeoServices::IsAuthenticated("NadeoServices")) {
            warn("Not authenticated for ScoreRequest");
            return null;
        }
        array<string> playerIds;
        for(uint i = 0; i < players.Length; ++i) {
            playerIds.InsertLast(players[i].User.WebServicesUserId);
        }
        string url = recordUrl + "accountIdList=" + string::Join(playerIds, ",");
        url += "&mapIdList=" + mapId;
        return NadeoServices::Get("NadeoServices", url);
    }

    /* get map info to convert uid to map id */
    Net::HttpRequest@ MakeMapInfoRequest(const string mapUid) {
        if(mapUid == "") {
            warn("No mapUid provided for MapInfoRequest");
            return null;
        }
        string url = mapInfoUrl + "mapUidList=" + mapUid;
        return NadeoServices::Get("NadeoServices", url);
    }

    /* execute request and parse to json */
    Json::Value@ DoRequest(Net::HttpRequest@ req) {
		req.Start();
		while(!req.Finished()) {
			yield();
		}
		if(req.ResponseCode() != 200) {
			warn("Error on Request to " + req.Url + ": " + req.ResponseCode() + " => " + req.Error());
		}
		return Json::Parse(req.String());
	}
}