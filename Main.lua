--[[
   ✦•·················•✦•·················•✦
--                                            --
    Credits:
        1.Infinity🪽 developers
        2. Chat_GPT, DeepSeek_AI, Claude_AI
        3. Rayfield UI Library
        4. Hasan diddy piker = dog zapper
--                                            --
   ✦•·················•✦•·················•✦
]]


local Project_Infinity = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

--// Services
local Players            = game:GetService("Players")
local GuiService         = game:GetService("GuiService")
local VIM                = game:GetService("VirtualInputManager")
local VirtualUser        = game:GetService("VirtualUser")
local HttpService        = game:GetService("HttpService")
local PathfindingService = game:GetService("PathfindingService")

--// Replicated Storage
local Event = game:GetService("ReplicatedStorage").Modules.GlobalInit.RemoteEvents.PlayerSetSetting

--// Player
local Player     = Players.LocalPlayer
local PlayerGui  = Player:WaitForChild("PlayerGui")
local MainGui    = PlayerGui:WaitForChild("MainGui")
local MainFrames = MainGui:WaitForChild("MainFrames")

--// UI References
local reward       = MainFrames:WaitForChild("DailyReward")
local targetButton = reward:WaitForChild("Frame"):WaitForChild("Claim")

--// Unit Inspect
local UnitInspect    = MainFrames:WaitForChild("UnitInspect")
local UpgradeButton  = UnitInspect:WaitForChild("Main"):WaitForChild("Foreground"):WaitForChild("ActionButtons"):WaitForChild("Upgrade")
local UpgradeCost    = UpgradeButton:WaitForChild("Foreground"):WaitForChild("Amount")
local UpgradeCounter = UnitInspect:WaitForChild("Main"):WaitForChild("Foreground"):WaitForChild("Upgrades"):WaitForChild("UpgradeCounter"):WaitForChild("TextLabel")

--// Place Cost UI (safe)
local Inventory      = MainFrames:WaitForChild("Inventory")
local StatsOverlay   = Inventory:WaitForChild("RightPanel"):WaitForChild("StatsOverlay")
local PlaceCostLabel = nil
pcall(function()
    PlaceCostLabel = StatsOverlay
        :WaitForChild("StatsList", 5)
        :WaitForChild("CostStat",  5)
        :WaitForChild("Title",     5)
        :WaitForChild("amount",    5)
end)

--// Round Over UI (safe)
local RoundOver   = nil
local LobbyButton = nil
pcall(function()
    RoundOver   = MainFrames:WaitForChild("RoundOver", 10)
    LobbyButton = RoundOver:WaitForChild("Lobby", 10)
end)

--// Leaderstats
local Leaderstats = Player:FindFirstChild("leaderstats")
local Cash        = Leaderstats and Leaderstats:FindFirstChild("Cash")

--// Macro State
local MacroEnabled     = false
local SelectedGameMode = "Hard"

--// Portal CFrame
local Portal1 = CFrame.new(
    -199.997894, 3.52203035, -173.930939,
     0.809021652, -9.45965297e-08,  0.587778866,
     8.58364544e-08, 1,  4.27932747e-08,
    -0.587778866,  1.58321676e-08,  0.809021652
)

--// Anti-AFK
Player.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new(0, 0))
end)

Event:FireServer("toggleAutoUpgrade", true)

--// Daily Reward Auto-Claim
task.spawn(function()
    task.wait(2)
    if reward.Visible and targetButton.Visible then
        local inset = GuiService:GetGuiInset()
        local x = targetButton.AbsolutePosition.X + targetButton.AbsoluteSize.X / 2 + inset.X
        local y = targetButton.AbsolutePosition.Y + targetButton.AbsoluteSize.Y / 2 + inset.Y
        VIM:SendMouseButtonEvent(x, y, 0, true,  game, 1)
        task.wait(0.1)
        VIM:SendMouseButtonEvent(x, y, 0, false, game, 1)
    end
end)

