--!strict

--[[

    WaitFor (Promise verison)
    Author: memothelemo
    Created: March 30, 2021
    Updated: April 4, 2021 (Update 2 | Promise Version Update 1)

	Warning: I'm very tired while making a Promise version for Update 2 
		     so bugs and false errors may occurred (especially promise functions).

]]

--> Settings
local DEFAULT_TIMEOUT = 30


-- From WaitFor.Child
local TIMEOUT_ERROR = 'Failed to wait a child, "%s" from the parent of %s. (Timeout)'


-- From WaitFor.Path and PathSafe
local TIMEOUT_PATH_ERROR = [[
Failed to wait a descendant child, "%s" (the ancestor of %s) 
from the highest ancestor %s, whilst verifying all of the descendants 
found in the path
]]


-- From WaitFor.Children but timeout
local TIMEOUT_CHILDREN_ERROR = [[
Failed to wait a child, "%s" from the parent of %s whilst 
verifying required children. (Timeout)
]]


-- From WaitFor.Children
local WAITFOR_CHILDREN_FAILED = [[
Failed to wait the required children from the parent of %
s whilst verifying all of them.
]]


-- From WaitFor.Event
local TIMEOUT_EVENT_ERROR = [[
Failed to wait an event, %s whlist waiting until it is
being triggered. (Timeout)
]]


--[[
	Grabbing services
]]
local RunService = game:GetService("RunService")
local isClient = RunService:IsClient()


-- Grabbing Promise module script
local Promise = require(script.Parent.Promise)


--[[
	This function will be make the function easier to maintance
	and cleaner as well
]]
local function AssertFunction(functionName: string, ...)
	local args = {...}
	local assertments = {
		Path = function()
			assert(typeof(args[1]) == 'Instance', 'Parent argument must be an Instance')
			assert(typeof(args[2]) == 'string', 'Path argument must be a string')
		end,

		Children = function()
			assert(typeof(args[1]) == 'Instance', 'Parent argument must be an Instance')
			assert(typeof(args[2]) == 'table', 'Children argument must be a table')
		end,

		ChildSafe = function()
			assert(typeof(args[1]) == 'Instance', 'Parent argument must be an Instance')
			assert(type(args[2]) == 'string', 'Name argument must be a string')
		end,

		Child = function()
			assert(typeof(args[1]) == 'Instance', 'Parent argument must be an Instance')
			assert(type(args[2]) == 'string', 'Name argument must be a string')
			assert(type(args[3]) == 'boolean' or args[3] == nil, 'Ignore error argument must be a boolean or nil')
		end,
	}
	assertments[functionName]()
end


--[[
	Informative error message feature function
]]
local function Traceback(output: string)
	local tracebackContext = debug.traceback()
	warn(('\n[WaitFor Error]:\n%s\n[Traceback]:\n%s'):format(output, tracebackContext))
end


--[[
	Some important functions alternative ones than ROBLOX's built-in wait function
]] 
local function WaitStep(): number
	return (isClient and RunService.RenderStepped:Wait() or RunService.Heartbeat:Wait())
end


local function Wait(seconds: number): number
	local i = 0
	while (i <= seconds) do
		local dt = WaitStep()
		i += dt
	end
	return i
end


local function Spawn(callback)
	local heartbeat = nil
	heartbeat = RunService.Heartbeat:Connect(function()
		callback()
	end)
	heartbeat:Disconnect()
end


--> WaitFor Module Call
local WaitFor = {}


--[[
	It is a function that it ignores the timeout by using ChildAdded 
	event instead looping which it helps the performance
]]
function WaitFor.ChildSafe(parent: Instance, name: string): Instance
	--> Verifying for arguments
	AssertFunction("ChildSafe", parent, name)

	--> Variables
	local bindable = Instance.new('BindableEvent')
	local connection = nil
	local child = parent:FindFirstChild(name)

	if not child then
		connection = parent.ChildAdded:Connect(function(newChild)
			--[[
				Verifying if it is the same name (new child)
				as the expected child
			]]
			if (newChild.Name == name) then
				child = newChild

				connection:Disconnect()
				bindable:Fire()
			end
		end)
	else
		return child
	end

	--[[
		If the child is not yet found then it has to wait
		until the bindable responds that a waiting child founds it
	]]
	bindable.Event:Wait()
	bindable:Destroy()

	return child
end
WaitFor.childSafe = WaitFor.ChildSafe


