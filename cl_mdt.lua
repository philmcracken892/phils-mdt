
local RSGCore = exports['rsg-core']:GetCoreObject()
local lib = exports.ox_lib
local showWarrantDetails

local mdtData = {
    offenses = {},
    officerName = "",
    recentReports = {},
    recentWarrants = {},
    recentNotes = {},
    recentFines = {},  
    searchResults = {},
    currentOffender = nil,
    currentReport = nil,
    currentNote = nil,
    currentFine = nil,  
    pendingFine = nil   
}


local currentContextId = nil


function IsValidImageURL(url)
    if not url or url == "" then
        return false
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

RegisterCommand('payfines', function()
    TriggerServerEvent('phils-mdt:getMyFines')
end)

RegisterCommand('checkfines', function()
    TriggerServerEvent('phils-mdt:getMyFines')
end)


local function showMyFines(fines)
    if not fines or #fines == 0 then
        lib:notify({
            title = 'Fines',
            description = 'You have no fines.',
            type = 'success'
        })
        return
    end
    
    local options = {}
    local totalOwed = 0
    
    
    for i, fine in ipairs(fines) do
        if fine.paid == false then
            totalOwed = totalOwed + fine.amount
            table.insert(options, {
                title = 'Fine #' .. fine.id .. ': $' .. fine.amount,
                description = 'Offense: ' .. fine.offense .. ' | Issued by: ' .. fine.officer_name .. ' | Date: ' .. fine.date,
                icon = 'fa-solid fa-money-bill',
                iconColor = 'red',
                onSelect = function()
                    payIndividualFine(fine)
                end
            })
        end
    end
    
    if #options == 0 then
        lib:notify({
            title = 'Fines',
            description = 'You have no  fines.',
            type = 'success'
        })
        return
    end
    
    
    if #options > 1 then
        table.insert(options, 1, {
            title = 'Pay All Fines ($' .. totalOwed .. ')',
            description = 'Pay all  fines at once',
            icon = 'fa-solid fa-credit-card',
            iconColor = 'green',
            onSelect = function()
                payAllFines(fines, totalOwed)
            end
        })
        
        table.insert(options, 2, {
            title = '------- Individual Fines -------',
            description = 'Select individual fines to pay below',
            icon = 'fa-solid fa-list',
            disabled = true
        })
    end
    
    lib:registerContext({
        id = 'my_fines',
        title = ' Fines ($' .. totalOwed .. ' total)',
        options = options
    })
    
    lib:showContext('my_fines')
end


function payIndividualFine(fine)
    local confirm = lib:alertDialog({
        header = 'Pay Fine',
        content = 'Pay fine for: ' .. fine.offense .. 
                  '\nAmount: $' .. fine.amount ..
                  '\nIssued by: ' .. fine.officer_name ..
                  (fine.notes and fine.notes ~= '' and ('\nNotes: ' .. fine.notes) or ''),
        centered = true,
        cancel = true,
        labels = {
            confirm = 'Pay $' .. fine.amount,
            cancel = 'Cancel'
        }
    })
    
    if confirm == 'confirm' then
       
        selectPaymentMethod(fine.id, fine.amount, 'single')
    end
end


function payAllFines(fines, totalAmount)
    local unpaidFines = {}
    for _, fine in ipairs(fines) do
        if fine.paid == false then
            table.insert(unpaidFines, fine.id)
        end
    end
    
    local confirm = lib:alertDialog({
        header = 'Pay All Fines',
        content = 'Pay all fines?\n\nTotal Amount: $' .. totalAmount .. '\nNumber of fines: ' .. #unpaidFines,
        centered = true,
        cancel = true,
        labels = {
            confirm = 'Pay $' .. totalAmount,
            cancel = 'Cancel'
        }
    })
    
    if confirm == 'confirm' then
        selectPaymentMethod(unpaidFines, totalAmount, 'all')
    end
end


function selectPaymentMethod(fineData, amount, paymentType)
    local options = {
        {
            title = 'Pay with Cash',
            description = 'Pay using cash on hand',
            icon = 'fa-solid fa-money-bill',
            onSelect = function()
                TriggerServerEvent('phils-mdt:payFine', fineData, amount, 'cash', paymentType)
            end
        },
        {
            title = 'Pay with Bank',
            description = 'Pay using bank account',
            icon = 'fa-solid fa-building-columns',
            onSelect = function()
                TriggerServerEvent('phils-mdt:payFine', fineData, amount, 'bank', paymentType)
            end
        },
        {
            title = 'Cancel',
            description = 'Go back to fines list',
            icon = 'fa-solid fa-times',
            onSelect = function()
                TriggerServerEvent('phils-mdt:getMyFines')
            end
        }
    }
    
    lib:registerContext({
        id = 'payment_method',
        title = 'Select  Method ($' .. amount .. ')',
        options = options
    })
    
    lib:showContext('payment_method')
end


RegisterNetEvent('phils-mdt:returnMyFines')
AddEventHandler('phils-mdt:returnMyFines', function(fines)
    showMyFines(fines)
end)

RegisterNetEvent('phils-mdt:finePaymentResult')
AddEventHandler('phils-mdt:finePaymentResult', function(success, message, newBalance)
    if success then
        lib:notify({
            title = 'Payment Successful',
            description = message .. (newBalance and ('\nRemaining Balance: $' .. newBalance) or ''),
            type = 'success',
            duration = 5000
        })
    else
        lib:notify({
            title = 'Payment Failed',
            description = message,
            type = 'error',
            duration = 5000
        })
    end
    
    
    Wait(1000)
    TriggerServerEvent('phils-mdt:getMyFines')
end)


RegisterCommand('finestatus', function()
    TriggerServerEvent('phils-mdt:getMyFinesStatus')
end)

RegisterNetEvent('phils-mdt:fineStatus')
AddEventHandler('phils-mdt:fineStatus', function(totalFines, totalAmount)
    if totalFines == 0 then
        lib:notify({
            title = 'Fine Status',
            description = 'You have no fines.',
            type = 'success'
        })
    else
        lib:notify({
            title = 'Fine Status',
            description = 'You have ' .. totalFines .. ' outstanding fine(s) totaling $' .. totalAmount .. '\nUse /payfines to pay them.',
            type = 'inform',
            duration = 7000
        })
    end
end)