-- =====================================================================
--  Walk Function
-- =====================================================================
function WalkToCFrame(targetCFrame, walkSpeed, jumpPower, avoidanceDistance)
    local Character = Player.Character or Player.CharacterAdded:Wait()
    local Humanoid  = Character:WaitForChild("Humanoid")
    local RootPart  = Character:WaitForChild("HumanoidRootPart")

    Humanoid.WalkSpeed = walkSpeed or 16
    Humanoid.JumpPower = jumpPower or 50

    local function attemptWalk()
        local Path = PathfindingService:CreatePath({
            AgentRadius     = avoidanceDistance or 3,
            AgentHeight     = 3,
            AgentCanJump    = true,
            AgentJumpHeight = jumpPower or 10,
            AgentMaxSlope   = 45,
        })

        Path:ComputeAsync(RootPart.Position, targetCFrame.Position)
        if Path.Status ~= Enum.PathStatus.Success then return false end

        for _, Waypoint in ipairs(Path:GetWaypoints()) do
            if not MacroEnabled then
                Humanoid:Move(Vector3.zero)
                return "cancelled"
            end

            if Waypoint.Action == Enum.PathWaypointAction.Jump then
                Humanoid.Jump = true
            end

            Humanoid:MoveTo(Waypoint.Position)

            local Finished   = false
            local Connection = Humanoid.MoveToFinished:Connect(function() Finished = true end)
            local start      = tick()

            repeat
                if not MacroEnabled then Connection:Disconnect() return "cancelled" end
                if tick() - start > 3  then Connection:Disconnect() return false    end
                task.wait()
            until Finished

            Connection:Disconnect()
        end

        return true
    end

    local attempts = 0
    while attempts < 5 do
        local result = attemptWalk()
        if result == true        then return true  end
        if result == "cancelled" then return false end

        attempts += 1
        local char = Player.Character
        if char and char:FindFirstChild("HumanoidRootPart") then
            char.HumanoidRootPart.CFrame = char.HumanoidRootPart.CFrame * CFrame.new(-13, 0, 0)
        end
        task.wait(0.2)
    end

    return false
end

-- =====================================================================
--  CFrame Serialization
-- =====================================================================
local function SerializeCFrame(cf)
    local x,y,z, r00,r01,r02, r10,r11,r12, r20,r21,r22 = cf:GetComponents()
    return { x,y,z, r00,r01,r02, r10,r11,r12, r20,r21,r22 }
end

local function DeserializeCFrame(t)
    return CFrame.new(unpack(t))
end

-- =====================================================================
--  Tower Data Store
-- =====================================================================
local CryoHub = {
    ClassicTowers        = {},
    ClassicSubTowers     = {},
    ClassicPlaceCosts    = {},
    ClassicSubPlaceCosts = {},
}
local CLASSIC_MAX_TOWERS = 9
local ClassicSavePath    = "Classic_CryoHub_Towers.json"

pcall(function()
    if not isfolder("Project Infinity") then makefolder("Project Infinity") end
end)

-- ─── Save ─────────────────────────────────────────────────────────────
local function SaveClassicTowers()
    local data = {
        towers        = {},
        subTowers     = {},
        placeCosts    = CryoHub.ClassicPlaceCosts    or {},
        subPlaceCosts = CryoHub.ClassicSubPlaceCosts or {},
    }
    for i = 1, CLASSIC_MAX_TOWERS do
        if CryoHub.ClassicTowers[i] then
            data.towers[i] = SerializeCFrame(CryoHub.ClassicTowers[i])
        end
        if CryoHub.ClassicSubTowers[i] then
            data.subTowers[i] = {}
            for j, cf in ipairs(CryoHub.ClassicSubTowers[i]) do
                data.subTowers[i][j] = SerializeCFrame(cf)
            end
        end
    end
    writefile("Project Infinity/" .. ClassicSavePath, HttpService:JSONEncode(data))
end

