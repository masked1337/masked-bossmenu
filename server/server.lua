ESX = exports['es_extended']:getSharedObject()

RegisterNetEvent('masked-bossmenu:sv:povuciIgrace')
AddEventHandler('masked-bossmenu:sv:povuciIgrace', function()
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    
    if not xPlayer then return end
    
    local jobName = xPlayer.job.name
    local jobLabel = xPlayer.job.label or jobName
    
    if not IsPlayerBoss(xPlayer) then
        TriggerClientEvent('esx:showNotification', src, 'Niste ovlasteni za ovu radnju!')
        return
    end
    
    local onlinePlayers = ESX.GetExtendedPlayers('job', jobName)
    local zaposljeni = {}
    local onlineIdentifiers = {}
    
    for _, player in ipairs(onlinePlayers) do
        onlineIdentifiers[player.identifier] = true
        table.insert(zaposljeni, {
            identifier = player.identifier,
            name = player.getName(),
            steam_name = GetPlayerName(player.source) or player.getName(),
            steam_hex = GetPlayerIdentifier(player.source, 0) or player.identifier,
            job_rank = player.job.grade_label or ('Rank ' .. player.job.grade),
            grade = player.job.grade,
            online = true
        })
    end
    
    MySQL.Async.fetchAll('SELECT identifier, firstname, lastname, job_grade FROM users WHERE job = @job_name', {
        ['@job_name'] = jobName
    }, function(allEmployees)
        local pendingQueries = 0
        local processedQueries = 0
        
        for _, employee in ipairs(allEmployees) do
            if not onlineIdentifiers[employee.identifier] then
                pendingQueries = pendingQueries + 1
                
                MySQL.Async.fetchAll('SELECT label FROM job_grades WHERE job_name = @job_name AND grade = @grade', {
                    ['@job_name'] = jobName,
                    ['@grade'] = employee.job_grade
                }, function(gradeResult)
                    local rankLabel = 'Nepoznato'
                    if gradeResult and #gradeResult > 0 then
                        rankLabel = gradeResult[1].label
                    end
                    
                    local fullName = (employee.firstname or '') .. ' ' .. (employee.lastname or '')
                    if fullName == ' ' then fullName = 'Nepoznato' end
                    
                    table.insert(zaposljeni, {
                        identifier = employee.identifier,
                        name = fullName,
                        steam_name = 'Offline',
                        steam_hex = employee.identifier,
                        job_rank = rankLabel,
                        grade = employee.job_grade,
                        online = false
                    })
                    
                    processedQueries = processedQueries + 1
                    if processedQueries == pendingQueries then
                        PosaljiPodatke(src, jobLabel, zaposljeni)
                    end
                end)
            end
        end
        
        if pendingQueries == 0 then
            PosaljiPodatke(src, jobLabel, zaposljeni)
        end
    end)
end)

