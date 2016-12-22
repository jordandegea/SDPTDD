package fr.ensimag.twitter_weather;

import de.thjom.java.systemd.Manager;
import de.thjom.java.systemd.Systemd;
import de.thjom.java.systemd.Unit;
import org.apache.zookeeper.WatchedEvent;
import org.apache.zookeeper.Watcher;
import org.apache.zookeeper.ZooKeeper;
import org.freedesktop.dbus.exceptions.DBusException;

import java.io.IOException;

/**
 * Created by Vincent on 22/12/2016.
 */
public class ServiceWatcher {
    static void printUsage() {
        System.err.println("Usage: java -jar ServiceWatcher.jar zookeeper1:port1[,zookeeper2:port2]");
    }

    public static void main(String[] args) throws IOException, InterruptedException, DBusException {
        // Check arguments
        if (args.length == 0) {
            printUsage();
            System.exit(1);
        }

        // Find out the Zookeeper Quorum to connect to
        ZooKeeper zooKeeper = new ZooKeeper(args[0], 5000, new Watcher() {
            @Override
            public void process(WatchedEvent event) {
                System.out.println("root ZooKeeper event: [" + event.getType().name() + "]@" + event.getPath());
            }
        });

        Runtime.getRuntime().addShutdownHook(new Thread() {
            @Override
            public void run() {
                System.out.println("Exiting ServiceWatcher...");
            }
        });

        System.out.println("ServiceWatcher connected to ZooKeeper, waiting for events...");

        Systemd systemd = Systemd.get();
        Manager manager = systemd.getManager();

        // Ugly wait loop
        while (true) {
            Unit unit = manager.getUnit("zookeeper.service");
            System.out.println("zookeeper.service active state: " + unit.getActiveState());

            Thread.sleep(1000);
        }
    }
}
