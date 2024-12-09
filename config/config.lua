Config = {
    DevMode = false, --False on live server

    defaultlang = 'en_lang',

    keys = {
        Pickup = "G", --Pickup Chest prompt
        Open = "B"    -- Open Chest prompt
    },

    WebhookEnable = false,
    WebhookTitle = 'BCC-Stashes',
    WebhookLink = '',
    WebhookAvatar = '',

    Spots = {
        teststorage1 = {
            Pos = { x = -325.26, y = 766.19, z = 121.65 }, -- Coords in X,Y,Z
            containerid = "Testing2",                      --Unique Container ID
            ContainerName = "Stash",                       --Name shown in inventory UI
            limit = 250,                                   --Limit of storage
            JobOnly = false,                                --Only job can access
            JobName = { 'unemployed', 'offpolice' },       --Job names must go inside {} ie {'unemployed'} or {'police','sheriff'}
            JobGrades = 3,                                 -- If using Job Only, Job grade must be this rank or higher to access
            Shared = true,                                 -- Shared Storage
            NotAllowedItems = true,                        --Blacklist below items, Not in use yet
            Items = { 'canteen' },                         --Blacklisted Items
            prophash = "p_chestmedhunt01x"                 -- Prop hash for the object
        },

        teststorage2 = {
            Pos = { x = -326.89, y = 775.05, z = 121.64 }, -- Coords in X,Y,Z
            containerid = "TestStorage2-2",                --Unique Container ID
            ContainerName = "test Storage",                --Name shown in inventory UI
            limit = 250,                                   --Limit of storage
            JobOnly = false,                                --Only job can access
            JobName = { 'sheriff', 'police' },             --Job names must go inside {} ie {'unemployed'} or {'police','sheriff'}
            JobGrades = 3,                                 -- If using Job Only, Job grade must be this rank or higher to access
            Shared = true,                                 -- Shared Storage
            NotAllowedItems = false,                       --Blacklist below items,Not in use yet
            Items = {},                                    --Blacklisted Items
            prophash = "p_chestmedhunt01x"                 -- Prop hash for the object},
        },
    },

    Props = {
        p_chest01x =                                 -- hash of prop
        {
            dbname = 'chest1',                       ---Name of db item
            hash = 'p_chest01x',                     -- hash of prop
            containerid = "Stash2-1",                --Unique Container ID
            ContainerName = "Stash1",                --Name shown in inventory UI
            limit = 250,                             --Limit of storage
            JobOnly = false,                         --Only job can access
            JobName = { 'unemployed', 'offpolice' }, --Job names must go inside {} ie {'unemployed'} or {'police','sheriff'}
            JobGrades = 3,                           -- If using Job Only, Job grade must be this rank or higher to access
            Shared = true,                           -- Shared Storage
            NotAllowedItems = true,                  --Blacklist below items
            Items = { 'canteen' }
        },

        p_chest02x =                                 -- hash of prop
        {
            dbname = 'chest2',                       ---Name of db item
            hash = 'p_chest02x',                     -- hash of prop
            containerid = "Stash2-2",                --Unique Container ID
            ContainerName = "Stash2",                --Name shown in inventory UI
            limit = 250,                             --Limit of storage
            JobOnly = false,                         --Only job can access
            JobName = { 'unemployed', 'offpolice' }, --Job names must go inside {} ie {'unemployed'} or {'police','sheriff'}
            JobGrades = 3,                           -- If using Job Only, Job grade must be this rank or higher to access
            Shared = true,                           -- Shared Storage
            NotAllowedItems = true,                  --Blacklist below items
            Items = { 'canteen' }
        },
    }
}
