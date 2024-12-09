local Core = exports.vorp_core:GetCore()
local BccUtils = exports['bcc-utils'].initiate()
local Discord = BccUtils.Discord.setup(Config.WebhookLink, Config.WebhookTitle, Config.WebhookAvatar)
local Crypt = exports['bcc-crypt'].install()

if Config.DevMode then
    -- Helper function for debugging
    function devPrint(message)
        print("^1[DEV MODE] ^4" .. message .. "^0")
    end
else
    -- Define devPrint as a no-op function if DevMode is not enabled
    function devPrint(message) end
end

JobOnly, Jobs, JobGrades, Uuid = nil, {}, nil, nil

for k, v in pairs(Config.Props) do
    exports.vorp_inventory:registerUsableItem(v.dbname, function(data)
        local _source = data.source

        devPrint("Usable item triggered for " .. v.dbname .. " by source: " .. tostring(_source))

        -- Check if the player has the item
        local itemCount = exports.vorp_inventory:getItemCount(_source, nil, v.dbname)
        devPrint("Item count for " .. v.dbname .. ": " .. tostring(itemCount))
        if itemCount > 0 then
            -- Remove the item from inventory
            exports.vorp_inventory:subItem(_source, v.dbname, 1)
            devPrint("Item " .. v.dbname .. " removed from inventory.")

            -- Notify the player
            Core.NotifyAvanced(_source, _U('usedContainerItem'), "menu_textures", "item_chest", "COLOR_GREEN", 3000)

            -- Trigger the client RPC to place the container
            local response = BccUtils.RPC:CallAsync('bcc-stashes:PlaceContainer', {
                name = v.ContainerName,
                hash = v.hash
            }, _source)

            if response and response.success then
                devPrint("Container successfully placed: " .. v.ContainerName)
            else
                devPrint("[ERROR] Failed to place container: " .. (response and response.message or "Unknown error"))
            end
        else
            -- Notify the player if they don't have the item
            Core.NotifyAvanced(_source, _U('dontHaveContainerItem'), "menu_textures", "item_lockbox", "COLOR_RED", 3000)
            devPrint("Player does not have the item: " .. v.dbname)
        end

        -- Close inventory after the item is used
        exports.vorp_inventory:closeInventory(_source)
        devPrint("Inventory closed for source: " .. tostring(_source))
    end)
end

-- Register inventory
BccUtils.RPC:Register('bcc-stashes:registerInventory', function(params, cb, recSource)
    local containerId = params.containerId
    local hash = params.hash

    devPrint("Register inventory triggered for containerId: " .. tostring(containerId) .. " hash: " .. tostring(hash))

    -- Validate hash exists in the configuration
    if not Config.Props[hash] then
        devPrint("[ERROR] Hash not found in configuration: " .. tostring(hash))
        return cb({ success = false, message = "Invalid hash provided." })
    end

    local data = {
        id = containerId,
        name = Config.Props[hash].ContainerName,
        limit = Config.Props[hash].limit,
        acceptWeapons = true,
        shared = false,
        ignoreItemStackLimit = true,
        whitelistItems = false,
        UsePermissions = false,
        UseBlackList = false,
        whitelistWeapons = false
    }

    -- Apply shared and blacklist logic based on the configuration
    if Config.Props[hash].Shared then
        if Config.Props[hash].NotAllowedItems then
            data.shared = true
            data.UseBlackList = true
        else
            data.shared = true
        end
    else
        if Config.Props[hash].NotAllowedItems then
            data.UseBlackList = true
        end
    end

    -- Register the inventory
    exports.vorp_inventory:registerInventory(data)
    devPrint("Inventory registered for container: " .. tostring(containerId))

    -- Return success to the client
    cb({ success = true, message = "Inventory registered successfully." })
end)

