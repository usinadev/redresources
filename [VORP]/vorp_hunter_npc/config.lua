Config = {}

-- Hunter NPC Configuration
Config.HunterNPC = {
    -- NPC Model (use a male hunter model)
    Model = "A_M_M_BOUNTYHUNTER_01",
    
    -- Alternative models to try if main model fails
    AlternativeModels = {
        "CS_BOUNTYHUNTER_01",
        "S_M_M_BOUNTYHUNTER_01",
        "U_M_M_RHD_BOUNTY_01",
        "U_M_M_BHH_01",
        "MP_M_BOUNTYHUNTER_01",
        "A_M_M_BountyHunter_01",
        "A_M_M_Gunslinger_01",
        "A_M_M_Survivalist_01",
        "A_M_M_Rancher_01",
        "A_M_M_Wilderness_01"
    },
    
    -- Spawn Location (relative to player)
    SpawnDistance = 5.0, -- Distance from player to spawn NPC
    SpawnOffset = {
        x = 0.0,
        y = 5.0,
        z = 0.0
    },
    
    -- NPC Heading
    Heading = 180.0,
    
    -- Weapon Configuration
    Weapon = {
        -- Bow weapon hash
        WeaponHash = `WEAPON_BOW`,
        -- Arrow weapon hash
        AmmoHash = `AMMO_ARROW`,
        -- Infinite ammunition
        InfiniteAmmo = true,
        -- Ammo in clip
        AmmoInClip = 100,
        -- Reserve ammo
        ReserveAmmo = 9999
    },
    
    -- AI Behavior
    AI = {
        -- Combat style
        CombatStyle = 0,
        -- Movement speed (0 = still, 1 = walk, 2 = run)
        MovementSpeed = 1,
        -- Accuracy (0-100)
        Accuracy = 100,
        -- Search range for targets
        SearchRange = 200.0,
        -- Combat range
        CombatRange = 30.0,
        -- Patrol update interval (ms) - increased for smoother movement
        PatrolInterval = 100,
        -- Patrol radius around the hunter
        PatrolRadius = 500.0,
        -- Distance at which the hunter starts approaching a target
        ApproachDistance = 35.0,
        -- Distance at which the hunter starts engaging a target
        EngageDistance = 20.0,
        -- Loot cooldown (ms)
        LootCooldown = 1000
    },
    
    -- Camera Settings
    Camera = {
        -- Enable camera focus on NPC
        Enabled = true,
        -- Camera distance from NPC
        Distance = 5.0,
        -- Camera height offset
        HeightOffset = 2.0,
        -- Camera pitch angle (downward tilt)
        Pitch = -15.0,
        -- Camera heading offset (180 = directly behind NPC)
        HeadingOffset = 0.0,
        -- Camera smoothness (0-1, higher = smoother but slower)
        Smoothness = 0.1,
        -- Enable camera switch
        SwitchEnabled = true,
        -- Camera FOV
        FOV = 55.0,
        -- Enable dynamic camera adjustment based on NPC speed
        DynamicAdjustment = true,
        -- Minimum distance when NPC is moving fast
        MinDistance = 4.0,
        -- Maximum distance when NPC is stationary
        MaxDistance = 6.0
    },
    
    -- Player Settings
    Player = {
        -- Hide player character
        HidePlayer = true,
        -- Make player invisible
        MakeInvisible = true,
        -- Disable player controls
        DisableControls = false,
        -- Controls to disable (bitmask)
        DisabledControls = {
            0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31
        }
    },
    
    -- NPC Appearance
    Appearance = {
        -- Random outfit variation
        RandomOutfit = true,
        -- Enable random components
        RandomComponents = true
    },
    
    -- NPC Health and Damage
    Health = {
        -- Max health
        MaxHealth = 500,
        -- Make NPC invincible
        Invincible = false,
        -- Can be damaged
        CanBeDamaged = true
    },
    
    -- Blip Settings
    Blip = {
        -- Show blip on NPC
        ShowBlip = true,
        -- Blip sprite
        Sprite = `blip_mp_bounty_hunter`,
        -- Blip name
        Name = "Hunter NPC"
    }
}

-- Command to spawn hunter NPC
Config.Command = "spawnhunter"

-- Debug mode
Config.Debug = true
