package ca.weblite.objc;

/**
 * Do-nothing replacement for java-objc-bridge's Client.
 *
 * Minecraft 26.3 sees os.name "Mac OS X" on iOS and runs macOS-only window tweaks through
 * this library, which would pull in AppKit via JNA and kill the game at startup. The
 * library is unsigned (unlike the client jar), so it is safe to shadow here.
 */
public class Client {
    private static final Client INSTANCE = new Client();

    public static Client getInstance() { return INSTANCE; }

    public Proxy sendProxy(String target, String selector, Object... args) {
        return new Proxy();
    }
}