-- Create stash
BccUtils.RPC:Register('bcc-stashes:CreateStash', function(params, cb, recSource)
    local Character = Core.getUser(recSource).getUsedCharacter
    if not Character then
        devPrint("[ERROR] Failed to retrieve character data for source: " .. tostring(recSource))
        return cb({ success = false, message = "Character not found." })
    end

    local charid = Character.charIdentifier
    local name = params.name
    local hash = params.hash
    local x = params.x
    local y = params.y
    local z = params.z
    local h = params.h

    devPrint("Creating stash for CharID: " .. tostring(charid) .. ", Hash: " .. tostring(hash))

    local stashId
    local existingStash = MySQL.query.await("SELECT * FROM stashes WHERE charid = @charid AND pickedup = 1;", {
        ['charid'] = charid
    })

    if existingStash and #existingStash > 0 then
        stashId = existingStash[1].id
        devPrint("Reusing existing stash ID: " .. stashId)

        local updateResult = MySQL.query.await("UPDATE stashes SET x = @x, y = @y, z = @z, h = @h, pickedup = 0 WHERE id = @id;", {
            ['id'] = stashId,
            ['x'] = x,
            ['y'] = y,
            ['z'] = z,
            ['h'] = h
        })
        if updateResult and updateResult.affectedRows > 0 then
            devPrint("Successfully updated existing stash. Stash ID: " .. tostring(stashId))
        else
            devPrint("[ERROR] Failed to update existing stash location. Stash ID: " .. tostring(stashId))
            return cb({ success = false, message = "Failed to update existing stash." })
        end
    else
        stashId = Crypt.uuid4()
        devPrint("Creating new stash ID: " .. tostring(stashId))

        local insertResult = MySQL.query.await("INSERT INTO stashes (`id`, `charid`, `name`, `propname`, `x`, `y`, `z`, `h`, `pickedup`) VALUES (@id, @charid, @name, @propname, @x, @y, @z, @h, 0);", {
            ['id'] = stashId,
            ['charid'] = charid,
            ['name'] = name,
            ['propname'] = hash,
            ['x'] = x,
            ['y'] = y,
            ['z'] = z,
            ['h'] = h
        })
        if insertResult then
            devPrint("New stash created in the database. Stash ID: " .. tostring(stashId))
        else
            devPrint("[ERROR] Failed to insert new stash into the database.")
            return cb({ success = false, message = "Failed to create new stash." })
        end
    end

    -- Notify the client about the stash creation
    --TriggerClientEvent('bcc-stashes:StashCreated', recSource, stashId)
    Core.NotifyAvanced(recSource, _U('stashCreationSuccess'), "menu_textures", "stamp_locked", "COLOR_GREEN", 4000)

    return cb({ success = true, message = "Stash created successfully.", stashId = stashId })
end)


BccUtils.RPC:Register("bcc-stashes:NotifyStashCreated", function(params, cb, recSource)
    local stashId = params.stashId

    if not stashId then
        devPrint("[ERROR] Received nil Stash ID from client.")
        return cb({ success = false, message = "Stash ID is nil." })
    end

    devPrint("[DEBUG] Notifying client about stash creation. Stash ID: " .. tostring(stashId))

    -- Notify the client to handle stash creation
    cb({ success = true, stashId = stashId, message = "Client notified successfully." })
end)


BccUtils.RPC:Register("bcc-stashes:PickupChestServer", function(params, cb, recSource)
    local chestId = params.chestId
    local chestHash = params.chestHash

    devPrint("Attempting to mark chest as picked up. Chest ID: " .. tostring(chestId))

    local param = {
        ['id'] = chestId,
        ['pickedup'] = 1
    }

    local result = MySQL.query.await("UPDATE stashes SET pickedup = @pickedup WHERE id = @id", param)

    if result and result.affectedRows > 0 then
        devPrint("Successfully marked chest as picked up. Chest ID: " .. tostring(chestId))

        local itemName = nil
        for k, v in pairs(Config.Props) do
            if v.hash == chestHash then
                itemName = v.dbname
                break
            end
        end

        if itemName then
            exports.vorp_inventory:addItem(recSource, itemName, 1)
            devPrint("Chest item added to inventory: " .. itemName)
            Core.NotifyAvanced(recSource, _U("chestPickedUp"), "menu_textures", "item_chest", "COLOR_GREEN", 3000)
            cb({ success = true, message = "Chest picked up successfully.", item = itemName }) -- Successful callback
        else
            devPrint("[ERROR] Chest item not found in configuration for hash: " .. tostring(chestHash))
            Core.NotifyAvanced(recSource, _U("chestItemNotFound"), "menu_textures", "item_lockbox", "COLOR_RED", 3000)
            cb({ success = false, message = "Chest item not found in configuration." }) -- Error callback
        end
    else
        devPrint("[ERROR] Failed to mark chest as picked up in the database. Chest ID: " .. tostring(chestId))
        Core.NotifyAvanced(recSource, _U("chestUpdateFailed"), "generic_textures", "generic_warning", "COLOR_RED", 3000)
        cb({ success = false, message = "Failed to update chest status in the database." }) -- Error callback
    end
end)