-- ─── Load ─────────────────────────────────────────────────────────────
local function LoadClassicTowers()
    if not (isfile and isfile("Project Infinity/" .. ClassicSavePath)) then return end

    local decoded = HttpService:JSONDecode(readfile("Project Infinity/" .. ClassicSavePath))

    local towerSrc = decoded.towers or decoded
    for i, v in pairs(towerSrc) do
        if typeof(v) == "table" then
            CryoHub.ClassicTowers[tonumber(i)] = DeserializeCFrame(v)
        end
    end

    if decoded.subTowers then
        for i, subList in pairs(decoded.subTowers) do
            local mainIdx = tonumber(i)
            CryoHub.ClassicSubTowers[mainIdx] = {}
            for j, v in ipairs(subList) do
                if typeof(v) == "table" then
                    CryoHub.ClassicSubTowers[mainIdx][j] = DeserializeCFrame(v)
                end
            end
        end
    end

    -- Explicitly load costs, preserving 0 as a valid value
    CryoHub.ClassicPlaceCosts    = decoded.placeCosts    or {}
    CryoHub.ClassicSubPlaceCosts = decoded.subPlaceCosts or {}
end

LoadClassicTowers()

-- =====================================================================
--  Dropdown Label Helpers
-- =====================================================================
local function StripLabel(value)
    return (value:match("^(.-)%s*|") or value):match("^%s*(.-)%s*$")
end

local function ParseLabel(stripped)
    local m, s = stripped:match("^Tower (%d+), (%d+)$")
    if m and s then return tonumber(m), tonumber(s) end
    local m2 = stripped:match("^Tower (%d+)$")
    if m2 then return tonumber(m2), nil end
    return nil, nil
end

-- =====================================================================
--  Macro Helpers
-- =====================================================================
local NumberKeyCodes = {
    [1] = Enum.KeyCode.One,   [2] = Enum.KeyCode.Two,
    [3] = Enum.KeyCode.Three, [4] = Enum.KeyCode.Four,
    [5] = Enum.KeyCode.Five,  [6] = Enum.KeyCode.Six,
    [7] = Enum.KeyCode.Seven, [8] = Enum.KeyCode.Eight,
    [9] = Enum.KeyCode.Nine,
}

local Camera = workspace.CurrentCamera

local function PressNumberKey(num)
    local kc = NumberKeyCodes[num]
    if not kc then return end
    VIM:SendKeyEvent(true,  kc, false, game)
    task.wait(0.05)
    VIM:SendKeyEvent(false, kc, false, game)
    task.wait(0.1)
end

local function TeleportTo(cf)
    local char = Player.Character or Player.CharacterAdded:Wait()
    local root = char:WaitForChild("HumanoidRootPart")
    root.CFrame = cf
    task.wait(0.3)
end

local function ClickCenterLookingDown()
    local Players = game:GetService("Players")
    local Camera = workspace.CurrentCamera
    local VIM = game:GetService("VirtualInputManager")

    local Player = Players.LocalPlayer

    local oldCFrame = Camera.CFrame
    local oldMaxZoom = Player.CameraMaxZoomDistance

    -- Force zoom close using Roblox's camera system
    Player.CameraMaxZoomDistance = Player.CameraMinZoomDistance + 2

    task.wait(0.2)

    -- Look down
    local pos = Camera.CFrame.Position
    Camera.CFrame = CFrame.lookAt(pos, pos + Vector3.new(0, -100, 0))

    task.wait(0.5)

    local vs = Camera.ViewportSize
    VIM:SendMouseButtonEvent(vs.X / 2, vs.Y / 2, 0, true, game, 1)
    task.wait(0.05)
    VIM:SendMouseButtonEvent(vs.X / 2, vs.Y / 2, 0, false, game, 1)

    task.wait(0.5)

    -- Restore camera
    Camera.CFrame = oldCFrame
    Player.CameraMaxZoomDistance = oldMaxZoom
end

