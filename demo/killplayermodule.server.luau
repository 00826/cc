--!strict

--- ### killplayermodule.server.luau
---
--- umad?

local starterplayer = game:GetService("StarterPlayer")

--- runtime fork
local fork = Instance.new("ModuleScript")
fork.Name = "PlayerModule"
fork:SetAttribute("fork", true)
fork.Parent = starterplayer

--- kill
local function kill(maybeplayermodule: Instance)
	if maybeplayermodule:GetAttribute("fork") == true then return end

	if maybeplayermodule.Name == "PlayerModule" then
		maybeplayermodule.DescendantAdded:Connect(function(thing)
			if thing:IsA("Script") then
				thing.Enabled = false
				thing:Destroy()
			end
		end)
		for _, thing in maybeplayermodule:QueryDescendants("Script") do
			thing.Enabled = false
			thing:Destroy()
		end

		maybeplayermodule:Destroy()
	end
end

for _, thing in starterplayer:QueryDescendants("Instance") do
	kill(thing)
end
starterplayer.ChildAdded:Connect(kill)