RegisterNUICallback('closeMugshot', function(data, cb)
    SetNuiFocus(false, false)
    cb('ok')
end)


local function openMainMDT()
    TriggerServerEvent("phils-mdt:registerMDTUser")
    
    local options = {
        {
            title = 'Search Person',
            description = 'Search for a person',
            icon = 'fa-solid fa-file-lines',
            onSelect = function()
                openPersonSearch()
            end
        },
        {
            title = 'Search Reports',
            description = 'Search through reports',
            icon = 'fa-solid fa-file-lines',
            onSelect = function()
                openReportSearch()
            end
        },
        {
            title = 'Create Report',
            description = 'File a new  report',
            icon = 'fa-solid fa-file-lines',
            onSelect = function()
                openNewReportForm()
            end
        },
        {
            title = 'View Warrants',
            description = 'View active warrants',
            icon = 'fa-solid fa-gavel',
            onSelect = function()
                TriggerServerEvent("phils-mdt:getWarrants")
            end
        },
        {
            title = 'Create A Warrant',
            description = 'Issue a  warrant',
            icon = 'fa-solid fa-handcuffs',
            onSelect = function()
                openNewWarrantForm()
            end
        },
        
        {
            title = 'Issue Fine',
            description = 'Issue a fine ',
            icon = 'fa-solid fa-dollar-sign',
            onSelect = function()
                openNewFineForm()
            end
        },
        {
            title = 'View Recent Fines',
            description = 'View recent fines',
            icon = 'fa-solid fa-money-bill',
            onSelect = function()
                showRecentFines()
            end
        },
        {
            title = 'Write Telegram',
            description = 'Write a new note',
            icon = 'fa-solid fa-note-sticky',
            onSelect = function()
                openNewNoteForm()
            end
        },
        {
            title = 'Recent Reports',
            description = 'View recent reports',
            icon = 'fa-solid fa-clock-rotate-left',
            onSelect = function()
                showRecentReports()
            end
        },
        {
            title = 'Recent Telegrams',
            description = 'View recent telegrams',
            icon = 'fa-solid fa-envelope',
            onSelect = function()
                showRecentNotes()
            end
        }
    }
    
    lib:registerContext({
        id = 'rsg_mdt_main',
        title = 'Lawbook',
        options = options,
        onExit = function()
            TriggerServerEvent("phils-mdt:unregisterMDTUser")
            currentContextId = nil
            SendNUIMessage({
                action = 'closeMugshot'
            })
            SetNuiFocus(false, false)
        end
    })
    
    currentContextId = 'rsg_mdt_main'
    lib:showContext('rsg_mdt_main')
end
function openNewFineForm()
    local fineOptions = {}
    for _, offense in ipairs(mdtData.offenses) do
        if offense.amount and offense.amount > 0 then  -- Only show offenses with fine amounts
            table.insert(fineOptions, {
                label = offense.label .. ' ($' .. offense.amount .. ')',
                value = offense.label
            })
        end
    end
    
    if #fineOptions == 0 then
        lib:notify({
            title = 'MDT',
            description = 'No fineable offenses available. Contact administration.',
            type = 'error'
        })
        openMainMDT()
        return
    end
    
    local input = lib:inputDialog('Issue Fine', {
        {
            type = 'input',
            label = 'Citizen Name',
            description = 'Enter citizen full name',
            required = true,
            max = 100
        },
        {
            type = 'select',
            label = 'Offense',
            description = 'Select the offense',
            options = fineOptions,
            required = true
        },
        {
            type = 'textarea',
            label = 'Notes',
            description = 'Additional notes about the fine (optional)',
            max = 500
        }
    })
    
    if input then
        
        local selectedOffense = nil
        for _, offense in ipairs(mdtData.offenses) do
            if offense.label == input[2] then
                selectedOffense = offense
                break
            end
        end
        
        if selectedOffense then
            TriggerServerEvent("phils-mdt:performOffenderSearch", input[1])
            mdtData.pendingFine = {
                citizenName = input[1],
                offense = selectedOffense.label,
                amount = selectedOffense.amount,
                notes = input[3] or '',
                offenseData = selectedOffense
            }
        else
            lib:notify({
                title = 'MDT',
                description = 'Invalid offense selected.',
                type = 'error'
            })
            openMainMDT()
        end
    else
        openMainMDT()
    end
end


function showRecentFines()
    if not mdtData.recentFines or #mdtData.recentFines == 0 then
        lib:notify({
            title = 'MDT',
            description = 'No recent fines found',
            type = 'info'
        })
        openMainMDT()
        return
    end
    
    local options = {}
    
    for i, fine in ipairs(mdtData.recentFines) do
        local statusText = fine.paid and "PAID" or "UNPAID"
        local statusColor = fine.paid == 1 and "green" or "red"
        
        table.insert(options, {
            title = 'Fine #' .. fine.id .. ': ' .. fine.citizen_name,
            description = 'Offense: ' .. fine.offense .. ' | Amount: $' .. fine.amount .. ' | Status: ' .. statusText,
            icon = 'fa-solid fa-money-bill',
            iconColor = statusColor,
            onSelect = function()
                showFineDetails(fine)
            end
        })
    end
    
    table.insert(options, {
        title = 'Back to Main Menu',
        icon = 'fa-solid fa-arrow-left',
        onSelect = function()
            openMainMDT()
        end
    })
    
    lib:registerContext({
        id = 'recent_fines',
        title = 'Recent Fines',
        options = options
    })
    
    currentContextId = 'recent_fines'
    lib:showContext('recent_fines')
end