local function WaitForFullUpgrade(timeoutSeconds)
    timeoutSeconds = timeoutSeconds or 300
    local elapsed  = 0
    while elapsed < timeoutSeconds do
        if not MacroEnabled then return false end
        local text    = UpgradeCounter.Text or ""
        local current = tonumber(text:match("^(%d+)"))
        local maximum = tonumber(text:match("%d+$"))
        if current and maximum and current >= maximum then return true end
        task.wait(0.5)
        elapsed += 0.5
    end
    warn("[CryoHub] Upgrade timed out — moving on.")
    return false
end

local function WaitForCash(required, label)
    print("[CryoHub] Waiting for", required, "cash to place", label)
    while MacroEnabled do
        local ls   = Player:FindFirstChild("leaderstats")
        local cash = ls and ls:FindFirstChild("Cash")
        if cash and cash.Value >= required then return true end
        task.wait(0.5)
    end
    return false
end

--// Returns the cost for a given tower/sub-tower, or nil if none set
local function GetEffectiveCost(mainIndex, subIndex)
    if subIndex then
        local sub = CryoHub.ClassicSubPlaceCosts[mainIndex]
        if sub and sub[subIndex] ~= nil then   -- 0 is valid
            return sub[subIndex]
        end
    end
    return CryoHub.ClassicPlaceCosts[mainIndex]  -- may be nil or 0
end

local function PlaceAndUpgrade(keyNum, cf, placeCost, label)
    if not MacroEnabled then return end
    -- Only wait for cash if a positive cost is specified
    if placeCost and placeCost > 0 then
        if not WaitForCash(placeCost, label) then return end
    end
    TeleportTo(cf)
    PressNumberKey(keyNum)
    task.wait(0.2)
    ClickCenterLookingDown()
    WaitForFullUpgrade()
end

--// Validates that every tower with a CFrame has a place cost (even 0)
local function ValidatePlaceCosts()
    for i = 1, CLASSIC_MAX_TOWERS do
        if CryoHub.ClassicTowers[i] and CryoHub.ClassicPlaceCosts[i] == nil then
            return false, "Tower " .. i
        end
    end
    return true, nil
end

--// Checks if at least one tower has a non‑nil place cost (including 0)
local function HasAnyPlaceCost()
    for i = 1, CLASSIC_MAX_TOWERS do
        if CryoHub.ClassicPlaceCosts[i] ~= nil then return true end
    end
    return false
end

-- =====================================================================
--  Main Macro Loop
-- =====================================================================
local function RunClassicMacro()
    local valid, missing = ValidatePlaceCosts()
    if not valid then
        MacroEnabled = false
        Project_Infinity:Notify({
            Title    = "Project Infinity — Macro Stopped",
            Content  = "Missing Place Cost for " .. missing .. ". Record all costs before running.",
            Duration = 6,
        })
        return
    end

    print("[CryoHub] Classic Macro started.")

    for i = 1, CLASSIC_MAX_TOWERS do
        if not MacroEnabled then break end

        local mainCF = CryoHub.ClassicTowers[i]
        if mainCF then
            local cost = GetEffectiveCost(i, nil)
            print("[CryoHub] Placing Tower", i, "| Cost:", cost)
            PlaceAndUpgrade(i, mainCF, cost, "Tower " .. i)

            if CryoHub.ClassicSubTowers[i] then
                for j, subCF in ipairs(CryoHub.ClassicSubTowers[i]) do
                    if not MacroEnabled then break end
                    local subCost = GetEffectiveCost(i, j)
                    print("[CryoHub] Placing Tower " .. i .. ", " .. j, "| Cost:", subCost)
                    PlaceAndUpgrade(i, subCF, subCost, "Tower " .. i .. ", " .. j)
                end
            end
        end
    end

    print("[CryoHub] All towers placed and upgraded. Macro complete.")
end

