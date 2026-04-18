ESX = exports['es_extended']:getSharedObject()

local menuOpen = false
local cachedGrades, cachedGradesAt = nil, 0
local GRADES_CACHE_MS = 60000

local function zatvoriMenu()
    if not menuOpen then return end
    menuOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'zatvoriKurvu' })
end

RegisterNUICallback('nuiClosed', function(_, cb)
    zatvoriMenu()
    cb('ok')
end)

RegisterNUICallback('zatvoriKurvu', function(_, cb)
    zatvoriMenu()
    if cb then cb('ok') end
end)

RegisterNetEvent('masked-bossmenu:cl:otvori', function(jobLabel, zaposljeni, brojZaposljenih)
    if not menuOpen then
        menuOpen = true
        SetNuiFocus(true, true)
    end

    SendNUIMessage({
        action = 'otvoriKurvu',
        label = jobLabel,
        zaposljeni = zaposljeni,
        brojZaposljenih = brojZaposljenih
    })
end)

AddEventHandler('masked-bossmenu:cl:otvoriBoss', function()
    TriggerServerEvent('masked-bossmenu:sv:povuciIgrace')
end)

local function GetGradeOptions(grades)
    local options = {}
    local seenRanks = {}

    for _, grade in ipairs(grades) do
        local rankNumber = grade.grade
        if rankNumber and not seenRanks[rankNumber] then
            seenRanks[rankNumber] = true
            local label = grade.label or ('Rank ' .. rankNumber)
            options[#options + 1] = {
                label = label .. ' (' .. rankNumber .. ')',
                value = rankNumber
            }
        end
    end

    return options
end

local function GetJobGrades(callback)
    local currentTime = GetGameTimer()
    
    if cachedGrades and currentTime - cachedGradesAt < GRADES_CACHE_MS then
        callback(cachedGrades)
        return
    end

    ESX.TriggerServerCallback('masked-bossmenu:sv:getJobRanks', function(grades)
        cachedGrades = grades or {}
        cachedGradesAt = GetGameTimer()
        callback(cachedGrades)
    end)
end

RegisterNUICallback('zaposliKurvu', function(_, cb)
    GetJobGrades(function(grades)
        if not grades or #grades == 0 then
            ESX.ShowNotification('Nema dostupnih rankova!')
            if cb then cb('ok') end
            return
        end

        local input = lib.inputDialog('Zaposli Igraca', {
            { type = 'number', label = 'ID Igraca', min = 1, required = true },
            { type = 'select', label = 'Rank', options = GetGradeOptions(grades), required = true }
        })

        if input and input[1] and input[2] then
            TriggerServerEvent('masked-bossmenu:sv:zaposliKurvu', tonumber(input[1]), tonumber(input[2]))
        end

        if cb then cb('ok') end
    end)
end)

RegisterNUICallback('unaprijediKurvu', function(data, cb)
    GetJobGrades(function(grades)
        if not grades or #grades == 0 then
            ESX.ShowNotification('Nema dostupnih rankova!')
            if cb then cb('ok') end
            return
        end

        local selected = lib.inputDialog('Izaberite novi rank', {
            { type = 'select', label = 'Rank', options = GetGradeOptions(grades), required = true }
        })

        if selected and selected[1] then
            TriggerServerEvent('masked-bossmenu:sv:unaprijediKurvu', data.identifier, tonumber(selected[1]))
        end

        if cb then cb('ok') end
    end)
end)

RegisterNUICallback('dajotkazKurvi', function(data, cb)
    TriggerServerEvent('masked-bossmenu:sv:otpustiKurvu', data.identifier)
    if cb then cb('ok') end
end)

CreateThread(function()
    while true do
        if menuOpen then
            if IsControlJustPressed(0, 322) then
                zatvoriMenu()
            end
            Wait(0)
        else
            Wait(1000)
        end
    end
end)