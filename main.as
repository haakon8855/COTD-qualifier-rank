/*
*   Haakon8855
*/

bool debug = true;

bool showMainWindow = true;
bool initialised = false;
uint maxRetries = 35;

string rankServerBaseURL = "localhost:5000"; // Still in development

// Info about the map currently loaded
Json::Value rankInfo;
uint personalBest = 0;
string mapUid = "";

void Main() {
    NadeoServices::AddAudience("NadeoLiveServices");
    while (!NadeoServices::IsAuthenticated("NadeoLiveServices")) {
        yield();
    }

    while (true) {
        if (MapIsLoaded()) {
            if (showMainWindow) {
                if (!initialised) {
                    if (!Initialise()) {
                        continue;
                    }
                }
                GetPBRank();
            } else {
                yield();
            }
        } else {
            Reset();
            yield();
        }
    }
}

bool Initialise() {
    // Check if current map is a TOTD
    mapUid = GetApp().RootMap.MapInfo.MapUid; 
    string mapInfoUrl = NadeoService::BaseURLLive() + "/api/campaign/map/" + mapUid;
    Json::Value mapInfo = SendGetRequestNadeo(mapInfoUrl);
    if (mapInfo !is null){
        if (mapInfo["totdYear"] != "-1") {
            // Map is a totd
            initialised = true;
            return true;
        }
    }
    initialised = false;
    return false;
}

void Reset() {
    initialised = false;

    mapUid = "";
    personalBest = 0;
    rankInfo = null;
}

void GetPBRank() {
    uint currentPB = GetCurrentMapPB();
    if (currentPB != personalBest) {
        personalBest = currentPB;
        rankInfo = GetRankInfo(mapUid, personalBest);
    } else {
        yield();
    }
}

string FormatRecord(Json::Value record) {
    return "Rank: " + Json::Write(record["rank"]) + "\t Time: " + Json::Write(record["score"]);
}

Json::Value GetRankInfo(string mapUid, uint personalBest) {
    string requestURL = rankServerBaseURL + "/api/rank/" + mapUid + "/" + personalBest;
    Net::HttpRequest response = SendGetRequest(requestURL);
    int responseCode = response.ResponseCode(); 

    // if response code is 503, the server is fetching the leaderboard and we need to wait
    uint retryCount = 0;
    while (responseCode == 503 and retryCount < maxRetries) {
        sleep(2000);
        response = SendGetRequest(requestURL);
        responseCode = response.ResponseCode(); 
        retryCount++;
    }

    return Json::Parse(response.String());
}

void RenderMenu() {
    if (UI::MenuItem("\\$0f0" + Icons::ListOl + " \\$z" + "COTD Qualifier Rank", "", showMainWindow)) {
        showMainWindow = !showMainWindow;
    }
}

void RenderInterface() {
    if (showMainWindow and MapIsLoaded()) {
        RenderMainWindow();
    }
}

void RenderMainWindow() {
    auto mapInfo = GetApp().RootMap.MapInfo;
    UI::SetNextWindowSize(180, 205);
    if (UI::Begin("COTD Qualifier Rank", showMainWindow, UI::WindowFlags::NoCollapse | UI::WindowFlags::NoTitleBar)) {
        UI::BeginGroup();
            UI::BeginTable("header", 1, UI::TableFlags::SizingFixedFit);
                UI::TableNextRow();
                UI::TableNextColumn();
                UI::Text("\\$ddd" + StripFormatCodes(mapInfo.Name));
                UI::TableNextRow();
                UI::TableNextColumn();
                UI::Text("\\$888" + StripFormatCodes(mapInfo.AuthorNickName));
                if (rankInfo !is null) {
                    UI::TableNextRow();
                    UI::TableNextColumn();
                    UI::Text("\\$888" + rankInfo["date"].asString().substr(0, 10));
                }
            UI::EndTable();
            UI::BeginTable("table", 2, UI::TableFlags::SizingFixedFit);
                UI::TableNextRow();
                UI::TableNextColumn();
                UI::Text("Current rank:");
                UI::TableNextColumn();
                UI::Text("\\$aaa" + 
                    (rankInfo is null ? "--- " : rankInfo.rank + " ") + 
                    "/" + 
                    (rankInfo is null ? " --- " : " " + rankInfo.playerCount)
                    );

                UI::TableNextRow();
                UI::TableNextColumn();
                UI::Text("Current PB:");
                UI::TableNextColumn();
                UI::Text("\\$aaa" + 
                    (personalBest == 0 ? "---" : Time::Format((personalBest), true, false, false))
                    );
            UI::EndTable();
        UI::EndGroup();
    }
    UI::End();
}

bool MapIsLoaded() {
    return GetApp().RootMap !is null;
}

Json::Value SendGetRequestNadeo(const string &in endpoint) {
    while (!NadeoServices::IsAuthenticated("NadeoLiveServices")) {
        yield();
    }
    auto request = NadeoServices::Get("NadeoLiveServices", endpoint);
    request.Start(); // Send request
    while (!request.Finished()) { // Wait for response
        yield();
    }
    return Json::Parse(request.String());
}

Net::HttpRequest SendGetRequest(const string &in endpoint) {
    auto request = Net::HttpGet(endpoint);
    request.Start(); // Send request
    while (!request.Finished()) { // Wait for response
        yield();
    }
    return request;
}

uint GetCurrentMapPB() {
    string mapID = GetApp().RootMap.EdChallengeId;
    auto records = GetApp().ReplayRecordInfos;
    for (uint i = 0; i < records.Length; i++) {
        auto record = records[i];
        if (record.MapUid == mapID) {
            return record.BestTime;
        }
    }
    return 0;
}