function showFineDetails(fine)
    mdtData.currentFine = fine
    
    local statusText = fine.paid and "PAID" or "UNPAID"
    local statusColor = fine.paid == 1 and "green" or "red"
    
    local options = {
        {
            title = 'Fine #' .. fine.id,
            description = 'Citizen: ' .. fine.citizen_name,
            icon = 'fa-solid fa-money-bill',
            disabled = true
        },
        {
            title = 'Offense: ' .. fine.offense,
            description = 'Violation committed',
            icon = 'fa-solid fa-exclamation-triangle',
            disabled = true
        },
        {
            title = 'Amount: $' .. fine.amount,
            description = 'Fine amount',
            icon = 'fa-solid fa-dollar-sign',
            disabled = true
        },
        {
            title = 'Status: ' .. statusText,
            description = 'Payment status',
            icon = 'fa-solid fa-info-circle',
            iconColor = statusColor,
            disabled = true
        },
        {
            title = 'Issued by: ' .. fine.officer_name,
            description = 'Officer who issued the fine',
            icon = 'fa-solid fa-user-tie',
            disabled = true
        },
        {
            title = 'Date: ' .. fine.date,
            description = 'Issue date',
            icon = 'fa-solid fa-calendar',
            disabled = true
        }
    }
    
    if fine.notes and fine.notes ~= '' then
        table.insert(options, {
            title = 'View Notes',
            description = 'Read fine notes',
            icon = 'fa-solid fa-note-sticky',
            onSelect = function()
                lib:alertDialog({
                    header = 'Fine Notes',
                    content = fine.notes,
                    centered = true,
                    cancel = true,
                    labels = {
                        cancel = 'Close'
                    }
                })
            end
        })
    end
    
    if fine.paid == false then
        table.insert(options, {
            title = 'Mark as Paid',
            description = 'Mark this fine as paid',
            icon = 'fa-solid fa-check',
            iconColor = 'green',
            onSelect = function()
                markFineAsPaid()
            end
        })
    end
    
    table.insert(options, {
        title = 'Delete Fine',
        description = 'Remove this fine permanently',
        icon = 'fa-solid fa-trash',
        iconColor = 'red',
        onSelect = function()
            deleteFine()
        end
    })
    
    table.insert(options, {
        title = 'Back to Fines',
        icon = 'fa-solid fa-arrow-left',
        onSelect = function()
            showRecentFines()
        end
    })
    
    lib:registerContext({
        id = 'fine_details',
        title = 'Fine Details',
        options = options
    })
    
    currentContextId = 'fine_details'
    lib:showContext('fine_details')
end

function markFineAsPaid()
    if not mdtData.currentFine then return end
    
    local confirm = lib:alertDialog({
        header = 'Mark Fine as Paid',
        content = 'Are you sure you want to mark Fine #' .. mdtData.currentFine.id .. ' as paid?\n\nAmount: $' .. mdtData.currentFine.amount,
        centered = true,
        cancel = true,
        labels = {
            confirm = 'Mark Paid',
            cancel = 'Cancel'
        }
    })
    
    if confirm == 'confirm' then
        TriggerServerEvent("phils-mdt:markFineAsPaid", mdtData.currentFine.id)
    else
        showFineDetails(mdtData.currentFine)
    end
end

function deleteFine()
    if not mdtData.currentFine then return end
    
    local confirm = lib:alertDialog({
        header = 'Delete Fine',
        content = 'Are you sure you want to delete Fine #' .. mdtData.currentFine.id .. '?\n\nThis action cannot be undone.',
        centered = true,
        cancel = true,
        labels = {
            confirm = 'Delete',
            cancel = 'Cancel'
        }
    })
    
    if confirm == 'confirm' then
        TriggerServerEvent("phils-mdt:deleteFine", mdtData.currentFine.id)
        openMainMDT()
    else
        showFineDetails(mdtData.currentFine)
    end
end


function selectPersonForFine(results)
    local options = {}
    
    for i, person in ipairs(results) do
        table.insert(options, {
            title = person.firstname .. ' ' .. person.lastname,
            description = 'DOB: ' .. (person.birthdate or 'Unknown') .. ' | ID: ' .. person.citizenid,
            icon = 'fa-solid fa-user',
            onSelect = function()
                confirmFineIssuance(person)
            end
        })
    end
    
    table.insert(options, {
        title = 'Cancel',
        icon = 'fa-solid fa-times',
        onSelect = function()
            mdtData.pendingFine = nil
            openMainMDT()
        end
    })
    
    lib:registerContext({
        id = 'select_person_fine',
        title = 'Select Person to Fine',
        options = options
    })
    
    currentContextId = 'select_person_fine'
    lib:showContext('select_person_fine')
end


function confirmFineIssuance(person)
    if not mdtData.pendingFine then return end
    
    local confirm = lib:alertDialog({
        header = 'Confirm Fine Issuance',
        content = 'Issue fine to: ' .. person.firstname .. ' ' .. person.lastname .. 
                  '\nOffense: ' .. mdtData.pendingFine.offense .. 
                  '\nAmount: $' .. mdtData.pendingFine.amount .. 
                  (mdtData.pendingFine.notes ~= '' and ('\nNotes: ' .. mdtData.pendingFine.notes) or ''),
        centered = true,
        cancel = true,
        labels = {
            confirm = 'Issue Fine',
            cancel = 'Cancel'
        }
    })
    
    if confirm == 'confirm' then
        local fineData = mdtData.pendingFine
        fineData.char_id = person.id
        fineData.citizenid = person.citizenid
        fineData.citizen_name = person.firstname .. ' ' .. person.lastname
        
        TriggerServerEvent("phils-mdt:submitNewFine", fineData)
        mdtData.pendingFine = nil
        openMainMDT()
    else
        selectPersonForFine({person})
    end
end
function openPersonSearch()
    local input = lib:inputDialog('Search Person', {
        {
            type = 'input',
            label = 'Name',
            description = 'Enter first or last name',
            required = true,
            min = 2,
            max = 50
        }
    })
    
    if input then
        TriggerServerEvent("phils-mdt:performOffenderSearch", input[1])
    else
        openMainMDT()
    end
end


local function showPersonSearchResults(results)
    if not results or #results == 0 then
        lib:notify({
            title = 'MDT',
            description = 'No results found',
            type = 'error'
        })
        openMainMDT()
        return
    end
    
    
    if mdtData.pendingFine then
        selectPersonForFine(results)
        return
    end
    
    
    local options = {}
    
    for i, person in ipairs(results) do
        table.insert(options, {
            title = person.firstname .. ' ' .. person.lastname,
            description = 'DOB: ' .. (person.birthdate or 'Unknown') .. ' | ID: ' .. person.citizenid,
            icon = 'fa-solid fa-user',
            onSelect = function()
                lib:notify({
                    title = 'MDT',
                    description = 'Loading person details...',
                    type = 'inform'
                })
                TriggerServerEvent("phils-mdt:getOffenderDetails", person)
            end
        })
    end
    
    table.insert(options, {
        title = 'New Search',
        icon = 'fa-solid fa-magnifying-glass',
        onSelect = function()
            openPersonSearch()
        end
    })
    
    table.insert(options, {
        title = 'Back to Main Menu',
        icon = 'fa-solid fa-arrow-left',
        onSelect = function()
            openMainMDT()
        end
    })
    
    lib:registerContext({
        id = 'person_search_results',
        title = 'Search Results (' .. #results .. ')',
        options = options
    })
    
    currentContextId = 'person_search_results'
    lib:showContext('person_search_results')
