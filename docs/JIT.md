# Built-in JIT (beta)

Think of JIT like a chef who needs permission to write new recipes mid-service. iOS normally forbids
apps from creating new code at runtime, unless a debugger is attached. A process can't debug itself
(it would freeze its own threads), so Calcite ships a tiny helper extension that plays the "debugger" role
for the game process.

## One-time setup
1. Install **LocalDevVPN** and connect it (the tunnel the helper talks through).
2. In StikDebug's pairing guide, create the RP pairing file for your device.
3. In Calcite: Settings > General > **Import pairing file**, pick that file.
4. Tap **Prepare JIT** (mounts the Developer Disk Image; needs the VPN on).
5. Turn on **Built-in JIT (beta)**.

## Using it
Launch a game. Calcite asks the helper to enable JIT for itself. If it fails, you get a dialog with the reason.
Use **Reset DDI** if the disk image gets into a bad state.

## Limits
- iOS 17.4+ and a build with the helper extension (the official IPA has it).
- Not available inside LiveContainer.
- On-device pairing generation for iOS 27 is not implemented yet; import a pairing file instead.
