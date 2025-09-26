local Core = exports.vorp_core:GetCore()
local BccUtils = exports['bcc-utils'].initiate()

---@type BCCStashesDebugLib
local DBG = BCCStashesDebug

-- Cache notification setting for performance
local showNotifications = Config.notifications.showNotifications

for _, propCfg in pairs(Props) do
    exports.vorp_inventory:registerUsableItem(propCfg.dbname, function(data)
        local src = data.source

        DBG.Info("Usable item triggered for " .. propCfg.dbname .. " by source: " .. tostring(src))

        -- Check job restrictions before allowing use
        if not ValidateJobAccess(src, propCfg, "use container item") then
            exports.vorp_inventory:closeInventory(src)
            return
        end

        -- Check if the player has the item
        local itemCount = exports.vorp_inventory:getItemCount(src, nil, propCfg.dbname)
        DBG.Info("Item count for " .. propCfg.dbname .. ": " .. tostring(itemCount))
        if itemCount > 0 then
            -- Remove the item from inventory
            exports.vorp_inventory:subItem(src, propCfg.dbname, 1)
            DBG.Info("Item " .. propCfg.dbname .. " removed from inventory.")

            -- Notify the player
            NotifyPlayer(src, _U('usedContainerItem'), 4000)

            -- Trigger the client RPC to place the container
            local response = BccUtils.RPC:CallAsync('bcc-stashes:PlaceContainer', {
                name = propCfg.ContainerName,
                hash = propCfg.hash
            }, src)

            if response and response.success then
                DBG.Info("Container successfully placed: " .. propCfg.ContainerName)
            else
                DBG.Warning("Failed to place container: " .. (response and response.message or "Unknown error"))
            end
        else
            -- Notify the player if they don't have the item
            NotifyPlayer(src, _U('dontHaveContainerItem'), 4000)
            DBG.Info("Player does not have the item: " .. propCfg.dbname)
        end

        -- Close inventory after the item is used
        exports.vorp_inventory:closeInventory(src)
        DBG.Info("Inventory closed for source: " .. tostring(src))
    end)
end

-- Register inventory
BccUtils.RPC:Register('bcc-stashes:registerInventory', function(params, cb, recSource)
    local containerId = params.containerId
    local hash = params.hash

    DBG.Info("Register inventory triggered for containerId: " .. tostring(containerId) .. " hash: " .. tostring(hash))

    -- Validate hash exists in the configuration
    if not Props[hash] then
        DBG.Error("Hash not found in configuration: " .. tostring(hash))
        return cb({ success = false, message = "Invalid hash provided." })
    end

    local data = {
        id = containerId,
        name = Props[hash].ContainerName,
        limit = Props[hash].limit,
        acceptWeapons = true,
        shared = Props[hash].Shared,
        ignoreItemStackLimit = true,
        whitelistItems = false,
        UsePermissions = false,
        UseBlackList = false,
        whitelistWeapons = false
    }

    -- Apply shared and blacklist logic based on the configuration
    if Props[hash].Shared then
        if Props[hash].NotAllowedItems then
            data.shared = true
            data.UseBlackList = true
        else
            data.shared = true
        end
    else
        if Props[hash].NotAllowedItems then
            data.UseBlackList = true
        end
    end

    -- Register the inventory
    exports.vorp_inventory:registerInventory(data)
    DBG.Info("Inventory registered for container: " .. tostring(containerId))

    -- Return success to the client
    cb({ success = true, message = "Inventory registered successfully." })
end)

