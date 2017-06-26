if !CLIENT then return end

EDSCFG = EDSCFG or {}
EDSCFG.Players = {}
EDSCFG.META = {}
EDSCFG.UpdateQueue = {}
EDSCFG.Updates = {}
EDSCFG.Admin = {}
//EDSCFG.ReceivedBulk = false
local refresh = Material("icon16/arrow_refresh.png")
local meta = FindMetaTable("Player")

/*---------------------------------------------------------------------------
Meta
---------------------------------------------------------------------------*/

function EDSCFG.META.GetDonatorRank(self)
	return EDSCFG.Players[self:SteamID()] != nil and EDSCFG.Players[self:SteamID()][1] or false
end

function EDSCFG.META.HasAccess(self, required_rank) 
	if EDSCFG.Players[self:SteamID()] == nil then return false end 
	if isnumber(required_rank) then
		if EDSCFG.Players[self:SteamID()][2] < required_rank then return false end
	end
	return true
end

function meta:EDSCFG(func, ...)
	if EDSCFG.META[func] then
		return EDSCFG.META[func](self, ...)
	else
		return false, "Function not found!"
	end
end

/*---------------------------------------------------------------------------
Chat command
---------------------------------------------------------------------------*/

hook.Add( "OnPlayerChat", "EDSCFG.ChatCommand", function( ply, strText, bTeam, bDead )
	if ply != LocalPlayer() or string.lower(strText) != EDSCFG.ChatCommand then return end
	if !EDSCFG.CanEdit(LocalPlayer()) then LocalPlayer():ChatPrint(EDSCFG.Language["NoAuthority"]) return end
	net.Start("EDSCFG.ReceiveMenu")
	net.SendToServer()
	return true
end)

concommand.Add("eds_menu", function() 
	if !EDSCFG.CanEdit(LocalPlayer()) then LocalPlayer():ChatPrint(EDSCFG.Language["NoAuthority"]) return end
	net.Start("EDSCFG.ReceiveMenu")
	net.SendToServer()
end)

/*---------------------------------------------------------------------------
Derma
---------------------------------------------------------------------------*/

local function GetRank(steamid)
	for k, v in ipairs(EDSCFG.Admin[1]) do
		if v[1] == steamid then
			return v[2]
		end
	end
	return ""
end

local function AddSync()

	EDSCFG.Frame:SetVisible(false)

	local h = 1

	local Frame = vgui.Create( "DFrame" )
	Frame:SetTitle( EDSCFG.Language["SyncRank"] )
	Frame:SetSize( h*300, h*190 )
	Frame:Center()
	Frame:MakePopup()
	Frame.OnClose = function()
		EDSCFG.Frame:SetVisible(true)
	end

	// SteamID
	local DLabel = vgui.Create( "DLabel", Frame )
	DLabel:SetPos( h*25, h*35 )
	DLabel:SetSize( h*250, h*25 )
	DLabel:SetText( EDSCFG.Language["UserGroup"] )
	DLabel:SetBright(true)

	local Combo = vgui.Create( "DComboBox", Frame)
	Combo:SetPos( h*25, h*60 )
	Combo:SetSize( h*250, h*25 )
	Combo:SetValue( EDSCFG.Language["SelectUserGroup"] ) 
	for k, v in pairs(CAMI.GetUsergroups()) do
		Combo:AddChoice( k )
	end

	local DLabel = vgui.Create( "DLabel", Frame )
	DLabel:SetPos( h*25, h*85 )
	DLabel:SetSize( h*250, h*25 )
	DLabel:SetText( EDSCFG.Language["Rank"] )
	DLabel:SetBright(true)

	local ComboR = vgui.Create( "DComboBox", Frame)
	ComboR:SetPos( h*25, h*110 )
	ComboR:SetSize( h*250, h*25 )
	ComboR:SetValue( EDSCFG.Language["SelectRank"] ) 
	for k, v in pairs(EDSCFG.Admin[2]) do
		ComboR:AddChoice( k )
	end

	// Submit
	local DermaButton = vgui.Create( "DButton", Frame ) 
	DermaButton:SetText( EDSCFG.Language["Submit"] )				
	DermaButton:SetPos( h*25, h*145 )
	DermaButton:SetSize( h*250, h*25 )			
	DermaButton.DoClick = function()
		net.Start("EDSCFG.ReceiveSync")	
			net.WriteString(Combo:GetValue())
			net.WriteString(ComboR:GetValue())
			net.WriteBool(false)
		net.SendToServer()
		Frame:Close()
	end

