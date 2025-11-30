--[[
    This script extracts all owned pet accessories and toys from the player's 
    inventory, aggregates them into a single table, and then invokes the 
    HousingAPI/ActivateInteriorFurniture function to "add" those items to the 
    merchant (or block/furniture context).

    STATUS: Updated with a Pre-Activation Selection UI. The user can now 
    see the item count for each category ('pet_accessories' and 'toys') 
    and select which ones to use for the 100-item trade.
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local ClientDataModule = require(ReplicatedStorage:WaitForChild("ClientModules"):WaitForChild("Core"):WaitForChild("ClientData"))

-- Configuration
local TARGET_INVENTORY_TABLES = {
    -- These are the categories the script will search through.
    "pet_accessories", 
    "toys",
}
local TARGET_MERCHANT_NAME = "black_friday_2025_merchant"
local MAX_ITEMS_TO_SEND = 100 -- Target items to trade
local ACTION_STRING = "UseBlock"

-- Utility function to wait for and retrieve player data
local function waitForData()
    local data = ClientDataModule.get_data()
    while not data do
        task.wait(0.5)
        data = ClientDataModule.get_data()
    end
    return data
end

-- Recursive function to search for the specific merchant model
local function searchForMerchant(rootInstance, merchantName)
    if not rootInstance or not rootInstance:IsA("Instance") then
        return nil
    end
    for _, child in ipairs(rootInstance:GetDescendants()) do
        if child.Name == merchantName then
            return child
        end
    end
    return nil
end

-- Pre-scan inventory to get total counts of available items in target categories
local function getCategoryCounts(playerInventory)
    local categoryCounts = {}
    for _, category in ipairs(TARGET_INVENTORY_TABLES) do
        local invTable = playerInventory[category]
        if invTable then
            local count = 0
            for _ in pairs(invTable) do
                count = count + 1
            end
            categoryCounts[category] = count
        else
            categoryCounts[category] = 0
        end
    end
    return categoryCounts
end

-- Core logic to collect the final 100 items from the selected categories
local function collectTradeItems(playerInventory, selectedCategories)
    local allTradeItems = {}
    local totalItemsCollected = 0
    local rKeyCounter = 1
    local tradeSummary = {}

    -- Only iterate over categories the user selected
    for _, category in ipairs(TARGET_INVENTORY_TABLES) do
        -- Skip category if it was not selected OR if we already hit the MAX_ITEMS_TO_SEND limit
        if selectedCategories[category] and totalItemsCollected < MAX_ITEMS_TO_SEND then
            local inventoryTable = playerInventory[category]
            local itemsAddedFromCategory = 0

            if inventoryTable then
                for itemKey, _ in pairs(inventoryTable) do
                    if totalItemsCollected < MAX_ITEMS_TO_SEND then
                        local rKey = "r_" .. rKeyCounter
                        allTradeItems[rKey] = itemKey 
                        totalItemsCollected = totalItemsCollected + 1
                        itemsAddedFromCategory = itemsAddedFromCategory + 1
                        rKeyCounter = rKeyCounter + 1
                    else
                        break -- Limit reached
                    end
                end
            end
            
            -- Add to the summary table only if items were successfully collected
            if itemsAddedFromCategory > 0 then
                tradeSummary[category] = itemsAddedFromCategory
            end
        end
    end
    
    return allTradeItems, totalItemsCollected, tradeSummary
end

-- Function to create the category selection UI
local function createSelectionUI(categoryCounts)
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "CategorySelectionUI"
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
    screenGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
    
    local selectedCategories = {} -- Map to store selection state
    local selectionSignal = Instance.new("BindableEvent")

    local backgroundFrame = Instance.new("Frame")
    backgroundFrame.Size = UDim2.new(0.4, 0, 0.5, 0)
    backgroundFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    backgroundFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    backgroundFrame.BackgroundColor3 = Color3.fromRGB(36, 40, 52)
    backgroundFrame.BorderSizePixel = 0
    backgroundFrame.Parent = screenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 16)
    corner.Parent = backgroundFrame

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, 0, 0.15, 0)
    titleLabel.Position = UDim2.new(0, 0, 0, 0)
    titleLabel.Text = "SELECT ITEMS FOR 100-ITEM TRADE"
    titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 20
    titleLabel.BackgroundColor3 = backgroundFrame.BackgroundColor3
    titleLabel.BorderSizePixel = 0
    titleLabel.Parent = backgroundFrame
    
    local instructLabel = Instance.new("TextLabel")
    instructLabel.Size = UDim2.new(0.9, 0, 0.1, 0)
    instructLabel.Position = UDim2.new(0.5, 0, 0.2, 0)
    instructLabel.AnchorPoint = Vector2.new(0.5, 0)
    instructLabel.Text = "Select categories to reach the 100 item goal."
    instructLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    instructLabel.Font = Enum.Font.SourceSans
    instructLabel.TextSize = 16
    instructLabel.BackgroundColor3 = backgroundFrame.BackgroundColor3
    instructLabel.BorderSizePixel = 0
    instructLabel.Parent = backgroundFrame

    local selectionFrame = Instance.new("Frame")
    selectionFrame.Size = UDim2.new(0.9, 0, 0.45, 0)
    selectionFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    selectionFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    selectionFrame.BackgroundColor3 = Color3.fromRGB(50, 55, 70)
    selectionFrame.BorderSizePixel = 0
    selectionFrame.Parent = backgroundFrame
    
    local selectionCorner = Instance.new("UICorner")
    selectionCorner.CornerRadius = UDim.new(0, 8)
    selectionCorner.Parent = selectionFrame

    local uilist = Instance.new("UIListLayout")
    uilist.FillDirection = Enum.FillDirection.Vertical
    uilist.Padding = UDim.new(0, 10)
    uilist.Parent = selectionFrame
    
    local totalSelectedLabel = Instance.new("TextLabel")
    totalSelectedLabel.Size = UDim2.new(0.9, 0, 0.1, 0)
    totalSelectedLabel.Position = UDim2.new(0.5, 0, 0.77, 0)
    totalSelectedLabel.AnchorPoint = Vector2.new(0.5, 0)
    totalSelectedLabel.Text = "Selected: 0 items (Target: 100)"
    totalSelectedLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    totalSelectedLabel.Font = Enum.Font.GothamBold
    totalSelectedLabel.TextSize = 18
    totalSelectedLabel.BackgroundColor3 = backgroundFrame.BackgroundColor3
    totalSelectedLabel.BorderSizePixel = 0
    totalSelectedLabel.Parent = backgroundFrame
    
    local confirmButton = Instance.new("TextButton")
    confirmButton.Size = UDim2.new(0.9, 0, 0.1, 0)
    confirmButton.Position = UDim2.new(0.5, 0, 0.9, 0)
    confirmButton.AnchorPoint = Vector2.new(0.5, 0.5)
    confirmButton.Text = "Confirm Selection and Activate"
    confirmButton.Font = Enum.Font.GothamBold
    confirmButton.TextSize = 20
    confirmButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    confirmButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100) -- Disabled color initially
    confirmButton.BorderSizePixel = 0
    confirmButton.Parent = backgroundFrame
    confirmButton.Active = false

    local confirmCorner = Instance.new("UICorner")
    confirmCorner.CornerRadius = UDim.new(0, 12)
    confirmCorner.Parent = confirmButton
    
    local function updateSelectionTotal()
        local total = 0
        for category, count in pairs(categoryCounts) do
            if selectedCategories[category] then
                total = total + count
            end
        end
        
        -- Cap the displayed total at the required trade amount
        local displayTotal = math.min(total, MAX_ITEMS_TO_SEND)
        totalSelectedLabel.Text = string.format("Selected: %d items (Target: %d)", displayTotal, MAX_ITEMS_TO_SEND)
        
        if total >= MAX_ITEMS_TO_SEND then
            confirmButton.BackgroundColor3 = Color3.fromRGB(48, 178, 255) -- Blue for ready
            confirmButton.Active = true
            totalSelectedLabel.TextColor3 = Color3.fromRGB(48, 178, 255)
        else
            confirmButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100) -- Grey for disabled
            confirmButton.Active = false
            totalSelectedLabel.TextColor3 = Color3.fromRGB(255, 80, 80) -- Red for insufficient
        end
    end

    -- Create a selectable entry for each category
    for category, count in pairs(categoryCounts) do
        -- Initialize selection state
        selectedCategories[category] = false 
        
        local entryFrame = Instance.new("Frame")
        entryFrame.Size = UDim2.new(1, 0, 0, 40)
        entryFrame.BackgroundColor3 = selectionFrame.BackgroundColor3
        entryFrame.BorderSizePixel = 0
        entryFrame.Parent = selectionFrame

        local categoryLabel = Instance.new("TextLabel")
        categoryLabel.Size = UDim2.new(0.65, 0, 1, 0)
        categoryLabel.Position = UDim2.new(0, 10, 0, 0)
        categoryLabel.AnchorPoint = Vector2.new(0, 0)
        categoryLabel.TextXAlignment = Enum.TextXAlignment.Left
        categoryLabel.Text = string.gsub(category, "_", " "):upper()
        categoryLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
        categoryLabel.Font = Enum.Font.SourceSansSemibold
        categoryLabel.TextSize = 16
        categoryLabel.BackgroundColor3 = entryFrame.BackgroundColor3
        categoryLabel.BorderSizePixel = 0
        categoryLabel.Parent = entryFrame

        local countLabel = Instance.new("TextLabel")
        countLabel.Size = UDim2.new(0.2, 0, 1, 0)
        countLabel.Position = UDim2.new(0.65, 0, 0, 0)
        countLabel.AnchorPoint = Vector2.new(0, 0)
        countLabel.TextXAlignment = Enum.TextXAlignment.Left
        countLabel.Text = string.format("(Available: %d)", count)
        countLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        countLabel.Font = Enum.Font.SourceSansBold
        countLabel.TextSize = 14
        countLabel.BackgroundColor3 = entryFrame.BackgroundColor3
        countLabel.BorderSizePixel = 0
        countLabel.Parent = entryFrame

        -- Toggle Button (Checkbox style)
        local toggleButton = Instance.new("TextButton")
        toggleButton.Size = UDim2.new(0, 20, 0, 20)
        toggleButton.Position = UDim2.new(1, -15, 0.5, 0)
        toggleButton.AnchorPoint = Vector2.new(1, 0.5)
        toggleButton.Text = "" -- Checkmark will be added when selected
        toggleButton.Font = Enum.Font.SourceSansSemibold
        toggleButton.TextSize = 18
        toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        toggleButton.BackgroundColor3 = Color3.fromRGB(70, 75, 90) -- Unselected color
        toggleButton.BorderSizePixel = 0
        toggleButton.Parent = entryFrame
        
        local toggleCorner = Instance.new("UICorner")
        toggleCorner.CornerRadius = UDim.new(0, 4)
        toggleCorner.Parent = toggleButton

        toggleButton.MouseButton1Click:Connect(function()
            selectedCategories[category] = not selectedCategories[category] -- Toggle state
            
            if selectedCategories[category] then
                toggleButton.BackgroundColor3 = Color3.fromRGB(48, 178, 255)
                toggleButton.Text = "✔"
            else
                toggleButton.BackgroundColor3 = Color3.fromRGB(70, 75, 90)
                toggleButton.Text = ""
            end
            updateSelectionTotal()
        end)
    end
    
    -- Circle Close Button (Top Right) - CANCEL
    local closeButton = Instance.new("TextButton")
    closeButton.Size = UDim2.new(0, 30, 0, 30)
    closeButton.Position = UDim2.new(1, -15, 0, 15)
    closeButton.AnchorPoint = Vector2.new(1, 0)
    closeButton.Text = "X"
    closeButton.Font = Enum.Font.SourceSansSemibold
    closeButton.TextSize = 18
    closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeButton.BackgroundColor3 = Color3.fromRGB(255, 80, 80)
    closeButton.BorderSizePixel = 0
    closeButton.Parent = backgroundFrame

    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(1, 0)
    closeCorner.Parent = closeButton
    
    -- Handlers
    closeButton.MouseButton1Click:Connect(function()
        screenGui:Destroy()
        selectionSignal:Fire(nil) -- Signal nil for cancel
    end)
    
    confirmButton.MouseButton1Click:Connect(function()
        if confirmButton.Active then
            screenGui:Destroy()
            selectionSignal:Fire(selectedCategories) -- Signal the map of selected categories
        end
    end)

    return screenGui, selectionSignal.Event
