local workspace = game:GetService("Workspace")
local players = game:GetService("Players")
local replicatedStorage = game:GetService("ReplicatedStorage")
local localPlayer = players.LocalPlayer
local BASE_THRESHOLD = 0.2
local VELOCITY_SCALING_FACTOR_FAST = 0.050
local VELOCITY_SCALING_FACTOR_SLOW = 0.1
local UserInputService = game:GetService("UserInputService")
local gameEndResponses = {"ggs", "gg", "good ga", "ggs yall", "wp", "ggs man"}
local heartbeatConnection
local focusedBall, displayBall = nil, nil
local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
local ballsFolder = workspace:WaitForChild("Balls")
local parryButtonPress = replicatedStorage.Remotes.ParryButtonPress
local abilityButtonPress = replicatedStorage.Remotes.AbilityButtonPress
local sliderValue = 20
local distanceVisualizer = nil
local isRunning = false
local notifyparried = false
local PlayerGui = localPlayer:WaitForChild("PlayerGui")
local Hotbar = PlayerGui:WaitForChild("Hotbar")
local UseRage = false

local uigrad1 = Hotbar.Block.border1.UIGradient
local uigrad2 = Hotbar.Ability.border2.UIGradient


local function isPlayerOnMobile()
    return UserInputService.TouchEnabled and not (UserInputService.KeyboardEnabled or UserInputService.GamepadEnabled)
end

local RayfieldURL = isPlayerOnMobile() and 
                    'https://raw.githubusercontent.com/Hosvile/Refinement/main/MC%3AArrayfield%20Library' or 
                    'https://sirius.menu/rayfield'

local Rayfield = loadstring(game:HttpGet(RayfieldURL))()


local Window = Rayfield:CreateWindow({
   Name = "Dark hub",
   LoadingTitle = "Script de teste, made in english",
   LoadingSubtitle = "by Bacon 98% open src",
   ConfigurationSaving = {
      Enabled = false,
      FolderName = "Aegians Scripts",
      FileName = "Aegians Scripts"
   },
   Discord = {
      Enabled = false,
      Invite = "",
      RememberJoins = true
   },
   KeySystem = true,
   KeySettings = {
      Title = "Bacon first script LoL",
      Subtitle = "Key System",
      Note = "Só os besto friendo tem a key ksks",
      FileName = "AegiansKey",
      SaveKey = false,
      GrabKeyFromSite = false,
      Key = "BaconFriend"
   }
})

local AutoParry = Window:CreateTab("Auto Parry", 13014537525)

if character then
    print("Personagem encontrado.")
else
    print("Personagem não encontrado")
    return
end

local function notify(title, content, duration)
    Rayfield:Notify({
        Title = title,
        Content = content,
        Duration = duration or 0.7,
        Image = 10010348543
    })
end

local function getPlayerPing()
    local ping = game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue()
    return ping
end

local function mapPingToDistance(ping)
    local multiplier = 0.15
    local offset = 15
    return math.min(100, math.max(0, ping * multiplier + offset))
end


local function chooseNewFocusedBall()
    local balls = ballsFolder:GetChildren()
    for _, ball in ipairs(balls) do
        if ball:GetAttribute("realBall") ~= nil and ball:GetAttribute("realBall") == true then
            focusedBall = ball
            print(focusedBall.Name)
            break
        elseif ball:GetAttribute("target") ~= nil then
            focusedBall = ball
            print(focusedBall.Name)
            break
        end
    end
    
    if focusedBall == nil then
        print("Debug: Could not find a ball that's the realBall or has a target.")
        wait(3)
        chooseNewFocusedBall()
    end
    return focusedBall
end

local function getDynamicThreshold(ballVelocityMagnitude)
    if ballVelocityMagnitude > 60 then
        return math.max(0.20, BASE_THRESHOLD - (ballVelocityMagnitude * VELOCITY_SCALING_FACTOR_FAST))
    else
        return math.min(0.01, BASE_THRESHOLD + (ballVelocityMagnitude * VELOCITY_SCALING_FACTOR_SLOW))
    end
end