end

local function AddID() 

	EDSCFG.Frame:SetVisible(false)

	local h = 1

	local Frame = vgui.Create( "DFrame" )
	Frame:SetTitle( EDSCFG.Language["AddID"] )
	Frame:SetSize( h*300, h*240 )
	Frame:Center()
	Frame:MakePopup()
	Frame.OnClose = function()
		EDSCFG.Frame:SetVisible(true)
	end

	// Search
	local DermaButton = vgui.Create( "DButton", Frame ) 
	DermaButton:SetText( EDSCFG.Language["Search"] )				
	DermaButton:SetPos( h*25, h*45 )
	DermaButton:SetSize( h*250, h*25 )			
	DermaButton.DoClick = function()
		Derma_StringRequest(
			EDSCFG.Language["Search"],
			EDSCFG.Language["SearchInfo"],
			"",
			function( text ) net.Start("EDSCFG.ReceiveInfo") net.WriteString(text) net.SendToServer() end,
			function( text ) end
		 )
	end

	// SteamID
	local DLabel = vgui.Create( "DLabel", Frame )
	DLabel:SetPos( h*25, h*70 )
	DLabel:SetSize( h*250, h*25 )
	DLabel:SetText( EDSCFG.Language["SteamID"] )
	DLabel:SetBright(true)

	local Text = vgui.Create( "DTextEntry", Frame )
	Text:SetPos( h*25, h*95 )
	Text:SetSize( h*250, h*25 )
	Text:SetText( "" )

	// Rank
	local Combo = vgui.Create( "DComboBox", Frame)
	Combo:SetPos( h*25, h*145 )
	Combo:SetSize( h*250, h*25 )
	Combo:SetValue( EDSCFG.Language["SelectRank"] ) 
	for k, v in pairs(EDSCFG.Admin[2]) do
		Combo:AddChoice( k )
	end

	// Submit
	local DermaButton = vgui.Create( "DButton", Frame ) 
	DermaButton:SetText( EDSCFG.Language["Submit"] )				
	DermaButton:SetPos( h*25, h*195 )
	DermaButton:SetSize( h*250, h*25 )			
	DermaButton.DoClick = function()
		net.Start("EDSCFG.ReceiveAdd")	
			net.WriteString(Text:GetValue())
			net.WriteString(Combo:GetValue())
		net.SendToServer()
		Frame:Close()
	end

end

local function RemoveID()

	EDSCFG.Frame:SetVisible(false)

	local h = 1

	local Frame = vgui.Create( "DFrame" )
	Frame:SetTitle( EDSCFG.Language["RemoveID"] )
	Frame:SetSize( h*300, h*190 )
	Frame:Center()
	Frame:MakePopup()
	Frame.OnClose = function()
		EDSCFG.Frame:SetVisible(true)
	end

	// Search
	local DermaButton = vgui.Create( "DButton", Frame ) 
	DermaButton:SetText( EDSCFG.Language["Search"] )				
	DermaButton:SetPos( h*25, h*45 )
	DermaButton:SetSize( h*250, h*25 )			
	DermaButton.DoClick = function()
		Derma_StringRequest(
			EDSCFG.Language["Search"],
			EDSCFG.Language["SearchInfo"],
			"",
			function( text ) net.Start("EDSCFG.ReceiveInfo") net.WriteString(text) net.SendToServer() end,
			function( text ) end
		 )
	end

	// SteamID
	local DLabel = vgui.Create( "DLabel", Frame )
	DLabel:SetPos( h*25, h*70 )
	DLabel:SetSize( h*250, h*25 )
	DLabel:SetText( EDSCFG.Language["SteamID"] )
	DLabel:SetBright(true)

	local Text = vgui.Create( "DTextEntry", Frame )
	Text:SetPos( h*25, h*95 )
	Text:SetSize( h*250, h*25 )
	Text:SetText( "" )

	// Submit
	local DermaButton = vgui.Create( "DButton", Frame ) 
	DermaButton:SetText( EDSCFG.Language["Submit"] )				
	DermaButton:SetPos( h*25, h*145 )
	DermaButton:SetSize( h*250, h*25 )			
	DermaButton.DoClick = function()
		net.Start("EDSCFG.ReceiveRemove")	
			net.WriteString(Text:GetValue())
		net.SendToServer()
		Frame:Close()
	end

