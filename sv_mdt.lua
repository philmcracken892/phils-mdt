local RSGCore = exports['rsg-core']:GetCoreObject()


local Config = {
    Command = "mdt",
    Jobs = {"ranger", "marshal", "vallaw", "rholaw", "blklaw", "strlaw", "stdenlaw", "leo"},
    Notify = {
        ['1'] = "Offender changes have been saved.",
        ['2'] = "Report changes have been saved.",
        ['3'] = "Report has been successfully deleted.",
        ['4'] = "A new report has been submitted.",
        ['5'] = "A new warrant has been created.",
        ['6'] = "Warrant has been successfully deleted.",
        ['7'] = "This report cannot be found.",
        ['8'] = "Telegram saved.",
        ['9'] = "Telegram deleted.",
        ['10'] = "Invalid mugshot URL provided.",
        ['11'] = "Fine has been issued successfully.",  
        ['12'] = "Fine has been marked as paid.",       
        ['13'] = "Fine has been deleted.",              
        ['14'] = "Fine not found.",                     
        ['15'] = "Player is not online to receive fine notification." 
    }
}


local activeMDTUsers = {}


local function IsValidImageURL(url)
    if not url or url == "" then
        return true 
    end
    
    if not string.match(url, "^https?://") then
        return false
    end
    
    local imageExtensions = {".jpg", ".jpeg", ".png", ".gif", ".webp", ".bmp"}
    local isDiscordCDN = string.match(url, "cdn%.discordapp%.com") or string.match(url, "media%.discordapp%.net")
    if isDiscordCDN then
        return true
    end
    for _, ext in ipairs(imageExtensions) do
        if string.match(string.lower(url), ext) then
            return true
        end
    end
    return false
end

RegisterServerEvent('phils-mdt:getMyFines')
AddEventHandler('phils-mdt:getMyFines', function()
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    exports.oxmysql:fetch('SELECT * FROM `mdt_fines` WHERE `citizenid` = ? AND `paid` = false ORDER BY `date` DESC', {
        Player.PlayerData.citizenid
    }, function(result)
        TriggerClientEvent('phils-mdt:returnMyFines', src, result)
    end)
end)


RegisterServerEvent('phils-mdt:getMyFinesStatus')
AddEventHandler('phils-mdt:getMyFinesStatus', function()
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    exports.oxmysql:fetch('SELECT COUNT(*) as count, SUM(amount) as total FROM `mdt_fines` WHERE `citizenid` = ? AND `paid` = false', {
        Player.PlayerData.citizenid
    }, function(result)
        local count = result[1] and result[1].count or 0
        local total = result[1] and result[1].total or 0
        TriggerClientEvent('phils-mdt:fineStatus', src, count, total)
    end)
end)

