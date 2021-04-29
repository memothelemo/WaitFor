--[[
    
    WaitFor.Event
    Author: memothelemo (Cedcedmeranez)
    
]]


local Config = require(script.Parent.Config)
local TimedResolver = require(script.Parent.TimedResolver)

local Event = {}


local function internalAssert(event)
    --> From OldWaitFor.EventSafe
    local isRBXScriptSignal = typeof(event) == 'RBXScriptSignal'
	local isTable = typeof(event) == 'table'
	assert(isTable or isRBXScriptSignal, 'Event argument must be on a table or RBXScriptSignal')

	--> It supports Signal class :D
	local isSignal = isTable and type(event['Connect']) == 'function'

	local isAnEvent = isRBXScriptSignal or isSignal
	assert(isAnEvent, 'Event argument must be RBXScriptSignal or Signal class')
end


function Event.Safe(event: RBXScriptSignal, onCancel: RBXScriptSignal)
    internalAssert(event)
    assert(typeof(onCancel) == 'RBXScriptSignal' or onCancel == nil, '`onCancel` must be a RBXScriptSignal or nil')

    --> Creating new bindable for the eventful something
	local bindable = Instance.new('BindableEvent')
	local connection = nil

	connection = event:Connect(function()
		connection:Disconnect()
		bindable:Fire()
	end)

    local cancelConnection
    if onCancel then
        cancelConnection = onCancel:Connect(function()
            cancelConnection:Disconnect()
            bindable:Fire()
        end)
    end
    
	bindable.Event:Wait()
	bindable:Destroy()
end


function Event.WithTimeout(event, timeout: number, ignoreError: boolean | nil)
    internalAssert(event)

    assert(typeof(timeout) == 'number' or timeout == nil, "`Timeout` must be a number or nil")
    assert(typeof(ignoreError) == 'boolean', '`IgnoreError` must be a boolean or nil')
    
    timeout = timeout or Config.TIMEOUT

    --> Same thing among the WaitFors with timeouts
    local cancellationBindable = Instance.new('BindableEvent')
    local safeResolver = TimedResolver.new(Config.TIMEOUT, function(resolve)
        pcall(function()
            Event.Safe(event, cancellationBindable.Event)
            resolve()
        end)
    end, true)

    if (safeResolver:IsResolved()) then
        cancellationBindable:Fire()
        cancellationBindable:Destroy()
        safeResolver:Destroy()
    else
        cancellationBindable:Destroy()
        safeResolver:Destroy()
        if not ignoreError then
            warn(("[WaitFor]: %s event failed to resolve in time"):format(tostring(event)))
        end
    end
end


return Event