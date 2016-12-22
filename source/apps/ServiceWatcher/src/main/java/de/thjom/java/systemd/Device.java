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

import org.freedesktop.dbus.exceptions.DBusException;

import de.thjom.java.systemd.interfaces.DeviceInterface;

public class Device extends Unit {

    public static final String SERVICE_NAME = Systemd.SERVICE_NAME + ".Device";
    public static final String UNIT_SUFFIX = ".device";

    public static class Property extends InterfaceAdapter.Property {

        public static final String SYS_FSPATH = "SysFSPath";

        private Property() {
            super();
        }

        public static final String[] getAllNames() {
            return getAllNames(Property.class);
        }

    }

    private Device(final Manager manager, final DeviceInterface iface, final String objectPath, final String name) throws DBusException {
        super(manager, iface, objectPath, name);

        this.properties = Properties.create(dbus, objectPath, SERVICE_NAME);
    }

    static Device create(final Manager manager, String name) throws DBusException {
        name = Unit.normalizeName(name, UNIT_SUFFIX);

        String objectPath = Unit.OBJECT_PATH + Systemd.escapePath(name);
        DeviceInterface iface = manager.dbus.getRemoteObject(Systemd.SERVICE_NAME, objectPath, DeviceInterface.class);

        return new Device(manager, iface, objectPath, name);
    }

    @Override
    public DeviceInterface getInterface() {
        return (DeviceInterface) super.getInterface();
    }

    public String getSysFSPath() {
        return properties.getString(Property.SYS_FSPATH);
    }

}
