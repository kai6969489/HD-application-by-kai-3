-- Services 
local CollectioService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService") 
local Players = game:GetService("Players")

-- Folders
local PartySystemFolder : Folder = ReplicatedStorage["PartySystem"]
local PartiesFolder : Folder = PartySystemFolder["Parties"]
local Remotes : Folder = PartySystemFolder["Remotes"]
local Packages : Folder = ReplicatedStorage["Packages"]

-- OSS
local Janitor = require(Packages["Janitor"])
local Packets = require(Packages["Packets"])

-- Player Var
local localPlayer = game.Players.LocalPlayer
local playerGUI = localPlayer.PlayerGui

-- template
local partyTemplate = script.PartyTemplate
local playerInPartyTemplate = script.PlayerInParty

-- Gui Var
local screenGui = playerGUI["Miqhail UI"]
local gameLobby = screenGui["GameLobby"]
local partyFrame = gameLobby["Party"] ; partyFrame.Visible = false
local partyActivate = screenGui["PartyActivate"]
local createPartyButton = partyFrame["CreateParty"]
local container = partyFrame["Container"]
local partyCreateSettings : ImageLabel = partyFrame["PartyCreateSettings"] ; partyCreateSettings.Visible = false
local createPartyButtonForOwner : ImageButton = partyCreateSettings["CreateParty"]
local partySizes : Frame = partyCreateSettings["PartySizes"]
local cancelCreateButton : ImageButton = partyCreateSettings["CancelCreate"]
local playerList = partyFrame["PlayerList"] ; playerList.Visible = false
local backButtonPlayerList = playerList["BackButtonPlayerList"]
local passwordButton = partyCreateSettings["Password"]
local enterPassword = partyFrame["EnterPassword"]
local doneEnterPassword = enterPassword["DoneButton"]
local passwordBox : TextBox = enterPassword["PasswordBox"]
local signal : ImageButton = partyCreateSettings["Signal"]
local signalWarning : ImageButton = partyFrame["SignalWarning"]


local PartyClient = {}

visibility = {

	Party = false,
	PartyCreateSettings = false ,
	PlayerList = false,
	EnterPassword = false
}


PartyClient.AllJanitors = {}

PartyClient.OpenDB = false
PartyClient.PlayerLimit = nil
PartyClient.PartyPassword = nil
PartyClient.SettingPassword = false
PartyClient.TweenDB = false

function PartyClient.Start()

	PartyClient.OnPlayerAdded(localPlayer)
	Players.PlayerRemoving:Connect(PartyClient.OnPlayerRemoving)

		-- Updating GUI
		Packets.CreateParty.OnClientEvent:Connect(PartyClient.CreatedParty)
	Packets.JoinParty.OnClientEvent:Connect(PartyClient.JoinedParty)
	Packets.LeaveParty.OnClientEvent:Connect(PartyClient.LeftParty)
	Packets.KickParty.OnClientEvent:Connect(PartyClient.KickedFromParty)
	Packets.TeleportParty.OnClientEvent:Connect(PartyClient.Teleported)

	-- party activate button
	partyActivate.MouseButton1Click:Connect(function()
		PartyClient.ToggleGuiVis(not visibility.Party, partyFrame)
	end)

	createPartyButton.MouseButton1Click:Connect(PartyClient.OnCreateButton)
	passwordButton.MouseButton1Click:Connect(PartyClient.OnSetPassword)

end

function PartyClient.OnPlayerAdded(player : Player)
	-- making a new janitor
	local newJanitor = Janitor.new()
	PartyClient.AllJanitors[player.UserId] = newJanitor
	print(PartyClient.AllJanitors)
end

function PartyClient.OnPlayerRemoving(player : Player)
	-- cleanup once player left
	PartyClient.AllJanitors[player.UserId]:Cleanup()
	PartyClient.AllJanitors[player.UserId] = nil
end