-- =====================================================================
--  Build dropdown display label
-- =====================================================================
local function BuildLabel(mainIdx, subIdx)
    local base = subIdx
        and ("Tower " .. mainIdx .. ", " .. subIdx)
        or  ("Tower " .. mainIdx)
    local cost = GetEffectiveCost(mainIdx, subIdx)
    -- cost may be nil → just base, otherwise append " | cost"
    return cost ~= nil and (base .. " | " .. tostring(cost)) or base
end

-- =====================================================================
--  Rayfield Window
-- =====================================================================
local Window = Project_Infinity:CreateWindow({
    Name                   = "Project Infinity🪽",
    Icon                   = 71972989536496,
    LoadingTitle           = "Welcome to Project Infinity",
    LoadingSubtitle        = "by pb_cryo",
    ShowText               = "Project Infinity",
    Theme                  = "Amethyst",
    ToggleUIKeybind        = "K",
    DisableRayfieldPrompts = true,
    DisableBuildWarnings   = true,
    ConfigurationSaving    = {
        Enabled    = true,
        FolderName = "Project Infinity",
        FileName   = "CryoHubConfig",
    },
    Discord = {
        Enabled       = false,
        Invite        = "noinvitelink",
        RememberJoins = true,
    },
    KeySystem   = false,
    KeySettings = {
        Title           = "Project Infinity",
        Subtitle        = "Key System",
        Note            = "No method of obtaining the key is provided",
        FileName        = "CryohubKey",
        SaveKey         = true,
        GrabKeyFromSite = true,
        Key             = {""},
    },
})

local Tab1 = Window:CreateTab("Home",            "home")
local Tab2 = Window:CreateTab("Macro - Classic", "workflow")
local Tab3 = Window:CreateTab("Macro - Dungeon", "workflow")
local Tab4 = Window:CreateTab("Settings",        "settings")

-- =====================================================================
--  TAB2: Classic Macro
-- =====================================================================
local TowerOptions = {}
local ClassicMacroTowersDropdown
local SubTowerEnabled = false

local function RefreshClassicDropdown()
    if not ClassicMacroTowersDropdown then return end
    TowerOptions = {}
    local hasAny = false

    for i = 1, CLASSIC_MAX_TOWERS do
        if CryoHub.ClassicTowers[i] then
            table.insert(TowerOptions, BuildLabel(i, nil))
            hasAny = true
        end
        if CryoHub.ClassicSubTowers[i] then
            for j in ipairs(CryoHub.ClassicSubTowers[i]) do
                table.insert(TowerOptions, BuildLabel(i, j))
                hasAny = true
            end
        end
    end

    if not hasAny then table.insert(TowerOptions, "Empty") end

    pcall(function()
        ClassicMacroTowersDropdown:Refresh(TowerOptions, false)
    end)
end

Tab2:CreateDivider()

-- ─── Record CFrame ────────────────────────────────────────────────────
Tab2:CreateButton({
    Name = "Record Cframe",
    Callback = function()
        local char = Player.Character or Player.CharacterAdded:Wait()
        local root = char:WaitForChild("HumanoidRootPart")

        if SubTowerEnabled then
            local sel   = (ClassicMacroTowersDropdown and ClassicMacroTowersDropdown.CurrentOption) or {}
            local mains = {}

            for _, v in ipairs(sel) do
                if typeof(v) == "string" then
                    local mainIdx, subIdx = ParseLabel(StripLabel(v))
                    if mainIdx and not subIdx and CryoHub.ClassicTowers[mainIdx] then
                        table.insert(mains, mainIdx)
                    end
                end
            end

            if #mains == 0 then
                print("[CryoHub] Sub-Tower: select a main 'Tower N' entry in the dropdown first.")
                return
            end

            for _, mainIdx in ipairs(mains) do
                CryoHub.ClassicSubTowers[mainIdx] = CryoHub.ClassicSubTowers[mainIdx] or {}
                table.insert(CryoHub.ClassicSubTowers[mainIdx], root.CFrame)
            end

            SaveClassicTowers()
            RefreshClassicDropdown()
        else
            for i = 1, CLASSIC_MAX_TOWERS do
                if not CryoHub.ClassicTowers[i] then
                    CryoHub.ClassicTowers[i] = root.CFrame
                    SaveClassicTowers()
                    RefreshClassicDropdown()
                    return
                end
            end
            print("[CryoHub] All 9 tower slots full. Delete one before recording.")
        end
    end,
})

