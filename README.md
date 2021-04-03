<h1 align="center">WaitFor</h1>

<h2 align="center">Usage</h2>

```lua
local WaitFor = require(WaitFor)

local player = game.Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()

local healthGui = WaitFor.Path(player, "PlayerGui.HealthGui")
local greenBar = WaitFor.Child(healthGui, "GreenBar")

local humanoid, rootTorso = WaitFor.Children(
    character, 
    {
        'Humanoid', 
        'HumanoidRootPart'
    }
)
```

<h2 align="center">Info</h2>
<hr>
A ROBLOX module where you can wait for something until it occurs, or found an Instance. It is modular (sometimes) than using WaitForChild.

Promises are also added but it can found on a seperate file. "WaitForPromise.lua"

This module is on early stage so bugs and false errors may expected. I'm not a perfect scripter but otherwise it works.
<br>
<br>

<h2 align="center">Docs</h2>
<hr>
Work in progress

<br>
<br>

<h2 align="center">License</h2>
<hr>
This module is free software; you can redistribute it and/or modify it under the terms of the MIT license.