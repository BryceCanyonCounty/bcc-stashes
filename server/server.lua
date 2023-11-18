local VORPcore = {}
TriggerEvent("getCore", function(core)
  VORPcore = core
end)
crypt = exports['bcc-crypt'].install()

local stashid

local ServerRPC = exports.vorp_core:ServerRpcCall()

JobOnly, Jobs, JobGrades, Uuid = nil, {}, nil, nil

CreateThread(function()
  for k, v in pairs(Config.Props) do
    exports.vorp_inventory:registerUsableItem(v.dbname, function(data)
      TriggerClientEvent('bcc-stashes:PlaceContainer', data.source, v.ContainerName, v.hash)
    end)
  end
end)

RegisterNetEvent('bcc-stashes:registerInventory', function(containerId, hash)
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
    exports.vorp_inventory:registerInventory(data)
end)

RegisterNetEvent('bcc-stashes:SaveToDB', function(name, hash, x, y, z, h)
  Uuid = crypt.uuid4()
  local param = {
    ['id'] = Uuid,
    ['name'] = name,
    ['hash'] = hash,
    ['x'] = x,
    ['y'] = y,
    ['z'] = z,
    ['h'] = h
  }
  MySQL.query.await(
    "INSERT INTO stashes (`id`, `name`,`propname`,`x`,`y`,`z`,`h` ) VALUES ( @id,@name,@hash,@x,@y,@z,@h) RETURNING *;",
    param)
end)

ServerRPC.Callback.Register('bcc-stashes:CreateStash', function(source, cb, args)
  Uuid = crypt.uuid4()
  local param = {
    ['id'] = Uuid,
    ['name'] = args.Name,
    ['hash'] = args.Hash,
    ['x'] = args.X,
    ['y'] = args.Y,
    ['z'] = args.Z,
    ['h'] = args.H
  }
  -- args contains a table of stuff you're sending over from the client. (see args as the last argument in the RPC call.

  local db = MySQL.query.await(
    "INSERT INTO stashes (`id`, `name`,`propname`,`x`,`y`,`z`,`h` ) VALUES ( @id,@name,@hash,@x,@y,@z,@h) RETURNING *;",
    param)
  cb(db)
end)

ServerRPC.Callback.Register('bcc-stashes:GetStashes', function(source, cb)
  local result = MySQL.query.await(
    'SELECT * FROM stashes')
  cb(result)
end)

RegisterNetEvent("bcc-stashes:OpenPropStash") -- inventory system
AddEventHandler("bcc-stashes:OpenPropStash", function(containerid, JobNames, propHash)
  local _source = source
  local Character = VORPcore.getUser(_source).getUsedCharacter
  local job = Character.job
  local jobgrade = Character.jobGrade
  local blacklistItems = {}
  for k, v in pairs(Config.Props) do
    if v.NotAllowedItems then
        if v.hash == propHash then
            blacklistItems = v.Items
            for key, value in pairs(blacklistItems) do
                exports.vorp_inventory:BlackListCustomAny(containerid, value)
            end
        end
    end
    Jobs = JobNames
    JobGrades = v.JobGrades
    if v.JobOnly then
      JobOnly = true
    else
      JobOnly = false
    end
  end
  Wait(250)
  if JobOnly then
    if CheckTable(Jobs, job) then
      if jobgrade >= JobGrades then
        exports.vorp_inventory:openInventory(_source, containerid)
        stashid = containerid
      else
        VORPcore.NotifyTip(_source, _U("WrongJobGrade"), 4000)
      end
    else
      VORPcore.NotifyTip(_source, _U("WrongJob"), 4000)
    end
  else
    exports.vorp_inventory:openInventory(_source, containerid)
    stashid = containerid
  end
end)

RegisterNetEvent("bcc-stashes:OpenContainer") -- inventory system
AddEventHandler("bcc-stashes:OpenContainer", function(containerid, containername, limit, JobNames)
    local _source = source
    local Character = VORPcore.getUser(_source).getUsedCharacter
    local job = Character.job
    local jobgrade = Character.jobGrade
    local blacklistItems = {}
    for k, v in pairs(Config.Spots) do
        if v.NotAllowedItems then
            if containerid == v.containerid then
                blacklistItems = v.Items
                for key, value in pairs(blacklistItems) do
                    exports.vorp_inventory:BlackListCustomAny(containerid, value)
                end
            end
        end
        Jobs = JobNames
        JobGrades = v.JobGrades
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
        if CheckTable(Jobs, job) then
            if jobgrade >= JobGrades then
                exports.vorp_inventory:openInventory(_source, containerid)
                stashid = containerid
            else
                VORPcore.NotifyTip(_source, _U("WrongJobGrade"), 4000)
            end
        else
            VORPcore.NotifyTip(_source, _U("WrongJob"), 4000)
        end
    else
        exports.vorp_inventory:openInventory(_source, containerid)
        stashid = containerid
    end
end)

RegisterServerEvent("vorp_inventory:MoveToCustom", function(obj)
    local _source = source
    local Character = VORPcore.getUser(_source).getUsedCharacter
    local item = json.decode(obj)
    VORPcore.AddWebhook(
    Config.WebhookInfo.Title,
    Config.WebhookInfo.Webhook,
    Character.firstname .. " " .. Character.lastname .. _U("Moved") .. item.number .. " " .. item.item.name .. _U("ToStash"),
    Config.WebhookInfo.Color,
    Config.WebhookInfo.Name,
    Config.WebhookInfo.Logo,
    Config.WebhookInfo.FooterLogo,
    Config.WebhookInfo.Avatar
    )
end)

RegisterServerEvent("vorp_inventory:TakeFromCustom", function(obj)
    local _source = source
    local Character = VORPcore.getUser(_source).getUsedCharacter
    local item = json.decode(obj)
    if stashid then
        VORPcore.AddWebhook(
        Config.WebhookInfo.Title,
        Config.WebhookInfo.Webhook,
        Character.firstname .. " " .. Character.lastname .. _U("Took") .. item.number .. " " .. item.item.name .. _U("ToStash") .. stashid,
        Config.WebhookInfo.Color,
        Config.WebhookInfo.Name,
        Config.WebhookInfo.Logo,
        Config.WebhookInfo.FooterLogo,
        Config.WebhookInfo.Avatar
        )
    end
end)

function CheckTable(table, element)
  for k, v in pairs(table) do
    if v == element then
      return true
    end
  end
  return false
end
