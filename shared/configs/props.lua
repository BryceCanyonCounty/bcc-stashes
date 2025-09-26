Props = {                                        -- Define storage props that can be picked up and placed by players
    p_chest01x = {
        dbname = 'chest1',                       -- Name of db item
        hash = 'p_chest01x',                     -- hash of prop
        containerid = "Stash2-1",                -- Unique Container ID
        ContainerName = "Stash1",                -- Name shown in inventory UI
        limit = 250,                             -- Limit of storage
        JobOnly = false,                         -- Only job can access
        JobRestrictions = {                      -- Job restrictions with individual grade requirements
            unemployed = 0,                      -- Job name = minimum required grade
            offpolice = 2,                       -- Job name = minimum required grade
        },
        Shared = true,                           -- Shared Storage
        NotAllowedItems = true,                  -- Enable Blacklist
        Items = { 'canteen' },                   -- Blacklisted Items
        PickupEmptyOnly = true,                  -- Only allow pickup if chest is empty
    },
    -----------------------------------------------------

    p_chest02x = {
        dbname = 'chest2',                       -- Name of db item
        hash = 'p_chest02x',                     -- hash of prop
        containerid = "Stash2-2",                -- Unique Container ID
        ContainerName = "Stash2",                -- Name shown in inventory UI
        limit = 250,                             -- Limit of storage
        JobOnly = false,                         -- Only job can access
        JobRestrictions = {                      -- Job restrictions with individual grade requirements
            unemployed = 0,                      -- Job name = minimum required grade
            police = 3,                          -- Job name = minimum required grade
            sheriff = 2,                         -- Job name = minimum required grade
        },
        Shared = true,                           -- Shared Storage
        NotAllowedItems = true,                  -- Enable Blacklist
        Items = { 'canteen' },                   -- Blacklisted Items
        PickupEmptyOnly = true,                  -- Only allow pickup if chest is empty
    },
    -----------------------------------------------------
}