end

-- Start of main script execution
local localPlayer = Players.LocalPlayer
if not localPlayer then
    warn("LocalPlayer is not available!")
    return
end

-- 1. Find Character and Furniture Container
local Character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")

local furnitureContainer = Workspace:FindFirstChild("HouseInteriors", true)
if furnitureContainer then
    furnitureContainer = furnitureContainer:FindFirstChild("furniture", true)
end

if not furnitureContainer then
    warn("FATAL ERROR: The furniture container (Workspace.HouseInteriors.furniture) was not found!")
    return
end

-- 2. Dynamically Confirm and Find the Block ID and Merchant Instance
print("\n--- CONFIRMING BLOCK EXISTENCE AND DISCOVERING BLOCK ID ---")
local merchantInstance = searchForMerchant(furnitureContainer, TARGET_MERCHANT_NAME)

local blockIdToUse = nil
if merchantInstance and merchantInstance.PrimaryPart then
    local fullBlockId = merchantInstance.Parent.Name
    blockIdToUse = fullBlockId:match("[^/]*$")
    print(string.format("SUCCESS: Block '%s' found. Dynamically determined Block ID: %s", TARGET_MERCHANT_NAME, blockIdToUse))
else
    warn(string.format("ERROR: Block '%s' was NOT found in the Workspace or did not have a parent. Cannot proceed.", TARGET_MERCHANT_NAME))
    return
