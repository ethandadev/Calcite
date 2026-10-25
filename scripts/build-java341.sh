#!/bin/bash
# Builds the Java side of Calcite's "LWJGL 3.4" stack (Minecraft 26.3+):
# stock LWJGL 3.4.x module jars from Maven Central merged with Calcite's GLFW/input shim,
# compiled against those jars. Output: JavaApp/build341/{lwjgl,launcher,patchjna_agent}.jar
#
# Usage: scripts/build-java341.sh   (env: BOOTJDK = a JDK 8 bin dir, LWJGL_VERSION = 3.4.3)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LWJGL_VERSION="${LWJGL_VERSION:-3.4.3}"
BOOTJDK="${BOOTJDK:?set BOOTJDK to a JDK 8 bin directory}"
MODULES="lwjgl lwjgl-glfw lwjgl-opengl lwjgl-openal lwjgl-stb lwjgl-tinyfd lwjgl-vma lwjgl-freetype \
         lwjgl-vulkan lwjgl-nanovg lwjgl-shaderc lwjgl-spvc lwjgl-jemalloc lwjgl-sdl"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
cp -R "$ROOT/JavaApp" "$WORK/JavaApp"
cd "$WORK/JavaApp"
rm -rf build

echo "== LWJGL $LWJGL_VERSION jars"
# lwjglx (LWJGL 2 compatibility) is Calcite's own, keep it.
find libs/lwjgl -name 'lwjgl*.jar' ! -name 'lwjgl-lwjglx.jar' -delete
for m in $MODULES; do
  curl -fsSL --retry 3 "https://repo1.maven.org/maven2/org/lwjgl/$m/$LWJGL_VERSION/$m-$LWJGL_VERSION.jar" -o "libs/lwjgl/$m.jar"
done

echo "== Patching GLFW shim for the 3.4 API"
python3 - "$WORK/JavaApp/src/lwjgl/org/lwjgl/glfw/GLFW.java" <<'PY'
import pathlib, sys
p = pathlib.Path(sys.argv[1]); s = p.read_text()

# JNI.invokeI takes an int, not a boolean, in 3.4.3.
s = s.replace("invokeI(!isCalledFromLWJGLX, __functionAddress)", "invokeI(!isCalledFromLWJGLX ? 1 : 0, __functionAddress)")

# New in 3.4: platform query, monitor name, IME hooks. iOS has one platform and one display.
anchor = "    @Nullable\n    @NativeType(\"GLFWmonitor **\")\n    public static PointerBuffer glfwGetMonitors() {"
assert anchor in s, "glfwGetMonitors not found"
s = s.replace(anchor, '''    public static boolean glfwPlatformSupported(int platform) {
        return platform == glfwGetPlatform();
    }

    public static String glfwGetMonitorName(@NativeType("GLFWmonitor *") long monitor) {
        return "iOS Display";
    }

    public static GLFWPreeditCallback glfwSetPreeditCallback(long window, GLFWPreeditCallbackI cbfun) { return null; }
    public static GLFWIMEStatusCallback glfwSetIMEStatusCallback(long window, GLFWIMEStatusCallbackI cbfun) { return null; }
    public static void glfwSetPreeditCursorRectangle(long window, int x, int y, int w, int h) { }

''' + anchor, 1)

# glfwGetInputMode must not NPE for modes that were never set (3.4 asks about GLFW_IME every tick).
old = "        return internalGetWindow(window).inputModes.get(mode);"
assert old in s, "glfwGetInputMode body not found"
s = s.replace(old, '''        Integer value = internalGetWindow(window).inputModes.get(mode);
        if (value != null) return value;
        return mode == GLFW_CURSOR ? GLFW_CURSOR_NORMAL : GLFW_FALSE;''', 1)
p.write_text(s)
PY

echo "== Compiling"
# The upstream Java makefile occasionally races under -j and emits an empty class; retry serially.
make -j4 BOOTJDK="$BOOTJDK" || { echo "retrying serially"; rm -rf build; make -j1 BOOTJDK="$BOOTJDK"; }

mkdir -p "$ROOT/JavaApp/build341"
cp build/lwjgl.jar build/launcher.jar build/patchjna_agent.jar "$ROOT/JavaApp/build341/"
ls -la "$ROOT/JavaApp/build341"