local function timeUntilImpact(ballVelocity, distanceToPlayer, playerVelocity)
    if not character then return end
    local directionToPlayer = (character.HumanoidRootPart.Position - focusedBall.Position).Unit
    local velocityTowardsPlayer = ballVelocity:Dot(directionToPlayer) - playerVelocity:Dot(directionToPlayer)
    
    if velocityTowardsPlayer <= 0 then
        return math.huge
    end
    
    return (distanceToPlayer - sliderValue) / velocityTowardsPlayer
end

local function updateDistanceVisualizer()
    local charPos = character and character.PrimaryPart and character.PrimaryPart.Position
    if charPos and focusedBall then
        if distanceVisualizer then
            distanceVisualizer:Destroy()
        end

        local timeToImpactValue = timeUntilImpact(focusedBall.Velocity, (focusedBall.Position - charPos).Magnitude, character.PrimaryPart.Velocity)
        local ballFuturePosition = focusedBall.Position + focusedBall.Velocity * timeToImpactValue

        distanceVisualizer = Instance.new("Part")
        distanceVisualizer.Size = Vector3.new(1, 1, 1)
        distanceVisualizer.Anchored = true
        distanceVisualizer.CanCollide = false
        distanceVisualizer.Position = ballFuturePosition
        distanceVisualizer.Parent = workspace    
    end
end


local function checkIfTarget()
    for _, v in pairs(ballsFolder:GetChildren()) do
        if v:IsA("Part") and v.BrickColor == BrickColor.new("Really red") then 
            print("Ball is targetting player.")
            return true 
        end 
    end 
    return false
end

local function isCooldownInEffect(uigradient)
    return uigradient.Offset.Y < 0.5
end

local function checkBallDistance()
    if not character or not checkIfTarget() then return end

    local charPos = character.PrimaryPart.Position
    local charVel = character.PrimaryPart.Velocity

    if focusedBall and not focusedBall.Parent then
        print("Focused ball lost parent. Choosing a new focused ball.")
        chooseNewFocusedBall()
    end
    if not focusedBall then 
        print("No focused ball.")
        chooseNewFocusedBall()
    end

    local ball = focusedBall
    local distanceToPlayer = (ball.Position - charPos).Magnitude
    local ballVelocityTowardsPlayer = ball.Velocity:Dot((charPos - ball.Position).Unit)
    if ball.zoomies.VectorVelocity == nil or (ball.zoomies.VectorVelocity.x == -0 or ball.zoomies.VectorVelocity.x == 0 or ball.zoomies.VectorVelocity.y == -0 or ball.zoomies.VectorVelocity.y == 0 or ball.zoomies.VectorVelocity.z == -0 or ball.zoomies.VectorVelocity.z == 0) then
        return 
    end

    if distanceToPlayer <= 15 then
        parryButtonPress:Fire()
        task.wait(0.5)
    end

    if timeUntilImpact(ball.Velocity, distanceToPlayer, charVel) < getDynamicThreshold(ballVelocityTowardsPlayer) then
        if (character.Abilities["Raging Deflection"].Enabled or character.Abilities["Rapture"].Enabled) and UseRage == true then
            if not isCooldownInEffect(uigrad2) then
                abilityButtonPress:Fire()
            end

            if isCooldownInEffect(uigrad2) and not isCooldownInEffect(uigrad1) then
                parryButtonPress:Fire()
                if notifyparried == true then
                    notify("Auto Parry", "Manually Parried Ball (Ability on CD)", 0.3)
                end
            end

        elseif not isCooldownInEffect(uigrad1) then
            print(isCooldownInEffect(uigrad1))
            parryButtonPress:Fire()
            if notifyparried == true then
                notify("Auto Parry", "Automatically Parried Ball", 0.3)
            end
            task.wait(0.5)
        end
    end
end


local function autoParryCoroutine()
    while isRunning do
        local ping = getPlayerPing()
        sliderValue = mapPingToDistance(ping)
        
        checkBallDistance()
        updateDistanceVisualizer()
        task.wait()
    end
end


localPlayer.CharacterAdded:Connect(function(newCharacter)
    character = newCharacter
    chooseNewFocusedBall()
    updateDistanceVisualizer()
end)

