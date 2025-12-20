# ccㅤ/character controller/

## about

|ico.svg|lore|
|-|-|
|<img src="./cc-ico.svg" width="96"/>|humanoidless player controller and replicator as a simple all-in-one-place alternative to the `PlayerModule`, `Humanoids`, and player-character replication|

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

2. cc must be required on the server and client

this is because cc has a self-contained replication process

3. i do not know how to write comprehensive or proper documentation for a project of this nature

because of this some annotations are on the more verbose side hopefully for better clarity. also for some variables used in the playermodule rewrite i have tried to include their original variable name so it's easier to trace where something came from

4. vr is not supported (no vr headset sob)

## interfacing

[cc/init.luau](cc/init.luau) contains cc mutator and step functions and runs the client/server replication process when required by the client/server \
`cc.input` is the input table read from by the `cc` mutator functions and is meant to be written to externally \
`cc.output` is the output table written to during `cc.step(...)` and is meant to be read from externally

## the rewritten playermodule

[cc/cameracontroller.luau](cc/cameracontroller.luau) \
[cc/inputcontroller.luau](cc/inputcontroller.luau) \
[cc/viewport.luau](cc/viewport.luau) \
[cc/spring.luau](cc/spring.luau) \
[cc/transformextrapolator.luau](cc/transformextrapolator.luau) \
...are parts of a minimal rewrite of roblox's `PlayerModule`

[cc/cameracontroller.luau](cc/cameracontroller.luau) controls the camera based on inputs read from [cc/inputcontroller.luau](cc/inputcontroller.luau) \
[cc/viewport.luau](cc/viewport.luau) is the equivalent of the playermodule poppercam and queries the camera viewport in order to artificially limit camera zoom distance \
[cc/spring.luau](cc/spring.luau) is a de-ooped spring module found in the playermodule camerautils \
[cc/transformextrapolator.luau](cc/transformextrapolator.luau) is a de-ooped cframe extrapolator found in the playermodule poppercam

## fast rig setup

[cc/rig.luau](cc/rig.luau) is a minimal motor6d-basepart-animationcontroller rig constructor/mutator meant to create rigs that are visually identical to humanoid r6 rigs without the humanoid bloat

---

ㅍ cc by 00826 / overflowed