-- ─── Delete CFrame ────────────────────────────────────────────────────
Tab2:CreateButton({
    Name = "Delete Cframe",
    Callback = function()
        if not ClassicMacroTowersDropdown then return end
        local sel = ClassicMacroTowersDropdown.CurrentOption
        if typeof(sel) ~= "table" or #sel == 0 then return end

        for _, v in ipairs(sel) do
            if typeof(v) == "string" then
                local m, s = ParseLabel(StripLabel(v))

                if m and s then
                    if CryoHub.ClassicSubTowers[m] then
                        table.remove(CryoHub.ClassicSubTowers[m], s)
                        if #CryoHub.ClassicSubTowers[m] == 0 then
                            CryoHub.ClassicSubTowers[m] = nil
                        end
                    end
                    if CryoHub.ClassicSubPlaceCosts[m] then
                        table.remove(CryoHub.ClassicSubPlaceCosts[m], s)
                        if #CryoHub.ClassicSubPlaceCosts[m] == 0 then
                            CryoHub.ClassicSubPlaceCosts[m] = nil
                        end
                    end
                elseif m then
                    CryoHub.ClassicTowers[m]        = nil
                    CryoHub.ClassicSubTowers[m]     = nil
                    CryoHub.ClassicPlaceCosts[m]    = nil
                    CryoHub.ClassicSubPlaceCosts[m] = nil
                end
            end
        end

        SaveClassicTowers()
        RefreshClassicDropdown()
    end,
})

Tab2:CreateDivider()

-- =====================================================================
--  Place Cost Section (FIXED – no gsub / base bug)
-- =====================================================================
local MainTowerDropdown = nil

-- Refresh the tower‑only dropdown used for assigning costs
local function RefreshMainTowerDropdown()
    if not MainTowerDropdown then return end
    local options = {}
    for i = 1, CLASSIC_MAX_TOWERS do
        if CryoHub.ClassicTowers[i] then
            local cost = CryoHub.ClassicPlaceCosts[i]
            local text = (cost ~= nil) and ("Tower " .. i .. " | Current: " .. tostring(cost))
                                       or ("Tower " .. i .. " | No cost")
            table.insert(options, text)
        end
    end
    if #options == 0 then
        table.insert(options, "No towers recorded")
    end
    pcall(function()
        MainTowerDropdown:Refresh(options, true)
    end)
end

-- Variable to store user input text
local ManualCostValue = ""

-- Create input field
local CostInputObject = Tab2:CreateInput({
    Name                     = "Place Cost (number)",
    PlaceholderText          = "Enter cost, e.g. 1500",
    RemoveTextAfterFocusLost = false,
    Flag                     = "ManualCostInput",
    Callback = function(Text)
        ManualCostValue = Text
    end,
})

