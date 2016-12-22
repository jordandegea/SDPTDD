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

import de.thjom.java.systemd.interfaces.BusNameInterface;

public class BusName extends Unit {

    public static final String SERVICE_NAME = Systemd.SERVICE_NAME + ".BusName";
    public static final String UNIT_SUFFIX = ".busname";

    public static class Property extends InterfaceAdapter.Property {

        public static final String ACCEPT_FILE_DESCRIPTORS = "AcceptFileDescriptors";
        public static final String ACTIVATING = "Activating";
        public static final String CONTROL_PID = "ControlPID";
        public static final String NAME = "Name";
        public static final String RESULT = "Result";
        public static final String TIMEOUT_USEC = "TimeoutUSec";

        private Property() {
            super();
        }

        public static final String[] getAllNames() {
            return getAllNames(Property.class);
        }

    }

    private BusName(final Manager manager, final BusNameInterface iface, final String objectPath, final String name) throws DBusException {
        super(manager, iface, objectPath, name);

        this.properties = Properties.create(dbus, objectPath, SERVICE_NAME);
    }

    static BusName create(final Manager manager, String name) throws DBusException {
        name = Unit.normalizeName(name, UNIT_SUFFIX);

        String objectPath = Unit.OBJECT_PATH + Systemd.escapePath(name);
        BusNameInterface iface = manager.dbus.getRemoteObject(Systemd.SERVICE_NAME, objectPath, BusNameInterface.class);

        return new BusName(manager, iface, objectPath, name);
    }

    @Override
    public BusNameInterface getInterface() {
        return (BusNameInterface) super.getInterface();
    }

    public boolean isAcceptFileDescriptors() {
        return properties.getBoolean(Property.ACCEPT_FILE_DESCRIPTORS);
    }

    public boolean isActivating() {
        return properties.getBoolean(Property.ACTIVATING);
    }

    public long getControlPID() {
        return properties.getLong(Property.CONTROL_PID);
    }

    public String getName() {
        return properties.getString(Property.NAME);
    }

    public String getResult() {
        return properties.getString(Property.RESULT);
    }

    public long getTimeoutUSec() {
        return properties.getLong(Property.TIMEOUT_USEC);
    }

}