end


local function showPersonDetails(offender)
    mdtData.currentOffender = offender
    
    local options = {
        {
            title = 'Name: ' .. (offender.firstname or '') .. ' ' .. (offender.lastname or ''),
            description = 'Citizen Information',
            icon = 'fa-solid fa-id-card',
            disabled = true
        },
        {
            title = 'DOB: ' .. (offender.birthdate or 'Unknown'),
            description = 'Date of Birth',
            icon = 'fa-solid fa-calendar',
            disabled = true
        },
        {
            title = 'Citizen ID: ' .. (offender.citizenid or 'Unknown'),
            description = 'Unique Citizen Identifier',
            icon = 'fa-solid fa-id-badge',
            disabled = true
        },
        {
            title = 'Edit Notes',
            description = 'Add or edit notes ',
            icon = 'fa-solid fa-edit',
            onSelect = function()
                editPersonNotes()
            end
        },
        {
            title = 'View Convictions',
            description = 'View criminal history',
            icon = 'fa-solid fa-gavel',
            onSelect = function()
                showConvictions()
            end
        }
    }
    
    if offender.haswarrant then
        table.insert(options, {
            title = 'Active Warrant',
            description = 'This person has an active warrant',
            icon = 'fa-solid fa-exclamation-triangle',
            iconColor = 'red',
            disabled = true
        })
    end
    
    if offender.mugshot_url and offender.mugshot_url ~= "" then
        table.insert(options, {
            title = 'View Mugshot',
            description = 'View the suspect\'s mugshot',
            icon = 'fa-solid fa-image',
            onSelect = function()
                if IsValidImageURL(offender.mugshot_url) then
                    SetNuiFocus(true, true)
					Wait(100)  
                    SendNUIMessage({
                        action = 'showMugshot',
                        url = offender.mugshot_url
                    })
                else
                    lib:notify({
                        title = 'MDT',
                        description = 'Invalid mugshot URL.',
                        type = 'error'
                    })
                end
            end
        })
    end
    
    table.insert(options, {
        title = 'New Person Search',
        icon = 'fa-solid fa-magnifying-glass',
        onSelect = function()
            openPersonSearch()
        end
    })
    
    table.insert(options, {
        title = 'Back to Main Menu',
        icon = 'fa-solid fa-arrow-left',
        onSelect = function()
            openMainMDT()
        end
    })
    
    lib:registerContext({
        id = 'person_details',
        title = (offender.firstname or '') .. ' ' .. (offender.lastname or ''),
        options = options
    })
    
    currentContextId = 'person_details'
    lib:showContext('person_details')
end


function editPersonNotes()
    if not mdtData.currentOffender then return end
    
    local input = lib:inputDialog('Edit Person Notes', {
        {
            type = 'textarea',
            label = 'Notes',
            description = 'Enter notes about this person',
            default = mdtData.currentOffender.notes or '',
            max = 500
        },
        {
            type = 'input',
            label = 'Mugshot URL',
            description = 'Enter a valid image URL (e.g., Discord CDN or .jpg/.png)',
            default = mdtData.currentOffender.mugshot_url or ''
        },
        {
            type = 'checkbox',
            label = 'Bail Eligible',
            checked = mdtData.currentOffender.bail or false
        }
    })
    
    if input then
        local mugshot_url = input[2]
        if not IsValidImageURL(mugshot_url) then
            lib:notify({
                title = 'MDT',
                description = 'Invalid mugshot URL. Use a valid image URL (e.g., Discord CDN or .jpg/.png).',
                type = 'error'
            })
            return
        end
        
        local changes = {
            notes = input[1],
            mugshot_url = mugshot_url,
            bail = input[3]
        }
        
        TriggerServerEvent("phils-mdt:saveOffenderChanges", mdtData.currentOffender.id, changes, mdtData.currentOffender.citizenid)
    end
    
    showPersonDetails(mdtData.currentOffender)
end


function showConvictions()
    if not mdtData.currentOffender then return end
    
    local options = {}
    
    if mdtData.currentOffender.convictions then
        for offense, count in pairs(mdtData.currentOffender.convictions) do
            table.insert(options, {
                title = offense,
                description = 'Convictions: ' .. count,
                icon = 'fa-solid fa-balance-scale',
                disabled = true
            })
        end
    end
    
    if #options == 0 then
        table.insert(options, {
            title = 'No Convictions Found',
            description = 'This person has a clean record',
            icon = 'fa-solid fa-check-circle',
            iconColor = 'green',
            disabled = true
        })
    end
    
    table.insert(options, {
        title = 'Back to Person Details',
        icon = 'fa-solid fa-arrow-left',
        onSelect = function()
            showPersonDetails(mdtData.currentOffender)
        end
    })
    
    lib:registerContext({
        id = 'person_convictions',
        title = 'Criminal History',
        options = options
    })
    
    currentContextId = 'person_convictions'
    lib:showContext('person_convictions')
end


function openReportSearch()
    local input = lib:inputDialog('Search Reports', {
        {
            type = 'input',
            label = 'Search Term',
            description = 'Enter report ID, title, name, or author',
            required = true,
            min = 2,
            max = 50
        }
    })
    
    if input then
        TriggerServerEvent("phils-mdt:performReportSearch", input[1])
    else
        openMainMDT()
    end
end


local function showReportSearchResults(results)
    if not results or #results == 0 then
        lib:notify({
            title = 'MDT',
            description = 'No reports found',
            type = 'error'
        })
        openMainMDT()
        return
    end
    
    local options = {}
    
    for i, report in ipairs(results) do
        table.insert(options, {
            title = 'Report #' .. report.id .. ': ' .. report.title,
            description = 'Author: ' .. report.author .. ' | Date: ' .. report.date,
            icon = 'fa-solid fa-file',
            onSelect = function()
                TriggerServerEvent("phils-mdt:getReportDetailsById", report.id)
            end
        })
    end
    
    table.insert(options, {
        title = 'Back to Main Menu',
        icon = 'fa-solid fa-arrow-left',
        onSelect = function()
            openMainMDT()
        end
    })
    
    lib:registerContext({
        id = 'report_search_results',
        title = 'Report Search Results (' .. #results .. ')',
        options = options
    })
    
    currentContextId = 'report_search_results'
    lib:showContext('report_search_results')