end

local function EditRank(rank)

	EDSCFG.Frame:SetVisible(false)

	local h = 1
	local bools = {}
	bools[EDSCFG.Language["True"]] = true
	bools[EDSCFG.Language["False"]] = false

	local rank_name, rank_power, rank_private = rank, 1, EDSCFG.Language["False"]

	if EDSCFG.Admin[2] != nil and EDSCFG.Admin[2][rank] != nil then
		rank_power = EDSCFG.Admin[2][rank][1]
		rank_private = EDSCFG.Admin[2][rank][2] != nil and tostring(EDSCFG.Admin[2][rank][2] == "true") and EDSCFG.Language["True"] or EDSCFG.Language["False"]
	end

	local Frame = vgui.Create( "DFrame" )
	Frame:SetTitle( EDSCFG.Language["EditRank"] .. " '" .. rank .. "'" )
	Frame:SetSize( h*300, h*240 )
	Frame:Center()
	Frame:MakePopup()
	Frame.OnClose = function()
		EDSCFG.Frame:SetVisible(true)
	end

	// Name
	local DLabel = vgui.Create( "DLabel", Frame )
	DLabel:SetPos( h*25, h*35 )
	DLabel:SetSize( h*250, h*25 )
	DLabel:SetText( EDSCFG.Language["Name"] )
	DLabel:SetBright(true)

	local Text = vgui.Create( "DTextEntry", Frame )
	Text:SetPos( h*25, h*60 )
	Text:SetSize( h*250, h*25 )
	Text:SetText( rank_name )

	// Power
	local DLabel = vgui.Create( "DLabel", Frame )
	DLabel:SetPos( h*25, h*85 )
	DLabel:SetSize( h*250, h*25 )
	DLabel:SetText( EDSCFG.Language["Power"] )
	DLabel:SetBright(true)

	local DermaNumSlider = vgui.Create( "DNumSlider", Frame )
	DermaNumSlider:SetPos( h*-140, h*110 )
	DermaNumSlider:SetSize( h*440, h*25 )	
	DermaNumSlider:SetText( "" )	
	DermaNumSlider:SetMin( 1 )			
	DermaNumSlider:SetMax( 100 )	
	DermaNumSlider:SetValue( rank_power )	
	DermaNumSlider:SetDecimals( 0 )		

	// Private
	local DLabel = vgui.Create( "DLabel", Frame )
	DLabel:SetPos( h*25, h*135 )
	DLabel:SetSize( h*250, h*25 )
	DLabel:SetText( EDSCFG.Language["Private"] )
	DLabel:SetBright(true)

	local Combo = vgui.Create( "DComboBox", Frame)
	Combo:SetPos( h*25, h*160 )
	Combo:SetSize( h*250, h*25 )
	Combo:SetValue( rank_private ) 
	Combo:AddChoice( EDSCFG.Language["False"] )
	Combo:AddChoice( EDSCFG.Language["True"] )

	// Create math.round
	local DermaButton = vgui.Create( "DButton", Frame ) 
	DermaButton:SetText( EDSCFG.Language["Edit"] )				
	DermaButton:SetPos( h*25, h*195 )
	DermaButton:SetSize( h*250, h*25 )			
	DermaButton.DoClick = function()
		net.Start("EDSCFG.ReceiveEdit")	
			net.WriteString(rank)
			net.WriteString(Text:GetValue())
			net.WriteInt(DermaNumSlider:GetValue(), EDSCFG.IntPowerSize)
			net.WriteBool(bools[Combo:GetValue()])
		net.SendToServer()
		Frame:Close()
	end