BccUtils.RPC:Register("bcc-stashes:ValidateAndPickupChest", function(params, cb, recSource)
    local chestId = params.chestId
    if not chestId then
        devPrint("[ERROR] Chest ID is nil. Cannot validate pickup.")
        return cb({ success = false, message = "Chest ID is missing." })
    end

    local Character = Core.getUser(recSource).getUsedCharacter

    if not Character then
        devPrint("[ERROR] Failed to retrieve character data for source: " .. tostring(recSource))
        return cb({ success = false, message = "Character data not found." })
    end

    local charid = Character.charIdentifier

    -- Query the database to validate ownership
    local chest = MySQL.query.await("SELECT * FROM stashes WHERE id = @id AND charid = @charid", {
        ['id'] = chestId,
        ['charid'] = charid
    })

    if chest and #chest > 0 then
        -- Call the client-side RPC to handle the chest pickup
        local response = BccUtils.RPC:CallAsync("bcc-stashes:PickUpChest", { chestId = chestId }, recSource)

        if response and response.success then
            devPrint("[DEBUG] Chest pickup completed successfully for Chest ID: " .. tostring(chestId))
            return cb({ success = true, message = "Chest pickup completed successfully." })
        else
            devPrint("[ERROR] Failed to pick up chest on client: " .. (response and response.message or "Unknown error"))
            return cb({ success = false, message = response and response.message or "Failed to pick up chest on client." })
        end
        devPrint("[DEBUG] Chest pickup initiated for Chest ID: " .. tostring(chestId))
        return cb({ success = true, message = "Chest pickup initiated." })
    else
        -- Notify the player that they cannot pick up the chest
        Core.NotifyAvanced(recSource, _U("ChestNotOwnedOrNotFound"), "menu_textures", "generic_warning", "COLOR_RED", 4000)
        devPrint("[ERROR] Chest not found or not owned for Chest ID: " .. tostring(chestId))
        return cb({ success = false, message = "Chest not owned or not found." })
    end
end)

BccUtils.RPC:Register('bcc-stashes:GetStashes', function(params, cb, source)
    local Character = Core.getUser(source).getUsedCharacter
    if not Character then
        devPrint("[ERROR] Failed to retrieve character data for source: " .. tostring(source))
        return cb(nil) -- Return nil to the callback in case of an error
    end

    local charid = Character.charIdentifier
    devPrint("[DEBUG] Fetching stashes from the database for CharID: " .. tostring(charid))

    -- Fetch stashes by charid
    local result = MySQL.query.await('SELECT * FROM stashes WHERE charid = @charid', {
        ['charid'] = charid
    })

    if result then
        devPrint("[DEBUG] Returning stashes: " .. json.encode(result))
        cb(result) -- Return stashes to the callback
    else
        devPrint("[ERROR] No stashes found for CharID: " .. tostring(charid))
        cb(nil) -- Return nil if no stashes are found
    end
end)

BccUtils.RPC:Register("bcc-stashes:OpenPropStash", function(params, cb, recSource)
    local containerid = params.containerid
    local JobNames = params.JobNames
    local propHash = params.propHash

    local Character = Core.getUser(recSource).getUsedCharacter
    if not Character then
        devPrint("[ERROR] Failed to retrieve character data for source: " .. tostring(recSource))
        return cb({ success = false, message = "Failed to retrieve character data." })
    end

    local job = Character.job
    local jobgrade = Character.jobGrade
    local blacklistItems = {}
    local JobOnly = false
    local JobGrades = 0

    -- Debug input values
    devPrint("RPC 'bcc-stashes:OpenPropStash' triggered.")
    devPrint("Container ID: " .. tostring(containerid) .. ", Prop Hash: " .. tostring(propHash) .. ", Job Names: " .. json.encode(JobNames))

    if not containerid then
        devPrint("[ERROR] Missing container ID. Cannot proceed.")
        return cb({ success = false, message = "Missing container ID." })
    end

    for k, v in pairs(Config.Props) do
        if v.hash == propHash then
            JobGrades = v.JobGrades or 0 -- Ensure a default value for JobGrades
            if v.NotAllowedItems then
                blacklistItems = v.Items
                for key, value in pairs(blacklistItems) do
                    exports.vorp_inventory:BlackListCustomAny(containerid, value)
                end
            end
            JobOnly = v.JobOnly or false
        end
    end

    Wait(250)

    if JobOnly then
        if CheckTable(JobNames, job) then
            if jobgrade >= JobGrades then
                exports.vorp_inventory:openInventory(recSource, containerid)
                devPrint("Opened inventory for job-specific Container ID: " .. tostring(containerid))
                return cb({ success = true, message = "Inventory opened successfully." })
            else
                Core.NotifyAvanced(recSource, _U("WrongJobGrade"), "menu_textures", "generic_warning", "COLOR_RED", 4000)
                devPrint("Failed to open inventory for Container ID: " .. tostring(containerid) .. " - Wrong job grade.")
                return cb({ success = false, message = "Insufficient job grade." })
            end
        else
            Core.NotifyAvanced(recSource, _U("WrongJob"), "menu_textures", "generic_warning", "COLOR_RED", 4000)
            devPrint("Failed to open inventory for Container ID: " .. tostring(containerid) .. " - Wrong job.")
            return cb({ success = false, message = "Unauthorized job." })
        end
    else
        exports.vorp_inventory:openInventory(recSource, containerid)
        devPrint("Opened inventory for non-job-specific Container ID: " .. tostring(containerid))
        return cb({ success = true, message = "Inventory opened successfully." })
    end
end)