end

local function showReportDetails(report)
    mdtData.currentReport = report
    
    local options = {
        {
            title = 'Report #' .. report.id,
            description = report.title,
            icon = 'fa-solid fa-file-lines',
            disabled = true
        },
        {
            title = 'Author: ' .. report.author,
            description = 'Report created by',
            icon = 'fa-solid fa-user',
            disabled = true
        },
        {
            title = 'Date: ' .. report.date,
            description = 'Creation date',
            icon = 'fa-solid fa-calendar',
            disabled = true
        },
        {
            title = 'Suspect: ' .. report.name,
            description = 'Suspect name',
            icon = 'fa-solid fa-user',
            disabled = true
        }
    }
    
    if report.charges and #report.charges > 0 then
        table.insert(options, {
            title = 'Charges: ' .. table.concat(report.charges, ', '),
            description = 'Convictions associated with this report',
            icon = 'fa-solid fa-gavel',
            disabled = true
        })
    else
        table.insert(options, {
            title = 'No Charges',
            description = 'No convictions associated with this report',
            icon = 'fa-solid fa-gavel',
            disabled = true
        })
    end
    
    table.insert(options, {
        title = 'View Full Report',
        description = 'Read the complete incident report',
        icon = 'fa-solid fa-eye',
        onSelect = function()
            viewFullReport()
        end
    })
    
    table.insert(options, {
        title = 'Edit Report',
        description = 'Modify report details',
        icon = 'fa-solid fa-edit',
        onSelect = function()
            editReport()
        end
    })
    
    table.insert(options, {
        title = 'Delete Report',
        description = 'Permanently delete this report',
        icon = 'fa-solid fa-trash',
        iconColor = 'red',
        onSelect = function()
            deleteReport()
        end
    })
    
    table.insert(options, {
        title = 'Back to Search',
        icon = 'fa-solid fa-arrow-left',
        onSelect = function()
            openReportSearch()
        end
    })
    
    lib:registerContext({
        id = 'report_details',
        title = 'Report Details',
        options = options
    })
    
    currentContextId = 'report_details'
    lib:showContext('report_details')
end


function viewFullReport()
    if not mdtData.currentReport then return end
    
    local content = 'Title: ' .. mdtData.currentReport.title .. '\n\nIncident Details:\n' .. mdtData.currentReport.incident
    if mdtData.currentReport.charges and #mdtData.currentReport.charges > 0 then
        content = content .. '\n\nCharges:\n' .. table.concat(mdtData.currentReport.charges, ', ')
    end
    
    lib:alertDialog({
        header = 'Report #' .. mdtData.currentReport.id,
        content = content,
        centered = true,
        cancel = true,
        labels = {
            cancel = 'Close'
        }
    })
end


function editReport()
    if not mdtData.currentReport then return end
    
   
    local chargeOptions = {}
    for _, offense in ipairs(mdtData.offenses) do
        table.insert(chargeOptions, {
            label = offense.label,
            value = offense.label
        })
    end
    
    local input = lib:inputDialog('Edit Report', {
        {
            type = 'input',
            label = 'Title',
            description = 'Report title',
            default = mdtData.currentReport.title,
            required = true,
            max = 100
        },
        {
            type = 'textarea',
            label = 'Incident Details',
            description = 'Describe the incident',
            default = mdtData.currentReport.incident,
            required = true,
            max = 1000
        },
        {
            type = 'multi-select',
            label = 'Charges',
            description = 'Select applicable charges',
            options = chargeOptions,
            default = mdtData.currentReport.charges or {}
        }
    })
    
    if input then
        local data = {
            id = mdtData.currentReport.id,
            title = input[1],
            incident = input[2],
            charges = input[3],
            char_id = mdtData.currentReport.char_id
        }
        
        TriggerServerEvent("phils-mdt:saveReportChanges", data)
    end
    
    showReportDetails(mdtData.currentReport)
end


function deleteReport()
    if not mdtData.currentReport then return end
    
    local confirm = lib:alertDialog({
        header = 'Delete Report',
        content = 'Are you sure you want to delete Report #' .. mdtData.currentReport.id .. '?\n\nThis action cannot be undone.',
        centered = true,
        cancel = true,
        labels = {
            confirm = 'Delete',
            cancel = 'Cancel'
        }
    })
    
    if confirm == 'confirm' then
        TriggerServerEvent("phils-mdt:deleteReport", mdtData.currentReport.id)
        openMainMDT()
    else
        showReportDetails(mdtData.currentReport)
    end
end


function openNewReportForm()
    local chargeOptions = {}
    for _, offense in ipairs(mdtData.offenses) do
        table.insert(chargeOptions, {
            label = offense.label,
            value = offense.label
        })
    end
    
    local input = lib:inputDialog('New Incident Report', {
        {
            type = 'input',
            label = 'Suspect Name',
            description = 'Enter suspect full name',
            required = true,
            max = 100
        },
        {
            type = 'input',
            label = 'Report Title',
            description = 'Brief title for the report',
            required = true,
            max = 100
        },
        {
            type = 'textarea',
            label = 'Incident Details',
            description = 'Describe what happened',
            required = true,
            max = 1000
        },
        {
            type = 'multi-select',
            label = 'Charges',
            description = 'Select applicable charges',
            options = chargeOptions
        },
        {
            type = 'input',
            label = 'Notice Image URL',
            description = 'Optional image URL for public notice (e.g., mugshot)',
            max = 255
        }
    })
    
    if input then
        if input[5] and not IsValidImageURL(input[5]) then
            lib:notify({
                title = 'MDT',
                description = 'Invalid image URL for notice. Use Discord CDN or .jpg/.png.',
                type = 'error'
            })
            return
        end
        TriggerServerEvent("phils-mdt:performOffenderSearch", input[1])
        mdtData.pendingReport = {
            name = input[1],
            title = input[2],
            incident = input[3],
            charges = input[4] or {},
            notice_url = input[5] or '' -- Add notice URL
        }
    else
        openMainMDT()
    end