end

local function AddRank()

	EDSCFG.Frame:SetVisible(false)

	local h = 1
	local bools = {}
	bools[EDSCFG.Language["True"]] = true
	bools[EDSCFG.Language["False"]] = false

	local Frame = vgui.Create( "DFrame" )
	Frame:SetTitle( EDSCFG.Language["CreateRank"] )
	Frame:SetSize( h*300, h*240 )
	Frame:Center()
	Frame:MakePopup()
	Frame.OnClose = function()
		EDSCFG.Frame:SetVisible(true)
	end

	// Name
	local DLabel = vgui.Create( "DLabel", Frame )
	DLabel:SetPos( h*25, h*35 )
	DLabel:SetSize( h*250, h*25 )
	DLabel:SetText( EDSCFG.Language["Name"] )
	DLabel:SetBright(true)

	local Text = vgui.Create( "DTextEntry", Frame )
	Text:SetPos( h*25, h*60 )
	Text:SetSize( h*250, h*25 )
	Text:SetText( "" )

	// Power
	local DLabel = vgui.Create( "DLabel", Frame )
	DLabel:SetPos( h*25, h*85 )
	DLabel:SetSize( h*250, h*25 )
	DLabel:SetText( EDSCFG.Language["Power"] )
	DLabel:SetBright(true)

	local DermaNumSlider = vgui.Create( "DNumSlider", Frame )
	DermaNumSlider:SetPos( h*-140, h*110 )
	DermaNumSlider:SetSize( h*440, h*25 )	
	DermaNumSlider:SetText( "" )	
	DermaNumSlider:SetMin( 1 )			
	DermaNumSlider:SetMax( 100 )	
	DermaNumSlider:SetValue( 1 )	
	DermaNumSlider:SetDecimals( 0 )		

	// Private
	local DLabel = vgui.Create( "DLabel", Frame )
	DLabel:SetPos( h*25, h*135 )
	DLabel:SetSize( h*250, h*25 )
	DLabel:SetText( EDSCFG.Language["Private"] )
	DLabel:SetBright(true)

	local Combo = vgui.Create( "DComboBox", Frame)
	Combo:SetPos( h*25, h*160 )
	Combo:SetSize( h*250, h*25 )
	Combo:SetValue( EDSCFG.Language["False"] ) 
	Combo:AddChoice( EDSCFG.Language["False"] )
	Combo:AddChoice( EDSCFG.Language["True"] )

	// Create math.round
	local DermaButton = vgui.Create( "DButton", Frame ) 
	DermaButton:SetText( EDSCFG.Language["Create"] )				
	DermaButton:SetPos( h*25, h*195 )
	DermaButton:SetSize( h*250, h*25 )			
	DermaButton.DoClick = function()
		net.Start("EDSCFG.ReceiveCreate")	
			net.WriteString(Text:GetValue())
			net.WriteInt(DermaNumSlider:GetValue(), EDSCFG.IntPowerSize)
			net.WriteBool(bools[Combo:GetValue()])
		net.SendToServer()
		Frame:Close()
	end

end

local function OpenDerma(data)

	EDSCFG.Admin = data

	local h = 1 // ScrH() / 1080
	local diff = 0 // 65 - h*65
	local name
	EDSCFG.nameToSteamID = {}

