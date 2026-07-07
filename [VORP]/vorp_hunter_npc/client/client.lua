---@diagnostic disable: undefined-global

local hunterNPC = nil
local cameraHandle = nil
local isCameraActive = false
local playerHidden = false
local blipHandle = nil
local currentTarget = nil
local isLooting = false
local lootCooldown = 0
local lastPatrolUpdate = 0
local isHunting = false
local huntCooldown = 0
local aiState = "patrol"
local lastHealTime = 0
local lastTaskTime = 0
local patrolHeading = 0.0
local patrolDistance = 0.0

-- Register the command immediately (outside the thread)
RegisterCommand(Config.Command, function()
    if hunterNPC and DoesEntityExist(hunterNPC) then
        -- If NPC exists, remove it
        RemoveHunterNPC()
    else
        -- Spawn the hunter NPC
        SpawnHunterNPC()
    end
end, false)

-- Initialize the script
CreateThread(function()
    Wait(1000) -- Wait for resources to load
    
    if Config.Debug then
        print("Hunter NPC script loaded. Use /" .. Config.Command .. " to spawn/remove the hunter NPC.")
    end
end)

-- Function to spawn the hunter NPC
function SpawnHunterNPC()
    local player = PlayerPedId()
    local playerCoords = GetEntityCoords(player)
    local playerModel = GetEntityModel(player)
    local modelHash = nil -- Initialize modelHash
    local spawnSuccess = false
    
    -- Calculate spawn position
    local spawnX = playerCoords.x + Config.HunterNPC.SpawnOffset.x
    local spawnY = playerCoords.y + Config.HunterNPC.SpawnOffset.y
    local spawnZ = playerCoords.z + Config.HunterNPC.SpawnOffset.z
    
    print("Attempting to spawn NPC at: " .. spawnX .. ", " .. spawnY .. ", " .. spawnZ)
    
    -- First try using player's model (should always work)
    print("Trying player model: " .. playerModel)
    
    if IsModelValid(playerModel) then
        RequestModel(playerModel)
        local timeout = 0
        while not HasModelLoaded(playerModel) and timeout < 50 do
            Wait(100)
            timeout = timeout + 1
        end
        
        if HasModelLoaded(playerModel) then
            hunterNPC = CreatePed(playerModel, spawnX, spawnY, spawnZ, Config.HunterNPC.Heading, false, false, false, false)
            modelHash = playerModel -- Set modelHash to player model
            
            if DoesEntityExist(hunterNPC) then
                print("Successfully created NPC with player model")
                spawnSuccess = true
            else
                print("Failed to create NPC with player model")
            end
        end
    end
    
    -- If player model failed, try alternative models
    if not spawnSuccess then
        local modelsToTry = {Config.HunterNPC.Model}
        if Config.HunterNPC.AlternativeModels then
            for _, model in ipairs(Config.HunterNPC.AlternativeModels) do
                table.insert(modelsToTry, model)
            end
        end
        
        -- Try each model until one works
        for _, modelName in ipairs(modelsToTry) do
            print("Trying model: " .. modelName)
            
            -- Load the model
            modelHash = joaat(modelName)
            
            if not IsModelValid(modelHash) then
                print("Invalid model: " .. modelName .. ", trying next...")
                goto continue
            end
            
            RequestModel(modelHash)
            local timeout = 0
            while not HasModelLoaded(modelHash) and timeout < 50 do
                Wait(100)
                timeout = timeout + 1
            end
            
            if not HasModelLoaded(modelHash) then
                print("Failed to load model: " .. modelName .. ", trying next...")
                SetModelAsNoLongerNeeded(modelHash)
                goto continue
            end
            
            -- Create the NPC
            hunterNPC = CreatePed(modelHash, spawnX, spawnY, spawnZ, Config.HunterNPC.Heading, false, false, false, false)
            
            if not DoesEntityExist(hunterNPC) then
                print("Failed to create NPC with model: " .. modelName .. ", trying next...")
                SetModelAsNoLongerNeeded(modelHash)
                goto continue
            end
            
            -- Wait for NPC to be fully created
            repeat Wait(0) until DoesEntityExist(hunterNPC)
            
            print("Successfully created NPC with model: " .. modelName)
            spawnSuccess = true
            break
            
            ::continue::
        end
    end
    
    -- If no model worked
    if not spawnSuccess or not hunterNPC or not DoesEntityExist(hunterNPC) then
        print("Failed to create hunter NPC with all available models")
        return
    end
    
    -- Set NPC appearance
    if Config.HunterNPC.Appearance and Config.HunterNPC.Appearance.RandomOutfit then
        Citizen.InvokeNative(0x283978A15512B2FE, hunterNPC, true) -- SetRandomOutfitVariation
    end
    
    -- Place NPC on ground properly
    PlaceEntityOnGroundProperly(hunterNPC, true)
    
    -- Set NPC health
    if Config.HunterNPC.Health then
        SetEntityHealth(hunterNPC, Config.HunterNPC.Health.MaxHealth)
        
        -- Set invincibility
        if Config.HunterNPC.Health.Invincible then
            SetEntityInvincible(hunterNPC, true)
        else
            SetEntityCanBeDamaged(hunterNPC, Config.HunterNPC.Health.CanBeDamaged)
        end
    end
    
    -- Set NPC as mission entity
    SetEntityAsMissionEntity(hunterNPC, true, true)
    
    -- Set relationship group
    SetPedRelationshipGroupHash(hunterNPC, `CIVMALE`)
    
    -- Give weapon to NPC
    GiveWeaponToNPC()
    
    -- Set AI behavior
    SetNPCBehavior()
    SetHunterStealthMode(false)
    
    -- Start continuous wandering patrol
    StartPatrol()
    
    -- Create blip if enabled
    if Config.HunterNPC.Blip and Config.HunterNPC.Blip.ShowBlip then
        CreateNPCBlip()
    end
    
    -- Hide player and focus camera
    HidePlayerAndFocusCamera()
    
    -- Clean up model
    if modelHash then
        SetModelAsNoLongerNeeded(modelHash)
    end
    
    if Config.Debug then
        print("Hunter NPC spawned successfully")
    end