end


function openNewWarrantForm()
    local input = lib:inputDialog('New Warrant', {
        {
            type = 'input',
            label = 'Suspect Name',
            description = 'Enter suspect full name',
            required = true,
            max = 100
        },
        {
            type = 'input',
            label = 'Related Report ID',
            description = 'ID of related report (optional)',
            max = 10
        },
        {
            type = 'input',
            label = 'Report Title',
            description = 'Title of related report',
            max = 100
        },
        {
            type = 'textarea',
            label = 'Warrant Notes',
            description = 'Additional notes for the warrant',
            max = 500
        },
        {
            type = 'date',
            label = 'Expiry Date',
            description = 'When should this warrant expire?',
            default = true,
            format = 'DD/MM/YYYY'
        },
        {
            type = 'input',
            label = 'Notice Image URL',
            description = 'Optional image URL for public notice (e.g., mugshot)',
            max = 255
        }
    })
    
    if input then
        if input[6] and not IsValidImageURL(input[6]) then
            lib:notify({
                title = 'MDT',
                description = 'Invalid image URL for notice. Use Discord CDN or .jpg/.png.',
                type = 'error'
            })
            return
        end
        TriggerServerEvent("phils-mdt:performOffenderSearch", input[1])
        mdtData.pendingWarrant = {
            name = input[1],
            report_id = input[2] or 0,
            report_title = input[3] or '',
            notes = input[4] or '',
            expire = input[5] or '',
            notice_url = input[6] or '' -- Add notice URL
        }
    else
        openMainMDT()
    end
end


function openNewNoteForm()
    local input = lib:inputDialog('New Telegram', {
        {
            type = 'input',
            label = 'Title',
            description = 'Telegram title',
            required = true,
            max = 100
        },
        {
            type = 'textarea',
            label = 'Message',
            description = 'Telegram content',
            required = true,
            max = 500
        }
    })
    
    if input then
        local data = {
            title = input[1],
            note = input[2]
        }
        
        TriggerServerEvent("phils-mdt:submitNote", data)
    end
    
    openMainMDT()
end


function showRecentReports()
    if not mdtData.recentReports or #mdtData.recentReports == 0 then
        lib:notify({
            title = 'MDT',
            description = 'No recent reports found',
            type = 'info'
        })
        openMainMDT()
        return
    end
    
    local options = {}
    
    for i, report in ipairs(mdtData.recentReports) do
        table.insert(options, {
            title = 'Report #' .. report.id .. ': ' .. report.title,
            description = 'By: ' .. report.author .. ' | ' .. report.date,
            icon = 'fa-solid fa-file',
            onSelect = function()
                TriggerServerEvent("phils-mdt:getReportDetailsById", report.id)
            end
        })
    end
    
    table.insert(options, {
        title = 'Back to Main Menu',
        icon = 'fa-solid fa-arrow-left',
        onSelect = function()
            openMainMDT()
        end
    })
    
    lib:registerContext({
        id = 'recent_reports',
        title = 'Recent Reports',
        options = options
    })
    
    currentContextId = 'recent_reports'
    lib:showContext('recent_reports')
end


function showRecentNotes()
    if not mdtData.recentNotes or #mdtData.recentNotes == 0 then
        lib:notify({
            title = 'MDT',
            description = 'No recent telegrams found',
            type = 'info'
        })
        openMainMDT()
        return
    end
    
    local options = {}
    
    for i, note in ipairs(mdtData.recentNotes) do
        table.insert(options, {
            title = 'Telegram #' .. note.id .. ': ' .. note.title,
            description = 'By: ' .. note.author .. ' | ' .. note.date,
            icon = 'fa-solid fa-envelope',
            onSelect = function()
                TriggerServerEvent("phils-mdt:getNoteDetailsById", note.id)
            end
        })
    end
    
    table.insert(options, {
        title = 'Back to Main Menu',
        icon = 'fa-solid fa-arrow-left',
        onSelect = function()
            openMainMDT()
        end
    })
    
    lib:registerContext({
        id = 'recent_notes',
        title = 'Recent Telegrams',
        options = options
    })
    
    currentContextId = 'recent_notes'
    lib:showContext('recent_notes')
end


function showNoteDetails(note)
    mdtData.currentNote = note
    
    local options = {
        {
            title = 'Telegram #' .. note.id,
            description = note.title,
            icon = 'fa-solid fa-envelope',
            disabled = true
        },
        {
            title = 'Author: ' .. note.author,
            description = 'Telegram created by',
            icon = 'fa-solid fa-user',
            disabled = true
        },
        {
            title = 'Date: ' .. note.date,
            description = 'Creation date',
            icon = 'fa-solid fa-calendar',
            disabled = true
        },
        {
            title = 'View Full Telegram',
            description = 'Read the complete telegram message',
            icon = 'fa-solid fa-eye',
            onSelect = function()
                viewFullNote()
            end
        },
        {
            title = 'Delete Telegram',
            description = 'Permanently delete this telegram',
            icon = 'fa-solid fa-trash',
            iconColor = 'red',
            onSelect = function()
                deleteNote()
            end
        },
        {
            title = 'Back to Telegrams',
            icon = 'fa-solid fa-arrow-left',
            onSelect = function()
                showRecentNotes()
            end
        }
    }
    
    lib:registerContext({
        id = 'note_details',
        title = 'Telegram Details',
        options = options
    })
    
    currentContextId = 'note_details'
    lib:showContext('note_details')
end


function viewFullNote()
    if not mdtData.currentNote then return end
    
    lib:alertDialog({
        header = 'Telegram #' .. mdtData.currentNote.id,
        content = 'Title: ' .. mdtData.currentNote.title .. '\n\nMessage:\n' .. mdtData.currentNote.incident,
        centered = true,
        cancel = true,
        labels = {
            cancel = 'Close'
        }
    })
end


function deleteNote()
    if not mdtData.currentNote then return end
    
    local confirm = lib:alertDialog({
        header = 'Delete Telegram',
        content = 'Are you sure you want to delete Telegram #' .. mdtData.currentNote.id .. '?\n\nThis action cannot be undone.',
        centered = true,
        cancel = true,
        labels = {
            confirm = 'Delete',
            cancel = 'Cancel'
        }
    })
    
    if confirm == 'confirm' then
        TriggerServerEvent("phils-mdt:deleteNote", mdtData.currentNote.id)
        openMainMDT()
    else
        showNoteDetails(mdtData.currentNote)
    end
