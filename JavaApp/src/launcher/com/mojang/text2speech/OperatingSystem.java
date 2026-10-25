package com.mojang.text2speech;

import java.util.Locale;

/** Stand-in for text2speech's OperatingSystem, which some mods look up by name. */
public enum OperatingSystem {
    LINUX("linux"),
    WINDOWS("win"),
    MAC_OS("mac"),
    UNSUPPORTED("");

    private final String detectWith;

    OperatingSystem(String detectWith) {
        this.detectWith = detectWith;
    }

    public static OperatingSystem get() {
        String name = System.getProperty("os.name", "").toLowerCase(Locale.ROOT);
        for (OperatingSystem os : values()) {
            if (os != UNSUPPORTED && name.contains(os.detectWith)) return os;
        }
        return UNSUPPORTED;
    }
}
