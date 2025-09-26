Spots = {                                        -- Define permanent storage spots
    teststorage1 = {
        coords = vec3(-325.26, 766.19, 121.65),  -- Storage location
        heading = 180.0,                         -- Heading of prop
        containerid = "Testing2",                -- Unique Container ID
        ContainerName = "Stash",                 -- Name shown in inventory UI
        limit = 250,                             -- Limit of storage Slots
        JobOnly = false,                         -- Only job can access
        JobRestrictions = {                      -- Job restrictions with individual grade requirements
            unemployed = 0,                      -- Job name = minimum required grade
            offpolice = 2,                       -- Job name = minimum required grade
        },
        Shared = true,                           -- Shared Storage
        NotAllowedItems = true,                  -- Enable Blacklist
        Items = { 'canteen' },                   -- Blacklisted Items
        prophash = "p_chestmedhunt01x"           -- Prop hash for the object
    },
    -----------------------------------------------------

    teststorage2 = {
        coords = vec3(-326.89, 775.05, 121.64), -- Storage location
        heading = 180.0,                        -- Heading of prop
        containerid = "TestStorage2-2",         -- Unique Container ID
        ContainerName = "test Storage",         -- Name shown in inventory UI
        limit = 250,                            -- Limit of storage Slots
        JobOnly = false,                        -- Only job can access
        JobRestrictions = {                      -- Job restrictions with individual grade requirements
            sheriff = 3,                         -- Job name = minimum required grade
            police = 2,                          -- Job name = minimum required grade
        },
        Shared = true,                          -- Shared Storage
        NotAllowedItems = false,                -- Enable Blacklist
        Items = {},                             -- Blacklisted Items
        prophash = "p_chestmedhunt01x"          -- Prop hash for the object
    },
    -----------------------------------------------------
}
