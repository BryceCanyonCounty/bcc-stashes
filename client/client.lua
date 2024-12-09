local BccUtils = exports['bcc-utils'].initiate()

local Chests = {}
-- Table to store created objects
local CreatedObjects = {}

local function LoadAnim(dict)
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do
        Wait(10)
    end
end

if Config.DevMode then
    -- Helper function for debugging
    function devPrint(message)
        print("^1[DEV MODE] ^4" .. message)
    end
else
    -- Define devPrint as a no-op function if DevMode is not enabled
    function devPrint(message)
    end
end

CreateThread(function()
    local PromptGroup = BccUtils.Prompts:SetupPromptGroup()
    local OpenPrompt = PromptGroup:RegisterPrompt(_U("OpenStorage"), BccUtils.Keys[Config.keys.Open], 1, 1, true, 'hold',
        { timedeventhash = "SHORT_TIMED_EVENT" })

    -- Iterate through Config.Spots and create objects dynamically
    for k, v in pairs(Config.Spots) do
        if v.prophash and v.Pos then
            -- Use the prophash and position to create the object
            local Object = BccUtils.Objects:Create(v.prophash, v.Pos.x, v.Pos.y, v.Pos.z - 1, 0, true, 'standard')
            Object:SetHeading(v.StandHeading or 0) -- Use StandHeading if available, default to 0
            CreatedObjects[#CreatedObjects + 1] = Object
            devPrint("Created object for: " .. k .. " at " .. v.Pos.x .. ", " .. v.Pos.y .. ", " .. v.Pos.z)
        else
            devPrint("Missing prophash or position for spot: " .. k)
        end
    end

    -- Main loop for proximity detection and interaction
    while true do
        Wait(0)
        local ped = PlayerPedId()
        local pedpos = GetEntityCoords(ped, true)
        local isDead = IsEntityDead(ped)

        for k, v in pairs(Config.Spots) do
            local distance = GetDistanceBetweenCoords(v.Pos.x, v.Pos.y, v.Pos.z, pedpos.x, pedpos.y, pedpos.z, true)
            if distance < 1.5 and not isDead then
                PromptGroup:ShowGroup(_U("OpenStorage"))
                if OpenPrompt:HasCompleted() then
                    local dict = 'mech_ransack@chest@med@open@crouch@b'
                    LoadAnim(dict)
                    TaskPlayAnim(PlayerPedId(), dict, 'base', 1.0, 1.0, 5000, 17, 1.0, false, false, false)
                    -- Call the server RPC to open the container
                    local response = BccUtils.RPC:CallAsync("bcc-stashes:OpenContainer", {
                        containerid = v.containerid,
                        containername = v.ContainerName,
                        limit = v.limit,
                        JobNames = v.JobName
                    })

                    -- Handle the response from the server
                    if response and response.success then
                        print("[DEBUG] Container opened successfully.")
                    else
                        print("[ERROR] Failed to open container: " .. (response and response.message or "Unknown error"))
                    end
                end
            end
        end
    end
end)

BccUtils.RPC:Register('bcc-stashes:PlaceContainer', function(params, cb)
    local name = params.name
    local hash = params.hash

    -- Fetch the latest stashes from the server
    local result = BccUtils.RPC:CallAsync('bcc-stashes:GetStashes')
    if not result then
        devPrint("[ERROR] Failed to fetch stashes from the server.")
        return cb({ success = false, message = "Failed to fetch stashes from the server." })
    end

    -- Get player position and heading
    local x, y, z = table.unpack(GetOffsetFromEntityInWorldCoords(PlayerPedId(), 0.0, 2.0, -0.5))
    local h = GetEntityHeading(PlayerPedId())

    -- Create the new chest
    local obj = BccUtils.Objects:Create(hash, x, y, z - 1, h, true, 'standard')
    obj:PlaceOnGround(true)
    local tobj = obj:GetObj()
    local objcoords = GetEntityCoords(tobj)

    -- Debugging chest creation
    if not tobj then
        devPrint("[ERROR] Failed to create chest object for Hash: " .. hash)
        return cb({ success = false, message = "Failed to create chest object." })
    end

    devPrint("[DEBUG] Chest created successfully. Entity ID: " .. tostring(tobj))

    -- Add the chest to the local Chests table
    table.insert(Chests, { Entityid = tobj, Hash = hash })
    devPrint("[DEBUG] Chest added to local Chests table. Hash: " .. hash)

    -- Call the server RPC for stash creation or updating
    local response = BccUtils.RPC:CallAsync('bcc-stashes:CreateStash', {
        name = name,
        hash = hash,
        x = objcoords.x,
        y = objcoords.y,
        z = objcoords.z,
        h = h
    })

    -- Handle the response from the server
    if response and response.success then
        devPrint("[DEBUG] Stash created successfully! Stash ID: " .. response.stashId)
        cb({ success = true, message = "Stash created successfully.", stashId = response.stashId })
    else
        devPrint("[ERROR] Failed to create stash: " .. (response and response.message or "Unknown error"))
        cb({ success = false, message = response and response.message or "Failed to create stash." })
    end
end)

RegisterNetEvent('bcc-stashes:StashCreated', function(stashId)
    if stashId then
        for _, chest in pairs(Chests) do
            if DoesEntityExist(chest.Entityid) then
                Entity(chest.Entityid).state:set('id', stashId, true)
                devPrint("[DEBUG] Stash ID " .. stashId .. " assigned to chest entity.")
            end
        end
    else
        devPrint("[ERROR] Received nil Stash ID from server.")
    end
end)

RegisterNetEvent("vorp:SelectedCharacter", function()
    local result = BccUtils.RPC:CallAsync('bcc-stashes:GetStashes')
    if result and #result > 0 then
        for k, v in pairs(result) do
            devPrint("Processing stash ID: " .. v.id .. " PickedUp: " .. tostring(v.pickedup))
            if not v.pickedup then
                local obj = BccUtils.Objects:Create(v.propname, v.x, v.y, v.z, v.h, true, 'standard')

                obj:PlaceOnGround(true)

                local entity = obj:GetObj()
                if entity then
                    Entity(entity).state:set('id', v.id, true)
                    table.insert(Chests, { Entityid = entity, Hash = v.propname })

                    local response = BccUtils.RPC:CallAsync('bcc-stashes:registerInventory', {
                        containerId = v.id,
                        hash = v.propname
                    })

                    if response and response.success then
                        devPrint("Stash ID " .. v.id .. " has been loaded into Chests and inventory registered.")
                    else
                        devPrint("[ERROR] Failed to register inventory for stash ID: " ..
                            v.id .. ". Message: " .. (response and response.message or "Unknown error"))
                    end
                else
                    devPrint("Failed to create entity for stash ID: " .. v.id)
                end
            else
                devPrint("Skipping stash with ID: " .. v.id .. " as it has been picked up.")
            end
        end
    else
        devPrint("No stashes returned from the server.")
    end
end)

CreateThread(function()
    local PromptGroup = BccUtils.Prompts:SetupPromptGroup()
    local PickUpPrompt = PromptGroup:RegisterPrompt(_U("PickUpStorage"), BccUtils.Keys[Config.keys.Pickup], 1, 1, true,
        'hold', { timedeventhash = "SHORT_TIMED_EVENT" })
    local OpenPrompt = PromptGroup:RegisterPrompt(_U("OpenStorage"), BccUtils.Keys[Config.keys.Open], 1, 1, true, 'hold',
        { timedeventhash = "SHORT_TIMED_EVENT" })

    while true do
        Wait(0)
        local pcoords = GetEntityCoords(PlayerPedId())
        local isDead = IsEntityDead(PlayerPedId())

        for _, chest in pairs(Chests) do
            local propcoords = GetEntityCoords(chest.Entityid)
            local distance = #(pcoords - propcoords)

            -- Highlight nearby entities
            Citizen.InvokeNative(0xA22712E8471AA08E, chest.Entityid, distance < 2.5, true)

            if distance < 2.5 and not isDead then
                PromptGroup:ShowGroup(_U("StorageOptions"))
                if OpenPrompt:HasCompleted() then
                    local dict = 'mech_ransack@chest@med@open@crouch@b'
                    LoadAnim(dict)
                    TaskPlayAnim(PlayerPedId(), dict, 'base', 1.0, 1.0, 5000, 17, 1.0, false, false, false)

                    -- Use Call for open interaction
                    BccUtils.RPC:Call("bcc-stashes:OpenPropStash", {
                        containerid = Entity(chest.Entityid).state.id,
                        JobNames = Config.Props[chest.Hash].JobName,
                        propHash = chest.Hash
                    }, function(response)
                        if response and response.success then
                            print("[DEBUG] Inventory opened successfully for container ID:",
                                Entity(chest.Entityid).state.id)
                        else
                            print("[ERROR] Failed to open inventory for container ID:",
                                response and response.message or "Unknown error")
                        end
                    end)
                elseif PickUpPrompt:HasCompleted() then
                    local chestId = Entity(chest.Entityid).state.id
                    if not chestId then
                        print("[ERROR] Chest ID is nil for Entity ID:", chest.Entityid)
                        return
                    end

                    local response = BccUtils.RPC:CallAsync("bcc-stashes:ValidateAndPickupChest", {
                        chestId = chestId
                    })

                    -- Handle the response from the server
                    if response and response.success then
                        print("[DEBUG] Chest pickup initiated for Chest ID:", chestId)
                    else
                        print("[ERROR] Failed to pick up chest:", response and response.message or "Unknown error")
                    end
                end
            end
        end
    end
end)

BccUtils.RPC:Register("bcc-stashes:PickUpChest", function(params, cb)
    local chestId = params.chestId
    local playerPed = PlayerPedId()

    -- Debug: Log the chestId being picked up
    devPrint("[DEBUG] Picking up chest with ID: " .. tostring(chestId))

    -- Find the chest entity
    local chestEntity = nil
    for _, chest in pairs(Chests) do
        local entityStateId = Entity(chest.Entityid).state.id
        devPrint("[DEBUG] Checking chest with Entity ID: " ..
            tostring(chest.Entityid) .. ", State ID: " .. tostring(entityStateId))

        if entityStateId == chestId then
            chestEntity = chest
            break
        end
    end

    if chestEntity then
        -- Debug: Log the found chest details
        devPrint("[DEBUG] Found chest to pick up. Entity ID: " .. tostring(chestEntity.Entityid))

        -- Remove the chest prop
        if DoesEntityExist(chestEntity.Entityid) then
            DeleteObject(chestEntity.Entityid)
            devPrint("[DEBUG] Chest prop deleted successfully.")
        else
            devPrint("[WARNING] Chest prop does not exist.")
        end

        -- Get new coordinates and heading
        local newCoords = GetOffsetFromEntityInWorldCoords(playerPed, 0.0, 2.0, -0.5)
        local heading = GetEntityHeading(playerPed)
        devPrint("[DEBUG] New coordinates for chest: " .. json.encode(newCoords) .. ", Heading: " .. tostring(heading))

        -- Call the server RPC to update location and add item back to inventory
        local response = BccUtils.RPC:CallAsync("bcc-stashes:PickupChestServer",
            { chestId = chestId, chestHash = chestEntity.Hash, newCoords = newCoords, heading = heading })

        -- Process the response from the server
        if response and response.success then
            devPrint("[DEBUG] Chest successfully picked up. Item added to inventory: " .. response.item)

            -- Remove from local list
            for i, chest in ipairs(Chests) do
                if chest.Entityid == chestEntity.Entityid then
                    table.remove(Chests, i)
                    devPrint("[DEBUG] Chest removed from local list. Entity ID: " .. tostring(chestEntity.Entityid))
                    break
                end
            end
            cb({ success = true, message = "Chest successfully picked up." })
        else
            devPrint("[ERROR] Failed to pick up chest: " .. (response and response.message or "Unknown error"))
            cb({ success = false, message = response and response.message or "Failed to pick up chest." })
        end
    else
        devPrint("[ERROR] Chest not found in local list for ID: " .. tostring(chestId))
        cb({ success = false, message = "Chest not found in local list." })
    end
end)

RegisterNetEvent('onResourceStop', function()
    -- Remove all chests
    for _, chest in ipairs(Chests) do
        if DoesEntityExist(chest.Entityid) then
            DeleteObject(chest.Entityid) -- Properly delete the entity
        end
    end

    -- Remove all created objects
    for _, stand in ipairs(CreatedObjects) do
        if DoesEntityExist(stand) then
            DeleteObject(stand) -- Properly delete the entity
        end
    end
end)
