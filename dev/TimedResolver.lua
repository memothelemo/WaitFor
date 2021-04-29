--[[
    
    TimedResolver
    Author: memothelemo (Cedcedmeranez)
    
    Purpose: Checks if the function is
    taking too much time to resolve

]]

local FastSpawn = require(script.Parent.FastSpawn)


local RunService = game:GetService("RunService")
local Heartbeat = RunService.Heartbeat

local TimedResolver = {}

local function heartbeatWait(duration: number)
    if not duration then
        return Heartbeat:Wait()
    else
        local i = 0
        while i < duration do
            i += Heartbeat:Wait()
        end
        return i
    end
end

function TimedResolver._new(duration: number, callback, ignoreError)
    local self = {}
    self._duration = duration
    self._resolved = false
    self._canceled = false
    self._callback = callback
    self._cancellationEvent = Instance.new('BindableEvent')

    local function resolve()
        if self._canceled then return end
        self._resolved = true
    end

    function self:Try()
        if (self._canceled or self._resolved) then return end
        
        --[[
            Spawning a new thread to avoid
            yielding and able to evaluate
            if it takes awhile to respond
        ]]
        FastSpawn(self._callback, resolve, self._cancellationEvent.Event)
        
        local countdown = duration
        while (countdown > 0 and not self._resolved) do
            countdown -= heartbeatWait()
        end

        --> If it is not resolved then the cancellationEvent will be called
        if (not self._resolved) then
            self._cancellationEvent:Fire()
            self._canceled = true
            if (not ignoreError) then
                warn("Failed to resolve the function!")
            end
        end
    end

    function self:IsTimedOut()
        return self._canceled
    end

    function self:IsResolved()
        return self._resolved
    end

    function self:Destroy()
        self._cancellationEvent:Destroy()
        self = nil
    end

    return self
end

function TimedResolver.new(duration: number, callback, ignoreError: boolean)
    assert(typeof(duration) == 'number', '`Duration` is required and must be a number')
    assert(typeof(callback) == 'function', '`Callback` is required and must be a number')

    local resolver = TimedResolver._new(duration, callback, ignoreError)
    resolver:Try()

    return resolver
end


return TimedResolver