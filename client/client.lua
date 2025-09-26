local BccUtils = exports['bcc-utils'].initiate()

---@type BCCStashesDebugLib
local DBG = BCCStashesDebug

local Chests = {}
local CreatedObjects = {}

local function LoadAnim(animDict)
    if HasAnimDictLoaded(animDict) then return end

    RequestAnimDict(animDict)
    local timeout = 10000
    local startTime = GetGameTimer()

    while not HasAnimDictLoaded(animDict) do
        if GetGameTimer() - startTime > timeout then
            DBG.Warning('Failed to load dictionary: ' .. animDict)
            return
        end
        Wait(10)
    end
end

CreateThread(function()
    local SpotGroup = BccUtils.Prompts:SetupPromptGroup()
    local OpenSpotPrompt = SpotGroup:RegisterPrompt(_U("OpenStorage"), BccUtils.Keys[Config.keys.Open], 1, 1, true, 'hold',
        { timedeventhash = "SHORT_TIMED_EVENT" })

    -- Iterate through Spots and create objects dynamically
    for k, v in pairs(Spots) do
        if v.prophash and v.coords then
            -- Use the prophash and position to create the object
            local Object = BccUtils.Objects:Create(v.prophash, v.coords.x, v.coords.y, v.coords.z - 1, 0, true, 'standard')
            Object:SetHeading(v.heading or 0) -- Use heading if available, default to 0
            CreatedObjects[#CreatedObjects + 1] = Object
            DBG.Info("Created object for: " .. k .. " at " .. v.coords.x .. ", " .. v.coords.y .. ", " .. v.coords.z)
        else
            DBG.Warning("Missing prophash or position for spot: " .. k)
        end
    end

    -- Main loop for proximity detection and interaction
    while true do
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed, true)
        local sleep = 1000

        if IsEntityDead(playerPed) then
            Wait(1000)
            goto END
        end

        for _, spotCfg in pairs(Spots) do
            local distance = #(spotCfg.coords - playerCoords)
            if distance < 1.5 then
                sleep = 0
                SpotGroup:ShowGroup(_U("OpenStorage"))
                if OpenSpotPrompt:HasCompleted() then
                    -- Call the server RPC to open the container first (job check)
                    local response = BccUtils.RPC:CallAsync("bcc-stashes:OpenContainer", {
                        containerid = spotCfg.containerid,
                        containername = spotCfg.ContainerName,
                        limit = spotCfg.limit,
                        JobRestrictions = spotCfg.JobRestrictions,
                        isShare = spotCfg.Shared
                    })

                    -- Only play animation if job restrictions are met
                    if response and response.success then
                        local dict = 'mech_ransack@chest@med@open@crouch@b'
                        LoadAnim(dict)
                        TaskPlayAnim(playerPed, dict, 'base', 1.0, 1.0, 5000, 17, 1.0, false, false, false)
                    end

                    -- Handle the response from the server
                    if response and response.success then
                        DBG.Info("Container opened successfully.")
                    else
                        DBG.Warning("Failed to open container: " .. (response and response.message or "Unknown error"))
                    end
                end
            end
        end
        ::END::
        Wait(sleep)
    end
end)

BccUtils.RPC:Register('bcc-stashes:PlaceContainer', function(params, cb)
    local name = params.name
    local hash = params.hash

    -- Fetch the latest stashes from the server
    local result = BccUtils.RPC:CallAsync('bcc-stashes:GetStashes')
    if not result then
        DBG.Warning("Failed to fetch stashes from the server.")
        return cb({ success = false, message = "Failed to fetch stashes from the server." })
    end

    -- Get player position and heading
    local x, y, z = table.unpack(GetOffsetFromEntityInWorldCoords(PlayerPedId(), 0.0, 2.0, -0.5))
    local h = GetEntityHeading(PlayerPedId())

    -- Create the new chest
    local obj = BccUtils.Objects:Create(hash, x, y, z - 1, h, true, 'standard')
    obj:PlaceOnGround(true)
    local tobj = obj:GetObj()

    -- Debugging chest creation
    if not tobj then
        DBG.Error("Failed to create chest object for Hash: " .. hash)
        return cb({ success = false, message = "Failed to create chest object." })
    end

    local objcoords = GetEntityCoords(tobj)

    DBG.Info("Chest created successfully. Entity ID: " .. tostring(tobj))

    -- Add the chest to the local Chests table
    table.insert(Chests, { Entityid = tobj, Hash = hash })
    DBG.Info("Chest added to local Chests table. Hash: " .. hash)

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
        DBG.Info("Stash created successfully! Stash ID: " .. response.stashId)

        -- Set the state ID immediately on the chest entity
        Entity(tobj).state:set('id', response.stashId, true)
        DBG.Info("State ID " .. response.stashId .. " set on chest entity " .. tostring(tobj))

        -- Register the inventory for this newly created stash
        local registerResponse = BccUtils.RPC:CallAsync('bcc-stashes:registerInventory', {
            containerId = response.stashId,
            hash = hash
        })

        if registerResponse and registerResponse.success then
            DBG.Info("Inventory registered successfully for stash ID: " .. response.stashId)
        else
            DBG.Warning("Failed to register inventory for stash ID: " .. response.stashId .. ". Message: " .. (registerResponse and registerResponse.message or "Unknown error"))
        end

        cb({ success = true, message = "Stash created successfully.", stashId = response.stashId })
    else
        DBG.Error("Failed to create stash: " .. (response and response.message or "Unknown error"))
        cb({ success = false, message = response and response.message or "Failed to create stash." })
    end
end)