end


function showWarrants(warrants)
    if not warrants or #warrants == 0 then
        lib:notify({
            title = 'MDT',
            description = 'No active warrants found',
            type = 'info'
        })
        openMainMDT()
        return
    end
    
    local options = {}
    
    for i, warrant in ipairs(warrants) do
        table.insert(options, {
            title = warrant.name,
            description = 'Report: ' .. warrant.report_title .. ' | By: ' .. warrant.author,
            icon = 'fa-solid fa-gavel',
            iconColor = 'red',
            onSelect = function()
                showWarrantDetails(warrant)  
            end
        })
    end
    
    table.insert(options, {
        title = 'Back to Main Menu',
        icon = 'fa-solid fa-arrow-left',
        onSelect = function()
            openMainMDT()
        end
    })
    
    lib:registerContext({
        id = 'warrants_list',
        title = 'Active Warrants (' .. #warrants .. ')',
        options = options
    })
    
    currentContextId = 'warrants_list'
    lib:showContext('warrants_list')
end

function showWarrantDetails(warrant)
    if not warrant or type(warrant) ~= 'table' then
        lib:notify({
            title = 'MDT',
            description = 'Invalid warrant data.',
            type = 'error'
        })
        openMainMDT()
        return
    end

   
    
    if IsScreenFadedOut() then
        DoScreenFadeIn(500)
    end

    local options = {
        {
            title = 'Suspect: ' .. (warrant.name or 'Unknown'),
            description = 'Warrant target',
            icon = 'fa-solid fa-user',
            disabled = true
        },
        {
            title = 'Report: ' .. (warrant.report_title or 'None'),
            description = 'Related report',
            icon = 'fa-solid fa-file',
            disabled = true
        },
        {
            title = 'Issued by: ' .. (warrant.author or 'Unknown'),
            description = 'Warrant author',
            icon = 'fa-solid fa-user-tie',
            disabled = true
        },
        {
            title = 'Date: ' .. (warrant.date or 'Unknown'),
            description = 'Issue date',
            icon = 'fa-solid fa-calendar',
            disabled = true
        },
        {
            title = 'Delete Warrant',
            description = 'Remove this warrant',
            icon = 'fa-solid fa-trash',
            iconColor = 'red',
            onSelect = function()
                deleteWarrant(warrant.id)
            end
        },
        {
            title = 'Back to Warrants',
            icon = 'fa-solid fa-arrow-left',
            onSelect = function()
                TriggerServerEvent("phils-mdt:getWarrants")
            end
        }
    }
    
    if warrant.notes and warrant.notes ~= '' then
        table.insert(options, 5, {
            title = 'View Notes',
            description = 'Read warrant notes',
            icon = 'fa-solid fa-note-sticky',
            onSelect = function()
                lib:alertDialog({
                    header = 'Warrant Notes',
                    content = warrant.notes,
                    centered = true,
                    cancel = true,
                    labels = {
                        cancel = 'Close'
                    }
                })
            end
        })
    end
    
    lib:registerContext({
        id = 'warrant_details',
        title = 'Warrant Details',
        options = options
    })
    
    currentContextId = 'warrant_details'
    lib:showContext('warrant_details')
end


function deleteWarrant(warrantId)
    local confirm = lib:alertDialog({
        header = 'Delete Warrant',
        content = 'Are you sure you want to delete this warrant?\n\nThis action cannot be undone.',
        centered = true,
        cancel = true,
        labels = {
            confirm = 'Delete',
            cancel = 'Cancel'
        }
    })
    
    if confirm == 'confirm' then
        TriggerServerEvent("phils-mdt:deleteWarrant", warrantId)
    end
end


function selectPersonForReport(results)
    local options = {}
    
    for i, person in ipairs(results) do
        table.insert(options, {
            title = person.firstname .. ' ' .. person.lastname,
            description = 'DOB: ' .. (person.birthdate or 'Unknown') .. ' | ID: ' .. person.citizenid,
            icon = 'fa-solid fa-user',
            onSelect = function()
                createReportWithPerson(person)
            end
        })
    end
    
    table.insert(options, {
        title = 'Cancel',
        icon = 'fa-solid fa-times',
        onSelect = function()
            mdtData.pendingReport = nil
            openMainMDT()
        end
    })
    
    lib:registerContext({
        id = 'select_person_report',
        title = 'Select Person for Report',
        options = options
    })
    
    currentContextId = 'select_person_report'
    lib:showContext('select_person_report')
end

function createReportWithPerson(person)
    local reportData = mdtData.pendingReport
    reportData.char_id = person.id
    reportData.name = person.firstname .. ' ' .. person.lastname
    reportData.notice_url = reportData.notice_url or '' -- Ensure notice_url is included
    
    TriggerServerEvent("phils-mdt:submitNewReport", reportData)
    mdtData.pendingReport = nil
    openMainMDT()
end

function selectPersonForWarrant(results)
    local options = {}
    
    for i, person in ipairs(results) do
        table.insert(options, {
            title = person.firstname .. ' ' .. person.lastname,
            description = 'DOB: ' .. (person.birthdate or 'Unknown') .. ' | ID: ' .. person.citizenid,
            icon = 'fa-solid fa-user',
            onSelect = function()
                createWarrantWithPerson(person)
            end
        })
    end
    
    table.insert(options, {
        title = 'Cancel',
        icon = 'fa-solid fa-times',
        onSelect = function()
            mdtData.pendingWarrant = nil
            openMainMDT()
        end
    })
    
    lib:registerContext({
        id = 'select_person_warrant',
        title = 'Select player',
        options = options
    })
    
    currentContextId = 'select_person_warrant'
    lib:showContext('select_person_warrant')
end

function createWarrantWithPerson(person)
    local warrantData = mdtData.pendingWarrant
    warrantData.char_id = person.id
    warrantData.name = person.firstname .. ' ' .. person.lastname
    warrantData.charges = {}
    warrantData.notice_url = warrantData.notice_url or '' -- Ensure notice_url is included
    
    TriggerServerEvent("phils-mdt:submitNewWarrant", warrantData)
    mdtData.pendingWarrant = nil
    openMainMDT()