RegisterServerEvent('phils-mdt:payFine')
AddEventHandler('phils-mdt:payFine', function(fineData, amount, paymentMethod, paymentType)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    
    local playerMoney = 0
    if paymentMethod == 'cash' then
        playerMoney = Player.PlayerData.money.cash
    elseif paymentMethod == 'bank' then
        playerMoney = Player.PlayerData.money.bank
    end
    
    if playerMoney < amount then
        TriggerClientEvent('phils-mdt:finePaymentResult', src, false, 
            'Insufficient funds. You need $' .. amount .. ' but only have $' .. playerMoney .. ' in your ' .. paymentMethod .. '.')
        return
    end
    
    
    if paymentType == 'single' then
        
        local fineId = fineData
        
        
        exports.oxmysql:fetch('SELECT * FROM `mdt_fines` WHERE `id` = ? AND `citizenid` = ? AND `paid` = false', {
            fineId, Player.PlayerData.citizenid
        }, function(result)
            if not result[1] then
                TriggerClientEvent('phils-mdt:finePaymentResult', src, false, 'Fine not found or already paid.')
                return
            end
            
            local fine = result[1]
            if fine.amount ~= amount then
                TriggerClientEvent('phils-mdt:finePaymentResult', src, false, 'Fine amount mismatch.')
                return
            end
            
            
            if Player.Functions.RemoveMoney(paymentMethod, amount, 'fine-payment') then
                
                exports.oxmysql:execute('UPDATE `mdt_fines` SET `paid` = true WHERE `id` = ?', {fineId})
                
               
                exports.oxmysql:insert('INSERT INTO `mdt_fine_payments` (`fine_id`, `citizenid`, `amount`, `payment_method`, `payment_date`) VALUES (?, ?, ?, ?, ?)', {
                    fineId, Player.PlayerData.citizenid, amount, paymentMethod, os.date('%Y-%m-%d %H:%M:%S')
                })
                
                TriggerClientEvent('phils-mdt:finePaymentResult', src, true, 
                    'Fine #' .. fineId .. ' paid successfully ($' .. amount .. ' via ' .. paymentMethod .. ')')
                
                
                broadcastMDTUpdate()
                
            else
                TriggerClientEvent('phils-mdt:finePaymentResult', src, false, 'Payment processing failed.')
            end
        end)
        
    elseif paymentType == 'all' then
        
        local fineIds = fineData
        
        if type(fineIds) ~= 'table' then
            TriggerClientEvent('phils-mdt:finePaymentResult', src, false, 'Invalid fine data.')
            return
        end
        
        
        local placeholders = {}
        for i = 1, #fineIds do
            table.insert(placeholders, '?')
        end
        local placeholderString = table.concat(placeholders, ',')
        
        local queryParams = {}
        for _, id in ipairs(fineIds) do
            table.insert(queryParams, id)
        end
        table.insert(queryParams, Player.PlayerData.citizenid)
        
        exports.oxmysql:fetch('SELECT * FROM `mdt_fines` WHERE `id` IN (' .. placeholderString .. ') AND `citizenid` = ? AND `paid` = false', 
            queryParams, function(result)
            
            if #result ~= #fineIds then
                TriggerClientEvent('phils-mdt:finePaymentResult', src, false, 'Some fines not found or already paid.')
                return
            end
            
           
            local dbTotal = 0
            for _, fine in ipairs(result) do
                dbTotal = dbTotal + fine.amount
            end
            
            if dbTotal ~= amount then
                TriggerClientEvent('phils-mdt:finePaymentResult', src, false, 'Amount mismatch. Please try again.')
                return
            end
            
            
            if Player.Functions.RemoveMoney(paymentMethod, amount, 'fines-payment') then
                
                exports.oxmysql:execute('UPDATE `mdt_fines` SET `paid` = true WHERE `id` IN (' .. placeholderString .. ') AND `citizenid` = ?', 
                    queryParams)
                
                
                for _, fineId in ipairs(fineIds) do
                    exports.oxmysql:insert('INSERT INTO `mdt_fine_payments` (`fine_id`, `citizenid`, `amount`, `payment_method`, `payment_date`) VALUES (?, ?, ?, ?, ?)', {
                        fineId, Player.PlayerData.citizenid, 0, paymentMethod, os.date('%Y-%m-%d %H:%M:%S')  -- Individual amounts in separate query if needed
                    })
                end
                
                TriggerClientEvent('phils-mdt:finePaymentResult', src, true, 
                    'All fines paid successfully! Total: $' .. amount .. ' via ' .. paymentMethod)
                
                
                broadcastMDTUpdate()
                
            else
                TriggerClientEvent('phils-mdt:finePaymentResult', src, false, 'Payment processing failed.')
            end
        end)
    end
end)
RegisterCommand('debugfines', function(source, args)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return end
    
    print("Player citizenid: " .. Player.PlayerData.citizenid)
    
    exports.oxmysql:fetch('SELECT * FROM `mdt_fines` WHERE `citizenid` = ?', {
        Player.PlayerData.citizenid
    }, function(result)
        print("Total fines found: " .. #result)
        for i, fine in ipairs(result) do
            print("Fine " .. i .. ": ID=" .. fine.id .. ", Amount=" .. fine.amount .. ", Paid=" .. tostring(fine.paid) .. ", CitizenID=" .. (fine.citizenid or "NULL"))
        end
    end)
end, false)
-- Optional: Admin command to forgive fines
RegisterCommand('forgivefines', function(source, args)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    
    if not RSGCore.Functions.HasPermission(src, 'admin') and not RSGCore.Functions.HasPermission(src, 'god') then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Access Denied',
            description = 'You do not have permission to use this command.',
            type = 'error'
        })
        return
    end
    
    if not args[1] then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Usage',
            description = 'Usage: /forgivefines [citizenid or player ID]',
            type = 'error'
        })
        return
    end
    
    local targetPlayer = nil
    local citizenId = nil
    
    
    if tonumber(args[1]) then
        targetPlayer = RSGCore.Functions.GetPlayer(tonumber(args[1]))
        if targetPlayer then
            citizenId = targetPlayer.PlayerData.citizenid
        end
    else-- Try as citizenid
        citizenId = args[1]
        targetPlayer = RSGCore.Functions.GetPlayerByCitizenId(citizenId)
    end
    
    if not citizenId then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Error',
            description = 'Player not found.',
            type = 'error'
        })
        return
    end
    
    
    exports.oxmysql:execute('UPDATE `mdt_fines` SET `paid` = 1 WHERE `citizenid` = ? AND `paid` = 0', {citizenId}, function(affectedRows)
        if affectedRows > 0 then
            TriggerClientEvent('ox_lib:notify', src, {
                title = 'Fines Forgiven',
                description = 'Forgave ' .. affectedRows .. ' fine(s) for citizen: ' .. citizenId,
                type = 'success'
            })
            
            
            if targetPlayer then
                TriggerClientEvent('ox_lib:notify', targetPlayer.PlayerData.source, {
                    title = 'Fines Forgiven',
                    description = 'All your outstanding fines have been forgiven by an administrator.',
                    type = 'success',
                    duration = 7000
                })
            end
            
            broadcastMDTUpdate()
        else
            TriggerClientEvent('ox_lib:notify', src, {
                title = 'No Fines',
                description = 'No outstanding fines found for citizen: ' .. citizenId,
                type = 'info'
            })
        end
    end)
