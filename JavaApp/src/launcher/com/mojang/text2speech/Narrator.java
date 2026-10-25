package com.mojang.text2speech;

public interface Narrator {
    void say(final String msg, final boolean interrupt);

    void clear();

    boolean active();

    void destroy();

    /** Newer Minecraft versions catch this when creating the narrator; the stub never throws it. */
    class InitializeException extends Exception {
        private static final long serialVersionUID = 1L;
        public InitializeException(String message) { super(message); }
        public InitializeException(String message, Throwable cause) { super(message, cause); }
    }

    static Narrator getNarrator() {
        return new NarratorDummy();
    }

    static void setJNAPath(String sep) {
        System.setProperty("jna.library.path", System.getProperty("jna.library.path") + sep + "./src/natives/resources/");
        System.setProperty("jna.library.path", System.getProperty("jna.library.path") + sep + System.getProperty("java.library.path"));
    }
}
