--!strict
--[[

	WaitFor (Non-Promise version)
	Author: memothelemo
    Created: March 29, 2021 as in-house script
    Updated: April 4, 2021 (Update 2)

    Update 1 (March 30, 2021):
        - Seperated between regular and promise implementation
        - Improved coding structure
        - Pascal case support
            > WaitFor.childPromise() instead of WaitFor.ChildPromise()
        - In WaitFor.childrenPromise(), instead of rejecting,
          expect all of the required children has been not found
          it will warn the user that any child is not yet found.
        - WaitFor.ChildrenThenGet is now removed in favor of WaitFor.Children
        - New Functions:
            > WaitFor.Seconds     	- No promise implementation because of Promise.Delay
            > WaitFor.NextStep
            > WaitFor.Event
        - No promise version added

    Update 2 (March 30 - April 4, 2021):
    	- Luau strict method is added
    	- Documentated to see how it works (kinda)
    	- WaitFor.Event is now strict (replaced with WaitFor.EventSafe)
        - WaitFor.Child functions are now optimized!
        - Informative and presentable error messages
        - New Functions:
            > WaitFor.ChildSafe
            > WaitFor.ChildrenSafe
			> WaitFor.Path 			- Inspired by: ChipioIndustries from his own module 'WaitForPath'
			> WaitFor.PathSafe
	
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
	Same features both WaitFor.ChildSafe and WaitFor.Children
]]
function WaitFor.ChildrenSafe(parent: Instance, children): any
	AssertFunction('Children', parent, children)

	local childrenInQueue = {}
	for index, childName in pairs(children) do
		local child = WaitFor.ChildSafe(parent, childName)
		childrenInQueue[index] = child
	end

	return unpack(childrenInQueue)
end
WaitFor.childrenSafe = WaitFor.ChildrenSafe


--[[
	It allows to find the descendant by descendant without
	spamming the entire line of WaitFor's
	
	Inspired by: ChipioIndustries from his own module 'WaitForPath'
]]
function WaitFor.Path(parent: Instance, path: string): Instance | nil
	AssertFunction('Path', parent, path)

	local segments = string.split(path, ".")
	local child: any = parent
	
	for _, descendant in pairs(segments) do
		local ancestor = child
		child = WaitFor.Child(child, descendant, true) 
		if (not child) then
			Traceback(TIMEOUT_PATH_ERROR:format(descendant, ancestor.Name, parent.Name))
			return nil
		end
	end
	
	return child
end
WaitFor.path = WaitFor.Path


--[[
	Same functionality from WaitFor.ChildSafe and WaitFor.Path
	but it will took awhile to process it.
]]
function WaitFor.PathSafe(parent: Instance, path: string): Instance
	AssertFunction('Path', parent, path)
	
	local segments = string.split(path, ".")
	local child = parent
	
	for _, descendant in pairs(segments) do
		child = WaitFor.ChildSafe(child, descendant)
	end
	
	return child
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
	It waits until any RBXScriptSignal event is being fired
]]
function WaitFor.EventSafe(event, execution)
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
		if (execution) then
			Spawn(function()
				execution(unpack(arguments))
			end)
		end
		bindable:Fire()
	end)

	bindable.Event:Wait()
	bindable:Destroy()
end
WaitFor.eventSafe = WaitFor.EventSafe


--[[
	Strict version of WaitFor.EventSafe
]]
function WaitFor.Event(event, execution)
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
		if (execution) then
			Spawn(function()
				execution(unpack(arguments))
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


return WaitFor