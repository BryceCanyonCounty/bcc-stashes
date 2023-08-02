Config = {}

Config.defaultlang = 'en'

Spots = {
    teststorage1 = {
        Pos = { x = -325.26, y = 766.19, z = 121.65 }, -- Coords in X,Y,Z
        containerid = "TestStorage1-2",                --Unique Container ID
        ContainerName = "Stash",                       --Name shown in inventory UI
        JobOnly = true,                                --Only job can access
        JobName = { 'unemployed', 'offpolice' },       --Job names must go inside {} ie {'unemployed'} or {'police','sheriff'}
        JobGrades = 3,                                 -- If using Job Only, Job grade must be this rank or higher to access
        Shared = true,                                 -- Shared Storage
        NotAllowedItems = true,                        --Blacklist below items, Not in use yet
        Items = { 'canteen' },                         --Blacklisted Items
        limit = 100

    },
    teststorage2 = {
        Pos = { x = -326.89, y = 775.05, z = 121.64 }, -- Coords in X,Y,Z
        containerid = "TestStorage2-2",                --Unique Container ID
        ContainerName = "test Storage",                --Name shown in inventory UI
        JobOnly = true,                                --Only job can access
        JobName = { 'sheriff', 'police' },             --Job names must go inside {} ie {'unemployed'} or {'police','sheriff'}
        JobGrades = 3,                                 -- If using Job Only, Job grade must be this rank or higher to access
        Shared = true,                                 -- Shared Storage
        NotAllowedItems = false,                       --Blacklist below items,Not in use yet
        Items = {},                                     --Blacklisted Items
        limit = 100

    },
}

Config.WebhookInfo = {
    Title = 'BCC Stashes',
    Webhook =
    'https://discord.com/api/webhooks/1011401671634583552/WAjupdiElzJHysLvvK4eydtMs0EAXuRy18FVNi_GPzfpEczng_U7pBCAmiPTKxUiA2TS',
    -- Color = '',
    -- Name = '',
    -- Logo = '',
    -- FooterLogo = '',
    -- Avatar = '',
}