//	print("Data1")
//	PrintTable(data[1])
//	print("Data2")
//	PrintTable(data[2])

	local players = data[1] // SteamID, Rank
	local ranks = data[2]
	local sync = data[3]

	EDSCFG.Frame = vgui.Create( "DFrame" )
	EDSCFG.Frame:SetTitle( EDSCFG.Language["Title"] )
	EDSCFG.Frame:SetSize( h*450, h*450 )
	EDSCFG.Frame:Center()
	EDSCFG.Frame:MakePopup()

	local DermaButton = vgui.Create( "DButton", EDSCFG.Frame ) 
	DermaButton:SetText( "" )				
	DermaButton:SetPos( h*420, h*20 - diff )				
	DermaButton:SetSize( h*30, h*30 - diff )				
	DermaButton.DoClick = function()
		EDSCFG.Frame:Remove()				
		net.Start("EDSCFG.ReceiveMenu")
		net.SendToServer()		
	end
	DermaButton:SetImage("icon16/arrow_refresh.png")
	DermaButton.Paint = function()
	end

	local sheet = vgui.Create( "DPropertySheet", EDSCFG.Frame )
	sheet:Dock( FILL )

	// Players
	EDSCFG.panel1 = vgui.Create( "DPanel", sheet )
	sheet:AddSheet( EDSCFG.Language["Players"], EDSCFG.panel1 )

	EDSCFG[1] = {}

		local AppList = vgui.Create( "DListView", EDSCFG.panel1 )
		AppList:SetMultiSelect( false )
		AppList:SetPos( h*5, h*5 - diff )				
		AppList:SetSize( h*414, h*340 - diff )	
		AppList:AddColumn( EDSCFG.Language["Name"] )
		AppList:AddColumn( EDSCFG.Language["Rank"] )
		AppList:AddColumn( EDSCFG.Language["Distance"] )

		EDSCFG[1].AppList = AppList

		// Right click
		AppList.OnRowRightClick = function( panel , line )
			local menu_ = DermaMenu()
								
			--> Copy SteamID
			local icon = menu_:AddOption( "Copy SteamID", function()
				if EDSCFG.nameToSteamID[panel:GetLine(line):GetValue(1)] then
					SetClipboardText( EDSCFG.nameToSteamID[panel:GetLine(line):GetValue(1)] )
					notification.AddLegacy( EDSCFG.Language["CopiedSteamID"], NOTIFY_HINT, 2 )
				else
					notification.AddLegacy( EDSCFG.Language["FailedSteamID"], NOTIFY_HINT, 2 )
				end
			end)
			icon:SetIcon( "icon16/building_edit.png" )

			--> Open Profile
			local icon = menu_:AddOption( "Open profile", function()
				if EDSCFG.nameToSteamID[panel:GetLine(line):GetValue(1)] then
					gui.OpenURL("http://steamcommunity.com/profiles/" .. util.SteamIDTo64(EDSCFG.nameToSteamID[panel:GetLine(line):GetValue(1)]))
				else
					notification.AddLegacy( EDSCFG.Language["FailedProfile"], NOTIFY_HINT, 2 )
				end
			end)
			icon:SetIcon( "icon16/user.png" )
									
			menu_:Open()
		end

		local pos = LocalPlayer():GetPos()
		for k, v in ipairs(player.GetHumans()) do
			EDSCFG.nameToSteamID[v:Nick()] = v:SteamID()
			local rank = GetRank(v:SteamID())
			AppList:AddLine(v:Nick(), rank, math.Round(pos:Distance(v:GetPos()) * 0.0254, 1) .. "m")
		end

		local Combo = vgui.Create( "DComboBox", EDSCFG.panel1)
		Combo:SetPos( h*5, h*350 - diff )				
		Combo:SetSize( h*100, h*25 - diff )	
		Combo:SetValue( EDSCFG.Language["Add"] ) 
		Combo.OnSelect = function( panel, index, value )
			if AppList:GetSelectedLine() and EDSCFG.nameToSteamID[AppList:GetLine(AppList:GetSelectedLine()):GetValue(1)] then
				local id = EDSCFG.nameToSteamID[AppList:GetLine(AppList:GetSelectedLine()):GetValue(1)]
				net.Start("EDSCFG.ReceiveAdd")
					net.WriteString(id)
					net.WriteString(value)
				net.SendToServer()
			else
				AppList:Clear()

				local pos = LocalPlayer():GetPos()
				for k, v in ipairs(player.GetHumans()) do
					EDSCFG.nameToSteamID[v:Nick()] = v:SteamID()
					local rank = players[v:SteamID()] != nil and players[v:SteamID()][1] or ""
					AppList:AddLine(v:Nick(), rank, math.Round(pos:Distance(v:GetPos()) * 0.0254, 1) .. "m")
				end
			end

			Combo:SetValue( EDSCFG.Language["Add"] )
		end
		Combo.DoClick = function(self)
			if ( self:IsMenuOpen() ) then
				return self:CloseMenu()
			end

			self:Clear()
			self:SetValue( EDSCFG.Language["Add"] )

			for k, v in pairs(ranks) do
				Combo:AddChoice(k)
			end

			self:OpenMenu()
		end

		EDSCFG[1].Combo = Combo

		local DermaButton = vgui.Create( "DButton", EDSCFG.panel1 ) 
		DermaButton:SetText( EDSCFG.Language["Remove"] )				
		DermaButton:SetPos( h*110, h*350 - diff )				
		DermaButton:SetSize( h*100, h*25 - diff )				
		DermaButton.DoClick = function()	
			if AppList:GetSelectedLine() and EDSCFG.nameToSteamID[AppList:GetLine(AppList:GetSelectedLine()):GetValue(1)] then
				net.Start("EDSCFG.ReceiveRemove")
					net.WriteString(EDSCFG.nameToSteamID[AppList:GetLine(AppList:GetSelectedLine()):GetValue(1)])
				net.SendToServer()
			end			
		end

		local DermaButton = vgui.Create( "DButton", EDSCFG.panel1 ) 
		DermaButton:SetText( EDSCFG.Language["Add ID"] )				
		DermaButton:SetPos( h*215, h*350 - diff )				
		DermaButton:SetSize( h*100, h*25 - diff )					
		DermaButton.DoClick = function()				
			AddID()
		end

		local DermaButton = vgui.Create( "DButton", EDSCFG.panel1 ) 
		DermaButton:SetText( EDSCFG.Language["Remove ID"] )				
		DermaButton:SetPos( h*320, h*350 - diff )				
		DermaButton:SetSize( h*99, h*25 - diff )					
		DermaButton.DoClick = function()				
			RemoveID()
		end

	// Ranks
	EDSCFG.panel2 = vgui.Create( "DPanel", sheet )
	sheet:AddSheet( EDSCFG.Language["Ranks"], EDSCFG.panel2 )

	EDSCFG[2] = {}

		local AppList2 = vgui.Create( "DListView", EDSCFG.panel2 )
		AppList2:SetMultiSelect( false )
		AppList2:SetPos( h*5, h*5 - diff )				
		AppList2:SetSize( h*414, h*340 - diff )	
		AppList2:AddColumn( EDSCFG.Language["Rank"] )
		AppList2:AddColumn( EDSCFG.Language["Power"] )
		AppList2:AddColumn( EDSCFG.Language["Private"] )

		for k, v in pairs(ranks) do
			AppList2:AddLine(k, v[1], v[2] != nil and tostring(v[2]) or "")
		end

		EDSCFG[2].AppList2 = AppList2

		local DermaButton = vgui.Create( "DButton", EDSCFG.panel2 ) 
		DermaButton:SetText( EDSCFG.Language["Add"] )				
		DermaButton:SetPos( h*5, h*350 - diff )				
		DermaButton:SetSize( h*100, h*25 - diff )				
		DermaButton.DoClick = function()				
			AddRank()		
		end

		local DermaButton = vgui.Create( "DButton", EDSCFG.panel2 ) 
		DermaButton:SetText( EDSCFG.Language["Remove"] )				
		DermaButton:SetPos( h*110, h*350 - diff )				
		DermaButton:SetSize( h*100, h*25 - diff )				
		DermaButton.DoClick = function()				
			if AppList2:GetSelectedLine() and AppList2:GetLine(AppList2:GetSelectedLine()):GetValue(1) then
				net.Start("EDSCFG.ReceiveDelete")
					net.WriteString(AppList2:GetLine(AppList2:GetSelectedLine()):GetValue(1))
				net.SendToServer()
			end			
		end

		local DermaButton = vgui.Create( "DButton", EDSCFG.panel2 ) 
		DermaButton:SetText( EDSCFG.Language["Edit"] )				
		DermaButton:SetPos( h*215, h*350 - diff )				
		DermaButton:SetSize( h*100, h*25 - diff )				
		DermaButton.DoClick = function()	
			if AppList2:GetSelectedLine() and AppList2:GetLine(AppList2:GetSelectedLine()):GetValue(1) then
				EditRank(AppList2:GetLine(AppList2:GetSelectedLine()):GetValue(1))	
			end	
		end

	if CAMI == nil then return end

	// Sync
	EDSCFG.panel3 = vgui.Create( "DPanel", sheet )
	sheet:AddSheet( EDSCFG.Language["Sync"], EDSCFG.panel3 )

	EDSCFG[3] = {}

		local AppList3 = vgui.Create( "DListView", EDSCFG.panel3 )
		AppList3:SetMultiSelect( false )
		AppList3:SetPos( h*5, h*5 - diff )				
		AppList3:SetSize( h*414, h*340 - diff )	
		AppList3:AddColumn( EDSCFG.Language["UserGroup"] )
		AppList3:AddColumn( EDSCFG.Language["Rank"] )

		for k, v in pairs(sync) do
			AppList3:AddLine(k, v)
		end

		EDSCFG[3].AppList3 = AppList3

		local DermaButton = vgui.Create( "DButton", EDSCFG.panel3 ) 
		DermaButton:SetText( EDSCFG.Language["Add"] )				
		DermaButton:SetPos( h*5, h*350 - diff )				
		DermaButton:SetSize( h*100, h*25 - diff )				
		DermaButton.DoClick = function()				
			AddSync()
		end

		local DermaButton = vgui.Create( "DButton", EDSCFG.panel3 ) 
		DermaButton:SetText( EDSCFG.Language["Remove"] )				
		DermaButton:SetPos( h*110, h*350 - diff )				
		DermaButton:SetSize( h*100, h*25 - diff )				
		DermaButton.DoClick = function()				
			if AppList3:GetSelectedLine() and AppList3:GetLine(AppList3:GetSelectedLine()):GetValue(1) then
				net.Start("EDSCFG.ReceiveSync")
					net.WriteString(AppList3:GetLine(AppList3:GetSelectedLine()):GetValue(1))
					net.WriteString(AppList3:GetLine(AppList3:GetSelectedLine()):GetValue(2))
					net.WriteBool(true)
				net.SendToServer()
			end	
		end