-- Button to set cost (FIXED)
Tab2:CreateButton({
    Name = "Set Cost for Selected Tower",
    Callback = function()
        local success, err = pcall(function()
            -- Validate dropdown
            if not MainTowerDropdown then
                error("MainTowerDropdown not ready")
            end

            local selected = MainTowerDropdown.CurrentOption
            if typeof(selected) ~= "table" or #selected == 0 then
                error("Select a tower from the dropdown first.")
            end

            local selectedStr = selected[1]
            if type(selectedStr) ~= "string" then
                error("Invalid dropdown selection format.")
            end

            local towerIdx = tonumber(selectedStr:match("^Tower (%d+)"))
            if not towerIdx or not CryoHub.ClassicTowers[towerIdx] then
                error("Invalid tower selection.")
            end

            -- Validate cost input – SIMPLE, no gsub return‑count problems
            if ManualCostValue == "" then
                error("Please enter a cost in the input field.")
            end

            -- Just take the first run of digits (like a human would)
            local costStr = ManualCostValue:match("%d+")
            local cost = costStr and tonumber(costStr)

            if not cost or cost < 0 then   -- allow 0
                error("Enter a valid non‑negative number (e.g., 1500).")
            end

            -- Save
            CryoHub.ClassicPlaceCosts[towerIdx] = cost
            SaveClassicTowers()
            RefreshClassicDropdown()
            RefreshMainTowerDropdown()

            -- Clear input
            ManualCostValue = ""
            pcall(function()
                if CostInputObject and CostInputObject.SetText then
                    CostInputObject:SetText("")
                end
            end)

            Project_Infinity:Notify({
                Title    = "Project Infinity",
                Content  = "Cost " .. tostring(cost) .. " saved to Tower " .. towerIdx,
                Duration = 3,
            })
        end)

        if not success then
            warn("[CryoHub] SetCost error:", err)
            Project_Infinity:Notify({
                Title    = "Project Infinity – Error",
                Content  = "Failed to set cost: " .. tostring(err),
                Duration = 5,
            })
        end
    end,
})

-- Dropdown for selecting which tower to assign cost to
MainTowerDropdown = Tab2:CreateDropdown({
    Name            = "Select Tower for Cost",
    Options         = {},
    CurrentOption   = {},
    MultipleOptions = false,
    Flag            = "MainTowerDropdownFlag",
    Callback        = function() end,
})

task.spawn(function()
    task.wait(1)
    RefreshMainTowerDropdown()
end)

Tab2:CreateDivider()

-- ─── Sub-Tower Toggle ─────────────────────────────────────────────────
Tab2:CreateToggle({
    Name         = "Sub-Tower",
    CurrentValue = false,
    Flag         = "SubTowerToggle",
    Callback     = function(val) SubTowerEnabled = val end,
})

-- ─── Towers Dropdown (multi‑select for macro) ─────────────────────────
local SelectedTowers = {}
ClassicMacroTowersDropdown = Tab2:CreateDropdown({
    Name            = "Towers (Macro Selection)",
    Options         = {},
    CurrentOption   = {},
    MultipleOptions = true,
    Flag            = "Dropdown1",
    Callback        = function(opts) SelectedTowers = opts or {} end,
})

task.spawn(function()
    task.wait(1)
    RefreshClassicDropdown()
end)

-- ─── Game Mode ────────────────────────────────────────────────────────
Tab2:CreateDropdown({
    Name            = "Game Mode",
    Options         = {"Easy", "Hard"},
    CurrentOption   = {"Hard"},
    MultipleOptions = false,
    Flag            = "GameMode",
    Callback        = function(v) SelectedGameMode = v[1] end,
})