RegisterNetEvent('bcc-stashes:StashCreated', function(stashId)
    if not stashId then
        DBG.Warning("Received nil Stash ID from server.")
        return
    end

    for _, chest in pairs(Chests) do
        if DoesEntityExist(chest.Entityid) then
            Entity(chest.Entityid).state:set('id', stashId, true)
            DBG.Info("Stash ID " .. stashId .. " assigned to chest entity.")
        end
    end
end)

RegisterNetEvent("vorp:SelectedCharacter", function()
    local result = BccUtils.RPC:CallAsync('bcc-stashes:GetStashes')
    if not result and #result <= 0 then
        DBG.Info("No stashes returned from the server.")
        return
    end

    for _, v in pairs(result) do
        DBG.Info("Processing stash ID: " .. v.id .. " PickedUp: " .. tostring(v.pickedup))
        if v.pickedup then
            DBG.Info("Skipping stash with ID: " .. v.id .. " as it has been picked up.")
            goto continue
        end

        local obj = BccUtils.Objects:Create(v.propname, v.x, v.y, v.z, v.h, true, 'standard')

        obj:PlaceOnGround(true)

        local entity = obj:GetObj()
        if not entity then
            DBG.Warning("Failed to create entity for stash ID: " .. v.id)
            goto continue
        end

        Entity(entity).state:set('id', v.id, true)
        table.insert(Chests, { Entityid = entity, Hash = v.propname })

        local response = BccUtils.RPC:CallAsync('bcc-stashes:registerInventory', {
            containerId = v.id,
            hash = v.propname
        })

        if response and response.success then
            DBG.Info("Stash ID " .. v.id .. " has been loaded into Chests and inventory registered.")
        else
            DBG.Warning("Failed to register inventory for stash ID: " ..
                v.id .. ". Message: " .. (response and response.message or "Unknown error"))
        end

        ::continue::
    end
end)

CreateThread(function()
    local PropGroup = BccUtils.Prompts:SetupPromptGroup()
    local PickUpPrompt = PropGroup:RegisterPrompt(_U("PickUpStorage"), BccUtils.Keys[Config.keys.Pickup], 1, 1, true,
        'hold', { timedeventhash = "SHORT_TIMED_EVENT" })
    local OpenPropPrompt = PropGroup:RegisterPrompt(_U("OpenStorage"), BccUtils.Keys[Config.keys.Open], 1, 1, true, 'hold',
        { timedeventhash = "SHORT_TIMED_EVENT" })

    while true do
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        local sleep = 1000

        if IsEntityDead(playerPed) then
            Wait(1000)
            goto END
        end

        for _, chest in pairs(Chests) do
            -- Skip chests that don't have a valid entity or state ID
            if not chest.Entityid or not DoesEntityExist(chest.Entityid) then
                DBG.Warning("Skipping invalid chest entity in Chests table")
                goto NEXT
            end

            -- Check if this chest has a state ID (only dynamically created chests should)
            local containerId = Entity(chest.Entityid).state.id
            if not containerId then
                DBG.Warning("Skipping chest without state ID - Entity ID: " ..
                tostring(chest.Entityid) .. ", Hash: " .. tostring(chest.Hash))
                goto NEXT
            end

            local propcoords = GetEntityCoords(chest.Entityid)
            local distance = #(playerCoords - propcoords)

            -- Highlight nearby entities
            Citizen.InvokeNative(0xA22712E8471AA08E, chest.Entityid, distance < 2.5, true)

            if distance < 2.5 then
                sleep = 0
                PropGroup:ShowGroup(_U("StorageOptions"))
                if OpenPropPrompt:HasCompleted() then
                    -- Use Call for open interaction (check job restrictions first)
                    BccUtils.RPC:Call("bcc-stashes:OpenPropStash", {
                        containerid = containerId,
                        JobRestrictions = Props and Props[chest.Hash] and Props[chest.Hash].JobRestrictions or nil,
                        propHash = chest.Hash
                    }, function(response)
                        if response and response.success then
                            -- Only play animation if job restrictions are met
                            local dict = 'mech_ransack@chest@med@open@crouch@b'
                            LoadAnim(dict)
                            TaskPlayAnim(PlayerPedId(), dict, 'base', 1.0, 1.0, 5000, 17, 1.0, false, false, false)
                            DBG.Info("Inventory opened successfully for container ID: " .. containerId)
                        else
                            DBG.Warning("Failed to open inventory for container ID: " .. containerId .. ", " ..
                                (response and response.message or "Unknown error"))
                        end
                    end)
                elseif PickUpPrompt:HasCompleted() then
                    -- Check if this chest type has PickupEmptyOnly restriction
                    local pickupEmptyOnly = Props and Props[chest.Hash] and Props[chest.Hash].PickupEmptyOnly or false

                    if pickupEmptyOnly then
                        DBG.Info("Checking if chest is empty before pickup - Chest ID: " .. containerId)

                        -- First check with server if chest is empty
                        local emptyCheckResponse = BccUtils.RPC:CallAsync("bcc-stashes:CheckChestEmpty", {
                            chestId = containerId
                        })

                        if emptyCheckResponse and emptyCheckResponse.isEmpty then
                            -- Chest is empty, proceed with pickup
                            DBG.Info("Chest is empty, proceeding with pickup")
                            local response = BccUtils.RPC:CallAsync("bcc-stashes:ValidateAndPickupChest", {
                                chestId = containerId
                            })

                            -- Handle the response from the server
                            if response and response.success then
                                DBG.Info("Chest pickup initiated for Chest ID: " .. containerId)
                            else
                                DBG.Warning("Failed to pick up chest: " ..
                                (response and response.message or "Unknown error"))
                            end
                        else
                            -- Chest is not empty or check failed
                            local message = emptyCheckResponse and emptyCheckResponse.message or
                            "Chest must be empty before pickup."
                            DBG.Warning("Cannot pickup chest: " .. message)
                        end
                    else
                        -- No PickupEmptyOnly restriction, proceed normally
                        local response = BccUtils.RPC:CallAsync("bcc-stashes:ValidateAndPickupChest", {
                            chestId = containerId
                        })

                        -- Handle the response from the server
                        if response and response.success then
                            DBG.Info("Chest pickup initiated for Chest ID: " .. containerId)
                        else
                            DBG.Warning("Failed to pick up chest: " .. (response and response.message or "Unknown error"))
                        end
                    end
                end
            end
            ::NEXT::
        end
        ::END::
        Wait(sleep)
    end
end)

