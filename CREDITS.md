# Credits

Calcite stands on the work of others.

## Game engine
The native game engine (JVM launch glue, LWJGL 3 ports, renderers) comes from **PojavLauncher** and
**Amethyst-iOS** (LGPL-3.0, see `LICENSE`). Renderers and libraries include MoltenVK, Mesa/Zink,
MetalANGLE, GL4ES, MobileGlues and OpenAL. Java runtimes are Azul Zulu / OpenJDK builds.

## Built-in JIT
- **StikJIT** (StikDebug team, MPL-2.0) is built from source in CI and embedded as `StikJIT.framework`.
  It performs the debugger attach and Developer Disk Image handling.
- **StikDebug** (AGPL-3.0) pioneered the on-device JIT approach and the `stikjit://` flow Calcite can still use.
- **idevice** by jkcoxson (MIT) is the protocol library underneath StikJIT.
- **LiveContainer** pioneered launching an app extension through the private `NSExtension` API,
  which Calcite uses to run the JIT helper outside the game process.
- **Madeira** (willfaust, GPL-3.0-or-later) was studied for design ideas. Calcite's implementation is
  independent and written from StikJIT's public integration guide.

Minecraft is a trademark of Mojang AB. Calcite is not affiliated with Mojang or Microsoft.