localPlayer.CharacterRemoving:Connect(function()
    if distanceVisualizer then
        distanceVisualizer:Destroy()
        distanceVisualizer = nil
    end
end)



local function startAutoParry()
    print("Script successfully ran.")
    
    chooseNewFocusedBall()
    
    isRunning = true
    local co = coroutine.create(autoParryCoroutine)
    coroutine.resume(co)
end

local function stopAutoParry()
    isRunning = false
end


local AutoParrySection = AutoParry:CreateSection("Auto Parry")

local AutoParryToggle = AutoParry:CreateToggle({
    Name = "Auto Parry",
    CurrentValue = false,
    Flag = "AutoParryFlag",
    Callback = function(Value)
        if Value then
            startAutoParry()
            notify("Auto Parry", "Auto parry foi iniciado.", 1)
        else
            stopAutoParry()
            notify("Auto Parry", "Auto parry desativado.", 1)
        end
    end,
})


local AutoRagingDeflect = AutoParry:CreateToggle({
    Name = "Auto Rage Parry/Rapture Parry (Equipe raging deflect/rapture)",
    CurrentValue = false,
    Flag = "AutoRagingDeflectFlag",
    Callback = function(Value)
        if Value then
            startAutoParry()
            UseRage = Value
            notify("Auto Parry", "Auto Parry com habilidade foi iniciado.", 1)
        else
            stopAutoParry()
            UseRage = Value
            notify("Auto Parry", "Auto Parry com habilidade foi desativado.", 1)
        end
    end,
})



local CloseFighting = AutoParry:CreateSection("Clash")
 local SpamParry = AutoParry:CreateKeybind({
    Name = "Spam Parry (Segure)",
    CurrentKeybind = "C",
    HoldToInteract = true,
    Flag = "ToggleParrySpam", 
    Callback = function(Keybind)
        parryButtonPress:Fire()
    end,
 })
 

local Configuration = AutoParry:CreateSection("Configuration")

local ToggleParryOn = AutoParry:CreateKeybind({
   Name = "Toggle Parry On (Tecla, bind)",
   CurrentKeybind = "One",
   HoldToInteract = false,
   Flag = "ToggleParryOn", 
   Callback = function(Keybind)
AutoParryToggle:Set(true)

   end
})



local ToggleParryOff = AutoParry:CreateKeybind({
   Name = "Toggle Parry Off (Tecla, bind)",
   CurrentKeybind = "Two",
   HoldToInteract = false,
   Flag = "ToggleParryOff",
   Callback = function(Keybind)
   AutoParryToggle:Set(false)
   end,
})


local AutoGGToggle = AutoParry:CreateToggle({
    Name = "Auto GG",
    CurrentValue = false,
    Flag = "AutoGGFlage",
    Callback = function(Value)
        return
    end
})

local notifyparriedthing = AutoParry:CreateButton({
    Name = "Enable/Disable Notificar quando defender",
    Callback = function()
        if not notifyparried == true then
            notifyparried = true
            notify("Auto Parry", "Auto Parry com notifação ativado.", 0.7)
        else
            notifyparried = false
            notify("Auto Parry", "Auto Parry com notificação desativado.", 0.7)
        end
    end,
 })

workspace:FindFirstChild("Alive").ChildRemoved:Connect(function()
    if #(workspace.Alive:GetChildren()) <= 1 and AutoGGToggle.CurrentValue and not ggdebounce then
        ggdebounce = true
        local randomResponse = math.random(1, #gameEndResponses)
        wait(math.random(2,3.5))
        replicatedStorage.DefaultChatSystemChatEvents.SayMessageRequest:FireServer(gameEndResponses[randomResponse],"All")
        task.wait(math.random(1.5,3.3))
        ggdebounce = false
    end
end)

players.PlayerChatted:Connect(function(PlayerChatType,Player,Message)
    for _,v in pairs(keywords) do
        if (string.find(Message, v)) and Player ~= localPlayer and AutoResponseToggle.CurrentValue and not responsedebounce then
            responsedebounce = true
            local choice = math.random(1, #responses)
            replicatedStorage.DefaultChatSystemChatEvents.SayMessageRequest:FireServer(responses[choice],"All")
            task.wait(2,5)
            responsedebounce = false
        end
    end
end)