BccUtils.RPC:Register("bcc-stashes:OpenContainer", function(params, cb, recSource)
    local _source = recSource
    local containerid = params.containerid
    local containername = params.containername
    local limit = params.limit
    local JobNames = params.JobNames

    local Character = Core.getUser(_source).getUsedCharacter
    local job = Character.job
    local jobgrade = Character.jobGrade
    local blacklistItems = {}
    local JobOnly = false
    local JobGrades = nil

    devPrint("Opening container for ID: " .. tostring(containerid) .. " Name: " .. tostring(containername))

    for k, v in pairs(Config.Spots) do
        if containerid == v.containerid then
            JobGrades = v.JobGrades
            if v.NotAllowedItems then
                blacklistItems = v.Items
                for key, value in pairs(blacklistItems) do
                    exports.vorp_inventory:BlackListCustomAny(containerid, value)
                end
            end
        end

        local data = {
            id = containerid,
            name = containername,
            limit = limit,
            acceptWeapons = true,
            shared = false,
            ignoreItemStackLimit = true,
            whitelistItems = false,
            UsePermissions = false,
            UseBlackList = false,
            whitelistWeapons = false
        }

        if v.Shared then
            if v.NotAllowedItems then
                data.shared = true
                data.UseBlackList = true
            else
                data.shared = true
            end
        else
            if v.NotAllowedItems then
                data.UseBlackList = true
            end
        end

        exports.vorp_inventory:registerInventory(data)
        if v.JobOnly then
            JobOnly = true
        else
            JobOnly = false
        end
    end

    Wait(250)
    if JobOnly then
        if CheckTable(JobNames, job) then
            if jobgrade >= JobGrades then
                exports.vorp_inventory:openInventory(_source, containerid)
                devPrint("Opened job-specific container ID: " .. tostring(containerid))
                return cb({ success = true, message = "Container opened successfully." })
            else
                Core.NotifyAvanced(_source, _U("WrongJobGrade"), "menu_textures", "generic_warning", "COLOR_RED", 4000)
                devPrint("Failed to open container: Wrong job grade.")
                return cb({ success = false, message = "Insufficient job grade." })
            end
        else
            Core.NotifyAvanced(_source, _U("WrongJob"), "menu_textures", "generic_warning", "COLOR_RED", 4000)
            devPrint("Failed to open container: Wrong job.")
            return cb({ success = false, message = "Job not authorized." })
        end
    else
        exports.vorp_inventory:openInventory(_source, containerid)
        devPrint("Opened non-job-specific container ID: " .. tostring(containerid))
        return cb({ success = true, message = "Container opened successfully." })
    end
end)

--[[RegisterServerEvent("vorp_inventory:MoveToCustom", function(obj)
    local _source = source
    local Character = Core.getUser(_source).getUsedCharacter
    local item = json.decode(obj)
    devPrint("Moved item to custom stash: " .. tostring(item.item.name) .. " Amount: " .. tostring(item.number))
    Discord:sendMessage(Character.firstname .. " " .. Character.lastname .. _U("Moved") .. item.number .. " " .. item.item.name .. _U("ToStash") .. stashid)
end)

RegisterServerEvent("vorp_inventory:TakeFromCustom", function(obj)
    local _source = source
    local Character = Core.getUser(_source).getUsedCharacter
    local item = json.decode(obj)
    if stashid then
        devPrint("Took item from custom stash: " .. tostring(item.item.name) .. " Amount: " .. tostring(item.number))
        Discord:sendMessage(Character.firstname .. " " .. Character.lastname .. _U("Took") .. item.number .. " " .. item.item.name .. _U("ToStash") .. stashid)
    end
end)]]--

function CheckTable(table, element)
    for k, v in pairs(table) do
        if v == element then
            return true
        end
    end
    return false
end

BccUtils.Versioner.checkFile(GetCurrentResourceName(), 'https://github.com/BryceCanyonCounty/bcc-stashes')
