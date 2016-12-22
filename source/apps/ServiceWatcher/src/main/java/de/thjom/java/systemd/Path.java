/*
 * Java-systemd implementation
 * Copyright (c) 2016 Markus Enax
 *
 * This program is free software; you can redistribute it and/or modify it under
 * the terms of either the GNU Lesser General Public License Version 2 or the
 * Academic Free Licence Version 2.1.
 *
 * Full licence texts are included in the COPYING file with this program.
 */

package de.thjom.java.systemd;

import java.util.List;

import org.freedesktop.dbus.exceptions.DBusException;

import de.thjom.java.systemd.interfaces.PathInterface;
import de.thjom.java.systemd.types.PathInfo;

public class Path extends Unit {

    public static final String SERVICE_NAME = Systemd.SERVICE_NAME + ".Path";
    public static final String UNIT_SUFFIX = ".path";

    public static class Property extends InterfaceAdapter.Property {

        public static final String DIRECTORY_MODE = "DirectoryMode";
        public static final String MAKE_DIRECTORY = "MakeDirectory";
        public static final String PATHS = "Paths";
        public static final String RESULT = "Result";
        public static final String UNIT = "Unit";

        private Property() {
            super();
        }

        public static final String[] getAllNames() {
            return getAllNames(Property.class);
        }

    }

    private Path(final Manager manager, final PathInterface iface, final String objectPath, final String name) throws DBusException {
        super(manager, iface, objectPath, name);

        this.properties = Properties.create(dbus, objectPath, SERVICE_NAME);
    }

    static Path create(final Manager manager, String name) throws DBusException {
        name = Unit.normalizeName(name, UNIT_SUFFIX);

        String objectPath = Unit.OBJECT_PATH + Systemd.escapePath(name);
        PathInterface iface = manager.dbus.getRemoteObject(Systemd.SERVICE_NAME, objectPath, PathInterface.class);

        return new Path(manager, iface, objectPath, name);
    }

    @Override
    public PathInterface getInterface() {
        return (PathInterface) super.getInterface();
    }

    public long getDirectoryMode() {
        return properties.getLong(Property.DIRECTORY_MODE);
    }

    public boolean isMakeDirectory() {
        return properties.getBoolean(Property.MAKE_DIRECTORY);
    }

    public List<PathInfo> getPaths() {
        return PathInfo.list(properties.getVector(Property.PATHS));
    }

    public String getResult() {
        return properties.getString(Property.RESULT);
    }

    public String getUnit() {
        return properties.getString(Property.UNIT);
    }

}
