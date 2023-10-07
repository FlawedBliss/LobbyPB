namespace LobbyPBPlugin {
    class PB {
        string PlayerId;
        int Time;

        PB() {

        }

        PB(const string playerId, const int time) {
            this.PlayerId = playerId;
            this.Time = time;
        }

        int opCmp(PB@ other) {
            return this.Time - other.Time;
        }
    }

    class MapIds {
        string Uid;
        string Id;
        
        MapIds() {
        }
        
        MapIds(const string uid, const string id) {
            this.Uid = uid;
            this.Id = id;
        }

    }

    class CachedPlayer {
        string WebId;
        string Name;
    }

    class Cache {
        /* for fast player access in render() by their webid */
        dictionary PlayerMap;
        /* to avoid calculating the gradient on every render() */
	    array<vec3> Gradient;
        string ColumnTitlePlayer;
        string ColumnTitleRecord;
        string ColumnTitleDelta;

        /* to detect if an update is necessary on map/player change */
        MapIds LastMap;
        uint LastPlayerCount = 0;
        uint LastTime = Time::get_Stamp();

        /* to detect if our update is failing too much */
        int FailCount = 0;
        
        /* data and quick access to own PB without iterating in render()*/
        array<PB> PBs;
        PB@ OwnPB = null;
    }
}