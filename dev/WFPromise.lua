--[[

    WFPromise
    Author: memothelemo (Cedcedmeranez)

    Inside of WaitFor's promise implementation

]]

local Promise = require(script.Parent.Promise)

local AllContains = require(script.Parent.AllContains)
local Child = require(script.Parent.Child)
local Children = require(script.Parent.Children)
local Path = require(script.Parent.Path)


local WFPromise = {}

function WFPromise.ChildSafe(parent: Instance, child: string)
    assert(typeof(parent) == 'Instance', '`Parent` is required and must be an Instance')
    assert(typeof(child) == 'string', '`Child` is required and must be a string')

    return Promise.new(function(resolve, _, onCancel)
        local bindable = Instance.new("BindableEvent")

        onCancel(function()
            bindable:Fire()
        end)

        local realChild = Child.Safe(parent, child, bindable.Event)

        bindable:Destroy()
        resolve(realChild)
    end)
end

function WFPromise.ChildTimeout(parent: Instance, child: string, timeout: number)
    assert(typeof(parent) == 'Instance', '`Parent` is required and must be an Instance')
    assert(typeof(child) == 'string', '`Child` is required and must be a string')
    assert(typeof(timeout) == 'number' or timeout == nil, "`Timeout` must be a number or nil")

    return Promise.new(function(resolve, reject)
        local realChild = Child.WithTimeout(parent, child, timeout, true)
        if realChild then
            return resolve(realChild)
        else
            return reject(("[WaitFor]: Failed to find a child (%s) in the parent of %s"):format(child, parent.Name))
        end
    end)
end

function WFPromise.ChildrenSafe(parent: Instance, children: table)
    assert(typeof(parent) == 'Instance', '`Parent` is required and must be an Instance')
    assert(typeof(children) == 'table', '`Children` is required and must be a table')
    assert(AllContains(children, 'string'), 'All children argument table\'s value/s requires string')

    return Promise.new(function(resolve, _, onCancel)
        local bindable = Instance.new("BindableEvent")

        onCancel(function()
            bindable:Fire()
        end)

        local realChildren = { Children.Safe(parent, children) }

        bindable:Destroy()
        resolve(unpack(realChildren))
    end)
end

function WFPromise.ChildrenTimeout(parent: Instance, children: table, timeout: number)
    assert(typeof(parent) == 'Instance', '`Parent` is required and must be an Instance')
    assert(typeof(children) == 'table', '`Children` is required and must be a table')
    assert(AllContains(children, 'string'), 'All children argument table\'s value/s requires string')
    assert(typeof(timeout) == 'number' or timeout == nil, "`Timeout` must be a number or nil")

    return Promise.new(function(resolve, reject)
        local realChildren = { Children.WithTimeout(parent, children, timeout, true) }
        if #realChildren ~= 0 then
            return resolve(unpack(realChildren))
        else
            return reject(("[WaitFor]: Failed to find required children in the parent of %s"):format(parent.Name))
        end
    end)
end

function WFPromise.PathSafe(parent: Instance, path: string)
    assert(typeof(parent) == 'Instance', '`Parent` is required and must be an Instance')
    assert(type(path) == 'string', '`Path` is required and must be a string')

    return Promise.new(function(resolve, _, onCancel)
        local bindable = Instance.new("BindableEvent")

        onCancel(function()
            bindable:Fire()
        end)

        local realChild = Path.Safe(parent, path, bindable.Event)

        bindable:Destroy()
        if realChild then
            resolve(realChild)
        end
    end)
end

function WFPromise.PathTimeout(parent: Instance, path: string, timeout: number)
    assert(typeof(parent) == 'Instance', '`Parent` is required and must be an Instance')
    assert(type(path) == 'string', '`Path` is required and must be a string')
    assert(typeof(timeout) == 'number' or timeout == nil, "`Timeout` must be a number or nil")

    return Promise.new(function(resolve, reject)
        local realChild = Path.WithTimeout(parent, path, timeout, true)
        if realChild then
            return resolve(realChild)
        else
            return reject(("[WaitFor]: Failed to require ancestors to find the required child. Parent: %s"):format(parent.Name))
        end
    end)
end

return WFPromise