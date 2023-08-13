VORPutils = {}
TriggerEvent("getUtils", function(utils)
    VORPutils = utils
end)

-- at the top of your file
local VORPcore = {}

TriggerEvent("getCore", function(core)
    VORPcore = core
end)

local Chests = {}

local OpenPrompt

CreateThread(function()
    local PromptGroup = VORPutils.Prompts:SetupPromptGroup()
    local firstprompt = PromptGroup:RegisterPrompt(_U("OpenStorage"), 0x760A9C6F, 1, 1, true, 'hold',
        { timedeventhash = "SHORT_TIMED_EVENT" })
    while true do
        Wait(0)
        local ped = PlayerPedId()
        local pedpos = GetEntityCoords(PlayerPedId(), true)
        local isDead = IsEntityDead(ped)

        for k, v in pairs(Config.Spots) do
            local distance = GetDistanceBetweenCoords(v.Pos.x, v.Pos.y, v.Pos.z, pedpos.x, pedpos.y, pedpos.z, true)
            if distance < 1.5 and not isDead then
                PromptGroup:ShowGroup(_U("OpenStorage"))
                if firstprompt:HasCompleted() then
                    TriggerServerEvent("bcc-stashes:OpenContainer", v.containerid, v.ContainerName, v.limit, v.JobName)
                end
            end
        end
    end
end)

RegisterNetEvent('bcc-stashes:PlaceContainer', function(name, hash)
    local x, y, z = table.unpack(GetOffsetFromEntityInWorldCoords(PlayerPedId(), 0.0, 2.0, -1.55))
    local h = GetEntityHeading(PlayerPedId())
    local obj = VORPutils.Objects:Create(hash, x, y, z, h, true, 'standard')
    obj:PlaceOnGround(true)
    table.insert(Chests, { Entityid = obj:GetObj(), Hash = hash })
    VORPcore.RpcCall('CreateStash', function(result)
        Entity(obj:GetObj()).state:set('id', result[1].id, true)
        TriggerServerEvent('bcc-stashes:registerInventory', result[1].id, result[1].propname)
    end, { Name = name, Hash = hash, X = x, Y = y, Z = z, H = h })
end)

AddEventHandler('CharacterSelect', function()
    VORPcore.RpcCall('GetStashes', function(result)
        if type(result) == 'table' then
            for k, v in pairs(result) do
                local x, y, z = table.unpack(GetOffsetFromEntityInWorldCoords(PlayerPedId(), 0.0, 2.0, -1.55))
                local h = GetEntityHeading(PlayerPedId())
                local obj = VORPutils.Objects:Create(result[1].propname, x, y, z, h, true, 'standard')
                obj:PlaceOnGround(true)
                Entity(obj:GetObj()).state:set('id', result[1].id, true)
                table.insert(Chests, { Entityid = obj:GetObj(), Hash = result[1].propname })
                TriggerServerEvent('bcc-stashes:registerInventory', result[1].id, result[1].propname)
            end
        end
    end)
end)

CreateThread(function()
    local distance, TargetPrompt
    while true do
        local pcoords = GetEntityCoords(PlayerPedId())
        Wait(0)
        for k, v in pairs(Chests) do
            local propcoords = GetEntityCoords(v.Entityid)
            Citizen.InvokeNative(0xA22712E8471AA08E, v.Entityid, true, true)
            local aiming = Citizen.InvokeNative(0x27F89FDC16688A7A, PlayerId(), v.Entityid, 0)
            distance = #(pcoords - propcoords)
            local isDead = IsEntityDead(PlayerPedId())
            if distance < 2.5 and not isDead then
                Citizen.InvokeNative(0xFC094EF26DD153FA, 2)
                if aiming then
                    TargetPrompt = Citizen.InvokeNative(0xB796970BD125FCE8, v.Entityid) -- PromptGetGroupIdForTargetEntity
                    TriggerEvent('bcc-stashes:FocusPrompt', TargetPrompt)
                    if Citizen.InvokeNative(0x580417101DDB492F, 2, Config.keys.g) then  -- IsControlJustPressed
                        TriggerServerEvent("bcc-stashes:OpenPropStash", Entity(v.Entityid).state.id,
                            Config.Props[v.Hash].JobName)
                    end
                else
                    Citizen.InvokeNative(0x4E52C800A28F7BE8, OpenPrompt, 1)
                end
            else
                Citizen.InvokeNative(0xA22712E8471AA08E, v.Entityid, false, false)
            end
        end
    end
end)


AddEventHandler('bcc-stashes:FocusPrompt', function(TargetPrompt)
    local str = CreateVarString(10, 'LITERAL_STRING', 'Open')
    OpenPrompt = PromptRegisterBegin()
    PromptSetControlAction(OpenPrompt, Config.keys.g)
    PromptSetText(OpenPrompt, str)
    PromptSetEnabled(OpenPrompt, 1)
    PromptSetVisible(OpenPrompt, 1)
    PromptSetStandardMode(OpenPrompt, 1)
    PromptSetGroup(OpenPrompt, TargetPrompt)
    PromptRegisterEnd(OpenPrompt)
end)