end

-- Function to give weapon to NPC
function GiveWeaponToNPC()
    if not hunterNPC or not DoesEntityExist(hunterNPC) then
        return
    end
    
    if not Config.HunterNPC.Weapon then
        print("Weapon configuration missing")
        return
    end
    
    -- Give the bow to the NPC
    Citizen.InvokeNative(0xB282DC6EBD803C75, hunterNPC, Config.HunterNPC.Weapon.WeaponHash, 500, true, true) -- GiveWeaponToPed_2
    
    -- Set infinite ammo
    if Config.HunterNPC.Weapon.InfiniteAmmo then
        SetPedInfiniteAmmo(hunterNPC, true, Config.HunterNPC.Weapon.AmmoHash)
        SetPedInfiniteAmmoClip(hunterNPC, true)
    else
        -- Set ammo in clip
        SetAmmoInClip(hunterNPC, Config.HunterNPC.Weapon.WeaponHash, Config.HunterNPC.Weapon.AmmoInClip)
        -- Set reserve ammo
        SetPedAmmo(hunterNPC, Config.HunterNPC.Weapon.WeaponHash, Config.HunterNPC.Weapon.ReserveAmmo)
    end
    
    -- Equip the weapon
    SetCurrentPedWeapon(hunterNPC, Config.HunterNPC.Weapon.WeaponHash, true)
    
    -- Set weapon accuracy
    if Config.HunterNPC.AI and Config.HunterNPC.AI.Accuracy then
        SetPedAccuracy(hunterNPC, Config.HunterNPC.AI.Accuracy)
    end
    
    if Config.Debug then
        print("Weapon given to NPC: Bow with infinite ammo")
    end
end

