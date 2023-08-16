bool showMainWindow = true;

uint currentRank = 0;
uint totalPlayers = 0;

void Main()
{
    NadeoServices::AddAudience("NadeoClubServices");
    while (!NadeoServices::IsAuthenticated("NadeoClubServices"))
    {
        yield();
    }
    print("Done");

    if (MapIsLoaded())
    {
        uint competitionId = 8887;

        // Get qualifierId from the cup
        string competitionEndpoint = NadeoServices::BaseURLClub() + "/api/competitions/" + competitionId + "/rounds";
        auto competitionDetails = SendGetRequest(competitionEndpoint);
        uint challengeId = competitionDetails[0]["qualifierChallengeId"];

        // Get five spaced initial values (rank 1, rank <total> and three spaced equally between these)
        // E.g. 0, 200, 400, 600, 800 if there are 800 records
        uint length = 1;

        // First record
        Json::Value record = GetChallengeLeaderboard(challengeId, length, 0);
        // Store total amount of players
        totalPlayers = record["cardinal"];
        // Store first record
        array<Json::Value> records(totalPlayers);
        records[record["results"][0]["rank"]-1] = record["results"][0];

        // Last record
        record = GetChallengeLeaderboard(challengeId, length, totalPlayers-1);
        records[record["results"][0]["rank"]-1] = record["results"][0];

        // Middle record
        uint middleIndex = totalPlayers / 2;
        record = GetChallengeLeaderboard(challengeId, length, middleIndex);
        records[record["results"][0]["rank"]-1] = record["results"][0];

        // Lower middle record
        uint lowerMiddleIndex = middleIndex / 2;
        record = GetChallengeLeaderboard(challengeId, length, lowerMiddleIndex);
        records[record["results"][0]["rank"]-1] = record["results"][0];

        // Upper middle record
        uint upperMiddleIndex = middleIndex + lowerMiddleIndex;
        record = GetChallengeLeaderboard(challengeId, length, upperMiddleIndex);
        records[record["results"][0]["rank"]-1] = record["results"][0];

        for (uint i = 0; i < records.Length; i++)
        {
            if (Json::Write(records[i]) != "null")
            {
                print(FormatRecord(records[i]));
            }
        }
    }
}

string FormatRecord(Json::Value record)
{
    return "Rank: " + Json::Write(record["rank"]) + "\t Time: " + Json::Write(record["score"]);
}

Json::Value GetChallengeLeaderboard(uint challengeId, uint length, uint offset)
{
    string challengeURL = NadeoServices::BaseURLClub() + "/api/challenges/" + challengeId + "/leaderboard?length=" + length + "&offset=" + offset;
    return SendGetRequest(challengeURL);
}

void OnSettingsChanged() {}

void RenderMenu()
{
    if (UI::MenuItem("\\$0f0" + Icons::ListOl + " \\$z" + "COTD Qualifier Rank", "", showMainWindow))
    {
        showMainWindow = !showMainWindow;
    }
}

void RenderInterface()
{
    if (showMainWindow and MapIsLoaded())
    {
        RenderMainWindow();
    }
}

void RenderMainWindow()
{
    auto mapInfo = GetApp().RootMap.MapInfo;
    UI::SetNextWindowSize(300, 200);
    if (UI::Begin("COTD Qualifier Rank", showMainWindow, UI::WindowFlags::NoCollapse))
    {
        UI::BeginGroup();
            UI::BeginTable("header", 1, UI::TableFlags::SizingFixedFit);
                UI::TableNextRow();
                UI::TableNextColumn();
                UI::Text("\\$ddd" + StripFormatCodes(mapInfo.Name));
                UI::TableNextRow();
                UI::TableNextColumn();
                UI::Text("\\$888" + StripFormatCodes(mapInfo.AuthorNickName));
            UI::EndTable();
            UI::BeginTable("table", 2, UI::TableFlags::SizingFixedFit);
                UI::TableNextRow();
                UI::TableNextColumn();
                UI::Text("Current rank: ");
                UI::TableNextColumn();
                UI::Text(
                    (currentRank == 0 ? "--- " : currentRank + " ") + 
                    "/" + 
                    (totalPlayers == 0 ? " --- " : " " + totalPlayers)
                    );
                UI::TableNextRow();
                UI::TableNextColumn();
                UI::Text("Current PB: ");
                UI::TableNextColumn();
                UI::Text(Time::Format(GetCurrentMapPB(), true, false, false));
            UI::EndTable();
            if (UI::Button("Get rank"))
            {
                print("Error: Not implemented");
            }
        UI::EndGroup();
    }
    UI::End();
}

bool MapIsLoaded()
{
    return GetApp().RootMap !is null;
}

Json::Value SendGetRequest(const string &in endpoint)
{
    while (!NadeoServices::IsAuthenticated("NadeoClubServices"))
    {
        yield();
    }
    auto request = NadeoServices::Get("NadeoClubServices", endpoint);

    // Throttle request rate
    sleep(500);
    print("Sent request");

    request.Start();
    while (!request.Finished())
    {
        yield();
    }
    return Json::Parse(request.String());
}

uint GetCurrentMapPB()
{
    string mapID = GetApp().RootMap.EdChallengeId;
    auto records = GetApp().ReplayRecordInfos;
    for (uint i = 0; i < records.Length; i++)
    {
        auto record = records[i];
        if (record.MapUid == mapID)
        {
            return record.BestTime;
        }
    }
    return 0;
}
