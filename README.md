# ccㅤ/character controller/

humanoidless character controller+replicator and strictly-typed playermodule rewrite

## about

|ico.svg|lore|
|-|-|
|<img src="./cc-ico.svg" width="96"/>|humanoidless player-character controller and replicator as a simple all-in-one-place alternative to the roblox `PlayerModule` and `Humanoid`|

## gotchas

1. an empty fork of the playermodule is required for any project using cc

this is because cc uses a minimal rewrite/functionality of the roblox `PlayerModule` (and therefore has conflicts with it)

```json
"StarterPlayer": {
	"$className": "StarterPlayer",
	"StarterPlayerScripts": {
		"$className": "StarterPlayerScripts",
		"PlayerModule": { "$className": "ModuleScript" },
		"PlayerScriptsLoader": { "$className": "LocalScript" }
	}
}
```

2. [cc.replication.luau](cc/replication.luau) must be required on the server

cc.replication controls the server-side of cc's replication

3. i do not know how to write comprehensive or proper documentation for a project of this nature

because of this some annotations are on the more verbose side hopefully for better clarity. also for some variables used in the playermodule rewrite i have tried to include their original variable name so it's easier to trace where something came from

4. vr is not supported (no vr headset T_T), but will most definitely be added when i have the means to do so

## interfacing

[cc/init.luau](cc/init.luau) contains cc mutator and step functions and runs the client/server replication process when required by the client/server \
`cc.input` is the input table read from by the `cc` mutator functions and is meant to be written to externally \
`cc.output` is the output table written to during `cc.step(...)` and is meant to be read from externally

`cc.step()` works best when bound to `RunService.Heartbeat`, as binding it to renderstep at any renderpriority causes character jitter and binding it to stepped causes characters to fling when jumping

## general script overview

[cc/cameracontroller.luau](cc/cameracontroller.luau) \
[cc/inputcontroller.luau](cc/inputcontroller.luau) \
[cc/viewport.luau](cc/viewport.luau) \
...are parts of a minimal rewrite of roblox's `PlayerModule`

[cc/cameracontroller.luau](cc/cameracontroller.luau) controls the camera based on inputs read from [cc/inputcontroller.luau](cc/inputcontroller.luau) \
[cc/viewport.luau](cc/viewport.luau) is the equivalent of the playermodule poppercam and queries the camera viewport in order to artificially limit camera zoom distance

[cc/interpolation.luau](cc/interpolation.luau) is a general solver for interpolating replicated characters, intended for external use. a general use pattern is provided in the client demo script \
[cc/replication.luau](cc/replication.luau) controls the character replication between clients using heavily space-optimized buffers

[demo/client.client.luau](demo/client.client.luau) contains a general use pattern for cc, and is the script used in the demo game (linked below) \
[demo/server.server.luau](demo/server.server.luau) satisfies `gotcha #2`

## fast rig setup

[cc/rig.luau](cc/rig.luau) creates rigs from pure tables and comes with a r6 preset without humanoid bloat

[cc-rig-unwrap.png](cc-rig-unwrap.png) is a blank clothing template for the default limbs found in `cc/rig.luau` (torso, left arm, left leg, right arm, right leg)

## demo game



---

ㅍ cc by 00826 / overflowed