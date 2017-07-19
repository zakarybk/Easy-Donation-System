if !SERVER then return end

/*
	Structure -- network to client, private rank option
	Higher rank power gets everything below + more

	EDSCFG.Ranks = {
		"VIP" = { 1 },
		"Secret" = { 2, true }
	}
*/

// Send
util.AddNetworkString("EDSCFG.SendRank") 
util.AddNetworkString("EDSCFG.SendOthersRank")
util.AddNetworkString("EDSCFG.SendMenu")
util.AddNetworkString("EDSCFG.SendCleanup")
util.AddNetworkString("EDSCFG.SendAdminUpdate")

// Receive
util.AddNetworkString("EDSCFG.ReceiveEdit")
util.AddNetworkString("EDSCFG.ReceiveCreate")
util.AddNetworkString("EDSCFG.ReceiveDelete")
util.AddNetworkString("EDSCFG.ReceiveMenu")
util.AddNetworkString("EDSCFG.ReceiveAdd")
util.AddNetworkString("EDSCFG.ReceiveRemove")
util.AddNetworkString("EDSCFG.ReceiveInfo")
util.AddNetworkString("EDSCFG.ReceiveSync")

EDSCFG = EDSCFG or {}
local meta = FindMetaTable("Player")
EDSCFG.Ranks = {}
EDSCFG.Sync = {}
EDSCFG.META = {}
EDSCFG.Players = {}
EDSCFG.SendTable = {}
EDSCFG.RankPower = {}
EDSCFG.PrivateRank = {}
EDSCFG.SendTableCompressed = "[]"

// Load ranks
function EDSCFG.LoadRanks()
	if file.Exists("edscfg_ranks.txt", "DATA") then
		EDSCFG.Ranks = util.JSONToTable(file.Read("edscfg_ranks.txt", "DATA"))
	end
	for k, v in pairs(EDSCFG.Ranks) do
		if v[1] then
			EDSCFG.RankPower[k] = v[1]
		end
		if v[2] then
			EDSCFG.PrivateRank[k] = true
		end
	end
	if file.Exists("edscfg_sync.txt", "DATA") then
		EDSCFG.Sync = util.JSONToTable(file.Read("edscfg_sync.txt", "DATA"))
	end
	return true
end
EDSCFG.LoadRanks()

// Save ranks
function EDSCFG.SaveRanks()
	file.Write("edscfg_ranks.txt", util.TableToJSON(EDSCFG.Ranks))
	return true
end

// Save Sync
function EDSCFG.SaveSync()
	file.Write("edscfg_sync.txt", util.TableToJSON(EDSCFG.Sync))
	return true
end

// Get Admins
function EDSCFG.GetAdmins()
	local new = {}
	for k, v in ipairs(player.GetHumans()) do
		if EDSCFG.CanEdit(v) then
			table.insert(new, v)
		end
	end
	return new
end

// Edit rank
function EDSCFG.EditRank(admin, name, new_name, power, private)
	if name and isstring(name) and #name < EDSCFG.MaxNameLength and #name >= EDSCFG.MinNameLength then
		if power and isnumber(power) then
			power = math.Round(power)
			local old_power, old_private = EDSCFG.Ranks[name][1], EDSCFG.PrivateRank[name] or false
			// Easy update
			if name == new_name then
				if private then
					EDSCFG.Ranks[name] = {power, true}
					EDSCFG.PrivateRank[name] = true
//					print(EDSCFG.PrivateRank[name])
				else
					EDSCFG.Ranks[name] = {power}
				end
				EDSCFG.RankPower[name] = power
				EDSCFG.SaveRanks()
				hook.Call("EDSCFG.RankEdited", nil, admin, name, new_name, old_power, power, old_private, private or false)
				EDSCFG.UpdateAdmin(EDSCFG.Keys["EditRank"], {name, new_name, power, private == true and private or nil})
			else
				// Create new rank
				if private then
					EDSCFG.Ranks[new_name] = {power, true}
					EDSCFG.PrivateRank[new_name] = true
