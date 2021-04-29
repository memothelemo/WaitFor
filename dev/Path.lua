--[[

    Path
    Author: memothelemo (Cedcedmeranez)

    It allows to find the descendant by descendant without
	spamming the entire line of WaitFor's

	Inspired by: ChipioIndustries from his own module 'WaitForPath'

    Path.Safe(parent: Instance, path: string)
        => Instance

    Path.WithTimeout(parent: Instance, path: string, timeout: number | nil)
        => Instance | nil

]]

local Path = {}
local Config = require(script.Parent.Config)
local TimedResolver = require(script.Parent.TimedResolver)
local Child = require(script.Parent.Child)



function Path.Safe(parent: Instance, path: string, onCancel: RBXScriptSignal)
    --> Asserting
    assert(typeof(parent) == 'Instance', '`Parent` is required and must be an Instance')
    assert(type(path) == 'string', '`Path` is required and must be a string')
    assert(typeof(onCancel) == 'RBXScriptSignal' or onCancel == nil, '`onCancel` must be a RBXScriptSignal or nil')

    local segments = string.split(path, ".")
    local child = parent
    local isCanceled = false
    local canceledConnection

    if onCancel then
        canceledConnection = onCancel:Connect(function()
            canceledConnection:Disconnect()
            isCanceled = true
        end)
    end

    for _, descendant in pairs(segments) do
        child = Child['Safe'](child, descendant, onCancel)
        if isCanceled then
            break
        end
    end

    return child
end


function Path.WithTimeout(parent: Instance, path: string, timeout: number, ignoreError: boolean)
    --> Asserting
    assert(typeof(parent) == 'Instance', '`Parent` is required and must be an Instance')
    assert(type(path) == 'string', '`Path` is required and must be a string')
    assert(typeof(timeout) == 'number' or timeout == nil, "`Timeout` must be a number or nil")
    assert(typeof(ignoreError) == 'boolean', '`IgnoreError` must be a boolean or nil')
    
    timeout = timeout or Config.TIMEOUT

    local child = nil
    local cancellationBindable = Instance.new('BindableEvent')

    local safeResolver = TimedResolver.new(timeout, function(resolve)
        pcall(function()
            child = Path['Safe'](parent, path, cancellationBindable.Event)
            resolve()
        end)
    end, true)

    if (safeResolver:IsTimedOut()) then
        cancellationBindable:Fire()
        cancellationBindable:Destroy()

        safeResolver:Destroy()
        if not ignoreError then
            warn(("[WaitFor]: Failed to require ancestors to find the required child"))
        end
        return nil
    end

    cancellationBindable:Destroy()

    return child
end


return Path