end, false)

RegisterServerEvent("phils-mdt:registerMDTUser")
AddEventHandler("phils-mdt:registerMDTUser", function()
    local src = source
    activeMDTUsers[src] = true
end)


RegisterServerEvent("phils-mdt:unregisterMDTUser")
AddEventHandler("phils-mdt:unregisterMDTUser", function()
    local src = source
    activeMDTUsers[src] = nil
end)


AddEventHandler('playerDropped', function()
    local src = source
    activeMDTUsers[src] = nil
end)


local function broadcastMDTUpdate()
    exports.oxmysql:fetch("SELECT * FROM (SELECT * FROM `mdt_reports` ORDER BY `id` DESC LIMIT 6) sub ORDER BY `id` DESC", {}, function(reports)
        for r = 1, #reports do
            if reports[r].charges then
                reports[r].charges = json.decode(reports[r].charges)
            end
        end
        
        exports.oxmysql:fetch("SELECT * FROM (SELECT * FROM `mdt_warrants` ORDER BY `id` DESC LIMIT 6) sub ORDER BY `id` DESC", {}, function(warrants)
            for w = 1, #warrants do
                if warrants[w].charges then
                    warrants[w].charges = json.decode(warrants[w].charges)
                end
            end
            
            exports.oxmysql:fetch("SELECT * FROM (SELECT * FROM `mdt_telegrams` ORDER BY `id` DESC LIMIT 6) sub ORDER BY `id` DESC", {}, function(notes)
                for n = 1, #notes do
                    if notes[n].charges then
                        notes[n].charges = json.decode(notes[n].charges)
                    end
                end
                
               
                exports.oxmysql:fetch("SELECT * FROM (SELECT * FROM `mdt_fines` ORDER BY `id` DESC LIMIT 10) sub ORDER BY `id` DESC", {}, function(fines)
                    for src, _ in pairs(activeMDTUsers) do
                        TriggerClientEvent('phils-mdt:updateMDTData', src, reports, warrants, notes, fines)
                    end
                end)
            end)
        end)
    end)
end

RegisterCommand(Config.Command, function(source, args)
    local _source = source
    local Player = RSGCore.Functions.GetPlayer(_source)
    
    if not Player then return end
    
    local job_access = false
    
    for k, v in pairs(Config.Jobs) do
        if Player.PlayerData.job.type == v then
            job_access = true
            break
        end
    end
    
    if not job_access then
        TriggerClientEvent('ox_lib:notify', _source, {
            title = 'MDT',
            description = 'You do not have access to the MDT system.',
            type = 'error'
        })
        return
    end
    
    
    activeMDTUsers[_source] = true
    
    
    exports.oxmysql:fetch("SELECT * FROM (SELECT * FROM `mdt_reports` ORDER BY `id` DESC LIMIT 6) sub ORDER BY `id` DESC", {}, function(reports)
        for r = 1, #reports do
            if reports[r].charges then
                reports[r].charges = json.decode(reports[r].charges)
            end
        end
        
       
        exports.oxmysql:fetch("SELECT * FROM (SELECT * FROM `mdt_warrants` ORDER BY `id` DESC LIMIT 6) sub ORDER BY `id` DESC", {}, function(warrants)
            for w = 1, #warrants do
                if warrants[w].charges then
                    warrants[w].charges = json.decode(warrants[w].charges)
                end
            end
            
           
            exports.oxmysql:fetch("SELECT * FROM (SELECT * FROM `mdt_telegrams` ORDER BY `id` DESC LIMIT 6) sub ORDER BY `id` DESC", {}, function(notes)
                for n = 1, #notes do
                    if notes[n].charges then
                        notes[n].charges = json.decode(notes[n].charges)
                    end
                end
                
                
                exports.oxmysql:fetch("SELECT * FROM (SELECT * FROM `mdt_fines` ORDER BY `id` DESC LIMIT 10) sub ORDER BY `id` DESC", {}, function(fines)
                    TriggerClientEvent('phils-mdt:toggleVisibilty', _source, reports, warrants, Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname, Player.PlayerData.job.type, Player.PlayerData.job.grade.level, notes, fines)
                end)
            end)
        end)
    end)
end)

