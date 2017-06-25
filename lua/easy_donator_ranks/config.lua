/*---------------------------------------------------------------------------
Config
---------------------------------------------------------------------------*/

EDSCFG = EDSCFG or {}
EDSCFG.MaxNameLength = 15										// Maximum number of characters you can have in the name of a donator's rank
EDSCFG.MinNameLength = 1										// Minimum number of characters you can have in the name of a donator's rank
EDSCFG.CanEdit = function(ply) return ply:IsSuperAdmin() end    // The function which returns true if the player should be able to use the menu
EDSCFG.IntDataCountSize = 16									// If you have a really big player base you might need to change this but it's unlikely
EDSCFG.IsDarkRP = engine.ActiveGamemode() == "darkrp" or false  // Change false (bool) to true if you are running a custom flavour of DarkRP
EDSCFG.ChatCommand = "!eds"										// What the player has to type into chat to open the menu

// Language
EDSCFG.Language = {}
EDSCFG.Language["NoAuthority"] = "You have no authority for this action!"
EDSCFG.Language["Rank"] = "Rank"
EDSCFG.Language["Ranks"] = "Ranks"
EDSCFG.Language["SelectRank"] = "Select a rank"
EDSCFG.Language["SelectUserGroup"] = "Select a user group"
EDSCFG.Language["Power"] = "Power"
EDSCFG.Language["Private"] = "Private"
EDSCFG.Language["Edit"] = "Edit"
EDSCFG.Language["EditRank"] = "Edit Rank"
EDSCFG.Language["Add"] = "Add"
EDSCFG.Language["Add ID"] = "Add ID"
EDSCFG.Language["Remove"] = "Remove"
EDSCFG.Language["Remove ID"] = "Remove ID"
EDSCFG.Language["Name"] = "Name"
EDSCFG.Language["Distance"] = "Distance"
EDSCFG.Language["Players"] = "Players"
EDSCFG.Language["Title"] = "Easy Donation System"
EDSCFG.Language["Create"] = "Create"
EDSCFG.Language["True"] = "True"
EDSCFG.Language["False"] = "False"
EDSCFG.Language["CreateRank"] = "Create a rank"
EDSCFG.Language["RemoveID"] = "Remove a SteamID from their rank"
EDSCFG.Language["AddID"] = "Add a SteamID to a rank"
EDSCFG.Language["Search"] = "Search"
EDSCFG.Language["SearchInfo"] = "Input a SteamID to see if it's in the database (control + v to paste)"
EDSCFG.Language["SteamID"] = "SteamID"
EDSCFG.Language["CopiedSteamID"] = "Copied SteamID to clipboard!"
EDSCFG.Language["FailedSteamID"] = "Failed to copy SteamID, maybe refresh?"
EDSCFG.Language["FailedProfile"] = "Failed to open profile, maybe refresh?"
EDSCFG.Language["Submit"] = "Submit"
EDSCFG.Language["Sync"] = "Sync"
EDSCFG.Language["CAMI"] = "CAMI not found!"
EDSCFG.Language["UserGroup"] = "UserGroup"
EDSCFG.Language["SyncFail"] = "Cannot remove player from synced rank!"
EDSCFG.Language["SyncRank"] = "Sync a rank to a user group"

/*---------------------------------------------------------------------------
Dev corner - SERVER

Hooks:
	EDSCFG.PlayerLoaded 	arguments(ply, rank, power, private) // ply (entity), rank (string), power (number), private (bool, true == private rank)
	EDSCFG.PlayerLeft 		arguments(ply, rank, power, private) // ply (entity), rank (string), power (number), private (bool, true == private rank)
	EDSCFG.RankCreated		arguments(admin, rank, power, private) // admin (entity), rank (string), power (number),  private (bool, true == private rank)
	EDSCFG.RankDeleted		arguments(admin, rank, power, private) // admin (entity), rank (string), power (number),  private (bool, true == private rank)
	EDSCFG.RankEdited		arguments(admin, rank, new_rank, power, new_power, private, new_private) // admin (entity), rank (string), new_rank (string), power (number),  new_power (number), private (bool), new_private (bool, true == private rank)
	EDSCFG.SyncAdded		arguments(admin, admin_rank, rank) // admin (entity), admin_rank (string), rank (string)
	EDSCFG.SyncRemoved		arguments(admin, admin_rank, rank) // admin (entity), admin_rank (string), rank (string)

	EDSCFG.RankSet			arguments(admin, ply or plysteamid, rank)	 // admin (entity), ply (entity) or plysteamid (string), rank (string)
	EDSCFG.RankRemoved		arguments(admin, ply or plysteamid, rank)	 // admin (entity), ply (entity) or plysteamid (string), rank (string)

Meta:
	EDSCFG("HasAccess", required_rank) // Pass through the name(string) or power(number) of the required rank. Compares the power of the rank to see if it's high enough.

	EDSCFG("SetPlayersRank", rank) // rank (string) Set the player's rank.
	EDSCFG("RemovePlayersRank") // Removes the player from their current rank.
	EDSCFG("LoadPlayersRank") // Load their rank from the database. This is currently ran on PlayerInitialSpawn.
	EDSCFG("CreateRank", name, power, private) // name (string), power (number), private (bool) Create a rank.
	EDSCFG("DeleteRank", name) // name (string) Delete a rank.

Console Commands:
	eds_addid "STEAMID" "RANK"	// Adds a user to a specified rank. Remember to wrap the steamid and rank in their own quotes.
	eds_removeid "STEAMID"		// Removes a user from all ranks. Remember to wrap the steamid in quotes.

Examples:
	1.
		hook.Add("EDSCFG.PlayerLoaded", "JoinMessage", function(ply, rank, power, private)
			if !private then
				PrintMessage(HUD_PRINTTALK, ply:Nick() .. " has joined the game. Their rank is: " .. rank .. "!")
			end
		end)
	2.
		concommand.Add("test1234", function(ply)
			if ply:IsSuperAdmin() then
				ply:EDSCFG("SetRank", "UberDonator")
			end
		end)

Dev corner - CLIENT

	META:
		EDSCFG("HasAccess", required_rank) // Pass through the power(number) of the required rank. Compares the power of the rank to see if it's high enough. This can be used in a shared file however the
											difference with the client version is that it can ONLY take a number otherwise the client would have to know about the private ranks.
		EDSCFG("GetDonatorRank") 		   // Returns the rank of the player unless they're using a private rank
											

---------------------------------------------------------------------------*/

/*---------------------------------------------------------------------------
Don't edit below this line
---------------------------------------------------------------------------*/

EDSCFG.Keys = {}
EDSCFG.Keys["EditRank"] = 1
EDSCFG.Keys["PlayerRank"] = 2
EDSCFG.Keys["Sync"] = 3
EDSCFG.KeySize = 10
EDSCFG.IntPowerSize = 10										