end

/*---------------------------------------------------------------------------
Updates stuff!
---------------------------------------------------------------------------*/

// List of all ranks
function EDSCFG.Updates.EditRank(data) // data[1] steamid, data[2] rank
	if EDSCFG[2] and IsValid(EDSCFG[2].AppList2) and EDSCFG.Admin != nil and EDSCFG.Admin[2] != nil then
		for k, line in pairs(EDSCFG[2].AppList2:GetLines()) do
			if line:GetValue(1) == data[1] then
				EDSCFG[2].AppList2:RemoveLine(k)
				EDSCFG.Admin[2][data[1]] = nil
				break
			end
		end
		if data[2] != nil then
			if isstring(data[2]) then
				EDSCFG.Admin[2][data[2]] = {data[3], data[4]}
				EDSCFG[2].AppList2:AddLine(data[2], data[3], data[4])
			else
				EDSCFG.Admin[2][data[1]] = {data[2], data[3]}
				EDSCFG[2].AppList2:AddLine(data[1], data[2], data[3])
			end
		end
	end
end

// Player specific ranks
function EDSCFG.Updates.PlayerRank(data) // data[1] steamid, data[2] rank
	if EDSCFG[1] and IsValid(EDSCFG[1].AppList) and EDSCFG.Admin != nil and EDSCFG.Admin[1] != nil then

		local ply = player.GetBySteamID(data[1])
		local nick = ""
		for k, v in pairs(EDSCFG.nameToSteamID) do
			if v == data[1] then
				nick = k
			end
		end

		for k, line in pairs(EDSCFG[1].AppList:GetLines()) do
			if line:GetValue(1) == nick then
				EDSCFG[1].AppList:RemoveLine(k)
				EDSCFG.Admin[1][data[1]] = nil
				break
			end
		end
		if data[2] != nil or ply then
			table.insert(EDSCFG.Admin[1], {data[1], data[2]})
			EDSCFG[1].AppList:AddLine(nick, data[2], math.Round(LocalPlayer():GetPos():Distance(ply:GetPos()) * 0.0254, 1) .. "m")
		end
	end