--[[
    Promise implementation
]]
function WaitFor.ChildSafePromise(parent: Instance, name: string)
	--> Verifying for arguments
	AssertFunction("ChildSafe", parent, name)

	return Promise.new(function(resolve)
		--> Variables
		local connection = nil
		local child = parent:FindFirstChild(name)

		if not child then
			connection = parent.ChildAdded:Connect(function(newChild)
			--[[
				Verifying if it is the same name (new child)
				as the expected child
			]]
				if (newChild.Name == name) then
					connection:Disconnect()
					resolve(newChild)
				end	
			end)
		end

		resolve(child)
	end)
end
WaitFor.childSafePromise = WaitFor.ChildSafePromise


--[[
	Strict version of WaitFor.ChildSafe
]]
function WaitFor.Child(parent: Instance, name: string, ignoreError: boolean | nil): Instance | nil
	--> Verifying for arguments
	AssertFunction('Child', parent, name, ignoreError)
	ignoreError = ignoreError or false

	--> Variables
	local timer = 0
	local child = parent:FindFirstChild(name)
	local timeout = false

	if (not child) then
		while (not child) do
			timer += Wait(1)
			child = parent:FindFirstChild(name)
			timeout = timer >= DEFAULT_TIMEOUT

			if timeout then
				break
			end
		end
	end

	local success = (not timeout and child)
	if not success and not ignoreError then
		Traceback(TIMEOUT_ERROR:format(name, parent.Name))
		return nil
	end

	return child
end
WaitFor.child = WaitFor.Child


--[[
    Promise implementation
]]
function WaitFor.ChildPromise(parent: Instance, name: string)
	AssertFunction('Child', parent, name) -- don't worry, assertFunction will handle that
	return Promise.new(function(resolve, reject)
		local timer = 0
		local child = parent:FindFirstChild(name)
		local timeout = false
		
		if (not child) then
			while (not child) do
				timer += Wait(1)
				child = parent:FindFirstChild(name)
				timeout = timer >= DEFAULT_TIMEOUT

				if timeout then
					break
				end
			end
		else
			return resolve(child)
		end

		local success = (not timeout and child)
		local result: any = success and child or TIMEOUT_ERROR:format(name, parent.Name)
		;(success and resolve or reject)(result)
	end)
end
WaitFor.childPromise = WaitFor.ChildPromise


--[[
	Same features as WaitFor.Child
]]
function WaitFor.Children(parent: Instance, children): any
	AssertFunction('Children', parent, children)

	local childrenInQueue = {}
	for index, childName in pairs(children) do
		local child = WaitFor.Child(parent, childName, true)
		childrenInQueue[index] = child

		if (child == nil) then
			Traceback(TIMEOUT_CHILDREN_ERROR:format(childName, parent.Name))
		end
	end

	return unpack(childrenInQueue)
end
WaitFor.children = WaitFor.Children


--[[
	Promise implementation
]]
function WaitFor.ChildrenPromise(parent: Instance, children)
	AssertFunction('Children', parent, children)

	local childrenPromises = {}
	for _, childName in ipairs(children) do
		local candidate = WaitFor.ChildPromise(parent, childName)
		table.insert(childrenPromises, candidate)
	end

	return Promise.all(childrenPromises)
end
WaitFor.childrenPromise = WaitFor.ChildrenPromise


--[[
	It waits until any RBXScriptSignal event is being fired
]]
function WaitFor.EventSafe(event: any, callback)
	local isRBXScriptSignal = typeof(event) == 'RBXScriptSignal'
	local isTable = typeof(event) == 'table'
	assert(isTable or isRBXScriptSignal, 'Event argument must be on a table or RBXScriptSignal')

	--> It supports Signal class :D
	local isSignal = isTable and type(event['Connect']) == 'function'

	local isAnEvent = isRBXScriptSignal or isSignal
	assert(isAnEvent, 'Event argument must be RBXScriptSignal or Signal class')

	--> Creating new bindable for the eventful something
	local bindable = Instance.new('BindableEvent')
	local connection = nil

	connection = event:Connect(function(...)
		connection:Disconnect()

		local arguments = {...}
		if (callback) then
			Spawn(function()
				callback(unpack(arguments))
			end)
		end
		bindable:Fire()
	end)

	bindable.Event:Wait()
	bindable:Destroy()
end
WaitFor.eventSafe = WaitFor.EventSafe