RegisterServerEvent("phils-mdt:submitNewFine")
AddEventHandler("phils-mdt:submitNewFine", function(data)
    local usource = source
    local Player = RSGCore.Functions.GetPlayer(usource)
    
    if not Player then return end
    
    local officername = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
    data.date = os.date('%m-%d-%Y %H:%M:%S', os.time())
    
    exports.oxmysql:insert('INSERT INTO `mdt_fines` (`char_id`, `citizenid`, `citizen_name`, `officer_name`, `offense`, `amount`, `notes`, `date`, `paid`) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)', {
        data.char_id, 
        data.citizenid,
        data.citizen_name,
        officername, 
        data.offense,
        data.amount,
        data.notes,
        data.date,
        0  -- 0 = unpaid, 1 = paid
    }, function(fineId)
        
        local targetPlayer = RSGCore.Functions.GetPlayerByCitizenId(data.citizenid)
        if targetPlayer then
            TriggerClientEvent('ox_lib:notify', targetPlayer.PlayerData.source, {
                title = 'FINE ISSUED',
                description = 'You have been fined $' .. data.amount .. ' for: ' .. data.offense .. '\nIssued by: ' .. officername,
                type = 'error',
                duration = 10000
            })
            
            -- Optionally remove money from player (uncomment if you want automatic payment)
            -- targetPlayer.Functions.RemoveMoney('cash', data.amount, 'mdt-fine')
            -- if targetPlayer.PlayerData.money.cash < data.amount then
            --     targetPlayer.Functions.RemoveMoney('bank', data.amount - targetPlayer.PlayerData.money.cash, 'mdt-fine')
            -- end
        else
            TriggerClientEvent("phils-mdt:sendNotification", usource, Config.Notify['15'])
        end
        
        TriggerClientEvent("phils-mdt:sendNotification", usource, Config.Notify['11'])
        broadcastMDTUpdate()
    end)
end)

RegisterServerEvent("phils-mdt:getRecentFines")
AddEventHandler("phils-mdt:getRecentFines", function()
    local usource = source
    
    exports.oxmysql:fetch("SELECT * FROM `mdt_fines` ORDER BY `id` DESC LIMIT 20", {}, function(fines)
        TriggerClientEvent("phils-mdt:returnRecentFines", usource, fines)
    end)
end)


RegisterServerEvent("phils-mdt:markFineAsPaid")
AddEventHandler("phils-mdt:markFineAsPaid", function(fineId)
    local usource = source
    
    exports.oxmysql:execute('UPDATE `mdt_fines` SET `paid` = 1 WHERE `id` = ?', {fineId}, function(rowsChanged)
        if rowsChanged > 0 then
            TriggerClientEvent("phils-mdt:sendNotification", usource, Config.Notify['12'])
            TriggerClientEvent("phils-mdt:fineActionCompleted", usource)
            broadcastMDTUpdate()
        else
            TriggerClientEvent("phils-mdt:sendNotification", usource, Config.Notify['14'])
        end
    end)
end)