//					print(EDSCFG.PrivateRank[new_name])
				else
					EDSCFG.Ranks[new_name] = {power}
				end
				EDSCFG.RankPower[new_name] = power

				// Move all the offline players
				local tab = sql.Query( "SELECT infoid FROM playerpdata WHERE value = " .. SQLStr(name) )
				sql.Query( "UPDATE playerpdata SET value = " .. SQLStr(new_name) .. " WHERE value = " ..  SQLStr(name))

				// Move current players
				for k, v in ipairs(player.GetHumans()) do
					if EDSCFG.Players[v] == name then
						v:EDSCFG("SetPlayersRank", nil, new_name) 
					end
				end

				// Delete the old rank
				EDSCFG.Ranks[name] = nil
				EDSCFG.PrivateRank[name] = nil
				EDSCFG.RankPower[name] = nil

				// Save
				EDSCFG.SaveRanks()
				hook.Call("EDSCFG.RankEdited", nil, admin, name, new_name, old_power, power, old_private, private or false)
				EDSCFG.UpdateAdmin(EDSCFG.Keys["EditRank"], {name, new_name, power, private == true and private or nil})
			end
		else
			return false, "Power is not a number or is 0 or no number was input!"
		end
	else
		return false, "Name is either too long or is not a string!"
	end
	return true
end

// Create rank
function EDSCFG.CreateRank(admin, name, power, private)
	if name and isstring(name) and #name < EDSCFG.MaxNameLength and #name >= EDSCFG.MinNameLength then
		if power and isnumber(power) then
			power = math.Round(power)
//			print(private)
			if private then
				EDSCFG.Ranks[name] = {power, true}
				EDSCFG.PrivateRank[name] = true
//				print(EDSCFG.PrivateRank[name])
			else
				EDSCFG.Ranks[name] = {power}
			end
			EDSCFG.RankPower[name] = power
			EDSCFG.SaveRanks()
			hook.Call("EDSCFG.RankCreated", nil, admin, name, power, private)
			EDSCFG.UpdateAdmin(EDSCFG.Keys["EditRank"], {name, power, private == true and private or nil})
		else
			return false, "Power is not a number or is 0 or no number was input!"
		end
	else
		return false, "Name is either too long or is not a string!"
	end
	return true
end

// Turn entity to SteamID so we can send it to admins
function EDSCFG.IndexTable(t)
	if !istable(t) then return false, "Not a table!" end
	local new = {}
	local k, v

	for k, v in pairs(t) do
		if IsValid(k) then
			table.insert(new, {k:SteamID(), v})
		end
	end

	return new
end

// Update send table
function EDSCFG.UpdateSendTable(ply, rank, remove)
	if remove then
		EDSCFG.Players[ply] = nil
		if EDSCFG.PrivateRank[rank] == nil then
			EDSCFG.SendTable[ply:SteamID()] = nil
		end
		ply:EDSCFG("SendRank", remove, rank)
	else
		local old = EDSCFG.Players[ply] != nil and EDSCFG.Players[ply] or ""
		EDSCFG.Players[ply] = rank
		if EDSCFG.PrivateRank[rank] == nil then
			EDSCFG.SendTable[ply:SteamID()] = {rank, EDSCFG.RankPower[rank]}
			ply:EDSCFG("SendRank", remove, rank)
		elseif EDSCFG.PrivateRank[rank] and EDSCFG.PrivateRank[old] == nil then // If their old rank wasn't private, but their new one is, update players.
			ply:EDSCFG("SendRank", true, rank)
//			ply:ChatPrint("oi2")
			timer.Simple(0.01, function()
				net.Start("EDSCFG.SendRank")
					net.WriteString(ply:SteamID())
					net.WriteString(rank)
					net.WriteInt(EDSCFG.RankPower[rank], EDSCFG.IntPowerSize)
				net.Send(ply)
			end)
		end
	end
	local com = util.Compress(util.TableToJSON(EDSCFG.SendTable))
	EDSCFG.SendTableCompressed = #com > 2 and com or "[]"
	return true
