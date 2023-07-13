local VORPcore = {}

TriggerEvent("getCore", function(core)
  VORPcore = core
end)

local VORPInv = {}

VORPInv = exports.vorp_inventory:vorp_inventoryApi()

JobOnly, Jobs, JobGrades, BlacklistItems = nil, {}, nil, {}

RegisterNetEvent("bcc-stashes:OpenContainer") -- inventory system
AddEventHandler("bcc-stashes:OpenContainer", function(containerid)
  local _source = source
  local Character = VORPcore.getUser(_source).getUsedCharacter
  local job = Character.job
  local jobgrade = Character.jobGrade
  for k, v in pairs(Spots) do
    if v.NotAllowedItems then
      for k, v in pairs(BlacklistItems) do
        VORPInv.BlackListCustomAny(containerid, v)
      end
    end
    Jobs = v.JobName
    JobGrades = v.JobGrades
    BlacklistItems = v.Items
    if v.Shared then
      if v.NotAllowedItems then
        VORPInv.registerInventory(containerid, v.ContainerName, 100, true, true, true, false, false, true, false)
      else
        VORPInv.registerInventory(containerid, v.ContainerName, 100, true, true, true, false, false, false, false)
      end
    else
      if v.NotAllowedItems then
        VORPInv.registerInventory(containerid, v.ContainerName, 100, true, false, true, false, false, true, false)
      else
        VORPInv.registerInventory(containerid, v.ContainerName, 100, true, false, true, false, false, false, false)
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

function CheckTable(table, element)
  for k, v in pairs(table) do
    if v == element then
      return true
    end
  end
  return false
end