end

// Update rank Sync
function EDSCFG.Updates.RankSync(data) // usergroup, rank, delete
	if EDSCFG[3] and IsValid(EDSCFG[3].AppList3) and EDSCFG.Admin != nil and EDSCFG.Admin[3] != nil then

		local usergroup = data[1]
		local rank = data[2]
		local delete = data[3]

		for k, line in pairs(EDSCFG[3].AppList3:GetLines()) do
			if line:GetValue(1) == usergroup and line:GetValue(2) == rank then
				EDSCFG[3].AppList3:RemoveLine(k)
				EDSCFG.Admin[3][data[1]] = nil
				break
			end
		end
		if !delete then
			table.insert(EDSCFG.Admin[3], {usergroup, rank})
			EDSCFG[3].AppList3:AddLine(usergroup, rank)
		end
	end
end

/*---------------------------------------------------------------------------
Net
---------------------------------------------------------------------------*/

net.Receive("EDSCFG.SendMenu", function(len)
	local length = net.ReadInt(EDSCFG.IntDataCountSize)
	local compressed = net.ReadData(length)
	local data = util.JSONToTable(util.Decompress(compressed))
	OpenDerma(data)
end)

// FIX
net.Receive("EDSCFG.SendOthersRank", function(len)
	local length = net.ReadInt(EDSCFG.IntDataCountSize)
	local compressed = net.ReadData(length)
	local data = util.Decompress(compressed)
	if data != nil and isstring(data) then
		data = util.JSONToTable(util.Decompress(compressed))
		EDSCFG.Players = data
	end
	EDSCFG.ReceivedBulk = true
end)

net.Receive("EDSCFG.SendRank", function(len)
	local ent = net.ReadString()
	local rank = net.ReadString()
	local power = net.ReadInt(EDSCFG.IntPowerSize)
//	print(ent, rank, power)

	if rank == "nil" then
		EDSCFG.Players[ent] = nil
	else
		EDSCFG.Players[ent] = {rank, power}
	end
end)

net.Receive("EDSCFG.SendCleanup", function(len)
	local ids = {}
	for k, v in ipairs(player.GetHumans()) do
		ids[v:SteamID()] = true
	end

	for k, v in pairs(EDSCFG.Players) do
		if ids[k] == nil then
			EDSCFG.Players[k] = nil
		end
	end
end)

net.Receive("EDSCFG.SendAdminUpdate", function(len)
	local key = net.ReadInt(EDSCFG.KeySize)
	local data = net.ReadTable()

	if key == EDSCFG.Keys["EditRank"] then
		EDSCFG.Updates["EditRank"](data)
	elseif key == EDSCFG.Keys["PlayerRank"] then
		EDSCFG.Updates["PlayerRank"](data)
	elseif key == EDSCFG.Keys["Sync"] then
		EDSCFG.Updates.RankSync(data)
	end
end)