-- Create stash
BccUtils.RPC:Register('bcc-stashes:CreateStash', function(params, cb, recSource)
    local Character = Core.getUser(recSource).getUsedCharacter
    if not Character then
        DBG.Error("Failed to retrieve character data for source: " .. tostring(recSource))
        return cb({ success = false, message = "Character not found." })
    end

    local charid = Character.charIdentifier
    local name = params.name
    local hash = params.hash
    local x = params.x
    local y = params.y
    local z = params.z
    local h = params.h

    -- Check job restrictions for placement
    local propConfig = Props[hash]
    if not ValidateJobAccess(recSource, propConfig, "place container") then
        return cb({ success = false, message = "Job restrictions not met for placement." })
    end

    DBG.Info("Creating stash for CharID: " .. tostring(charid) .. ", Hash: " .. tostring(hash))

    local stashId
    local existingStash = MySQL.query.await("SELECT * FROM stashes WHERE charid = @charid AND pickedup = 1;", {
        ['charid'] = charid
    })

    if existingStash and #existingStash > 0 then
        stashId = existingStash[1].id
        DBG.Info("Reusing existing stash ID: " .. stashId)

        local updateResult = MySQL.query.await("UPDATE stashes SET x = @x, y = @y, z = @z, h = @h, pickedup = 0 WHERE id = @id;", {
            ['id'] = stashId,
            ['x'] = x,
            ['y'] = y,
            ['z'] = z,
            ['h'] = h
        })
        if updateResult and updateResult.affectedRows > 0 then
            DBG.Info("Successfully updated existing stash. Stash ID: " .. tostring(stashId))
        else
            DBG.Warning("Failed to update existing stash location. Stash ID: " .. tostring(stashId))
            return cb({ success = false, message = "Failed to update existing stash." })
        end
    else
        stashId = BccUtils.UUID()
        DBG.Info("Creating new stash ID: " .. tostring(stashId))

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
            DBG.Info("New stash created in the database. Stash ID: " .. tostring(stashId))
        else
            DBG.Error("Failed to insert new stash into the database.")
            return cb({ success = false, message = "Failed to create new stash." })
        end
    end

    -- Notify the client about the stash creation
    NotifyPlayer(recSource, _U('stashCreationSuccess'), 4000)

    return cb({ success = true, message = "Stash created successfully.", stashId = stashId })
end)


BccUtils.RPC:Register("bcc-stashes:NotifyStashCreated", function(params, cb, recSource)
    local stashId = params.stashId

    if not stashId then
        DBG.Error("Received nil Stash ID from client.")
        return cb({ success = false, message = "Stash ID is nil." })
    end

    DBG.Info("Notifying client about stash creation. Stash ID: " .. tostring(stashId))

    -- Notify the client to handle stash creation
    cb({ success = true, stashId = stashId, message = "Client notified successfully." })
end)


BccUtils.RPC:Register("bcc-stashes:PickupChestServer", function(params, cb, recSource)
    local chestId = params.chestId
    local chestHash = params.chestHash

    DBG.Info("Attempting to mark chest as picked up. Chest ID: " .. tostring(chestId))

    local param = {
        ['id'] = chestId,
        ['pickedup'] = 1
    }

    local result = MySQL.query.await("UPDATE stashes SET pickedup = @pickedup WHERE id = @id", param)

    if result and result.affectedRows > 0 then
        DBG.Info("Successfully marked chest as picked up. Chest ID: " .. tostring(chestId))

        local itemName = nil
        for k, v in pairs(Props) do
            if v.hash == chestHash then
                itemName = v.dbname
                break
            end
        end

        if itemName then
            exports.vorp_inventory:addItem(recSource, itemName, 1)
            DBG.Info("Chest item added to inventory: " .. itemName)
            NotifyPlayer(recSource, _U("chestPickedUp"), 4000)
            cb({ success = true, message = "Chest picked up successfully.", item = itemName }) -- Successful callback
        else
            DBG.Error("Chest item not found in configuration for hash: " .. tostring(chestHash))
            NotifyPlayer(recSource, _U("chestItemNotFound"), 4000)
            cb({ success = false, message = "Chest item not found in configuration." }) -- Error callback
        end
    else
        DBG.Error("Failed to mark chest as picked up in the database. Chest ID: " .. tostring(chestId))
        NotifyPlayer(recSource, _U("chestUpdateFailed"), 4000)
        cb({ success = false, message = "Failed to update chest status in the database." }) -- Error callback
    end
end)

BccUtils.RPC:Register("bcc-stashes:ValidateAndPickupChest", function(params, cb, recSource)
    local chestId = params.chestId
    if not chestId then
        DBG.Error("Chest ID is nil. Cannot validate pickup.")
        return cb({ success = false, message = "Chest ID is missing." })
    end

    local Character = Core.getUser(recSource).getUsedCharacter

    if not Character then
        DBG.Error("Failed to retrieve character data for source: " .. tostring(recSource))
        return cb({ success = false, message = "Character data not found." })
    end

    local charid = Character.charIdentifier

    -- Query the database to validate ownership
    local chest = MySQL.query.await("SELECT * FROM stashes WHERE id = @id AND charid = @charid", {
        ['id'] = chestId,
        ['charid'] = charid
    })

    if chest and #chest > 0 then
        -- Get the prop hash from the chest data
        local propHash = chest[1].propname

        -- Check job restrictions for pickup
        local propConfig = Props[propHash]
        if not ValidateJobAccess(recSource, propConfig, "pickup container") then
            return cb({ success = false, message = "Job restrictions not met for pickup." })
        end

        -- Call the client-side RPC to handle the chest pickup
        local response = BccUtils.RPC:CallAsync("bcc-stashes:PickUpChest", { chestId = chestId }, recSource)

        if response and response.success then
            DBG.Info("Chest pickup completed successfully for Chest ID: " .. tostring(chestId))
            return cb({ success = true, message = "Chest pickup completed successfully." })
        else
            DBG.Error("Failed to pick up chest on client: " .. (response and response.message or "Unknown error"))
            return cb({ success = false, message = response and response.message or "Failed to pick up chest on client." })
        end
    else
        -- Notify the player that they cannot pick up the chest
        NotifyPlayer(recSource, _U("ChestNotOwnedOrNotFound"), 4000)
        DBG.Warning("Chest not found or not owned for Chest ID: " .. tostring(chestId))
        return cb({ success = false, message = "Chest not owned or not found." })
    end
end)