function PartyClient.TweenSignal(gui , duration , property , attribute)

	-- if anything missing, bail
	if not gui or not duration or not property or not attribute then
		return
	end

	-- only do one tween at a time
	if not PartyClient.TweenDB then

		PartyClient.TweenDB = true

		-- make tween, play it
		local tweenInfo = TweenInfo.new(duration , Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local tween = TweenService:Create(gui , tweenInfo,  { [property] = attribute }) 
		tween:Play() 

		-- wait till done, then reset db
		task.wait(duration)
		PartyClient.TweenDB = false
	end
end

-- a function to toggle gui visibility
function PartyClient.ToggleGuiVis(setTo , gui)

	if PartyClient.OpenDB then return end 
	PartyClient.OpenDB = true

	if setTo == true then
		gui.Visible = true
		task.wait(0.2)
		visibility[gui.Name] = true

	else

		gui.Visible = false
		task.wait(0.2)
		visibility[gui.Name] = false
	end
	PartyClient.OpenDB = false
end

-- tweening for the party settings gui
function PartyClient.TweenPartySettings(setTo , gui)

	if PartyClient.OpenDB then return end 
	PartyClient.OpenDB = true

	local tweenInfo = TweenInfo.new(0.3 , Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	if setTo == true then 

		gui.Visible = true
		local tween = TweenService:Create(gui , tweenInfo,  { Position  = gui:GetAttribute("OpenPos") }) 
		tween:Play() 

		visibility[gui.Name] = true
	else

		local tween = TweenService:Create(gui , tweenInfo,  { Position  = gui:GetAttribute("ClosePos") }) 
		tween:Play() 
		task.wait(0.3)
		gui.Visible = false

		visibility[gui.Name] = false
	end

	PartyClient.OpenDB = false
end

-- destroying party gui after player is teleported
function PartyClient.Teleported(partyName)
	local gui = container:FindFirstChild(partyName)
	gui:Destroy()
end

-- function when create button is clicked
function PartyClient.OnCreateButton()

	if not Packets.GetPlayerInfo:Fire(localPlayer) then -- checks if player is in a party 

		-- make the party setting gui visible and tween the pop up
		PartyClient.TweenPartySettings(not visibility.PartyCreateSettings , partyCreateSettings)

		-- cancel button
		cancelCreateButton.MouseButton1Click:Connect(function()
			PartyClient.TweenPartySettings(not visibility.PartyCreateSettings , partyCreateSettings)
		end)

		-- -- loop thru party size buttons, connect a click to the button so player can pick party size
		for _ , partySize : ImageButton in partySizes:GetChildren() do

			if partySize:IsA("ImageButton") then
				partySize.MouseButton1Click:Connect(function()
					local partySizeNum = tonumber(tostring(partySize):match("%d+"))

					if partySizeNum == 1 then
						signal.Text.Text = "Picked " .. partySizeNum .. " player limit"

					else
						signal.Text.Text = "Picked " .. partySizeNum .. " players limit"
					end

					signal:GetPropertyChangedSignal("ImageTransparency"):Connect(function()
						signal.Text.TextTransparency = signal.ImageTransparency
					end)

					-- tweening to signal the player party size they picked
					PartyClient.TweenSignal(signal , 0.35 , "ImageTransparency" , 0)
					PartyClient.PlayerLimit = partySizeNum

					task.wait(0.3)
					PartyClient.TweenSignal(signal , 0.35 , "ImageTransparency" , 1)
				end)
			end
		end

		createPartyButtonForOwner.MouseButton1Click:Connect(PartyClient.CreateParty)

	else
		-- a warning GUI if player is already in a party , they can't create a party

		signalWarning:GetPropertyChangedSignal("ImageTransparency"):Connect(function()
			signalWarning.Text.TextTransparency = signalWarning.ImageTransparency
		end)

		PartyClient.TweenSignal(signalWarning , 0.35 , "ImageTransparency" , 0)

		signalWarning.Text.Text = signalWarning:GetAttribute("Error1")

		task.wait(0.3)
		PartyClient.TweenSignal(signalWarning , 0.35 , "ImageTransparency" , 1)
		warn("You're already in a party!")
	end
end

function PartyClient.CreateParty()
	-- sends the party size and password to the server to creaate a party folder on the server side
	Packets.CreateParty:Fire(PartyClient.PlayerLimit , PartyClient.PartyPassword)
	PartyClient.PartyPassword = nil
	PartyClient.ToggleGuiVis(not visibility.PartyCreateSettings , partyCreateSettings) -- make party settings not visible 
end

function PartyClient.OnSetPassword() -- prepares a password box for player to put password to join parties with password

	passwordBox.Text = "" -- clear box

	if not PartyClient.SettingPassword then
		PartyClient.SettingPassword = true
		PartyClient.ToggleGuiVis(not visibility.EnterPassword , enterPassword)

		-- if text too long, make uneditable ( over 10 word )
		passwordBox:GetPropertyChangedSignal("Text"):Connect(function()
			if #passwordBox.Text >= 10 then
				passwordBox.TextEditable = false
			else
				passwordBox.TextEditable = true
			end
		end)

		-- saves password whenn player stops interacting with the password box ( focus lost )
		local passwordBoxCon = passwordBox.FocusLost:Connect(function(enterPressed, input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				PartyClient.PartyPassword = passwordBox.Text

			end
		end)

		-- done button hides input & cleans up
		doneEnterPassword.MouseButton1Click:Connect(function()
			passwordBoxCon:Disconnect()
			PartyClient.ToggleGuiVis(not visibility.EnterPassword , enterPassword)
			PartyClient.SettingPassword = false
		end)
	end
end

function PartyClient.OnJoinButton(button : ImageButton)

	if Packets.GetPlayerInfo:Fire(localPlayer) then -- checks if player is in a party

		signalWarning:GetPropertyChangedSignal("ImageTransparency"):Connect(function()
			signalWarning.Text.TextTransparency = signalWarning.ImageTransparency
		end)

		signalWarning.Text.Text = signalWarning:GetAttribute("Error1")

		PartyClient.TweenSignal(signalWarning , 0.35 , "ImageTransparency" , 0)


		task.wait(0.3)
		PartyClient.TweenSignal(signalWarning , 0.35 , "ImageTransparency" , 1)
		-- pops up a warning that player is already in a party
		warn("You're already in a party!") 
		return
	end

	local partyName = button.Parent.Name
	local partyFolder = PartiesFolder[partyName]
	-- finds party folder in PartiesFolder by using party name

	if not partyFolder then
		warn("Party folder not found")
		return
	end

	local password =  Packets.GetPassword:Fire(partyFolder)

	if password then
		-- checks if password exists or nah
		PartyClient.OnSetPassword()

		while PartyClient.SettingPassword do
			-- while setting the password for the party yield.
			task.wait()
		end

		if PartyClient.PartyPassword ~= password then
			-- if password is wrong give warning
			signalWarning:GetPropertyChangedSignal("ImageTransparency"):Connect(function()
				signalWarning.Text.TextTransparency = signalWarning.ImageTransparency
			end)

			signalWarning.Text.Text = signalWarning:GetAttribute("Error2") -- wrong password warning
			PartyClient.TweenSignal(signalWarning , 0.35 , "ImageTransparency" , 0)
			task.wait(0.3)
			PartyClient.TweenSignal(signalWarning , 0.35 , "ImageTransparency" , 1)
			return -- stops here because password is wrong so player can't join party
		end

		Packets.JoinParty:Fire(partyName, PartyClient.PartyPassword) -- fires party name and password for server sided check ( double security )
		PartyClient.PartyPassword = nil -- resets the password player input

	else
		Packets.JoinParty:Fire(partyName) -- no password , player can join party by clicking join
	end
end

function PartyClient.OnStartButton(button) -- activated when player click start button
	local partyName = button.Parent.Name
	Packets.TeleportParty:Fire(partyName) -- fire data to server to do heavy sanity checks before teleport
	end

	function PartyClient.CreatedParty(player  : Player)
  -- this functions plays after a party is created

	local createdParty = PartiesFolder:FindFirstChild(player.Name)

	if createdParty then

		local template = partyTemplate:Clone()

		if Packets.GetPlayerInfo:Fire(player) == "Owner" and localPlayer.Name == player.Name then
      -- check if player is the owner if yes display start button
			template.LeaveButton.Visible = true
			template.StartButton.Visible = true

      -- configuring other guis
			template.StartButton.MouseButton1Click:Connect(function()
				PartyClient.OnStartButton(template.StartButton)
			end)

			template.LeaveButton.MouseButton1Click:Connect(function()
				PartyClient.OnLeaveButton(template.LeaveButton)
			end)

		else
			template.JoinButton.Visible = true

			template.JoinButton.MouseButton1Click:Connect(function()
				PartyClient.OnJoinButton(template.JoinButton)
			end)

		end

		local partyFolder = PartiesFolder:FindFirstChild(player.Name)
    
		template.ViewPlayerListButton.MouseButton1Click:Connect(function()
			PartyClient.OnViewPartyList(template.ViewPlayerListButton) -- when player list is clicked it displays the player in the party
		end)
    -- displaying player's name and pfp
		template.PlayerName.Text = player.Name
		template.OwnerPicture.Image = Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.AvatarBust , Enum.ThumbnailSize.Size100x100)
		template.PlayerInRound.Text = tostring(#partyFolder:GetChildren()) .."/".. tostring(partyFolder:GetAttribute("PartySize"))
		template.Name = player.Name
		template.Parent = container

    -- if party folder is destroyed then destroy the template and hide the pass word box if it is visible.
		createdParty.AncestryChanged:Connect(function()
			template:Destroy()

			if enterPassword.Visible == true then
				enterPassword.Visible = false
			end
		end)
  end
end

function PartyClient.OnViewPartyList(button)
	local myJanitor = PartyClient.AllJanitors[localPlayer.UserId]
	local partyName = button.Parent.Name
	local partyFolder : Folder = PartiesFolder[partyName]
	
	button.Visible = false

	PartyClient.RefreshPlayerList(partyFolder)

	PartyClient.ToggleGuiVis(not visibility.PlayerList ,playerList)


	-- update list when someone joins the party
	myJanitor:Add(partyFolder.ChildAdded:Connect(function(child)
		PartyClient.RefreshPlayerList(partyFolder)


		print(child.Name .. " has joined the party!")
	end) , "Disconnect") 
	
	-- update list when someone leaves the party
	myJanitor:Add(partyFolder.ChildRemoved:Connect(function(child)
		PartyClient.RefreshPlayerList(partyFolder)
		print(child.Name .. " has left the party!")
	end) , "Disconnect")

	-- if the party gets destroyed, close UI and clean everything
	myJanitor:Add(partyFolder.AncestryChanged:Connect(function()
		PartyClient.ToggleGuiVis(not visibility.PlayerList ,playerList)
		myJanitor:Cleanup()
	end), "Disconnect")
	
	-- back button closes the list and cleans all listeners
	myJanitor:Add(backButtonPlayerList.MouseButton1Click:Connect(function()
		PartyClient.ToggleGuiVis(not visibility.PlayerList , playerList)
		button.Visible = true
		myJanitor:Cleanup()
	end), "Disconnect") 
end

-- function to refresh player list
function PartyClient.RefreshPlayerList(partyFolder)

	local myJanitor = PartyClient.AllJanitors[localPlayer.UserId]
	local plrInfo = Packets.GetPlayerInfo:Fire(localPlayer)


  -- destroy previous ui
		for _ , template in playerList.Container:GetChildren() do
			if template:IsA("ImageLabel") then
				template:Destroy()
			end
		end

		if not partyFolder then
			warn("Error : Party Folder not found!")
			return
		end

  -- loops through player object in partyfolder
		for _ , objValue in partyFolder:GetChildren() do

			local player : Player = objValue.Value

			if playerList.Container:FindFirstChild(player.Name) then
				return
			end

    -- make player template for each plr in party
			local clonedTemplate = playerInPartyTemplate:Clone()
			clonedTemplate.Name = player.Name
			clonedTemplate.PlayerPicture.Image = Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.AvatarBust , Enum.ThumbnailSize.Size100x100)
			clonedTemplate.PlayerName.Text = player.Name
    -- if player is the owner make the kick button invisible ( owner can't kick themselves )  and crown gui visible
			if plrInfo ~= "Owner" then
				return
			end
			
		clonedTemplate.OwnerCrown.Visible = true
		clonedTemplate.KickButton.Visible = false
		clonedTemplate.Parent = playerList.Container
		
		-- if the player is the owner make the kick button for other players visible
		-- ( so the owner can kick players out )
			for _ , template in playerList.Container:GetChildren() do

				if template:IsA("ImageLabel") then
						if template.Name ~= localPlayer.Name then
							myJanitor:Add(template.KickButton.MouseButton1Click:Connect(function()
								PartyClient.KickParty(template.Name ,partyFolder)

							end) , "Disconnect")	

							template.KickButton.Visible = true
					end
				end
			end
		end
end

function PartyClient.JoinedParty(player : Player , partyName : string)
  
	local partyTemplate = container:FindFirstChild(partyName)
	local partyFolder = PartiesFolder:FindFirstChild(partyName)

	if not partyTemplate and not partyFolder then
		warn("Error : Party template not found!")		
		return
	end

	-- for all players
	partyTemplate.PlayerInRound.Text = tostring(#partyFolder:GetChildren()) .."/".. tostring(partyFolder:GetAttribute("PartySize"))

	-- updating party template for the local player
	if player.Name == localPlayer.Name then

		partyTemplate.JoinButton.Visible = false
		partyTemplate.LeaveButton.Visible = true

		partyTemplate.LeaveButton.MouseButton1Click:Connect(function()
			PartyClient.OnLeaveButton(partyTemplate.LeaveButton)
		end)
	end
end

function PartyClient.OnLeaveButton(button : ImageButton)
-- this function plays when player press leave button
	if not Packets.GetPlayerInfo:Fire(localPlayer) then
		warn("You're not in any party!")
		return
	end
	local partyName = button.Parent.Name
	Packets.LeaveParty:Fire(partyName)
end

function PartyClient.LeftParty(player : Player , partyFolder : Folder , role : string)
	
	if not partyFolder then

		return
	end

	local partyTemplate = container:FindFirstChild(partyFolder.Name)
	if not partyTemplate then

		return
	end
	-- update party after a player leave

	if player.Name == localPlayer.Name and role == "Member" then

		partyTemplate.JoinButton.Visible = true
		partyTemplate.LeaveButton.Visible = false

	end
	partyTemplate.PlayerInRound.Text = tostring(#partyFolder:GetChildren()) .."/".. tostring(partyFolder:GetAttribute("PartySize"))
end

function PartyClient.KickParty(kickedPlayerName , partyFolder : Folder)
	Packets.KickParty:Fire(kickedPlayerName , partyFolder) -- send data to server to perform kick and do checks
end

function PartyClient.KickedFromParty(playerName , partyFolder)
-- update on client when player is kicked out from party

  	-- grab the party UI template using the folder name
	local partyTemplate = container:FindFirstChild(partyFolder.Name)

	if not playerName or not partyFolder then
		warn("Error : Player's name or party folder not provided!")
		return
	end
  
-- if its us that got kicked, swap buttons back
	if playerName == localPlayer.Name then
		partyTemplate.JoinButton.Visible = true
		partyTemplate.LeaveButton.Visible = false
	end
	-- update player count
	partyTemplate.PlayerInRound.Text = tostring(#partyFolder:GetChildren()) .."/".. tostring(partyFolder:GetAttribute("PartySize"))
end

return PartyClient
