local Players = game:GetService("Players")

local InfoGui = {}
InfoGui.__index = InfoGui

local DEFAULT_CONFIG = {
	Height = 0.5,
	Font = Enum.Font.SourceSans,
	LabelColor = Color3.new(1, 1, 1),
	LabelHeight = 20,
	Scrollable = false,
	ScrollbarVisible = false,
	DeleteWhenCreate = true,
	Offset = 0
}

--[[
	Initializes the InfoGui.
]]
function InfoGui.Init(config)
	local cfg = {}
	for key, defaultValue in pairs(DEFAULT_CONFIG) do
		if config and config[key] ~= nil then
			cfg[key] = config[key]
		else
			cfg[key] = defaultValue
		end
	end

	if cfg.DeleteWhenCreate and getgenv().activeInfoGui then
		getgenv().activeInfoGui:Destroy()
	end

	local player = Players.LocalPlayer
	if not player then
		warn("InfoGui can only be initialized on the client.")
		return nil
	end

	local playerGui
	local hui = gethui or get_hidden_ui
	local s, coregui = pcall(game.GetService, game, "CoreGui")

	if hui then
		playerGui = hui()
	elseif s then
		playerGui = coregui
	else
		playerGui = player:WaitForChild("PlayerGui")
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "InfoGui_" .. tostring(math.random(1000, 9999))
	gui.ResetOnSpawn = false
	gui.Parent = playerGui

	local frame
	if cfg.Scrollable then
		frame = Instance.new("ScrollingFrame")
		frame.ScrollBarThickness = cfg.ScrollbarVisible and 4 or 0
		frame.AutomaticCanvasSize = Enum.AutomaticSize.Y
		frame.CanvasSize = UDim2.new(0, 0, 0, 0)
		frame.BackgroundTransparency = 1
		frame.BorderSizePixel = 0
	else
		frame = Instance.new("Frame")
		frame.BackgroundTransparency = 1
		frame.BorderSizePixel = 0
	end

	frame.Size = UDim2.new(0.5, 0, cfg.Height, 0)
	frame.AnchorPoint = Vector2.new(0, 0.5)
	frame.Position = UDim2.new(0, 0, 0.5 + cfg.Offset, 0)
	frame.Parent = gui
	
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 4)
	padding.PaddingTop = UDim.new(0, 4)
	padding.PaddingBottom = UDim.new(0, 4)
	padding.Parent = frame

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 2)
	layout.Parent = frame

	local self = setmetatable({
		_gui = gui,
		_frame = frame,
		_config = cfg,
	}, InfoGui)

	getgenv().activeInfoGui = self

	return self
end

--[[
	Adds a label to the GUI.
]]
function InfoGui:AddLabel(text: string, color: Color3?)
	local label = Instance.new("TextLabel")
	
	label.Size = UDim2.new(1, 0, 0, self._config.LabelHeight)
	label.BackgroundTransparency = 1
	
	label.RichText = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Text = text
	label.TextColor3 = color or self._config.LabelColor
	label.TextScaled = true

	if typeof(self._config.Font) == "Font" then
		label.FontFace = self._config.Font
	else
		label.Font = self._config.Font or Enum.Font.SourceSans
	end

	label.Parent = self._frame
	
	return label
end

--[[
	Clears all currently active labels from the frame.
]]
function InfoGui:ClearAll()
	for _, child in ipairs(self._frame:GetChildren()) do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
end

--[[ Toggles the visibility of the entire InfoGui ]]
function InfoGui:SetVisible(visible: boolean)
	if self._gui then
		self._gui.Enabled = visible
	end
end

--[[ Completely destroys the GUI and cleans up memory ]]
function InfoGui:Destroy()
	if getgenv().activeInfoGui == self then
		getgenv().activeInfoGui = nil
	end
	if self._gui then
		self._gui:Destroy()
	end
	self = nil
end

return InfoGui