-- Function to set NPC behavior
function SetNPCBehavior()
    if not hunterNPC or not DoesEntityExist(hunterNPC) then
        return
    end
    
    if not Config.HunterNPC.AI then
        print("AI configuration missing")
        return
    end
    
    -- Set combat attributes
    SetPedCombatAttributes(hunterNPC, 46, true) -- Can use cover
    SetPedCombatAttributes(hunterNPC, 5, true) -- Can fight armed peds
    SetPedCombatAttributes(hunterNPC, 1, true) -- Can fight
    SetPedCombatAttributes(hunterNPC, 0, true) -- Can use melee
    
    -- Set combat movement
    if Config.HunterNPC.AI.CombatStyle then
        SetPedCombatMovement(hunterNPC, Config.HunterNPC.AI.CombatStyle)
    end
    
    -- Set combat range
    if Config.HunterNPC.AI.CombatRange then
        SetPedCombatRange(hunterNPC, Config.HunterNPC.AI.CombatRange)
    end
    
    -- Set search range
    if Config.HunterNPC.AI.SearchRange then
        SetPedSeeingRange(hunterNPC, Config.HunterNPC.AI.SearchRange)
        SetPedHearingRange(hunterNPC, Config.HunterNPC.AI.SearchRange)
    end
    
    if Config.Debug then
        print("NPC AI behavior set")
    end
end

-- Function to start continuous patrol
function StartPatrol()
    if not hunterNPC or not DoesEntityExist(hunterNPC) then
        return
    end
    
    SetHunterMovementMode("walk")

    -- Clear any existing tasks first
    ClearPedTasks(hunterNPC)
    
    -- Use TaskWanderStandard for natural wandering without area constraints
    -- This allows the NPC to move more naturally
    TaskWanderStandard(hunterNPC, 0, 0)
    
    if Config.Debug then
        print("NPC started continuous patrol")
    end
end

-- Function to hide player and focus camera
function HidePlayerAndFocusCamera()
    local player = PlayerPedId()
    
    -- Hide player if enabled
    if Config.HunterNPC.Player and Config.HunterNPC.Player.HidePlayer then
        -- Make player invisible
        if Config.HunterNPC.Player.MakeInvisible then
            SetEntityVisible(player, false, false)
            print("Player hidden (invisible)")
        end
        
        -- Disable player controls
        if Config.HunterNPC.Player.DisableControls then
            DisablePlayerControls(true)
            print("Player controls disabled")
        end
        
        playerHidden = true
    else
        print("Player hiding disabled in config")
    end
    
    -- Focus camera on NPC if enabled
    if Config.HunterNPC.Camera and Config.HunterNPC.Camera.Enabled then
        FocusCameraOnNPC()
    else
        print("Camera focus disabled in config")
    end
end

-- Function to focus camera on NPC
function FocusCameraOnNPC()
    if not hunterNPC or not DoesEntityExist(hunterNPC) then
        return
    end
    
    if not Config.HunterNPC.Camera then
        print("Camera configuration missing")
        return
    end
    
    -- Create camera
    cameraHandle = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    SetCamActive(cameraHandle, true)
    RenderScriptCams(true, false, 0, true, true)
    
    -- Get camera settings
    local baseDistance = Config.HunterNPC.Camera.Distance or 8.0
    local headingOffset = Config.HunterNPC.Camera.HeadingOffset or 180.0
    local heightOffset = Config.HunterNPC.Camera.HeightOffset or 2.5
    local fov = Config.HunterNPC.Camera.FOV or 50.0
    local smoothness = Config.HunterNPC.Camera.Smoothness or 0.08
    local dynamicAdjustment = Config.HunterNPC.Camera.DynamicAdjustment or true
    local minDistance = Config.HunterNPC.Camera.MinDistance or 6.0
    local maxDistance = Config.HunterNPC.Camera.MaxDistance or 10.0
    
    -- Set camera FOV
    SetCamFov(cameraHandle, fov)
    
    -- Set camera shake
    ShakeCam(cameraHandle, "HAND_SHAKE", 0.0)
    
    isCameraActive = true
    
    -- Variables for smooth camera movement
    local currentCamX, currentCamY, currentCamZ = 0, 0, 0
    local lastNpcCoords = GetEntityCoords(hunterNPC)
    local initialized = false
    
    -- Start camera update thread
    CreateThread(function()
        while isCameraActive and hunterNPC and DoesEntityExist(hunterNPC) do
            Wait(0)
            
            local npcCoords = GetEntityCoords(hunterNPC)
            local npcHeading = GetEntityHeading(hunterNPC)
            
            -- Calculate NPC speed for dynamic adjustment
            local npcVelocity = GetEntityVelocity(hunterNPC)
            local speed = #(npcVelocity)
            local speedFactor = math.min(speed / 5.0, 1.0) -- Normalize speed
            
            -- Dynamic distance based on speed
            local currentDistance = baseDistance
            if dynamicAdjustment then
                currentDistance = maxDistance - (maxDistance - minDistance) * speedFactor
            end
            
            -- Calculate camera position behind NPC using offset
            local behindOffset = vector3(0, -currentDistance, heightOffset)
            local camOffset = GetOffsetFromEntityInWorldCoords(hunterNPC, behindOffset.x, behindOffset.y, behindOffset.z)
            local targetCamX = camOffset.x
            local targetCamY = camOffset.y
            local targetCamZ = camOffset.z
            
            -- Initialize camera position on first frame
            if not initialized then
                currentCamX, currentCamY, currentCamZ = targetCamX, targetCamY, targetCamZ
                SetCamCoord(cameraHandle, currentCamX, currentCamY, currentCamZ)
                initialized = true
            else
                -- Smooth camera interpolation
                currentCamX = currentCamX + (targetCamX - currentCamX) * smoothness
                currentCamY = currentCamY + (targetCamY - currentCamY) * smoothness
                currentCamZ = currentCamZ + (targetCamZ - currentCamZ) * smoothness
                
                SetCamCoord(cameraHandle, currentCamX, currentCamY, currentCamZ)
            end
            
            -- Point camera at NPC with offset for better viewing angle
            PointCamAtEntity(cameraHandle, hunterNPC, 0.0, 0.0, 0.5, true)
            
            lastNpcCoords = npcCoords
        end
    end)
    
    if Config.Debug then
        print("Camera focused on NPC with improved behind-the-shoulder view")
    end