--[[
	Promise implementation
]]
function WaitFor.EventSafePromise(event)
	local isRBXScriptSignal = typeof(event) == 'RBXScriptSignal'
	local isTable = typeof(event) == 'table'
	assert(isTable or isRBXScriptSignal, 'Event argument must be on a table or RBXScriptSignal')

	--> It supports Signal class :D
	local isSignal = isTable and type(event['Connect']) == 'function'

	local isAnEvent = isRBXScriptSignal or isSignal
	assert(isAnEvent, 'Event argument must be RBXScriptSignal or Signal class')

	return Promise.new(function(resolve)
		local connection = nil
		connection = event:Connect(function(...)
			connection:Disconnect()

			local arguments = {...}
			Spawn(function()
				resolve(unpack(arguments))
			end)
		end)
	end)
end
WaitFor.eventSafePromise = WaitFor.EventSafePromise


--[[
	Strict version of WaitFor.EventSafe
]]
function WaitFor.Event(event, callback)
	local isRBXScriptSignal = typeof(event) == 'RBXScriptSignal'
	local isTable = typeof(event) == 'table'
	assert(isTable or isRBXScriptSignal, 'Event argument must be on a table or RBXScriptSignal')

	--> It supports Signal class :D
	local isSignal = isTable and type(event['Connect']) == 'function'

	local isAnEvent = isRBXScriptSignal or isSignal
	assert(isAnEvent, 'Event argument must be RBXScriptSignal or Signal class')

	--> Creating new bindable for the eventful something
	local bindable = Instance.new('BindableEvent')
	local connection = nil

	connection = event:Connect(function(...)
		connection:Disconnect()

		local arguments = {...}
		if (callback) then
			Spawn(function()
				callback(unpack(arguments))
			end)
		end
		bindable:Fire()
	end)

	--> Yielding for evaluation later on
	local waiting = true
	local bindableConnection = nil	

	local timeout = false
	local timer = 0

	bindableConnection = bindable.Event:Connect(function()
		waiting = false
	end)

	while (waiting) do
		timer += Wait(1)
		timeout = timer >= DEFAULT_TIMEOUT
		if timeout then
			break
		end
	end

	--> Evaluation
	if (timeout and waiting) then
		Traceback(TIMEOUT_EVENT_ERROR:format(tostring(event)))
	end

	bindableConnection:Disconnect()
	bindable:Destroy()
end
WaitFor.event = WaitFor.Event


--[[
	Promise implementation
]]
function WaitFor.EventPromise(event)
	local isRBXScriptSignal = typeof(event) == 'RBXScriptSignal'
	local isTable = typeof(event) == 'table'
	assert(isTable or isRBXScriptSignal, 'Event argument must be on a table or RBXScriptSignal')

	--> It supports Signal class :D
	local isSignal = isTable and type(event['Connect']) == 'function'

	local isAnEvent = isRBXScriptSignal or isSignal
	assert(isAnEvent, 'Event argument must be RBXScriptSignal or Signal class')
	
	--> Creating new bindable for the eventful something
	return Promise.new(function(resolve, reject)
		local bindable = Instance.new('BindableEvent')
		local connection = nil
		
		connection = event:Connect(function(...)
			connection:Disconnect()
			bindable:Fire()
			
			local arguments = {...}
			Spawn(function()
				resolve(unpack(arguments))
			end)
		end)
		
		--> Yielding
		local waiting = true
		local bindableConnection = nil
		
		local timeout = false
		local timer = 0
		
		bindableConnection = bindable.Event:Connect(function()
			waiting = false
		end)
		
		while waiting do
			timer += Wait(1)
			timeout = timer >= DEFAULT_TIMEOUT
			if timeout then
				break
			end
		end
		
		bindableConnection:Disconnect()
		bindable:Destroy()
		
		if timeout and waiting then
			return reject(TIMEOUT_EVENT_ERROR:format(tostring(event)))
		end
	end)
end


--[[
	More accurate than ROBLOX's built-in one.
	I do not sure if it is better than wait()
]]
function WaitFor.Seconds(second: number): number
	assert(typeof(second) == 'number', 'Seconds argument must be a number')
	return Wait(second)
end
WaitFor.seconds = WaitFor.Seconds


--[[
	Waits until the next frame or heartbeat and
	it is now supported on both Client and Server
]]
function WaitFor.NextStep(): number
	return WaitStep()
end
WaitFor.nextStep = WaitFor.NextStep


--[[
	Promise implementation
]]
function WaitFor.NextStepPromise()
	return Promise.new(function(resolve)
		return resolve(WaitStep())
	end)
end
WaitFor.nextStepPromise = WaitFor.NextStepPromise


return WaitFor
