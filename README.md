# WaitFor

## Usage

```lua
local WaitFor = require(WaitFor)

local player = game.Players.LocalPlayer
local character = Player.Character or Player.CharacterAdded:Wait()

local playerGui = WaitFor.Child(player, "PlayerGui")

WaitFor.ChildrenSafePromise(character, {
    "Humanoid",
    "HumanoidRootPart",
})
```

## Info

A ROBLOX module where you can wait for something until it occurs, or found an Instance. Modular than WaitForChild but with features that you can try. (One of them is inspired from other scripter)

This module is on early stage so bugs and false errors may expected. I'm not a perfect scripter but otherwise it works.

## Docs

Work in progress

## License

This module is free software; you can redistribute it and/or modify it under the terms of the MIT license.
