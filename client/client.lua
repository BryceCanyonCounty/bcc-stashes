VORPutils = {}
TriggerEvent("getUtils", function(utils)
    VORPutils = utils
end)

Citizen.CreateThread(function()
    local PromptGroup = VORPutils.Prompts:SetupPromptGroup()
    local firstprompt = PromptGroup:RegisterPrompt(_U("OpenStorage"), 0x760A9C6F, 1, 1, true, 'hold',
        { timedeventhash = "SHORT_TIMED_EVENT" })
    while true do
        Wait(0)
        local ped = PlayerPedId()
        local pedpos = GetEntityCoords(PlayerPedId(), true)
        local isDead = IsEntityDead(ped)

        for k, v in pairs(Spots) do
            local distance = GetDistanceBetweenCoords(v.Pos.x, v.Pos.y, v.Pos.z, pedpos.x, pedpos.y, pedpos.z, true)
            if distance < 1.5 and not isDead then
                PromptGroup:ShowGroup(_U("OpenStorage"))
                if firstprompt:HasCompleted() then
                    TriggerServerEvent("bcc-stashes:OpenContainer", v.containerid, v.ContainerName, v.JobName)
                end
            end
        end
    end
end)