end

-- Function to disable player controls
function DisablePlayerControls(disable)
    local player = PlayerId()
    
    if not Config.HunterNPC.Player or not Config.HunterNPC.Player.DisabledControls then
        return
    end
    
    if disable then
        -- Disable all controls
        for _, control in ipairs(Config.HunterNPC.Player.DisabledControls) do
            DisableControlAction(0, control, true)
        end
    else
        -- Enable all controls
        for _, control in ipairs(Config.HunterNPC.Player.DisabledControls) do
            EnableControlAction(0, control, true)
        end
    end
end

-- Function to create NPC blip
function CreateNPCBlip()
    if not hunterNPC or not DoesEntityExist(hunterNPC) then
        return
    end
    
    if not Config.HunterNPC.Blip then
        print("Blip configuration missing")
        return
    end
    
    -- Create blip
    blipHandle = Citizen.InvokeNative(0x554D9D53F696D002, Config.HunterNPC.Blip.Sprite, hunterNPC)
    
    -- Set blip name
    if Config.HunterNPC.Blip.Name then
        Citizen.InvokeNative(0x9CB1A1623062F402, blipHandle, Config.HunterNPC.Blip.Name)
    end
    
    -- Set blip sprite
    if Config.HunterNPC.Blip.Sprite then
        SetBlipSprite(blipHandle, Config.HunterNPC.Blip.Sprite, true)
    end
    
    if Config.Debug then
        print("NPC blip created")
    end
end

-- Function to remove hunter NPC
function RemoveHunterNPC()
    -- Restore player visibility and controls
    if playerHidden then
        SetEntityVisible(PlayerPedId(), true, false)
        DisablePlayerControls(false)
        playerHidden = false
    end
    
    -- Destroy camera
    if isCameraActive and cameraHandle then
        RenderScriptCams(false, false, 0, true, true)
        DestroyCam(cameraHandle, true)
        cameraHandle = nil
        isCameraActive = false
    end
    
    -- Remove blip
    if blipHandle then
        RemoveBlip(blipHandle)
        blipHandle = nil
    end
    
    -- Delete NPC
    if hunterNPC and DoesEntityExist(hunterNPC) then
        SetEntityAsMissionEntity(hunterNPC, false, true)
        DeleteEntity(hunterNPC)
        hunterNPC = nil
    end
    
    -- Reset hunting state
    currentTarget = nil
    isLooting = false
    lootCooldown = 0
    
    if Config.Debug then
        print("Hunter NPC removed")
    end
end