BccUtils.RPC:Register("bcc-stashes:PickUpChest", function(params, cb)
    local chestId = params.chestId
    local playerPed = PlayerPedId()

    -- Debug: Log the chestId being picked up
    DBG.Info("Picking up chest with ID: " .. tostring(chestId))

    -- Find the chest entity
    local chestEntity = nil
    for _, chest in pairs(Chests) do
        local entityStateId = Entity(chest.Entityid).state.id
        DBG.Info("Checking chest with Entity ID: " ..
            tostring(chest.Entityid) .. ", State ID: " .. tostring(entityStateId))

        if entityStateId == chestId then
            chestEntity = chest
            break
        end
    end

    if chestEntity then
        -- Debug: Log the found chest details
        DBG.Info("Found chest to pick up. Entity ID: " .. tostring(chestEntity.Entityid))

        -- Remove the chest prop
        if DoesEntityExist(chestEntity.Entityid) then
            DeleteObject(chestEntity.Entityid)
            DBG.Info("Chest prop deleted successfully.")
        else
            DBG.Warning("Chest prop does not exist.")
        end

        -- Get new coordinates and heading
        local newCoords = GetOffsetFromEntityInWorldCoords(playerPed, 0.0, 2.0, -0.5)
        local heading = GetEntityHeading(playerPed)
        DBG.Info("New coordinates for chest: " .. json.encode(newCoords) .. ", Heading: " .. tostring(heading))

        -- Call the server RPC to update location and add item back to inventory
        local response = BccUtils.RPC:CallAsync("bcc-stashes:PickupChestServer",
            { chestId = chestId, chestHash = chestEntity.Hash, newCoords = newCoords, heading = heading })

        -- Process the response from the server
        if response and response.success then
            DBG.Info("Chest successfully picked up. Item added to inventory: " .. response.item)

            -- Remove from local list
            for i, chest in ipairs(Chests) do
                if chest.Entityid == chestEntity.Entityid then
                    table.remove(Chests, i)
                    DBG.Info("Chest removed from local list. Entity ID: " .. tostring(chestEntity.Entityid))
                    break
                end
            end
            cb({ success = true, message = "Chest successfully picked up." })
        else
            DBG.Warning("Failed to pick up chest: " .. (response and response.message or "Unknown error"))
            cb({ success = false, message = response and response.message or "Failed to pick up chest." })
        end
    else
        DBG.Warning("Chest not found in local list for ID: " .. tostring(chestId))
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
        local entityId = stand:GetObj()
        if entityId and DoesEntityExist(entityId) then
            DeleteObject(entityId) -- Properly delete the entity
        end
    end
end)