BccUtils.RPC:Register('bcc-stashes:GetStashes', function(params, cb, source)
    local Character = Core.getUser(source).getUsedCharacter
    if not Character then
        DBG.Error("Failed to retrieve character data for source: " .. tostring(source))
        return cb(nil) -- Return nil to the callback in case of an error
    end

    local charid = Character.charIdentifier
    DBG.Info("Fetching stashes from the database for CharID: " .. tostring(charid))

    -- Fetch stashes by charid
    local result = MySQL.query.await('SELECT * FROM stashes WHERE charid = @charid', {
        ['charid'] = charid
    })

    if result then
        DBG.Info("Returning stashes: " .. json.encode(result))
        cb(result) -- Return stashes to the callback
    else
        DBG.Info("No stashes found for CharID: " .. tostring(charid))
        cb(nil) -- Return nil if no stashes are found
    end
end)

BccUtils.RPC:Register("bcc-stashes:OpenPropStash", function(params, cb, recSource)
    local containerid = params.containerid
    local JobRestrictions = params.JobRestrictions
    local propHash = params.propHash

    local Character = Core.getUser(recSource).getUsedCharacter
    if not Character then
        DBG.Error("Failed to retrieve character data for source: " .. tostring(recSource))
        return cb({ success = false, message = "Failed to retrieve character data." })
    end

    local job = Character.job
    local jobgrade = Character.jobGrade
    local blacklistItems = {}
    local JobOnly = false

    -- Debug input values
    DBG.Info("RPC 'bcc-stashes:OpenPropStash' triggered.")
    DBG.Info("Container ID: " .. tostring(containerid) .. ", Prop Hash: " .. tostring(propHash) .. ", Job Restrictions: " .. json.encode(JobRestrictions))

    if not containerid then
        DBG.Error("Missing container ID. Cannot proceed.")
        return cb({ success = false, message = "Missing container ID." })
    end

    for k, v in pairs(Props) do
        if v.hash == propHash then
            if v.NotAllowedItems then
                blacklistItems = v.Items
                for key, value in pairs(blacklistItems) do
                    exports.vorp_inventory:BlackListCustomAny(containerid, value)
                end
            end
            JobOnly = v.JobOnly or false
            break
        end
    end

    Wait(250)

    -- Create temporary config object for spots job validation
    local spotConfig = { JobOnly = JobOnly, JobRestrictions = JobRestrictions }

    if ValidateJobAccess(recSource, spotConfig, "open container") then
        exports.vorp_inventory:openInventory(recSource, containerid)
        DBG.Info("Opened container ID: " .. tostring(containerid) .. " (Job: " .. job .. ", Grade: " .. jobgrade .. ")")
        return cb({ success = true, message = "Container opened successfully." })
    else
        return cb({ success = false, message = "Job restrictions not met." })
    end
end)

