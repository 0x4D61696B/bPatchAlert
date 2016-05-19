-- =============================================================================
--  bPatchAlert
--    by: BurstBiscuit
-- =============================================================================

require "math"
require "table"
require "unicode"

require "lib/lib_Callback2"
require "lib/lib_ChatLib"
require "lib/lib_Debug"
require "lib/lib_HudNote"
require "lib/lib_InterfaceOptions"

Debug.EnableLogging(false)


-- =============================================================================
--  Constants and variables
-- =============================================================================

local c_URL         = {
    Production      = "https://operator.firefall.com/api/v1/products/Firefall_Beta",
    PublicTest      = "https://operator-publictest.firefall.com/api/v1/products/Firefall_PublicTest"
}

local g_Enable      = false
local g_BuildInfo   = {}
local g_Timer       = 900
local g_URL         = c_URL.Production

local CB2_ApplyOptions
local CB2_CheckForUpdate


-- =============================================================================
--  Interface Options
-- =============================================================================

function OnOptionChanged(id, value)
    if (id == "DEBUG_ENABLE") then
        Debug.EnableLogging(value)
        return

    elseif (id == "GENERAL_ENABLE") then
        g_Enable = value

    elseif (id == "CALLBACK_DELAY") then
        g_Timer = tonumber(value)

    elseif (id == "CALLBACK_EXECUTE") then
        CheckForUpdate(true)
        return
    end

    -- Don't spam callback updates
    if (CB2_ApplyOptions:Pending()) then
        CB2_ApplyOptions:Reschedule(1)

    else
        CB2_ApplyOptions:Schedule(1)
    end
end

do
    InterfaceOptions.SaveVersion(1)

    InterfaceOptions.AddCheckBox({
        id      = "DEBUG_ENABLE",
        label   = "Debug mode",
        default = false
    })

    InterfaceOptions.AddCheckBox({
        id      = "GENERAL_ENABLE",
        label   = "Addon enabled",
        default = false
    })

    InterfaceOptions.AddChoiceMenu({
        id      = "CALLBACK_DELAY",
        label   = "Timer",
        default = 900
    })
    InterfaceOptions.AddChoiceEntry({
        menuId  = "CALLBACK_DELAY",
        label   = "1 minute",
        val     = 60
    })
    InterfaceOptions.AddChoiceEntry({
        menuId  = "CALLBACK_DELAY",
        label   = "5 minutes",
        val     = 300
    })
    InterfaceOptions.AddChoiceEntry({
        menuId  = "CALLBACK_DELAY",
        label   = "15 minutes",
        val     = 900
    })
    InterfaceOptions.AddChoiceEntry({
        menuId  = "CALLBACK_DELAY",
        label   = "30 minutes",
        val     = 1800
    })
    InterfaceOptions.AddChoiceEntry({
        menuId  = "CALLBACK_DELAY",
        label   = "45 minutes",
        val     = 2700
    })
    InterfaceOptions.AddChoiceEntry({
        menuId  = "CALLBACK_DELAY",
        label   = "1 hour",
        val     = 3600
    })

    InterfaceOptions.AddButton({
        id      = "CALLBACK_EXECUTE",
        label   = "Check now"
    })
end

-- =============================================================================
--  Functions
-- =============================================================================

function Notification(message)
    ChatLib.Notification({text = "[bPatchAlert] " .. tostring(message)})
end

function CheckForUpdate(force)
    if (not g_Enable and not force) then
        return
    end

    Debug.Log("CheckForUpdate()")

    if (not HTTP.IsRequestPending(g_URL)) then
        HTTP.IssueRequest(g_URL, "GET", nil, OnRequestResponse)
    end
end

function UpdateCallback(timer)
    if (not g_Enable) then
        Debug.Log("Canceling callback ...")
        CB2_CheckForUpdate:Cancel()

    elseif (CB2_CheckForUpdate:Pending()) then
        Debug.Log("Rescheduling callback ...", timer or g_Timer)
        CB2_CheckForUpdate:Reschedule(g_Timer)

    else
        Debug.Log("Scheduling callback ...", timer or g_Timer)
        CB2_CheckForUpdate:Schedule(g_Timer)
    end
end

function OnRequestResponse(responseInfo, errorInfo)
    if (errorInfo) then
        Debug.Warn("OnRequestResponse()", errorInfo)

    elseif (responseInfo) then
        Debug.Table("OnRequestResponse()", responseInfo)
        Debug.Table("g_BuildInfo", g_BuildInfo)

        if (responseInfo.build) then
            local branch, build = unicode.match(responseInfo.build, "(%w+)%-(%d+)")
            Debug.Table("buildInfo", {Branch = branch, Build = build})

            if (unicode.match(branch, g_BuildInfo.Branch)) then
                if (tonumber(build) ~= g_BuildInfo.Build) then
                    HUDNOTE = HudNote.Create()
                    HUDNOTE:SetTitle("Update available!", "Firefall build " .. build .. " is available for download!")
                    HUDNOTE:SetDescription("Firefall build " .. build .. " is available for download!")
                    HUDNOTE:SetIconTexture("icons", "alert")
                    HUDNOTE:SetPrompt(1, "Exit game", function()
                        HUDNOTE:Remove()
                        System.Shutdown()
                    end)
                    HUDNOTE:SetPrompt(2, "Dismiss", function()
                        HUDNOTE:Remove()
                    end)
                    HUDNOTE:Post({ping = true})

                    return

                else
                    Debug.Log("Build is equal")
                end

            else
                Debug.Log("Not the same branch")
            end

        else
            Debug.Warn("No build info")
        end

    else
        Debug.Warn("OnRequestResponse() - no errorInfo or responseInfo")
    end

    UpdateCallback()
end


-- =============================================================================
--  Events
-- =============================================================================

function OnComponentLoad()
    local branch, build     = unicode.match(System.GetUniqueBuildID(), "(%w+)%-(%d+)")
    g_BuildInfo.Branch      = tostring(branch)
    g_BuildInfo.Build       = tonumber(build)

    CB2_ApplyOptions        = Callback2.Create()
    CB2_CheckForUpdate      = Callback2.Create()

    CB2_ApplyOptions:Bind(UpdateCallback)
    CB2_CheckForUpdate:Bind(CheckForUpdate)

    if (unicode.match(System.GetOperatorSetting("clientapi_host"), "clientapi%-publictest")) then
        g_URL = c_URL.PublicTest

    else
        g_URL = c_URL.Production
    end

    Debug.Log("g_URL", g_URL)

    InterfaceOptions.SetCallbackFunc(OnOptionChanged)
end