RegisterServerEvent("phils-mdt:deleteFine")
AddEventHandler("phils-mdt:deleteFine", function(fineId)
    local usource = source
    
    exports.oxmysql:execute('DELETE FROM `mdt_fines` WHERE `id` = ?', {fineId}, function(rowsChanged)
        if rowsChanged > 0 then
            TriggerClientEvent("phils-mdt:sendNotification", usource, Config.Notify['13'])
            broadcastMDTUpdate()
        else
            TriggerClientEvent("phils-mdt:sendNotification", usource, Config.Notify['14'])
        end
    end)
end)
RegisterServerEvent("phils-mdt:getOffensesAndOfficer")
AddEventHandler("phils-mdt:getOffensesAndOfficer", function()
    local usource = source
    local Player = RSGCore.Functions.GetPlayer(usource)
    
    if not Player then return end
    
    local officername = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
    local charges = {}
    
    exports.oxmysql:fetch('SELECT * FROM fine_types ORDER BY label ASC', {}, function(fines)
        for j = 1, #fines do
           
            table.insert(charges, fines[j])
        end
        
        TriggerClientEvent("phils-mdt:returnOffensesAndOfficer", usource, charges, officername)
    end)
end)


RegisterServerEvent("phils-mdt:performOffenderSearch")
AddEventHandler("phils-mdt:performOffenderSearch", function(query)
    local usource = source
    local matches = {}
    
    
    local searchQuery = [[
        SELECT * FROM `players` 
        WHERE LOWER(`charinfo`) LIKE ? 
        OR LOWER(`name`) LIKE ? 
        OR `citizenid` LIKE ?
        OR `id` = ?
        ORDER BY `last_updated` DESC
        LIMIT 50
    ]]
    
    local searchPattern = string.lower('%' .. query .. '%')
    local numericQuery = tonumber(query) or 0
    
    exports.oxmysql:query(searchQuery, {
        searchPattern,    
        searchPattern,    
        searchPattern,   
        numericQuery      
    }, function(result)
        for index, data in ipairs(result) do
            if data.charinfo then
                local charinfo = json.decode(data.charinfo)
                local metadata = json.decode(data.metadata or '{}')
                local corePlayer = RSGCore.Functions.GetPlayerByCitizenId(data.citizenid)
                
               
                if corePlayer then
                    charinfo = corePlayer.PlayerData.charinfo
                    metadata = corePlayer.PlayerData.metadata
                end
                
                
                if charinfo and charinfo.firstname and charinfo.lastname then
                    local offender = {
                        id = data.id,
                        citizenid = data.citizenid,
                        firstname = charinfo.firstname,
                        lastname = charinfo.lastname,
                        birthdate = charinfo.birthdate or 'Unknown',
                        phone = charinfo.phone or 'Unknown',
                        metadata = metadata,
                        last_updated = data.last_updated
                    }
                    table.insert(matches, offender)
                end
            end
        end
        
        TriggerClientEvent("phils-mdt:returnOffenderSearchResults", usource, matches)
    end)
end)


RegisterServerEvent("phils-mdt:getOffenderDetails")
AddEventHandler("phils-mdt:getOffenderDetails", function(offender)
    local usource = source
    
    exports.oxmysql:fetch('SELECT * FROM `players` WHERE `id` = ?', {offender.id}, function(playerResult)
        if not playerResult[1] then
            TriggerClientEvent("phils-mdt:closeModal", usource)
            TriggerClientEvent("phils-mdt:sendNotification", usource, "This person no longer exists.")
            return
        end
        
        local data = playerResult[1]
        local charinfo = json.decode(data.charinfo)
        local metadata = json.decode(data.metadata or '{}')
        local corePlayer = RSGCore.Functions.GetPlayerByCitizenId(data.citizenid)
        
        if corePlayer then
            charinfo = corePlayer.PlayerData.charinfo
            metadata = corePlayer.PlayerData.metadata
        end
        
        offender.firstname = charinfo.firstname
        offender.lastname = charinfo.lastname
        offender.birthdate = charinfo.birthdate
        offender.phone = charinfo.phone
        offender.citizenid = data.citizenid
        offender.metadata = metadata
        
        exports.oxmysql:fetch('SELECT * FROM `user_mdt` WHERE `char_id` = ?', {offender.id}, function(mdtResult)
            if mdtResult[1] then
                offender.notes = mdtResult[1].notes
                offender.mugshot_url = mdtResult[1].mugshot_url
                offender.bail = mdtResult[1].bail
            else
                offender.notes = ""
                offender.mugshot_url = ""
                offender.bail = false
            end
            
            exports.oxmysql:fetch('SELECT * FROM `user_convictions` WHERE `char_id` = ?', {offender.id}, function(convictions)
                if convictions[1] then
                    offender.convictions = {}
                    for i = 1, #convictions do
                        local conviction = convictions[i]
                        offender.convictions[conviction.offense] = conviction.count
                    end
                end
                
                exports.oxmysql:fetch('SELECT * FROM `mdt_warrants` WHERE `char_id` = ?', {offender.id}, function(warrants)
                    if warrants[1] then
                        offender.haswarrant = true
                    end
                    
                    TriggerClientEvent("phils-mdt:returnOffenderDetails", usource, offender)
                end)
            end)
        end)
    end)
end)