-- Clean up on resource stop
AddEventHandler("onResourceStop", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end
    
    RemoveHunterNPC()
end)

-- Main thread for disabling controls
CreateThread(function()
    while true do
        Wait(0)
        
        if playerHidden and Config.HunterNPC.Player and Config.HunterNPC.Player.DisableControls then
            DisablePlayerControls(true)
        end
    end
end)

-- NPC AI update thread
CreateThread(function()
    while true do
        Wait(500)
        
        if hunterNPC and DoesEntityExist(hunterNPC) and not IsEntityDead(hunterNPC) then
            -- Ensure weapon is equipped
            if Config.HunterNPC.Weapon and Config.HunterNPC.Weapon.WeaponHash then
                if GetCurrentPedWeapon(hunterNPC, 0) ~= Config.HunterNPC.Weapon.WeaponHash then
                    SetCurrentPedWeapon(hunterNPC, Config.HunterNPC.Weapon.WeaponHash, true)
                end
            end

            -- Keep the hunter resilient and active
            if Config.HunterNPC.Health and Config.HunterNPC.Health.MaxHealth then
                local currentHealth = GetEntityHealth(hunterNPC)
                local maxHealth = Config.HunterNPC.Health.MaxHealth
                if currentHealth < maxHealth and GetGameTimer() - lastHealTime > 3000 then
                    SetEntityHealth(hunterNPC, math.min(maxHealth, currentHealth + 50))
                    lastHealTime = GetGameTimer()
                end
            end
            
            UpdateHunterAI()
            
            if huntCooldown > 0 then
                huntCooldown = huntCooldown - 1
            end
        end
    end
end)

-- Function to keep the hunter moving and hunting intelligently
function UpdateHunterAI()
    if not hunterNPC or not DoesEntityExist(hunterNPC) or IsEntityDead(hunterNPC) then
        return
    end

    if currentTarget and DoesEntityExist(currentTarget) then
        if IsEntityDead(currentTarget) then
            currentTarget = nil
            isHunting = false
            isLooting = false
            huntCooldown = 8
            aiState = "patrol"
            SetHunterMovementMode("walk")
            ClearPedTasks(hunterNPC)
            TaskWanderStandard(hunterNPC, 0, 0)
            lastPatrolUpdate = GetGameTimer()
            return
        end

        local npcCoords = GetEntityCoords(hunterNPC)
        local targetCoords = GetEntityCoords(currentTarget)
        local distance = #(npcCoords - targetCoords)
        local shouldRefreshMovement = GetGameTimer() - lastTaskTime > 1200

        if distance < (Config.HunterNPC.AI.EngageDistance or 8.0) then
            aiState = "engaging"
            isHunting = true
            if aiState ~= "engaging" or shouldRefreshMovement then
                SetHunterMovementMode("run")
                TaskCombatPed(hunterNPC, currentTarget, 0, 16)
                lastTaskTime = GetGameTimer()
            end
        elseif distance < (Config.HunterNPC.AI.ApproachDistance or 35.0) then
            aiState = "approaching"
            isHunting = true
            if aiState ~= "approaching" or shouldRefreshMovement then
                local moveMode = distance < 12.0 and "stealth" or "run"
                SetHunterMovementMode(moveMode)
                local speed = moveMode == "stealth" and 1.0 or 2.2
                TaskGoToEntity(hunterNPC, currentTarget, -1, 2.5, speed, 1073741824, 0)
                lastTaskTime = GetGameTimer()
            end
        else
            currentTarget = nil
            aiState = "patrol"
            ChoosePatrolPoint()
        end

        return
    end

    if isLooting then
        if lootCooldown > 0 then
            lootCooldown = lootCooldown - 1
            return
        end

        isLooting = false
        if currentTarget and DoesEntityExist(currentTarget) and not IsEntityDead(currentTarget) then
            Citizen.InvokeNative(0x2B46CA0804B8E1E8, hunterNPC, currentTarget)
        end

        currentTarget = nil
        isHunting = false
        aiState = "patrol"
        ChoosePatrolPoint()
        return
    end

    if huntCooldown > 0 then
        return
    end

    local searchRange = Config.HunterNPC.AI.SearchRange or 100.0
    local npcCoords = GetEntityCoords(hunterNPC)
    local closestAnimal = nil
    local closestDistance = searchRange

    local peds = GetGamePool('CPed')
    for _, ped in ipairs(peds) do
        if DoesEntityExist(ped) and not IsPedAPlayer(ped) and not IsEntityDead(ped) then
            local pedType = GetPedType(ped)
            if pedType == 28 or pedType == 29 then
                local pedCoords = GetEntityCoords(ped)
                local distance = #(npcCoords - pedCoords)

                if distance < closestDistance then
                    closestDistance = distance
                    closestAnimal = ped
                end
            end
        end
    end

    if closestAnimal and closestDistance < searchRange then
        currentTarget = closestAnimal
        if aiState ~= "approaching" then
            aiState = "approaching"
        end
        isHunting = true
        if closestDistance < (Config.HunterNPC.AI.EngageDistance or 8.0) then
            if GetGameTimer() - lastTaskTime > 1200 or aiState ~= "engaging" then
                aiState = "engaging"
                SetHunterMovementMode("run")
                TaskCombatPed(hunterNPC, closestAnimal, 0, 16)
                lastTaskTime = GetGameTimer()
            end
        else
            if GetGameTimer() - lastTaskTime > 1200 or aiState ~= "approaching" then
                local moveMode = closestDistance < 12.0 and "stealth" or "run"
                SetHunterMovementMode(moveMode)
                local speed = moveMode == "stealth" and 1.0 or 2.2
                TaskGoToEntity(hunterNPC, closestAnimal, -1, 2.5, speed, 1073741824, 0)
                lastTaskTime = GetGameTimer()
            end
        end
    else
        if aiState ~= "patrol" then
            aiState = "patrol"
        end

        if GetGameTimer() - lastPatrolUpdate > (Config.HunterNPC.AI.PatrolInterval or 1500) then
            lastPatrolUpdate = GetGameTimer()
            ChoosePatrolPoint()
        end
    end
