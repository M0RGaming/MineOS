
local color = require("Color")
local screen = require("Screen")
local GUI = require("GUI")
local event = require("Event")
local filesystem = require("Filesystem")
local system = require("System")
local paths = require("Paths")

--------------------------------------------------------------------------------

local configPath = paths.user.applicationData .. "MultiScreen/Config.cfg"
local elementWidth = 48
local baseResolutionWidth = 146
local baseResolutionHeight = 54
local GPUProxy = screen.getGPUProxy()
local mainScreenAddress = GPUProxy.getScreen()

local config = {
	backgroundColor = 0x0,
}

--------------------------------------------------------------------------------

if filesystem.exists(configPath) then
	config = filesystem.readTable(configPath)
end

local function saveConfig()
	filesystem.writeTable(configPath, config, true)
end

local workspace, window = system.addWindow(GUI.filledWindow(1, 1, 64, 37, 0x2D2D2D))

local layout = window:addChild(GUI.layout(1, 1, window.width, window.height, 1, 1))

local function clearScreens()
	for address in component.list("screen") do
		if address ~= mainScreenAddress then
			GPUProxy.bind(address, false)
			GPUProxy.setDepth(8)
			GPUProxy.setResolution(baseResolutionWidth, baseResolutionHeight)
			GPUProxy.setBackground(config.backgroundColor)
			GPUProxy.fill(1, 1, baseResolutionWidth, baseResolutionHeight, " ")
		end
	end

	GPUProxy.bind(mainScreenAddress, false)
end

local function addButton(text)
	local button = layout:addChild(GUI.button(1, 1, elementWidth, 3, 0x4B4B4B, 0xD2D2D2, 0xD2D2D2, 0x4B4B4B, text))
	button.colors.disabled.background = 0x3C3C3C
	button.colors.disabled.text = 0x5A5A5A

	return button
end

local function addTextBox(lines)
	local textBox = layout:addChild(GUI.textBox(1, 1, elementWidth, 16, nil, 0x969696, lines, 1, 0, 0, true, true))
	textBox.eventHandler = nil

	return textBox
end