RegisterServerEvent("phils-mdt:getOffenderDetailsById")
AddEventHandler("phils-mdt:getOffenderDetailsById", function(char_id)
    local usource = source
    
    exports.oxmysql:fetch('SELECT * FROM `players` WHERE `id` = ?', {char_id}, function(playerResult)
        if not playerResult[1] then
            TriggerClientEvent("phils-mdt:closeModal", usource)
            TriggerClientEvent("phils-mdt:sendNotification", usource, "This person no longer exists.")
            return
        end
        
        local data = playerResult[1]
        local charinfo = json.decode(data.charinfo)
        local metadata = json.decode(data.metadata or '{}')
        local corePlayer = RSGCore.Functions.GetPlayerByCitizenId(data.citizenid)
        
        if corePlayer then
            charinfo = corePlayer.PlayerData.charinfo
            metadata = corePlayer.PlayerData.metadata
        end
        
        local offender = {
            id = data.id,
            citizenid = data.citizenid,
            firstname = charinfo.firstname,
            lastname = charinfo.lastname,
            birthdate = charinfo.birthdate,
            phone = charinfo.phone,
            metadata = metadata
        }
        
        exports.oxmysql:fetch('SELECT * FROM `user_mdt` WHERE `char_id` = ?', {char_id}, function(mdtResult)
            if mdtResult[1] then
                offender.notes = mdtResult[1].notes
                offender.mugshot_url = mdtResult[1].mugshot_url
                offender.bail = mdtResult[1].bail
            else
                offender.notes = ""
                offender.mugshot_url = ""
                offender.bail = false
            end
            
            exports.oxmysql:fetch('SELECT * FROM `user_convictions` WHERE `char_id` = ?', {char_id}, function(convictions)
                if convictions[1] then
                    offender.convictions = {}
                    for i = 1, #convictions do
                        local conviction = convictions[i]
                        offender.convictions[conviction.offense] = conviction.count
                    end
                end
                
                exports.oxmysql:fetch('SELECT * FROM `mdt_warrants` WHERE `char_id` = ?', {char_id}, function(warrants)
                    if warrants[1] then
                        offender.haswarrant = true
                    end
                    
                    TriggerClientEvent("phils-mdt:returnOffenderDetails", usource, offender)
                end)
            end)
        end)
    end)
end)


RegisterServerEvent("phils-mdt:saveOffenderChanges")
AddEventHandler("phils-mdt:saveOffenderChanges", function(id, changes, citizenid)
    local usource = source
    
  
    if not IsValidImageURL(changes.mugshot_url) then
        TriggerClientEvent("phils-mdt:sendNotification", usource, Config.Notify['10'])
        return
    end
    
    exports.oxmysql:fetch('SELECT * FROM `user_mdt` WHERE `char_id` = ?', {id}, function(result)
        if result[1] then
            exports.oxmysql:execute('UPDATE `user_mdt` SET `notes` = ?, `mugshot_url` = ?, `bail` = ? WHERE `char_id` = ?', {changes.notes, changes.mugshot_url, changes.bail, id})
        else
            exports.oxmysql:insert('INSERT INTO `user_mdt` (`char_id`, `notes`, `mugshot_url`, `bail`) VALUES (?, ?, ?, ?)', {id, changes.notes, changes.mugshot_url, changes.bail})
        end
        
        if changes.convictions ~= nil then
            for conviction, amount in pairs(changes.convictions) do
                exports.oxmysql:execute('SELECT * FROM `user_convictions` WHERE `char_id` = ? AND `offense` = ?', {id, conviction}, function(existing)
                    if existing[1] then
                        exports.oxmysql:execute('UPDATE `user_convictions` SET `count` = ? WHERE `char_id` = ? AND `offense` = ?', {amount, id, conviction})
                    else
                        exports.oxmysql:insert('INSERT INTO `user_convictions` (`char_id`, `offense`, `count`) VALUES (?, ?, ?)', {id, conviction, amount})
                    end
                end)
            end
        end
        
        if changes.convictions_removed then
            for i = 1, #changes.convictions_removed do
                exports.oxmysql:execute('DELETE FROM `user_convictions` WHERE `char_id` = ? AND `offense` = ?', {id, changes.convictions_removed[i]})
            end
        end
        
        TriggerClientEvent("phils-mdt:sendNotification", usource, Config.Notify['1'])
    end)
end)


