# ccㅤ/character controller/

humanoidless character controller+replicator

|ico.svg|contents|
|-|-|
|<img src="./cc-ico.svg" width="96"/>|setup: [setup.md](setup.md)<br/><br/>rbxm: [extras/cc-demo-scripts.rbxm](extras/cc-demo-scripts.rbxm)<br/>demo: [https://www.roblox.com/games/104949334668691/cc-demo](https://www.roblox.com/games/104949334668691/cc-demo)|

## gotchas

### 1. playermodule conflict
cc has a self-contained `PlayerModule` functionality ([cc/cameracontroller.luau](cc/cameracontroller.luau), [cc/inputcontroller.luau](cc/inputcontroller.luau), [cc/viewport.luau](cc/viewport.luau)) and therefore conflicts with the default roblox `PlayerModule`. as such, an empty fork should be placed in `StarterPlayer/StarterPlayerScripts`:

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

### 2. position limits

replicated positions are represented as `i24`'s (breakdown of the replication buffer can be viewed in [cc/replication.luau](cc/replication.luau)'s `replication.create()`). any positional component that is written beyond this limit will apply integer overflow. the range can be expanded by increasing `replication.precision` at the expense of visual accuracy

by default, integer overflow for replicated positions will occur when a point-along-an-axis is `~= ±209714.2` studs away from `0`

`limitalongaxis = replication.precision * 2^23-1`

### 3. lack of vr support

vr is not supported (no vr headset T_T), but will most definitely be added when i have the means to do so

## setup

a step-by-step guide for implementing cc from scratch or into a preexisting project

rendered: [setup.md](setup.md)

---

ㅍ cc by 00826