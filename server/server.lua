local VORPcore = {}

TriggerEvent("getCore", function(core)
  VORPcore = core
end)

local VORPInv = {}

VORPInv = exports.vorp_inventory:vorp_inventoryApi()

JobOnly, Jobs, JobGrades, BlacklistItems = nil, {}, nil, {}

RegisterNetEvent("bcc-stashes:OpenContainer") -- inventory system
AddEventHandler("bcc-stashes:OpenContainer", function(containerid, containername, limit, JobNames)
  local _source = source
  print(containername)
  local Character = VORPcore.getUser(_source).getUsedCharacter
  local job = Character.job
  local jobgrade = Character.jobGrade
  for k, v in pairs(Spots) do
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
    print(json.encode(Jobs))
    if CheckTable(Jobs, job) then
      if jobgrade >= JobGrades then
        VORPInv.OpenInv(_source, containerid)
      else
        VORPcore.NotifyTip(_source, _U("WrongJobGrade"), 4000)
      end
    else
      VORPcore.NotifyTip(_source, _U("WrongJob"), 4000)
    end
  else
    VORPInv.OpenInv(_source, containerid)
  end
end)

RegisterServerEvent("vorp_inventory:MoveToCustom", function(obj)
  print('test')
  local _source = source
  local Character = VORPcore.getUser(_source).getUsedCharacter
  local item = json.decode(obj)

  VORPcore.AddWebhook(Config.WebhookInfo.Title, Config.WebhookInfo.Webhook,
    Character.firstname ..
    " " .. Character.lastname .. _U("Moved") .. item.number .. " " .. item.item.name .. _U("ToStash"),
    Config.WebhookInfo.Color,
    Config.WebhookInfo.Name, Config.WebhookInfo.Logo, Config.WebhookInfo.FooterLogo, Config.WebhookInfo.Avatar)
  print('finished moved')
end)
RegisterServerEvent("vorp_inventory:TakeFromCustom", function(obj)
  local _source = source
  local Character = VORPcore.getUser(_source).getUsedCharacter
  local item = json.decode(obj)

  VORPcore.AddWebhook(Config.WebhookInfo.Title, Config.WebhookInfo.Webhook,
    Character.firstname ..
    " " .. Character.lastname .. _U("Took") .. item.number .. " " .. item.item.name .. _U("ToStash"),
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