RegisterServerEvent("phils-mdt:saveReportChanges")
AddEventHandler("phils-mdt:saveReportChanges", function(data)
    local usource = source
    local charges = json.encode(data.charges or {})
    
    exports.oxmysql:execute('UPDATE `mdt_reports` SET `title` = ?, `incident` = ?, `charges` = ? WHERE `id` = ?', {data.title, data.incident, charges, data.id})
    
    
    if data.char_id and data.charges then
        for _, charge in ipairs(data.charges) do
            exports.oxmysql:fetch('SELECT * FROM `user_convictions` WHERE `char_id` = ? AND `offense` = ?', {data.char_id, charge}, function(result)
                if result[1] then
                    exports.oxmysql:execute('UPDATE `user_convictions` SET `count` = ? WHERE `char_id` = ? AND `offense` = ?', {result[1].count + 1, data.char_id, charge})
                else
                    exports.oxmysql:insert('INSERT INTO `user_convictions` (`char_id`, `offense`, `count`) VALUES (?, ?, ?)', {data.char_id, charge, 1})
                end
            end)
        end
    end
    
    TriggerClientEvent("phils-mdt:sendNotification", usource, Config.Notify['2'])
    broadcastMDTUpdate()
end)


RegisterServerEvent("phils-mdt:deleteReport")
AddEventHandler("phils-mdt:deleteReport", function(id)
    local usource = source
    exports.oxmysql:execute('DELETE FROM `mdt_reports` WHERE `id` = ?', {id})
    TriggerClientEvent("phils-mdt:sendNotification", usource, Config.Notify['3'])
    broadcastMDTUpdate()
end)


RegisterServerEvent("phils-mdt:deleteNote")
AddEventHandler("phils-mdt:deleteNote", function(id)
    local usource = source
    exports.oxmysql:execute('DELETE FROM `mdt_telegrams` WHERE `id` = ?', {id})
    TriggerClientEvent("phils-mdt:sendNotification", usource, Config.Notify['9'])
    broadcastMDTUpdate()
end)


RegisterServerEvent("phils-mdt:submitNewReport")
AddEventHandler("phils-mdt:submitNewReport", function(data)
    local usource = source
    local Player = RSGCore.Functions.GetPlayer(usource)
    
    if not Player then return end
    
    local officername = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
    local charges = json.encode(data.charges or {})
    data.date = os.date('%m-%d-%Y %H:%M:%S', os.time())
    
    exports.oxmysql:insert('INSERT INTO `mdt_reports` (`char_id`, `title`, `incident`, `charges`, `author`, `name`, `date`) VALUES (?, ?, ?, ?, ?, ?, ?)', {
        data.char_id, 
        data.title, 
        data.incident, 
        charges, 
        officername, 
        data.name, 
        data.date
    }, function(id)
        TriggerEvent("phils-mdt:getReportDetailsById", id, usource)
        TriggerClientEvent("phils-mdt:sendNotification", usource, Config.Notify['4'])
        broadcastMDTUpdate()
    end)
    

    if data.char_id and data.charges then
        for _, charge in ipairs(data.charges) do
            exports.oxmysql:fetch('SELECT * FROM `user_convictions` WHERE `char_id` = ? AND `offense` = ?', {data.char_id, charge}, function(result)
                if result[1] then
                    exports.oxmysql:execute('UPDATE `user_convictions` SET `count` = ? WHERE `char_id` = ? AND `offense` = ?', {result[1].count + 1, data.char_id, charge})
                else
                    exports.oxmysql:insert('INSERT INTO `user_convictions` (`char_id`, `offense`, `count`) VALUES (?, ?, ?)', {data.char_id, charge, 1})
                end
            end)
        end
    end
end)


RegisterServerEvent("phils-mdt:submitNote")
AddEventHandler("phils-mdt:submitNote", function(data)
    local usource = source
    local Player = RSGCore.Functions.GetPlayer(usource)
    
    if not Player then return end
    
    local officername = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
    data.date = os.date('%m-%d-%Y %H:%M:%S', os.time())
    
    exports.oxmysql:insert('INSERT INTO `mdt_telegrams` (`title`, `incident`, `author`, `date`) VALUES (?, ?, ?, ?)', {
        data.title, 
        data.note, 
        officername, 
        data.date
    }, function(id)
        TriggerEvent("phils-mdt:getNoteDetailsById", id, usource)
        TriggerClientEvent("phils-mdt:sendNotification", usource, Config.Notify['8'])
        broadcastMDTUpdate()
    end)
end)