end

-- Function to pick a new patrol point around the hunter
function SetHunterStealthMode(enabled)
    if not hunterNPC or not DoesEntityExist(hunterNPC) then
        return
    end

    SetPedStealthMovement(hunterNPC, enabled)
end

function SetHunterMovementMode(mode)
    if not hunterNPC or not DoesEntityExist(hunterNPC) then
        return
    end

    if mode == "stealth" then
        SetPedStealthMovement(hunterNPC, true)
    else
        SetPedStealthMovement(hunterNPC, false)
    end
end

function ChoosePatrolPoint()
    if not hunterNPC or not DoesEntityExist(hunterNPC) then
        return
    end

    SetHunterMovementMode("walk")

    local npcCoords = GetEntityCoords(hunterNPC)
    local radius = Config.HunterNPC.AI.PatrolRadius or 35.0

    if patrolDistance <= 0.0 then
        patrolDistance = radius * 0.35
    end

    local headingOffset = patrolHeading or 0.0
    local patrolX = npcCoords.x + math.cos(math.rad(headingOffset)) * patrolDistance
    local patrolY = npcCoords.y + math.sin(math.rad(headingOffset)) * patrolDistance
    local patrolZ = npcCoords.z + 0.5

    patrolHeading = (headingOffset + 45.0) % 360.0
    patrolDistance = patrolDistance + 6.0
    if patrolDistance > radius then
        patrolDistance = radius * 0.25
    end

    TaskGoToCoordAnyMeans(hunterNPC, patrolX, patrolY, patrolZ, 0.8, 0, false, 786603, 0)
    lastTaskTime = GetGameTimer()
end

-- Function to start looting an animal without blocking the main loop
function StartLooting(animal)
    if not hunterNPC or not DoesEntityExist(hunterNPC) or not DoesEntityExist(animal) then
        return
    end

    isLooting = true
    currentTarget = animal
    local cooldownMs = Config.HunterNPC.AI.LootCooldown or 1500
    lootCooldown = math.ceil(cooldownMs / 100)

    SetHunterMovementMode("run")
    TaskGoToEntity(hunterNPC, animal, -1, 1.2, 2.2, 0, 0)
    lastTaskTime = GetGameTimer()

    if Config.Debug then
        print("Hunter approaching animal for looting")
    end
end