end

// Update admins
function EDSCFG.UpdateAdmin(key, data)
	net.Start("EDSCFG.SendAdminUpdate")
		net.WriteInt(key, EDSCFG.KeySize)
		net.WriteTable(data)
	net.Send(EDSCFG.GetAdmins())
end

// Remove rank
function EDSCFG.DeleteRank(admin, name)
	if EDSCFG.Ranks[name] then
		local power, private = EDSCFG.RankPower[name], EDSCFG.PrivateRank[name]
		for k, v in ipairs(player.GetHumans()) do
			if EDSCFG.Players[v] == name or EDSCFG.Sync[v:GetUserGroup()] != nil and EDSCFG.Sync[v:GetUserGroup()] == name then
				EDSCFG.UpdateSendTable(v, "", true)
				EDSCFG.Players[v] = nil
			end
		end
		EDSCFG.Ranks[name] = nil
		EDSCFG.SaveRanks()
		for k, v in pairs(EDSCFG.Sync) do
			if v == name then
				EDSCFG.Sync[k] = nil
			end
		end
		EDSCFG.SaveSync()
		hook.Call("EDSCFG.RankDeleted", nil, admin, name, power, private)
		EDSCFG.UpdateAdmin(EDSCFG.Keys["EditRank"], {name})
	else
		return false, "Rank '" .. name .. "' doesn't exist!"
	end
	return true
end

// Set rank
function EDSCFG.SetPlayersRank(admin, self, steamid, rank)
	steamid = steamid or self:SteamID()
	if EDSCFG.Ranks[rank] == nil then return false, "Rank '" .. rank .. "' not found!" end
	util.SetPData(steamid, "EDSCFG.Ranks", rank)
	if self and IsValid(self) then
		EDSCFG.UpdateSendTable(self, rank, false)
		hook.Call("EDSCFG.RankSet", nil, admin, self, rank)
	else
		hook.Call("EDSCFG.RankSet", nil, admin, steamid, rank)
	end
	EDSCFG.UpdateAdmin(EDSCFG.Keys["PlayerRank"], {steamid, rank})
	return true
end

// Remove rank
function EDSCFG.RemovePlayersRank(admin, self, steamid)
//	print(admin, self, steamid)
	steamid = steamid or self:SteamID()
	local rank = EDSCFG.Players[self] or util.GetPData(steamid, "EDSCFG.Ranks", "unknown")
	if rank == "unknown" then return false, "Player had no rank" end
	if self and IsValid(self) then
		if EDSCFG.Sync[self:GetUserGroup()] == EDSCFG.Players[self] then
			return false, EDSCFG.Language["SyncFail"]
		end
		util.RemovePData(steamid, "EDSCFG.Ranks")
		EDSCFG.UpdateSendTable(self, "", true)
		hook.Call("EDSCFG.RankRemoved", nil, admin, self, rank)
		EDSCFG.Players[self] = nil
	else
		util.RemovePData(steamid, "EDSCFG.Ranks")
		hook.Call("EDSCFG.RankRemoved", nil, admin, steamid, rank)
	end
	EDSCFG.UpdateAdmin(EDSCFG.Keys["PlayerRank"], {steamid})
	return true
end

// Update Sync
function EDSCFG.UpdateSync(ply, old, new, source)
	local usergroup = ply:GetUserGroup()

	if EDSCFG.Sync[old] != nil and EDSCFG.Sync[new] != nil and EDSCFG.Sync[old] == EDSCFG.Sync[new] then return end

	if EDSCFG.Sync[new] then
		EDSCFG.UpdateSendTable(ply, EDSCFG.Sync[new], false)
	elseif EDSCFG.Sync[old] then
		EDSCFG.UpdateSendTable(ply, "", true)
	end
