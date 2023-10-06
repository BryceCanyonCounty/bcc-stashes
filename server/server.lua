local VORPcore = {}
TriggerEvent("getCore", function(core)
  VORPcore = core
end)
local VORPInv = {}
crypt = exports['bcc-crypt'].install()

local stashid

local ServerRPC = exports.vorp_core:ServerRpcCall()

VORPInv = exports.vorp_inventory:vorp_inventoryApi()

JobOnly, Jobs, JobGrades, BlacklistItems, Uuid = nil, {}, nil, {}, nil
CreateThread(function()
  for k, v in pairs(Config.Props) do
    print(v)
    VORPInv.RegisterUsableItem(v.dbname, function(data)
      print('used item')
      TriggerClientEvent('bcc-stashes:PlaceContainer', data.source, v.ContainerName, v.hash)
    end)
  end
end)
RegisterNetEvent('bcc-stashes:registerInventory', function(id, hash)
  if Config.Props[hash].Shared then
    if Config.Props[hash].NotAllowedItems then
      VORPInv.registerInventory(id, Config.Props[hash].ContainerName, Config.Props[hash].limit, true, true, true, false,
        false, true, false)
    else
      VORPInv.registerInventory(id, Config.Props[hash].ContainerName, Config.Props[hash].limit, true, true, true, false,
        false, false, false)
    end
  else
    if Config.Props[hash].NotAllowedItems then
      VORPInv.registerInventory(id, Config.Props[hash].ContainerName, Config.Props[hash].limit, true, false, true, false,
        false, true, false)
    else
      VORPInv.registerInventory(id, Config.Props[hash].ContainerName, Config.Props[hash].limit, true, false, true, false,
        false, false,
        false)
    end
  end
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
  local db = MySQL.query.await(
    "INSERT INTO stashes (`id`, `name`,`propname`,`x`,`y`,`z`,`h` ) VALUES ( @id,@name,@hash,@x,@y,@z,@h) RETURNING *;",
    param)
end)


ServerRPC.Callback.Register('CreateStash', function(source, cb, args)
  print('hit server side rpc')
  local _source = source
  local character = VORPcore.getUser(_source).getUsedCharacter
  local charId = character.charIdentifier
  print(json.encode(args))
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


ServerRPC.Callback.Register('GetStashes', function(source, cb)
  local _source = source
  local result = MySQL.query.await(
    'SELECT * FROM stashes')
  cb(result)
end)


RegisterNetEvent("bcc-stashes:OpenPropStash") -- inventory system
AddEventHandler("bcc-stashes:OpenPropStash", function(containerid, JobNames)
  print(containerid)
  local _source = source
  local Character = VORPcore.getUser(_source).getUsedCharacter
  local job = Character.job
  local jobgrade = Character.jobGrade
  for k, v in pairs(Config.Props) do
    if v.NotAllowedItems then
      for k, v in pairs(BlacklistItems) do
        VORPInv.BlackListCustomAny(containerid, v)
      end
    end
    Jobs = JobNames
    JobGrades = v.JobGrades
    BlacklistItems = v.Items
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
        VORPInv.OpenInv(_source, containerid)
        stashid = containerid
      else
        VORPcore.NotifyTip(_source, _U("WrongJobGrade"), 4000)
      end
    else
      VORPcore.NotifyTip(_source, _U("WrongJob"), 4000)
    end
  else
    VORPInv.OpenInv(_source, containerid)
    stashid = containerid
  end
end)
RegisterNetEvent("bcc-stashes:OpenContainer") -- inventory system
AddEventHandler("bcc-stashes:OpenContainer", function(containerid, containername, limit, JobNames)
  local _source = source
  local Character = VORPcore.getUser(_source).getUsedCharacter
  local job = Character.job
  local jobgrade = Character.jobGrade
  for k, v in pairs(Config.Spots) do
    if v.NotAllowedItems then
      for k, v in pairs(BlacklistItems) do
        VORPInv.BlackListCustomAny(containerid, v)
      end
    end
    Jobs = JobNames
    JobGrades = v.JobGrades
    BlacklistItems = v.Items
    if v.Shared then
      if v.NotAllowedItems then
        VORPInv.registerInventory(containerid, containername, limit, true, true, true, false, false, true, false)
      else
        VORPInv.registerInventory(containerid, containername, limit, true, true, true, false, false, false, false)
      end
    else
      if v.NotAllowedItems then
        VORPInv.registerInventory(containerid, containername, limit, true, false, true, false, false, true, false)
      else
        VORPInv.registerInventory(containerid, containername, limit, true, false, true, false, false, false, false)
      end
    end
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
        VORPInv.OpenInv(_source, containerid)
        stashid = containerid
      else
        VORPcore.NotifyTip(_source, _U("WrongJobGrade"), 4000)
      end
    else
      VORPcore.NotifyTip(_source, _U("WrongJob"), 4000)
    end
  else
    VORPInv.OpenInv(_source, containerid)
    stashid = containerid
  end
end)
RegisterServerEvent("vorp_inventory:MoveToCustom", function(obj)
  local _source = source
  local Character = VORPcore.getUser(_source).getUsedCharacter
  local item = json.decode(obj)
  VORPcore.AddWebhook(Config.WebhookInfo.Title, Config.WebhookInfo.Webhook,
    Character.firstname ..
    " " .. Character.lastname .. _U("Moved") .. item.number .. " " .. item.item.name .. _U("ToStash"),
    Config.WebhookInfo.Color,
    Config.WebhookInfo.Name, Config.WebhookInfo.Logo, Config.WebhookInfo.FooterLogo, Config.WebhookInfo.Avatar)
end)
RegisterServerEvent("vorp_inventory:TakeFromCustom", function(obj)
  local _source = source
  local Character = VORPcore.getUser(_source).getUsedCharacter
  local item = json.decode(obj)
  VORPcore.AddWebhook(Config.WebhookInfo.Title, Config.WebhookInfo.Webhook,
    Character.firstname ..
    " " .. Character.lastname .. _U("Took") .. item.number .. " " .. item.item.name .. _U("ToStash") .. stashid,
    Config.WebhookInfo.Color,
    Config.WebhookInfo.Name, Config.WebhookInfo.Logo, Config.WebhookInfo.FooterLogo, Config.WebhookInfo.Avatar)
end)
function CheckTable(table, element)
  for k, v in pairs(table) do
    if v == element then
      return true
    end
  end
  return false
end
