# Built-in JIT (beta)

Think of JIT like a chef who needs permission to write new recipes mid-service. iOS normally forbids
apps from creating new code at runtime, unless a debugger is attached. A process can't debug itself
(it would freeze its own threads), so Calcite ships a tiny helper extension that plays the "debugger" role
for the game process.

## One-time setup
1. Install **LocalDevVPN** and connect it (the tunnel the helper talks through).
2. Get a pairing file. Either:
   - **iOS 27:** in Calcite, Settings > General > **Pair on this iPhone**. Then open Settings > Privacy & Security >
     Developer Mode on the phone, choose "Calcite", and type the code Calcite shows. Allow Local Network if asked.
   - **Any version:** create one with StikDebug's pairing guide and use **Import pairing file**.
4. Tap **Prepare JIT** (mounts the Developer Disk Image; needs the VPN on).
5. Turn on **Built-in JIT (beta)**.

## Using it
Launch a game. Calcite asks the helper to enable JIT for itself. If it fails, you get a dialog with the reason.
Use **Reset DDI** if the disk image gets into a bad state.

## Limits
- iOS 17.4+ and a build with the helper extension (the official IPA has it).
- Not available inside LiveContainer.
- On-device pairing needs iOS 27's device-initiated pairing. It is untested on hardware; if it misbehaves, import a pairing file.