end
hook.Add("CAMI.PlayerUsergroupChanged", "EDSCFG.UpdateSync", EDSCFG.UpdateSync)

// Sync our ranks to admin ranks
function EDSCFG.EditSync(admin, admin_rank, rank, delete)
	if EDSCFG.Ranks[rank] == nil then return false, "Rank '" .. rank .. "' not found!" end
	if CAMI.GetUsergroup(admin_rank) == nil then return false, "Admin rank '" .. rank .. "' not found!" end

	if delete then
		local old = EDSCFG.Sync
		EDSCFG.Sync[admin_rank] = nil
		EDSCFG.SaveSync()

		for k, v in ipairs(player.GetHumans()) do
			if old[v:GetUserGroup()] != nil and old[v:GetUserGroup()] == rank then
				EDSCFG.UpdateSendTable(v, "", true)
			end
		end

		hook.Call("EDSCFG.SyncAdded", nil, admin, admin_rank, rank)
		EDSCFG.UpdateAdmin(EDSCFG.Keys["Sync"], {admin_rank, rank, delete})
	else
		EDSCFG.Sync[admin_rank] = rank
		EDSCFG.SaveSync()

		for k, v in ipairs(player.GetHumans()) do
			if EDSCFG.Sync[v:GetUserGroup()] != nil and EDSCFG.Sync[v:GetUserGroup()] == rank then
				EDSCFG.UpdateSendTable(v, rank, false)
			end
		end

		hook.Call("EDSCFG.SyncRemoved", nil, admin, admin_rank, rank)
		EDSCFG.UpdateAdmin(EDSCFG.Keys["Sync"], {admin_rank, rank, delete})
	end
	return true
end

/*---------------------------------------------------------------------------
Meta functions
---------------------------------------------------------------------------*/

// Set rank
function EDSCFG.META.SetPlayersRank(self, admin, rank) 
	local result, reason = EDSCFG.SetPlayersRank(admin, self, self:SteamID(), rank)
	if !result then
		if IsValid(admin) then
			admin:ChatPrint(reason)
		end
		return reason
	end
	return true
end

// Remove ran
function EDSCFG.META.RemovePlayersRank(self, admin, steamid)
	steamid = steamid or self:SteamID()
	local result, reason = EDSCFG.RemovePlayersRank(admin, self, steamid)
	if !result then
		if IsValid(admin) then
			admin:ChatPrint(reason)
		end
		return reason
	end
	return true
end

// Load rank
function EDSCFG.META.LoadPlayersRank(self) 
	local rank = util.GetPData(self:SteamID(), "EDSCFG.Ranks", false)
	if EDSCFG.Ranks[rank] == nil then
		rank = false
	end
	local sync_rank = EDSCFG.Sync[self:GetUserGroup()]
	if sync_rank then
		if rank then
			print(rank, ";", sync_rank)
			if EDSCFG.RankPower[sync_rank] > EDSCFG.RankPower[rank] then
				rank = sync_rank
			end
		else
			rank = sync_rank
		end
	end
	if !rank then return end
	if EDSCFG.Ranks[rank] == nil then return false, "Rank '" .. rank .. "' not found!" end
	EDSCFG.UpdateSendTable(self, rank, false)
	return true
end

// Has access
function EDSCFG.META.HasAccess(self, required_rank) 
	if EDSCFG.Players[self] == nil then return false end 
	if isnumber(required_rank) then
		if EDSCFG.Ranks[EDSCFG.Players[self]][1] < required_rank then return false end
	else
		if EDSCFG.Ranks[required_rank] == nil or EDSCFG.Ranks[EDSCFG.Players[self]][1] < EDSCFG.RankPower[required_rank] then return false end
	end
	return true
end

// Send rank
function EDSCFG.META.SendRank(self, remove, rank) 
	if EDSCFG.Players[self] == nil or EDSCFG.Ranks[rank] == nil then return false, "Player has no rank or rank doesn't exist" end