local function mainMenu(force)
	layout:removeChildren()

	local lines = {
		{color = 0xE1E1E1, text = "Welcome to MultiScreen software"},
		" ",
		"You can combine multiple screens into a single cluster and draw huge images saved in OCIF5 format. Image converter converter can be downloaded from it's repository:",
		"github.com/IgorTimofeev/OCIFImageConverter",
		" ",
		"There's some useful tips for best experience:",
		"• Use maximum size constructions for each screen (8x6 blocks)",
		"• Connect more power sources to screens if they're blinking",
		" "
	}

	if config.map then
		table.insert(lines, {color = 0xE1E1E1, text = "Current cluster properties:"})
		table.insert(lines, " ")
		local width, height = #config.map[1], #config.map
		table.insert(lines, width .. "x" .. height .. " screen blocks")
		table.insert(lines, width * baseResolutionWidth .. "x" .. height * baseResolutionHeight .. " OpenComputers pixels")
		table.insert(lines, width * baseResolutionWidth * 2 .. "x" .. height * baseResolutionHeight * 4 .. " pixels using Braille font")
	else
		table.insert(lines, {color = 0xFF4940, text = "Calibrate your system before starting"})
	end

	addTextBox(lines)

	local actionComboBox = layout:addChild(GUI.comboBox(1, 1, elementWidth, 3, 0xEEEEEE, 0x2D2D2D, 0x3C3C3C, 0x888888))
	actionComboBox:addItem("Draw image")
	actionComboBox:addItem("Clear screens")
	actionComboBox:addItem("Calibrate")

	local filesystemChooser = layout:addChild(GUI.filesystemChooser(1, 1, elementWidth, 3, 0xE1E1E1, 0x888888, 0x3C3C3C, 0x888888, nil, "Open", "Cancel", "Choose file", "/"))
	filesystemChooser:setMode(GUI.IO_MODE_OPEN, GUI.IO_MODE_FILE)
	filesystemChooser:addExtensionFilter(".pic")

	local colorSelector = layout:addChild(GUI.colorSelector(2, 2, elementWidth, 3, config.backgroundColor, "Choose color"))

	local actionButton = addButton("Next")

	actionComboBox.onItemSelected = function()
		filesystemChooser.hidden = actionComboBox.selectedItem ~= 1
		colorSelector.hidden = actionComboBox.selectedItem ~= 2
		actionButton.disabled = actionComboBox.selectedItem == 1 and (not filesystemChooser.path or not config.map)
	end

	filesystemChooser.onSubmit = function()
		actionComboBox.onItemSelected()
		workspace:draw()
	end

	actionButton.onTouch = function()
		if actionComboBox.selectedItem == 1 then
			local file = filesystem.open(filesystemChooser.path, "rb")

			local signature = file:readString(4)
			if signature == "OCIF" then
				local encodingMethod = file:readBytes(1)
				if encodingMethod == 5 then
					local width = file:readBytes(2)
					local height = file:readBytes(2)

					clearScreens()

					local background, foreground, symbol, currentBackground, currentForeground, currentAddress
					for y = 1, height do
						for x = 1, width do
							background = color.to24Bit(file:readBytes(1))
							foreground = color.to24Bit(file:readBytes(1))
							file:readBytes(1)
							symbol = file:readUnicodeChar()

							local xMonitor = math.ceil(x / baseResolutionWidth)
							local yMonitor = math.ceil(y / baseResolutionHeight)
							
							if config.map[yMonitor] and config.map[yMonitor][xMonitor] then
								if currentAddress ~= config.map[yMonitor][xMonitor] then
									GPUProxy.bind(config.map[yMonitor][xMonitor], false)
									GPUProxy.setBackground(background)
									GPUProxy.setForeground(foreground)

									currentAddress, currentBackground, currentForeground = config.map[yMonitor][xMonitor], background, foreground
								end

								if currentBackground ~= background then
									GPUProxy.setBackground(background)
									currentBackground = background
								end

								if currentForeground ~= foreground then
									GPUProxy.setForeground(foreground)
									currentForeground = foreground
								end

								GPUProxy.set(x - (xMonitor - 1) * baseResolutionWidth, y - (yMonitor - 1) * baseResolutionHeight, symbol)
							end
						end
					end

					file:close()
					
					GPUProxy.bind(mainScreenAddress, false)
					GUI.alert("Done.")
				else
					file:close()
					GUI.alert("Wrong encodingMethod: " .. tostring(encodingMethod))
				end
			else
				file:close()
				GUI.alert("Wrong signature: " .. tostring(signature))
			end
		elseif actionComboBox.selectedItem == 2 then
			config.backgroundColor = colorSelector.color
			saveConfig()
			clearScreens()
		else
			layout:removeChildren()	 

			addTextBox({
				{color = 0xE1E1E1, text = "Screen cluster calibration"},
				" ",
				"Specify required count of screens (not screen blocks, screens!) by horizontal and vertical"
			})

			local hSlider = layout:addChild(GUI.slider(1, 1, elementWidth, 0x66DB80, 0x0, 0xFFFFFF, 0xAAAAAA, 1, 10, 5, false, "Screens by horizontal: ", ""))
			hSlider.roundValues = true
			hSlider.height = 2

			local vSlider = layout:addChild(GUI.slider(1, 1, elementWidth, 0x66DB80, 0x0, 0xFFFFFF, 0xAAAAAA, 1, 10, 4, false, "Screens by vertical: ", ""))
			vSlider.roundValues = true
			vSlider.height = 2

			addButton("Next").onTouch = function()
				local connectedCount = -1
				for address in component.list("screen") do
					connectedCount = connectedCount + 1
				end
				
				hSlider.value, vSlider.value = math.floor(hSlider.value), math.floor(vSlider.value)
				local specifiedCount = hSlider.value * vSlider.value

				if specifiedCount <= connectedCount then
					layout:removeChildren()

					addTextBox({
						{color = 0xE1E1E1, text = "Screen cluster calibration"},
						" ",
						"Touch highlighted screen with your hand once. After touching all of screens calibration will be finished"
					})

					local SSX, SSY = 1, 1
					local function screenObjectDraw(object)
						screen.drawRectangle(object.x, object.y, object.width, object.height, (SSX == object.SX and SSY == object.SY) and 0x22FF22 or 0xE1E1E1, 0x0, " ")
					end

					local function newScreen(SX, SY)
						local object = GUI.object(1, 1, 8, 3)
						object.draw = screenObjectDraw
						object.SX = SX
						object.SY = SY

						return object
					end

					local function newScreenLine(SY)
						local lineLayout = GUI.layout(1, 1, layout.width, 3, 1, 1)
						lineLayout:setDirection(1, 1, GUI.DIRECTION_HORIZONTAL)
						lineLayout:setSpacing(1, 1, 2)

						for SX = 1, hSlider.value do
							lineLayout:addChild(newScreen(SX, SY))
						end

						return lineLayout
					end

					for SY = 1, vSlider.value do
						layout:addChild(newScreenLine(SY))
					end

					workspace:draw()

					clearScreens(0x0)

					config.map = {}
					local hue, hueStep = 0, 360 / specifiedCount
					while true do
						local e1, e2 = event.pull()
						if e1 == "touch" then
							if e2 ~= mainScreenAddress then
								GPUProxy.bind(e2, false)
								GPUProxy.setDepth(8)
								GPUProxy.setResolution(baseResolutionWidth, baseResolutionHeight)
								GPUProxy.setBackground(color.HSBToInteger(hue, 1, 1))
								GPUProxy.setForeground(0x0)
								GPUProxy.fill(1, 1, baseResolutionWidth, baseResolutionHeight, " ")

								local text = "Screen " .. SSX .. "x" .. SSY .. " has been calibrated"
								GPUProxy.set(math.floor(baseResolutionWidth / 2 - unicode.len(text) / 2), math.floor(baseResolutionHeight / 2), text)
								
								GPUProxy.bind(mainScreenAddress, false)

								config.map[SSY] = config.map[SSY] or {}
								config.map[SSY][SSX] = e2

								SSX, hue = SSX + 1, hue + hueStep
								if SSX > hSlider.value then
									SSX, SSY = 1, SSY + 1
									if SSY > vSlider.value then
										saveConfig()
										break
									end
								end

								workspace:draw()
							end
						end
					end

					GUI.alert("All screens has been successfully calibrated")
					mainMenu()
				else
					GUI.alert("Invalid count of connected screens. You're specified " .. specifiedCount .. " of screens, but there's " .. connectedCount .. " connected screens")
				end
			end

			workspace:draw()
		end
	end

	actionComboBox.onItemSelected()
	workspace:draw(force)
end

window.onResize = function(width, height)
	window.backgroundPanel.width = width
	window.backgroundPanel.height = height

	layout.width = width
	layout.height = height
end

--------------------------------------------------------------------------------

window:resize(window.width, window.height)
mainMenu(true)
workspace:draw()
