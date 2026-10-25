package ca.weblite.objc;

/** Do-nothing replacement for java-objc-bridge's Proxy (see Client). */
public class Proxy {
    public Object send(String selector, Object... args) { return null; }
    public Object sendRaw(String selector, Object... args) { return null; }
    public int sendInt(String selector, Object... args) { return 0; }
    public Proxy sendProxy(String selector, Object... args) { return this; }
}