BccUtils.RPC:Register("bcc-stashes:OpenContainer", function(params, cb, recSource)
    local src = recSource
    local containerid = params.containerid
    local containername = params.containername
    local limit = params.limit
    local JobRestrictions = params.JobRestrictions

    local Character = Core.getUser(src).getUsedCharacter
    local job = Character.job
    local jobgrade = Character.jobGrade
    local blacklistItems = {}
    local JobOnly = false

    DBG.Info("Opening container for ID: " .. tostring(containerid) .. " Name: " .. tostring(containername))
    DBG.Info("Job Restrictions: " .. json.encode(JobRestrictions))

    local matchingSpot = nil
    for k, v in pairs(Spots) do
        if containerid == v.containerid then
            matchingSpot = v
            JobOnly = v.JobOnly or false

            if v.NotAllowedItems then
                blacklistItems = v.Items
                for key, value in pairs(blacklistItems) do
                    exports.vorp_inventory:BlackListCustomAny(containerid, value)
                end
            end
            break -- Exit loop once we find the matching spot
        end
    end

    if matchingSpot then
        local data = {
            id = containerid,
            name = containername,
            limit = limit,
            acceptWeapons = true,
            shared = params.isShare,
            ignoreItemStackLimit = true,
            whitelistItems = false,
            UsePermissions = false,
            UseBlackList = false,
            whitelistWeapons = false
        }

        if matchingSpot.Shared then
            if matchingSpot.NotAllowedItems then
                data.shared = true
                data.UseBlackList = true
            else
                data.shared = true
            end
        else
            if matchingSpot.NotAllowedItems then
                data.UseBlackList = true
            end
        end

        exports.vorp_inventory:registerInventory(data)
    end

    Wait(250)

    -- Create temporary config object for spots job validation
    local spotConfig = { JobOnly = JobOnly, JobRestrictions = JobRestrictions }

    if ValidateJobAccess(src, spotConfig, "open container") then
        exports.vorp_inventory:openInventory(src, containerid)
        DBG.Info("Opened container ID: " .. tostring(containerid) .. " (Job: " .. job .. ", Grade: " .. jobgrade .. ")")
        return cb({ success = true, message = "Container opened successfully." })
    else
        return cb({ success = false, message = "Job restrictions not met." })
    end
end)

-- Check if chest is empty (for PickupEmptyOnly restriction)
BccUtils.RPC:Register("bcc-stashes:CheckChestEmpty", function(params, cb, recSource)
    local chestId = params.chestId

    DBG.Info("Checking if chest is empty - Chest ID: " .. tostring(chestId))

    if not chestId then
        DBG.Error("Missing chest ID for empty check")
        return cb({ isEmpty = false, message = "Missing chest ID." })
    end

    -- Get inventory contents
    local inventoryItems = exports.vorp_inventory:getCustomInventoryItems(chestId)

    if inventoryItems and next(inventoryItems) ~= nil then
        -- Chest has items, send notification to player
        DBG.Info("Chest " .. tostring(chestId) .. " contains items, cannot pickup")
        NotifyPlayer(recSource, _U("ChestMustBeEmpty"), 4000)
        return cb({ isEmpty = false, message = "Chest must be empty to pickup." })
    else
        -- Chest is empty
        DBG.Info("Chest " .. tostring(chestId) .. " is empty, pickup allowed")
        return cb({ isEmpty = true, message = "Chest is empty." })
    end
end)

-- Helper function to send notifications based on cached config setting
function NotifyPlayer(source, message, duration)
    if showNotifications then
        Core.NotifyRightTip(source, message, duration or 4000)
    end
end

-- Helper function to validate job restrictions and send appropriate notifications
function ValidateJobAccess(source, config, action)
    if not config or not config.JobOnly then
        return true -- No job restrictions enabled, allow access
    end

    -- JobOnly is true, so job restrictions must be properly configured
    if not config.JobRestrictions or type(config.JobRestrictions) ~= "table" or next(config.JobRestrictions) == nil then
        DBG.Error("JobOnly is enabled but JobRestrictions is not properly configured for action: " .. action)
        NotifyPlayer(source, _U("jobRestriction"), 4000)
        return false -- Deny access when misconfigured
    end

    local Character = Core.getUser(source).getUsedCharacter
    if not Character then
        DBG.Error("Failed to retrieve character data for source: " .. tostring(source))
        return false
    end

    local job = Character.job
    local jobgrade = Character.jobGrade

    if CheckJobRestrictions(config.JobRestrictions, job, jobgrade) then
        return true -- Job restrictions met
    end

    -- Job restrictions not met, send appropriate notification
    if config.JobRestrictions[job] ~= nil then
        NotifyPlayer(source, _U("WrongJobGrade"), 4000)
        DBG.Warning("Failed to " .. action .. ": Insufficient job grade. Required: " .. config.JobRestrictions[job] .. ", Player: " .. jobgrade)
    else
        NotifyPlayer(source, _U("WrongJob"), 4000)
        DBG.Warning("Failed to " .. action .. ": Job not authorized.")
    end

    return false
end

-- Check if player's job and grade meet the requirements
function CheckJobRestrictions(jobRestrictions, playerJob, playerGrade)
    if not jobRestrictions or type(jobRestrictions) ~= "table" then
        return false -- No restrictions defined
    end

    -- Check if the player's job is in the restrictions
    local requiredGrade = jobRestrictions[playerJob]
    if requiredGrade == nil then
        return false -- Job not allowed
    end

    -- Check if player meets the minimum grade requirement
    return playerGrade >= requiredGrade
end

BccUtils.Versioner.checkFile(GetCurrentResourceName(), 'https://github.com/BryceCanyonCounty/bcc-stashes')