-- ─── Macro Toggle ─────────────────────────────────────────────────────
Tab2:CreateToggle({
    Name         = "Toggle Macro",
    CurrentValue = false,
    Flag         = "MacroToggle",
    Callback     = function(Value)
        MacroEnabled = Value
        if not Value then return end

        task.spawn(function()
            local ls   = Player:FindFirstChild("leaderstats")
            local cash = ls and ls:FindFirstChild("Cash")

            if not cash then
                VIM:SendKeyEvent(true,  "K", false, game)
                task.wait()
                VIM:SendKeyEvent(false, "K", false, game)
                task.wait(0.2)
                local Reached = WalkToCFrame(Portal1, 20, 40, 4)
                if not (Reached and MacroEnabled) then return end

                local MapSelection = MainFrames:FindFirstChild("MapSelection")
                if not (MapSelection and MapSelection.Visible) then return end

                task.wait(0.2)
                local inset = GuiService:GetGuiInset()

                local modeBtn = (SelectedGameMode == "Easy")
                    and MapSelection.Main.Foreground.RightFrame.Foreground.StagesFrame.EasyButtonFrame.EasyButton
                    or  MapSelection.Main.Foreground.RightFrame.Foreground.StagesFrame.HardButtonFrame.HardButton

                local mPos  = modeBtn.AbsolutePosition
                local mSize = modeBtn.AbsoluteSize
                local mx    = mPos.X + mSize.X / 2 + inset.X
                local my    = mPos.Y + mSize.Y / 2 + inset.Y
                VIM:SendMouseButtonEvent(mx, my, 0, true,  game, 1)
                task.wait(0.1)
                VIM:SendMouseButtonEvent(mx, my, 0, false, game, 1)
                task.wait(0.3)

                local startBtn = MapSelection.Main.Foreground.RightFrame.Foreground.StartGameButtonFrame.StartGameButton
                repeat task.wait() until startBtn and startBtn.AbsoluteSize.X > 0

                local sPos  = startBtn.AbsolutePosition
                local sSize = startBtn.AbsoluteSize
                local sx    = sPos.X + sSize.X / 2 + inset.X
                local sy    = sPos.Y + sSize.Y / 2 + inset.Y
                VIM:SendMouseButtonEvent(sx, sy, 0, true,  game, 1)
                task.wait(0.1)
                VIM:SendMouseButtonEvent(sx, sy, 0, false, game, 1)

                task.wait(0.1) -- wait and double click start to avoid game mis-click bug

               VIM:SendMouseButtonEvent(sx, sy, 0, true,  game, 1)
                task.wait(0.1)
                VIM:SendMouseButtonEvent(sx, sy, 0, false, game, 1)
            else
                -- In‑game: close the UI, then run the macro
                VIM:SendKeyEvent(true,  "K", false, game)
                task.wait()
                VIM:SendKeyEvent(false, "K", false, game)
                task.wait(2)

                if not HasAnyPlaceCost() then
                    MacroEnabled = false
                    Project_Infinity:Notify({
                        Title    = "Project Infinity — Macro Stopped",
                        Content  = "No Place Cost found. Set at least one tower's cost manually.",
                        Duration = 6,
                    })
                    return
                end

                print("[CryoHub] In game | Cash:", cash.Value)
                -- vote to start game
                loadstring(game:HttpGet("https://raw.githubusercontent.com/CryoScript/CryoHub/refs/heads/main/Resources.lua"))(true)
                RunClassicMacro()


               -- Wait until RoundOver is visible
               while not RoundOver.Visible do
                  task.wait(0.5)
               end

               -- Ensure the button has a size (sometimes it appears with zero size at first)
               repeat task.wait() until LobbyButton.AbsoluteSize.X > 0 and LobbyButton.AbsoluteSize.Y > 0

               -- First click: center of the screen (e.g., to claim rewards)
               local vs = workspace.CurrentCamera.ViewportSize
               local screenX = vs.X / 2
               local screenY = vs.Y / 2
               VIM:SendMouseButtonEvent(screenX, screenY, 0, true, game, 1)
               task.wait(0.1)
               VIM:SendMouseButtonEvent(screenX, screenY, 0, false, game, 1)

               task.wait(2)   -- small gap

               -- Second click: center of the Lobby button
               local inset = GuiService:GetGuiInset()
               local pos = LobbyButton.AbsolutePosition
               local size = LobbyButton.AbsoluteSize
               local x = pos.X + size.X / 2 + inset.X
               local y = pos.Y + size.Y / 2 + inset.Y

               VIM:SendMouseButtonEvent(x, y, 0, true, game, 1)
               task.wait(0.1)
               VIM:SendMouseButtonEvent(x, y, 0, false, game, 1)

               task.wait(0.1)

               VIM:SendMouseButtonEvent(x, y, 0, true, game, 1)
               task.wait(0.1)
               VIM:SendMouseButtonEvent(x, y, 0, false, game, 1)

            end
        end)
    end,
})

Tab2:CreateDivider()

-- =====================================================================
--  Load saved Rayfield configuration
-- =====================================================================
Project_Infinity:LoadConfiguration()