//	print(self:SteamID(), !remove and rank or "nil", EDSCFG.RankPower[rank])
	net.Start("EDSCFG.SendRank")
		net.WriteString(self:SteamID())
		net.WriteString(!remove and rank or "nil")
		net.WriteInt(EDSCFG.RankPower[rank], EDSCFG.IntPowerSize)
	net.Broadcast()
	return true
end

// Send other ranks
function EDSCFG.META.SendOthersRank(self) 
	net.Start("EDSCFG.SendOthersRank")
		net.WriteInt(#EDSCFG.SendTableCompressed, EDSCFG.IntDataCountSize)
		net.WriteData(EDSCFG.SendTableCompressed, #EDSCFG.SendTableCompressed)
	net.Send(self)
	return true
end

// Edit ran
function EDSCFG.META.EditRank(self, name, new_name, power, private)
	local result, reason = EDSCFG.EditRank(self, name, new_name, power, private)
	if !result then
		self:ChatPrint(reason)
		return false, reason
	end
	return true
end

// Create ran
function EDSCFG.META.CreateRank(self, name, power, private)
	local result, reason = EDSCFG.CreateRank(self, name, power, private)
	if !result then
		self:ChatPrint(reason)
		return false, reason
	end
	return true
end

// Remove rank
function EDSCFG.META.DeleteRank(self, name) 
	local result, reason = EDSCFG.DeleteRank(self, name)
	if !result then
		self:ChatPrint(reason)
		return false, reason
	end
	return true
end

// Run function, forgot that EDSCFG.whatever won't work as a meta method so switching to this
function meta:EDSCFG(func, ...)
	if EDSCFG.META[func] then
		return EDSCFG.META[func](self, ...)
	else
		return false, "Function not found!"
	end
end

/*---------------------------------------------------------------------------
Hooks
---------------------------------------------------------------------------*/

local function loadRankForPlayer(ply)
	if !IsValid(ply) then return end
	ply:EDSCFG("LoadPlayersRank")
	ply:EDSCFG("SendOthersRank")
	hook.Call("EDSCFG.PlayerLoaded", nil, ply, EDSCFG.Players[ply], EDSCFG.RankPower[EDSCFG.Players[ply]], EDSCFG.PrivateRank[EDSCFG.Players[ply]])
end
// Auto refresh
for k, v in ipairs(player.GetHumans()) do
	loadRankForPlayer(v)
end

hook.Add("PlayerInitialSpawn", "EDSCFG.InitialSpawn", function(ply)
	loadRankForPlayer(ply)
end)

hook.Add("PlayerDisconnected", "EDSCFG.Disconnected", function(ply)
	hook.Call("EDSCFG.PlayerLeft", nil, ply, EDSCFG.Players[ply], EDSCFG.RankPower[EDSCFG.Players[ply]], EDSCFG.PrivateRank[EDSCFG.Players[ply]])
	EDSCFG.UpdateSendTable(ply, "", true)
	EDSCFG.Players[ply] = nil
	net.Start("EDSCFG.SendCleanup")
	net.Broadcast()
end)

/*---------------------------------------------------------------------------
Net
---------------------------------------------------------------------------*/

net.Receive("EDSCFG.ReceiveEdit", function(len, ply)
	if !EDSCFG.CanEdit(ply) then ply:ChatPrint(EDSCFG.Language["NoAuthority"]) return false end

	ply:EDSCFG("EditRank", net.ReadString(), net.ReadString(), net.ReadInt(EDSCFG.IntPowerSize), net.ReadBool())
end)

net.Receive("EDSCFG.ReceiveCreate", function(len, ply)
	if !EDSCFG.CanEdit(ply) then ply:ChatPrint(EDSCFG.Language["NoAuthority"]) return false end

	ply:EDSCFG("CreateRank", net.ReadString(), net.ReadInt(EDSCFG.IntPowerSize), net.ReadBool())
end)

net.Receive("EDSCFG.ReceiveDelete", function(len, ply)
	if !EDSCFG.CanEdit(ply) then ply:ChatPrint(EDSCFG.Language["NoAuthority"]) return false end

	ply:EDSCFG("DeleteRank", net.ReadString())
end)

net.Receive("EDSCFG.ReceiveMenu", function(len, ply)
	if !EDSCFG.CanEdit(ply) then ply:ChatPrint(EDSCFG.Language["NoAuthority"]) return false end
	local indexed = EDSCFG.IndexTable(EDSCFG.Players)
//	print("po")
//	PrintTable(indexed)
	local data = util.Compress(util.TableToJSON({indexed, EDSCFG.Ranks, EDSCFG.Sync})) or util.Compress("[]")
	net.Start("EDSCFG.SendMenu")
		net.WriteInt(#data, EDSCFG.IntDataCountSize)
		net.WriteData(data, #data)
	net.Send(ply)
end)

net.Receive("EDSCFG.ReceiveAdd", function(len, ply)
	if !EDSCFG.CanEdit(ply) then ply:ChatPrint(EDSCFG.Language["NoAuthority"]) return false end

	local steamid = net.ReadString()
	local rank = net.ReadString()
	local target = player.GetBySteamID(steamid)

//	print(steamid, rank, target)
//	print("Private:", EDSCFG.PrivateRank[rank] or "false")

	if target then
		target:EDSCFG("SetPlayersRank", ply, rank) 
	else
		EDSCFG.SetPlayersRank(ply, false, steamid, rank)
	end
end)

net.Receive("EDSCFG.ReceiveRemove", function(len, ply)
	if !EDSCFG.CanEdit(ply) then ply:ChatPrint(EDSCFG.Language["NoAuthority"]) return false end
	
	local steamid = net.ReadString()
	local target = player.GetBySteamID(steamid)

	if target then
		target:EDSCFG("RemovePlayersRank", ply)
	else
		EDSCFG.RemovePlayersRank(ply, false, steamid)
	end
end)

net.Receive("EDSCFG.ReceiveInfo", function(len, ply)
	if !EDSCFG.CanEdit(ply) then ply:ChatPrint(EDSCFG.Language["NoAuthority"]) return false end

	local steamid = net.ReadString()
	local info = util.GetPData(steamid, "EDSCFG.Ranks", "unknown")

	if info == "unknown" then
		ply:ChatPrint("The player '" .. steamid .. "' has not been found in the database.")
	else
		ply:ChatPrint("The player '" .. steamid .. "' has been found in the database. Their rank is: " .. info)
	end
end)

net.Receive("EDSCFG.ReceiveSync", function(len, ply)
	if !EDSCFG.CanEdit(ply) then ply:ChatPrint(EDSCFG.Language["NoAuthority"]) return false end
	if CAMI == nil then ply:ChatPrint(EDSCFG.Language["CAMI"]) return false end

	local admin_rank = net.ReadString()
	local rank = net.ReadString()
	local delete = net.ReadBool()

	local delete, reason = EDSCFG.EditSync(ply, admin_rank, rank, delete)
	if !delete then
		ply:ChatPrint(reason)
	end
end)

/*---------------------------------------------------------------------------
Console commands
---------------------------------------------------------------------------*/

concommand.Add("eds_addid", function(ply, cmd, args, argStr)
	if !IsValid(ply) or EDSCFG.CanEdit(ply) then
		local id = args[1]
		local rank = args[2]
		EDSCFG.SetPlayersRank(nil, player.GetBySteamID(id), id, rank)
	else
		ply:ChatPrint(EDSCFG.Language["NoAuthority"])
	end
end)

concommand.Add("eds_removeid", function(ply, cmd, args, argStr)
	if !IsValid(ply) or EDSCFG.CanEdit(ply) then
		local id = args[1]
		EDSCFG.RemovePlayersRank(nil, player.GetBySteamID(id), id)
	else
		ply:ChatPrint(EDSCFG.Language["NoAuthority"])
	end
end)
