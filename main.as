bool showMainWindow = true;
bool initialised = false;

// current map info
uint currentRank = 0;
uint totalPlayers = 0;
uint personalBest = 0;
uint competitionId = 0;
uint challengeId = 0;
array<Json::Value> records;

uint requestsSent = 0;

void Main()
{
    NadeoServices::AddAudience("NadeoClubServices");
    while (!NadeoServices::IsAuthenticated("NadeoClubServices"))
    {
        yield();
    }
    print("Done");

    while (true)
    {
        if (MapIsLoaded())
        {
            if (!initialised)
            {
                currentRank = 0;
                requestsSent = 0;
                personalBest = 0;

                // TODO: Get actual correct competitionId from the map
                // Also need to check if current map is an actual TOTD
                competitionId = 8916;

                // Get qualifierId from the cup
                string competitionEndpoint = NadeoServices::BaseURLClub() + "/api/competitions/" + competitionId + "/rounds";
                auto competitionDetails = SendGetRequest(competitionEndpoint);
                challengeId = competitionDetails[0]["qualifierChallengeId"];

                // First record
                Json::Value record = GetChallengeLeaderboard(1, 0);
                // Store total amount of players
                totalPlayers = record["cardinal"];
                // Store first record
                array<Json::Value> recordList(totalPlayers);
                records = recordList;
                records[record["results"][0]["rank"]-1] = record["results"][0];

                // Middle record
                uint middleIndex = (totalPlayers - 1) / 2;
                record = GetChallengeLeaderboard(1, middleIndex);
                records[record["results"][0]["rank"]-1] = record["results"][0];

                initialised = true;
            }

            uint currentPB = GetCurrentMapPB();
            if (currentPB != personalBest)
            {
                personalBest = currentPB;
                currentRank = FindApproxPBRank(0, totalPlayers-1);

                for (uint i = 0; i < records.Length; i++)
                {
                    if (Json::Write(records[i]) != "null")
                    {
                        print(FormatRecord(records[i]));
                    }
                }

                print("Total requests: " + requestsSent);
            }
            else
            {
                yield();
            }
        } 
        else
        {
            yield();
        }
    }
}

uint FindApproxPBRank(uint left, uint right)
{
    while (left <= right)
    {
        // if there are 100 or less records between L and R
        if (left + 100 >= right)
        {
            // Get the remaining records in one request and do sequential search
            return FindExactPBRank(left, right);
        }

        // Calclulate middle index between L and R
        uint middle = (left + right) / 2;
        // if middle index has not been fetched already
        if (Json::Write(records[middle]) == "null")
        {
            // Fetch record at middle index and store it for future searches
            Json::Value middleRecord = GetChallengeLeaderboard(1, middle);
            records[middleRecord["results"][0]["rank"]-1] = middleRecord["results"][0];

            // TODO: Remove this, this is just a debug measure to ensure indices are correct
            if (middleRecord["results"][0]["rank"]-1 != middle)
            {
                print("ERROR!");
                return 0;
            }
        }
        // if PB is worse than score at middle index
        if (records[middle]["score"] < personalBest)
        {
            left = middle + 1;
        }
        // if PB is better than score at middle index
        else if (records[middle]["score"] > personalBest)
        {
            right = middle - 1;
        }
        // if PB is the same as score at middle index
        else
        {
            return middle + 1;
        }
    }
    return 0;
}

uint FindExactPBRank(uint left, uint right)
{
    if (left < right or left + 100 > right)
    {
        Json::Value recordRange = GetChallengeLeaderboard(right - left, left)["results"];
        for (uint i = 0; i < recordRange.Length; i++)
        {
            records[recordRange[i]["rank"]-1] = recordRange[i];
        }
        for (uint i = 0; i < recordRange.Length; i++)
        {
            if (recordRange[i]["score"] == personalBest)
            {
                return recordRange[i]["rank"];
            }
            else if (recordRange[i]["score"] < personalBest
                and recordRange[i+1]["score"] >= personalBest)
            {
                return recordRange[i+1]["rank"];
            }
        }
        // If no match return rank of last record in list
        return recordRange[recordRange.Length-1]["rank"];
    }
    return 0;
}

string FormatRecord(Json::Value record)
{
    return "Rank: " + Json::Write(record["rank"]) + "\t Time: " + Json::Write(record["score"]);
}

Json::Value GetChallengeLeaderboard(uint length, uint offset)
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
    requestsSent++;
    print("Total requests: " + requestsSent);

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
