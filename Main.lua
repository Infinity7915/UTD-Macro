--[[
   Version: 1.0.2
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
function WalkToCFrame(targetCFrame, walkSpeed, jumpPower, avoidanceDistance, isRunning, waypoints)
    isRunning = isRunning or function() return MacroEnabled end

    local Character = Player.Character or Player.CharacterAdded:Wait()
    local Humanoid  = Character:WaitForChild("Humanoid")
    local RootPart  = Character:WaitForChild("HumanoidRootPart")

    Humanoid.WalkSpeed = walkSpeed or 16
    Humanoid.JumpPower = jumpPower or 50

    -- ─── Build destination list ────────────────────────────────────────
    -- If waypoints are provided, find the closest one to the player,
    -- then queue all waypoints from that index onward, then the target.
    local destinations = {}

    if waypoints and #waypoints > 0 then
        local closestIdx  = 1
        local closestDist = math.huge

        for i, wp in ipairs(waypoints) do
            local dist = (RootPart.Position - wp.Position).Magnitude
            if dist < closestDist then
                closestDist = dist
                closestIdx  = i
            end
        end

        for i = closestIdx, #waypoints do
            table.insert(destinations, waypoints[i])
        end
    end

    table.insert(destinations, targetCFrame)   -- final destination always last

    -- ─── Walk each leg ────────────────────────────────────────────────
    local function walkToSingle(dest)
        local function attemptWalk()
            local Path = PathfindingService:CreatePath({
                AgentRadius     = avoidanceDistance or 3,
                AgentHeight     = 3,
                AgentCanJump    = true,
                AgentJumpHeight = jumpPower or 10,
                AgentMaxSlope   = 45,
            })

            Path:ComputeAsync(RootPart.Position, dest.Position)
            if Path.Status ~= Enum.PathStatus.Success then return false end

            for _, Waypoint in ipairs(Path:GetWaypoints()) do
                if not isRunning() then
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
                    if not isRunning() then Connection:Disconnect() return "cancelled" end
                    if tick() - start > 3 then Connection:Disconnect() return false end
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

    for _, dest in ipairs(destinations) do
        if not isRunning() then return false end
        if not walkToSingle(dest) then return false end
    end

    return true
end;

--[[
    WalkToCFrame Waypoints:

    Record waypoints in the order you would naturally walk them,
    starting from spawn and ending closest to the destination.

    Example path:  Spawn → Bridge → Gate → FishingSpot
    Waypoints:     { Bridge, Gate }   (FishingSpot is the targetCFrame)

    When the function runs it finds whichever waypoint is closest
    to the player, then walks every remaining waypoint in order,
    then walks to the final destination.

    This means if you are already past the Bridge when you toggle
    on, it will skip to Gate and continue from there instead of
    backtracking.
]]

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
    Name                   = "Project Infinity",
    Icon                   = "infinity",
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
        FileName   = "UTD_SavingConfig",
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
        FileName        = "ProjectInfinityKey",
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
--  TAB1: HOME TAB
-- =====================================================================
Tab1:CreateDivider()

local AutoFishFarm = false
Tab1:CreateToggle({
    Name         = "Auto Fish Farm",
    CurrentValue = false,
    Flag         = "AutoFishFarm",
    Callback = function(Value)
        AutoFishFarm = Value
        if not Value then return end

        -- Close the UI so clicks hit the game
        VIM:SendKeyEvent(true,  "K", false, game)
        task.wait()
        VIM:SendKeyEvent(false, "K", false, game)
        task.wait(2)

        task.spawn(function()
            local fishSpot = CFrame.new(-274.80413818359375, -5.411415100097656, 61.609859466552734, 0.7489927411079407, 6.21134930156586e-08, 0.6625782251358032, -6.678769892687342e-08, 1, -1.8246888444650722e-08, -0.6625782251358032, -3.058528719179776e-08, 0.7489927411079407)

            local fishWaypoints = {
                CFrame.new(-0.09244269877672195, 2.9815094470977783, -72.62796020507812, -0.9915661811828613, -4.878168979871589e-08, 0.12960118055343628, -3.4056359510259426e-08, 1, 1.1583655634694878e-07, -0.12960118055343628, 1.1044586756270292e-07, -0.9915661811828613),
                CFrame.new(0.2517731189727783, 4.004400730133057, 60.68347930908203, -1, 2.418794409209113e-08, -7.612515560140309e-07, 2.418800448822367e-08, 1, -7.926320932938324e-08, 7.612515560140309e-07, -7.926323064566532e-08, -1),
                CFrame.new(-65.22613525390625, 3.981844663619995, 122.2132797241211, -0.47409749031066895, -1.1714999637035817e-08, 0.8804723620414734, 6.608863234447426e-09, 1, 1.686395378897032e-08, -0.8804723620414734, 1.3814079657947786e-08, -0.47409749031066895),
                CFrame.new(-171.56607055664062, 2.009004592895508, 123.3414077758789, -8.093307997114607e-07, 8.120370154074408e-08, 1, -4.984693546816743e-08, 1, -8.120374417330822e-08, -1, -4.984699941701365e-08, -8.093307997114607e-07),
                CFrame.new(-245.95498657226562, -1.5657473802566528, 97.53718566894531, 0.6796119809150696, -8.49785450895979e-08, 0.7335717678070068, 5.687216741989687e-08, 1, 6.315338652029823e-08, -0.7335717678070068, -1.199979893229397e-09, 0.6796119809150696),
            }

            -- Walk to the fishing spot
            WalkToCFrame(fishSpot, 23, 40, 4, function() return AutoFishFarm end, fishWaypoints)

            if not AutoFishFarm then return end

            -- Helper to cast the rod (clicks centre of screen)
            local function CastRod()
                local vs = workspace.CurrentCamera.ViewportSize
                VIM:SendMouseButtonEvent(vs.X/2, vs.Y/2, 0, true, game, 1)
                task.wait(0.1)
                VIM:SendMouseButtonEvent(vs.X/2, vs.Y/2, 0, false, game, 1)
            end

            -- Wait for the fishing minigame to appear
            local function WaitForMinigame()
                while AutoFishFarm do
                    local mg = Player.PlayerGui:FindFirstChild("MainGui")
                    local mf = mg and mg:FindFirstChild("MainFrames")
                    local fg = mf and mf:FindFirstChild("FishingMinigame")
                    if fg and fg.Visible then return fg end
                    task.wait(0.2)
                end
                return nil
            end

            -- Initial cast
            task.wait(0.5)
            CastRod()

            while AutoFishFarm do
                local FishingGui = WaitForMinigame()
                if not FishingGui then break end  -- toggle turned off

                -- Minigame is now visible
                local lastInZone = false   -- track if we already clicked for this zone entry

                while AutoFishFarm do
                    local mg = Player.PlayerGui:FindFirstChild("MainGui")
                    local mf = mg and mg:FindFirstChild("MainFrames")
                    FishingGui = mf and mf:FindFirstChild("FishingMinigame")
                    if not (FishingGui and FishingGui.Visible) then break end  -- minigame ended

                    local Game    = FishingGui:FindFirstChild("Game")
                    local Pointer = Game and Game:FindFirstChild("Pointer")
                    local Target  = Game and Game:FindFirstChild("Target")
                    local Grades  = Pointer and Pointer:FindFirstChild("Grades")
                    local Cursor  = Target and Target:FindFirstChild("Cursor")

                    if Grades and Cursor then
                        local cLeft  = Cursor.AbsolutePosition.X
                        local cRight = cLeft + Cursor.AbsoluteSize.X

                        -- Check every grade child (Perfect, Nice, etc.)
                        local foundPerfect = false
                        for _, grade in ipairs(Grades:GetChildren()) do
                            if grade:IsA("GuiObject") then
                                local gLeft  = grade.AbsolutePosition.X
                                local gRight = gLeft + grade.AbsoluteSize.X

                                if cRight > gLeft and cLeft < gRight then
                                    -- Cursor overlaps this grade
                                    if grade.Name == "Perfect" then
                                        foundPerfect = true
                                        if not lastInZone then
                                            if not AutoFishFarm then return end
                                            local inset = GuiService:GetGuiInset()
                                            local x = grade.AbsolutePosition.X + grade.AbsoluteSize.X / 2 + inset.X
                                            local y = grade.AbsolutePosition.Y + grade.AbsoluteSize.Y / 2 + inset.Y
                                            VIM:SendMouseButtonEvent(x, y, 0, true,  game, 1)
                                            task.wait(0.03)
                                            VIM:SendMouseButtonEvent(x, y, 0, false, game, 1)
                                            lastInZone = true
                                        end
                                    end
                                    break  -- only one grade is overlapped at a time
                                end
                            end
                        end

                        if not foundPerfect then
                            lastInZone = false  -- cursor left Perfect zone, allow next click
                        end
                    end

                    task.wait()  -- poll every frame (best to set frame-rate as high as your device can handle in Roblox default settings)
                end

                -- Minigame ended, recast after a short pause
                if AutoFishFarm then
                    task.wait(2)   -- let reward screen cooldown clear
                    CastRod()
                    task.wait(0.5)
                end
            end
        end)
    end,
})

Tab1:CreateDivider()

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
            local sel = (ClassicMacroTowersDropdown and ClassicMacroTowersDropdown.CurrentOption) or {}
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
                Project_Infinity:Notify({
                    Title = "Project Infinity",
                    Content = "Please select a main tower before recording a sub-tower.",
                    Duration = 5,
                })
                return
            end

            for _, mainIdx in ipairs(mains) do
                CryoHub.ClassicSubTowers[mainIdx] = CryoHub.ClassicSubTowers[mainIdx] or {}
                table.insert(CryoHub.ClassicSubTowers[mainIdx], root.CFrame)

                Project_Infinity:Notify({
                    Title = "Project Infinity",
                    Content = "Recorded Sub-Tower " .. #CryoHub.ClassicSubTowers[mainIdx] .. " for Tower " .. mainIdx,
                    Duration = 3,
                })
            end

            SaveClassicTowers()
            RefreshClassicDropdown()

        else
            for i = 1, CLASSIC_MAX_TOWERS do
                if not CryoHub.ClassicTowers[i] then
                    CryoHub.ClassicTowers[i] = root.CFrame

                    SaveClassicTowers()
                    RefreshClassicDropdown()

                    Project_Infinity:Notify({
                        Title = "Project Infinity",
                        Content = "Recorded Tower " .. i,
                        Duration = 3,
                    })

                    return
                end
            end

            Project_Infinity:Notify({
                Title = "Project Infinity",
                Content = "All tower slots are full. Delete one before recording.",
                Duration = 5,
            })
        end
    end,
})