end

-- 3. Get Inventory Data and Show Selection UI
local serverData = waitForData()
local playerData = serverData[localPlayer.Name]
local playerInventory = playerData and playerData.inventory

if not playerInventory or type(playerInventory) ~= "table" then
    print("Required inventory data not found.")
    return
end

local categoryCounts = getCategoryCounts(playerInventory)

print("\n--- PAUSED: WAITING FOR CATEGORY SELECTION ---")
local ui, selectionEvent = createSelectionUI(categoryCounts)
local selectedCategories = selectionEvent:Wait()
print("--- RESUMING EXECUTION: UI DESTROYED ---")

-- *** CANCELLATION CHECK ***
if not selectedCategories then
    print("ACTION CANCELLED BY USER. Script execution stopped.")
    return
end

-- 4. Perform final item collection based on user selection
local allTradeItems, totalItemsCollected, tradeSummary = collectTradeItems(playerInventory, selectedCategories)

if totalItemsCollected < MAX_ITEMS_TO_SEND then
    warn(string.format("Trade cancelled: Only collected %d items. Need %d items to proceed.", totalItemsCollected, MAX_ITEMS_TO_SEND))
    return
end

print("\n==============================================")
print("INVENTORY COLLECTION COMPLETE.")
print(string.format("Total unique items collected for API call: %d", totalItemsCollected))
print("Summary of items used:")
for category, count in pairs(tradeSummary) do
    print(string.format("  - %s: %d items", string.gsub(category, "_", " "):upper(), count))
end
print("==============================================")

-- 5. Teleport and Invoke API (Activation)

-- Teleport the character to the merchant's position
local targetPosition = merchantInstance.PrimaryPart.CFrame * CFrame.new(0, 5, 0) 
HumanoidRootPart.CFrame = targetPosition
print(string.format("SUCCESS: Teleporting %s to the merchant location.", localPlayer.Name))


-- The arguments for the InvokeServer call
local args = {
	blockIdToUse,      -- Dynamically discovered Block ID
	ACTION_STRING,     -- Action ("UseBlock")
	allTradeItems,     -- The correctly structured table {r_1 = GUID_1, r_2 = GUID_2, ...}
	Character          -- The player's character instance
}

print("\n--- INVOKING HOUSING API ---")

-- Execute the API call
local success, result = pcall(function()
    return ReplicatedStorage:WaitForChild("API"):WaitForChild("HousingAPI/ActivateInteriorFurniture"):InvokeServer(unpack(args))
end)

if success then
    print("\n--- API INVOKE SUCCESS ---")
    -- The successful trade often returns nil or a specific success object/message
    print("API Response: " .. (tostring(result) or "nil/empty"))
else
    warn("\n--- API INVOKE FAILED ---")
    warn("Error during InvokeServer:", result)
end
