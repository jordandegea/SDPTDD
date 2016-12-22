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

import java.util.Arrays;
import java.util.Date;
import java.util.Optional;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import org.freedesktop.dbus.DBusConnection;
import org.freedesktop.dbus.exceptions.DBusException;
import org.freedesktop.dbus.exceptions.NotConnected;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public final class Systemd {

    public static final String SERVICE_NAME = "org.freedesktop.systemd1";
    public static final String OBJECT_PATH = "/org/freedesktop/systemd1";

    public static final Pattern PATH_ESCAPE_PATTERN = Pattern.compile("(\\W)");

    public static enum InstanceType {

        SYSTEM(DBusConnection.SYSTEM),
        USER(DBusConnection.SESSION);

        private final int index;

        private InstanceType(final int index) {
            this.index = index;
        }

        public final int getIndex() {
            return index;
        }

        @Override
        public String toString() {
            return super.toString().toLowerCase();
        }

    }

    private static final Logger log = LoggerFactory.getLogger(Systemd.class);

    private static final Systemd[] instances = new Systemd[InstanceType.values().length];

    private final InstanceType instanceType;

    private DBusConnection dbus;
    private Manager manager;

    private Systemd() {
        this(InstanceType.SYSTEM);
    }

    private Systemd(final InstanceType instanceType) {
        this.instanceType = instanceType;
    }

    public static final String escapePath(final CharSequence path) {
        StringBuffer escaped = new StringBuffer(path.length());
        Matcher matcher = PATH_ESCAPE_PATTERN.matcher(path);

        while (matcher.find()) {
            String replacement = '_' + Integer.toHexString((int) matcher.group().charAt(0));
            matcher.appendReplacement(escaped, replacement);
        }

        matcher.appendTail(escaped);

        return escaped.toString();
    }

    public static final Date timestampToDate(final long timestamp) {
        return new Date(timestamp / 1000);
    }

    public static Systemd get() throws DBusException {
        return get(InstanceType.SYSTEM);
    }

    public static Systemd get(final InstanceType instanceType) throws DBusException {
        final int index = instanceType.getIndex();

        Systemd instance;

        synchronized (instances) {
            if (instances[index] == null) {
                instance = new Systemd(instanceType);
                instance.open();

                instances[index] = instance;
            }
            else {
                instance = instances[index];
            }
        }

        return instance;
    }

    public static void disconnect() throws DBusException {
        disconnect(InstanceType.SYSTEM);
    }

    public static void disconnect(final InstanceType instanceType) throws DBusException {
        final int index = instanceType.getIndex();

        synchronized (instances) {
            Systemd instance = instances[index];

            if (instance != null) {
                instance.close();
            }

            instances[index] = null;
        }
    }

    public static void disconnectAll() {
        synchronized (instances) {
            for (Systemd instance : instances) {
                if (instance != null) {
                    try {
                        instance.close();
                    }
                    catch (final DBusException e) {
                        log.error(e.getMessage());
                    }
                }
            }

            Arrays.fill(instances, null);
        }
    }

    private void open() throws DBusException {
        log.debug(String.format("Connecting to %s bus", instanceType));

        try {
            dbus = DBusConnection.getConnection(instanceType.getIndex());
        }
        catch (final DBusException e) {
            log.error(String.format("Unable to connect to %s bus", instanceType), e);

            throw e;
        }
    }

    private void close() throws DBusException {
        if (isConnected()) {
            log.debug(String.format("Disconnecting from %s bus", instanceType));

            dbus.disconnect();
        }

        dbus = null;
    }

    public boolean isConnected() {
        return !(dbus == null || dbus.getError() instanceof NotConnected);
    }

    Optional<DBusConnection> getConnection() {
        return Optional.ofNullable(dbus);
    }

    public Manager getManager() throws DBusException {
        if (manager == null) {
            if (!isConnected()) {
                throw new DBusException("Unable to create manager without bus (please connect first)");
            }

            log.debug(String.format("Creating new manager instance on %s bus", instanceType));

            manager = Manager.create(dbus);
        }

        return manager;
    }

}