-- ─── Delete CFrame ────────────────────────────────────────────────────
Tab2:CreateButton({
    Name = "Delete Cframe",
    Callback = function()
        if not ClassicMacroTowersDropdown then
            Project_Infinity:Notify({
                Title = "Project Infinity",
                Content = "Tower dropdown is not available.",
                Duration = 5,
            })
            return
        end

        local sel = ClassicMacroTowersDropdown.CurrentOption

        if typeof(sel) ~= "table" or #sel == 0 then
            Project_Infinity:Notify({
                Title = "Project Infinity",
                Content = "Please select a tower or sub-tower to delete.",
                Duration = 5,
            })
            return
        end

        for _, v in ipairs(sel) do
            if typeof(v) == "string" then
                local m, s = ParseLabel(StripLabel(v))

                if m and s then
                    -- Delete Sub-Tower
                    if CryoHub.ClassicSubTowers[m] then
                        table.remove(CryoHub.ClassicSubTowers[m], s)

                        Project_Infinity:Notify({
                            Title = "Project Infinity",
                            Content = "Deleted Sub-Tower " .. s .. " from Tower " .. m,
                            Duration = 3,
                        })

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
                    -- Delete Main Tower
                    CryoHub.ClassicTowers[m]        = nil
                    CryoHub.ClassicSubTowers[m]     = nil
                    CryoHub.ClassicPlaceCosts[m]    = nil
                    CryoHub.ClassicSubPlaceCosts[m] = nil

                    Project_Infinity:Notify({
                        Title = "Project Infinity",
                        Content = "Deleted Tower " .. m .. " and all associated sub-towers.",
                        Duration = 3,
                    })
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

            -- Dropdown exists?
            if not MainTowerDropdown then
                Project_Infinity:Notify({
                    Title = "Project Infinity",
                    Content = "Tower dropdown is not loaded yet.",
                    Duration = 5,
                })
                return
            end

            -- Any towers available?
            if not CryoHub.ClassicTowers or next(CryoHub.ClassicTowers) == nil then
                Project_Infinity:Notify({
                    Title = "Project Infinity",
                    Content = "There are no towers available to configure.",
                    Duration = 5,
                })
                return
            end

            -- Tower selected?
            local selected = MainTowerDropdown.CurrentOption

            if typeof(selected) ~= "table" or #selected == 0 then
                Project_Infinity:Notify({
                    Title = "Project Infinity",
                    Content = "Please select a tower from the dropdown first.",
                    Duration = 5,
                })
                return
            end

            local selectedStr = selected[1]

            if type(selectedStr) ~= "string" then
                error("Invalid dropdown selection format.")
            end

            local towerIdx = tonumber(selectedStr:match("^Tower (%d+)"))

            if not towerIdx or not CryoHub.ClassicTowers[towerIdx] then
                Project_Infinity:Notify({
                    Title = "Project Infinity",
                    Content = "Invalid tower selection.",
                    Duration = 5,
                })
                return
            end

            -- Cost validation
            if ManualCostValue == "" then
                Project_Infinity:Notify({
                    Title = "Project Infinity",
                    Content = "Please enter a cost in the input field.",
                    Duration = 5,
                })
                return
            end

            local costStr = ManualCostValue:match("%d+")
            local cost = costStr and tonumber(costStr)

            if not cost or cost < 0 then
                Project_Infinity:Notify({
                    Title = "Project Infinity",
                    Content = "Enter a valid non-negative number (e.g. 1500).",
                    Duration = 5,
                })
                return
            end

            -- Save cost
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
                Title = "Project Infinity",
                Content = "Cost " .. tostring(cost) .. " saved to Tower " .. towerIdx,
                Duration = 3,
            })
        end)

        if not success then
            warn("[CryoHub] SetCost error:", err)

            Project_Infinity:Notify({
                Title = "Project Infinity – Error",
                Content = "Failed to set cost: " .. tostring(err),
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
    local lastState = ""

    while task.wait(0.5) do
        local currentState = game:GetService("HttpService"):JSONEncode(CryoHub.ClassicTowers)

        if currentState ~= lastState then
            lastState = currentState
            RefreshMainTowerDropdown()
        end
    end
end)

RefreshMainTowerDropdown();

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
                local Reached = WalkToCFrame(Portal1, 23, 40, 4)
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

                -- vote to start game
                loadstring(game:HttpGet("https://raw.githubusercontent.com/Infinity7915/UTD-Macro/refs/heads/main/Resources/Events/VoteStart_Event.lua"))(true)
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
                task.wait(0.1)  -- wait and double click start to avoid game mis-click bug
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

               task.wait(0.1)  -- wait and double click start to avoid game mis-click bug

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