end

RegisterNetEvent("phils-mdt:toggleVisibilty")
AddEventHandler("phils-mdt:toggleVisibilty", function(reports, warrants, officer, job, grade, notes, fines)
    mdtData.recentReports = reports or {}
    mdtData.recentWarrants = warrants or {}
    mdtData.recentNotes = notes or {}
    mdtData.recentFines = fines or {}  -- NEW: Add fines data
    mdtData.officerName = officer
    
    TriggerServerEvent("phils-mdt:getOffensesAndOfficer")
    openMainMDT()
end)

RegisterNetEvent("phils-mdt:updateMDTData")
AddEventHandler("phils-mdt:updateMDTData", function(reports, warrants, notes, fines)
    mdtData.recentReports = reports or {}
    mdtData.recentWarrants = warrants or {}
    mdtData.recentNotes = notes or {}
    mdtData.recentFines = fines or {}  -- NEW: Add fines data
    
    -- Refresh current context if viewing fines
    if currentContextId == 'recent_reports' then
        showRecentReports()
    elseif currentContextId == 'warrants_list' then
        showWarrants(mdtData.recentWarrants)
    elseif currentContextId == 'recent_notes' then
        showRecentNotes()
    elseif currentContextId == 'recent_fines' then  -- NEW: Handle fines refresh
        showRecentFines()
    elseif currentContextId == 'report_details' and mdtData.currentReport then
        local reportExists = false
        for _, report in ipairs(mdtData.recentReports) do
            if report.id == mdtData.currentReport.id then
                mdtData.currentReport = report
                reportExists = true
                break
            end
        end
        if reportExists then
            showReportDetails(mdtData.currentReport)
        else
            lib:notify({
                title = 'MDT',
                description = 'Current report no longer exists.',
                type = 'info'
            })
            openMainMDT()
        end
    elseif currentContextId == 'note_details' and mdtData.currentNote then
        local noteExists = false
        for _, note in ipairs(mdtData.recentNotes) do
            if note.id == mdtData.currentNote.id then
                mdtData.currentNote = note
                noteExists = true
                break
            end
        end
        if noteExists then
            showNoteDetails(mdtData.currentNote)
        else
            lib:notify({
                title = 'MDT',
                description = 'Current telegram no longer exists.',
                type = 'info'
            })
            openMainMDT()
        end
    elseif currentContextId == 'fine_details' and mdtData.currentFine then  -- NEW: Handle fine details refresh
        local fineExists = false
        for _, fine in ipairs(mdtData.recentFines) do
            if fine.id == mdtData.currentFine.id then
                mdtData.currentFine = fine
                fineExists = true
                break
            end
        end
        if fineExists then
            showFineDetails(mdtData.currentFine)
        else
            lib:notify({
                title = 'MDT',
                description = 'Current fine no longer exists.',
                type = 'info'
            })
            openMainMDT()
        end
    end
end)

RegisterNetEvent("phils-mdt:returnOffenderSearchResults")
AddEventHandler("phils-mdt:returnOffenderSearchResults", function(results)
    if mdtData.pendingReport then
        if results and #results > 0 then
            selectPersonForReport(results)
        else
            lib:notify({
                title = 'MDT',
                description = 'Person not found. Please search manually.',
                type = 'error'
            })
            openMainMDT()
        end
    elseif mdtData.pendingWarrant then
        if results and #results > 0 then
            selectPersonForWarrant(results)
        else
            lib:notify({
                title = 'MDT',
                description = 'Person not found. Please search manually.',
                type = 'error'
            })
            openMainMDT()
        end
    else
        showPersonSearchResults(results)
    end
end)

RegisterNetEvent("phils-mdt:returnOffenderDetails")
AddEventHandler("phils-mdt:returnOffenderDetails", function(data)
    if not data or not data.id then
        lib:notify({
            title = 'MDT',
            description = 'Failed to load person details. Try again.',
            type = 'error'
        })
        openMainMDT()
        return
    end
    showPersonDetails(data)
end)

RegisterNetEvent("phils-mdt:returnOffensesAndOfficer")
AddEventHandler("phils-mdt:returnOffensesAndOfficer", function(data, name)
    mdtData.offenses = data
    mdtData.officerName = name
end)

RegisterNetEvent("phils-mdt:returnReportSearchResults")
AddEventHandler("phils-mdt:returnReportSearchResults", function(results)
    showReportSearchResults(results)
end)

RegisterNetEvent("phils-mdt:returnWarrants")
AddEventHandler("phils-mdt:returnWarrants", function(data)
    showWarrants(data)
end)

RegisterNetEvent("phils-mdt:returnReportDetails")
AddEventHandler("phils-mdt:returnReportDetails", function(data)
    showReportDetails(data)
end)

RegisterNetEvent("phils-mdt:returnRecentFines")
AddEventHandler("phils-mdt:returnRecentFines", function(fines)
    mdtData.recentFines = fines or {}
    showRecentFines()
end)

RegisterNetEvent("phils-mdt:fineActionCompleted")
AddEventHandler("phils-mdt:fineActionCompleted", function()
    TriggerServerEvent("phils-mdt:getRecentFines")
end)

RegisterNetEvent("phils-mdt:returnNoteDetails")
AddEventHandler("phils-mdt:returnNoteDetails", function(data)
    if not data or not data.id then
        lib:notify({
            title = 'MDT',
            description = 'Failed to load telegram details. Try again.',
            type = 'error'
        })
        openMainMDT()
        return
    end
    showNoteDetails(data)
end)

RegisterNetEvent("phils-mdt:sendNotification")
AddEventHandler("phils-mdt:sendNotification", function(message)
    lib:notify({
        title = 'MDT',
        description = message,
        type = 'success'
    })
end)

RegisterNetEvent("phils-mdt:closeModal")
AddEventHandler("phils-mdt:closeModal", function()
    lib:notify({
        title = 'MDT',
        description = 'Operation cancelled or data not found.',
        type = 'error'
    })
    openMainMDT()
end)

RegisterNetEvent("phils-mdt:completedWarrantAction")
AddEventHandler("phils-mdt:completedWarrantAction", function()
    TriggerServerEvent("phils-mdt:getWarrants")
end)