RegisterServerEvent("phils-mdt:performReportSearch")
AddEventHandler("phils-mdt:performReportSearch", function(query)
    local usource = source
    local matches = {}
    
    exports.oxmysql:fetch("SELECT * FROM `mdt_reports` WHERE `id` LIKE @query OR LOWER(`title`) LIKE @query OR LOWER(`name`) LIKE @query OR LOWER(`author`) LIKE @query OR LOWER(`charges`) LIKE @query", {
        ['@query'] = string.lower('%'..query..'%')
    }, function(result)
        for index, data in ipairs(result) do
            if data.charges then
                data.charges = json.decode(data.charges)
            end
            table.insert(matches, data)
        end
        
        TriggerClientEvent("phils-mdt:returnReportSearchResults", usource, matches)
    end)
end)

-- Get warrants
RegisterServerEvent("phils-mdt:getWarrants")
AddEventHandler("phils-mdt:getWarrants", function()
    local usource = source
    
    exports.oxmysql:fetch("SELECT * FROM `mdt_warrants`", {}, function(warrants)
        for i = 1, #warrants do
            warrants[i].expire_time = ""
            if warrants[i].charges then
                warrants[i].charges = json.decode(warrants[i].charges)
            end
        end
        
        TriggerClientEvent("phils-mdt:returnWarrants", usource, warrants)
    end)
end)

-- Submit new warrant
RegisterServerEvent("phils-mdt:submitNewWarrant")
AddEventHandler("phils-mdt:submitNewWarrant", function(data)
    local usource = source
    local Player = RSGCore.Functions.GetPlayer(usource)
    
    if not Player then return end
    
    local officername = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
    
    data.charges = json.encode(data.charges or {})
    data.author = officername
    data.date = os.date('%m-%d-%Y %H:%M:%S', os.time())
    
    exports.oxmysql:insert('INSERT INTO `mdt_warrants` (`name`, `char_id`, `report_id`, `report_title`, `charges`, `date`, `expire`, `notes`, `author`) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)', {
        data.name, 
        data.char_id, 
        data.report_id, 
        data.report_title, 
        data.charges, 
        data.date, 
        data.expire, 
        data.notes, 
        data.author
    }, function()
        TriggerClientEvent("phils-mdt:completedWarrantAction", usource)
        TriggerClientEvent("phils-mdt:sendNotification", usource, Config.Notify['5'])
        broadcastMDTUpdate()
    end)
end)


RegisterServerEvent("phils-mdt:deleteWarrant")
AddEventHandler("phils-mdt:deleteWarrant", function(id)
    local usource = source
    
    exports.oxmysql:execute('DELETE FROM `mdt_warrants` WHERE `id` = ?', {id}, function()
        TriggerClientEvent("phils-mdt:completedWarrantAction", usource)
        TriggerClientEvent("phils-mdt:sendNotification", usource, Config.Notify['6'])
        broadcastMDTUpdate()
    end)
end)


RegisterServerEvent("phils-mdt:getReportDetailsById")
AddEventHandler("phils-mdt:getReportDetailsById", function(query, _source)
    if _source then source = _source end
    local usource = source
    
    exports.oxmysql:fetch("SELECT * FROM `mdt_reports` WHERE `id` = ?", {query}, function(result)
        if result and result[1] then
            if result[1].charges then
                result[1].charges = json.decode(result[1].charges)
            end
            TriggerClientEvent("phils-mdt:returnReportDetails", usource, result[1])
        else
            TriggerClientEvent("phils-mdt:closeModal", usource)
            TriggerClientEvent("phils-mdt:sendNotification", usource, Config.Notify['7'])
        end
    end)
end)


RegisterServerEvent("phils-mdt:getNoteDetailsById")
AddEventHandler("phils-mdt:getNoteDetailsById", function(query, _source)
    if _source then source = _source end
    local usource = source
    
    exports.oxmysql:fetch("SELECT * FROM `mdt_telegrams` WHERE `id` = ?", {query}, function(result)
        if result and result[1] then
            TriggerClientEvent("phils-mdt:returnNoteDetails", usource, result[1])
        else
            TriggerClientEvent("phils-mdt:closeModal", usource)
            TriggerClientEvent("phils-mdt:sendNotification", usource, Config.Notify['9'])
        end
    end)
end)