function PosaljiPodatke(src, jobLabel, zaposljeni)
    table.sort(zaposljeni, function(a, b)
        if a.online and not b.online then
            return true
        elseif not a.online and b.online then
            return false
        else
            return (a.name or '') < (b.name or '')
        end
    end)
    
    TriggerClientEvent('masked-bossmenu:cl:otvori', src, jobLabel, zaposljeni, #zaposljeni)
end

RegisterNetEvent('masked-bossmenu:sv:zaposliKurvu')
AddEventHandler('masked-bossmenu:sv:zaposliKurvu', function(targetId, rank)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    
    if not xPlayer then return end
    
    local tPlayer = ESX.GetPlayerFromId(targetId)
    
    if not tPlayer then
        TriggerClientEvent('esx:showNotification', src, 'Igrac nije online!')
        return
    end
    
    if not IsPlayerBoss(xPlayer) then
        TriggerClientEvent('esx:showNotification', src, 'Niste ovlasteni za ovu radnju!')
        return
    end
    
    local jobName = xPlayer.job.name
    
    MySQL.Async.fetchAll('SELECT label FROM job_grades WHERE job_name = @job_name AND grade = @grade', {
        ['@job_name'] = jobName,
        ['@grade'] = rank
    }, function(result)
        if not result or #result == 0 then
            TriggerClientEvent('esx:showNotification', src, 'Taj rank ne postoji!')
            return
        end
        
        tPlayer.setJob(jobName, rank)
        
        TriggerClientEvent('esx:showNotification', src, 'Zaposlili ste ' .. tPlayer.getName())
        TriggerClientEvent('esx:showNotification', targetId, 'Zaposljeni ste u ' .. (xPlayer.job.label or jobName))
    end)
end)

RegisterNetEvent('masked-bossmenu:sv:unaprijediKurvu')
AddEventHandler('masked-bossmenu:sv:unaprijediKurvu', function(identifier, newRank)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    
    if not xPlayer then return end
    
    if not IsPlayerBoss(xPlayer) then
        TriggerClientEvent('esx:showNotification', src, 'Niste ovlasteni za ovu radnju!')
        return
    end
    
    local jobName = xPlayer.job.name
    
    MySQL.Async.fetchAll('SELECT label FROM job_grades WHERE job_name = @job_name AND grade = @grade', {
        ['@job_name'] = jobName,
        ['@grade'] = newRank
    }, function(rankResult)
        if not rankResult or #rankResult == 0 then
            TriggerClientEvent('esx:showNotification', src, 'Taj rank ne postoji!')
            return
        end
        
        MySQL.Async.fetchAll('SELECT firstname, lastname FROM users WHERE identifier = @identifier', {
            ['@identifier'] = identifier
        }, function(userResult)
            if not userResult or #userResult == 0 then
                TriggerClientEvent('esx:showNotification', src, 'Igrac nije pronadjen!')
                return
            end
            
            MySQL.Async.execute('UPDATE users SET job = @job, job_grade = @grade WHERE identifier = @identifier', {
                ['@job'] = jobName,
                ['@grade'] = newRank,
                ['@identifier'] = identifier
            }, function(rowsChanged)
                if rowsChanged > 0 then
                    local targetPlayer = ESX.GetPlayerFromIdentifier(identifier)
                    if targetPlayer then
                        targetPlayer.setJob(jobName, newRank)
                        TriggerClientEvent('esx:showNotification', targetPlayer.source, 'Unaprijedjeni ste na ' .. (rankResult[1].label or 'Rank ' .. newRank))
                    end
                    
                    TriggerClientEvent('esx:showNotification', src, 'Uspesno unaprijedjen igrac!')
                else
                    TriggerClientEvent('esx:showNotification', src, 'Greska pri unapredjenju!')
                end
            end)
        end)
    end)
end)

RegisterNetEvent('masked-bossmenu:sv:otpustiKurvu')
AddEventHandler('masked-bossmenu:sv:otpustiKurvu', function(identifier)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    
    if not xPlayer then return end
    
    if not IsPlayerBoss(xPlayer) then
        TriggerClientEvent('esx:showNotification', src, 'Niste ovlasteni za ovu radnju!')
        return
    end
    
    MySQL.Async.fetchAll('SELECT firstname, lastname FROM users WHERE identifier = @identifier', {
        ['@identifier'] = identifier
    }, function(userResult)
        if not userResult or #userResult == 0 then
            TriggerClientEvent('esx:showNotification', src, 'Igrac nije pronadjen!')
            return
        end
        
        MySQL.Async.execute('UPDATE users SET job = @job, job_grade = @grade WHERE identifier = @identifier', {
            ['@job'] = 'unemployed',
            ['@grade'] = 0,
            ['@identifier'] = identifier
        }, function(rowsChanged)
            if rowsChanged > 0 then
                local targetPlayer = ESX.GetPlayerFromIdentifier(identifier)
                if targetPlayer then
                    targetPlayer.setJob('unemployed', 0)
                    TriggerClientEvent('esx:showNotification', targetPlayer.source, 'Otpušteni ste!')
                end
                
                TriggerClientEvent('esx:showNotification', src, 'Uspesno otpusten igrac!')
            else
                TriggerClientEvent('esx:showNotification', src, 'Greska pri otpustanju!')
            end
        end)
    end)
end)

ESX.RegisterServerCallback('masked-bossmenu:sv:getJobRanks', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not xPlayer then
        cb({})
        return
    end
    
    local jobName = xPlayer.job.name
    
    MySQL.Async.fetchAll('SELECT grade, label FROM job_grades WHERE job_name = @job_name ORDER BY grade ASC', {
        ['@job_name'] = jobName
    }, function(grades)
        cb(grades or {})
    end)
end)

function IsPlayerBoss(xPlayer)
    if not xPlayer or not xPlayer.job then
        return false
    end
    
    if xPlayer.job.grade_name == 'boss' then
        return true
    end
    
    local result = MySQL.Sync.fetchAll('SELECT MAX(grade) as highest FROM job_grades WHERE job_name = @job_name', {
        ['@job_name'] = xPlayer.job.name
    })
    
    if result and result[1] and result[1].highest then
        return xPlayer.job.grade == result[1].highest
    end
    
    return false
end