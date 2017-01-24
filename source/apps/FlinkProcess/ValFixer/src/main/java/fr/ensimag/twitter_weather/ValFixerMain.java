package fr.ensimag.twitter_weather;

import org.apache.hadoop.conf.Configuration;
import org.apache.hadoop.hbase.HBaseConfiguration;
import org.apache.hadoop.hbase.TableName;
import org.apache.hadoop.hbase.client.*;
import org.apache.hadoop.hbase.util.Bytes;

import java.io.IOException;
import java.util.ArrayList;

public class ValFixerMain {
    private static final String[] userProperties = new String[] { "name", "profile_sidebar_border_color", "profile_sidebar_fill_color", "profile_background_tile", "profile_image_url", "created_at", "location", "is_translator", "follow_request_sent", "id_str", "profile_link_color", "entities", "default_profile", "contributors_enabled", "url", "favourites_count", "utc_offset", "id", "profile_image_url_https", "profile_use_background_image", "listed_count", "profile_text_color", "protected", "lang", "followers_count", "time_zone", "profile_background_image_url_https", "verified", "profile_background_color", "notifications", "description", "geo_enabled", "statuses_count", "default_profile_image", "friends_count", "profile_background_image_url", "show_all_inline_media", "screen_name", "following" };
    private static final String[] tweetProperties = new String[] { "coordinates", "favorited", "created_at", "truncated", "id_str", "entities", "in_reply_to_user_id_str", "text", "contributors", "retweet_count", "id", "in_reply_to_status_id_str", "geo", "retweeted", "in_reply_to_user_id", "place", "source", "in_reply_to_screen_name", "in_reply_to_status_id" };
    private static final String[] feelingProperties = new String[] { "level", "char_count", "emoji_count", "unique_emoji_count", "most_used_emoji", "most_used_emoji_count", "text", "error" };
    private static final String[] longColumns = new String[] { "created_at", "level", "id", "char_count", "emoji_count", "unique_emoji_count", "most_used_emoji_count" };

    public static void main(String[] args) throws IOException {
        // Instantiating Configuration class
        Configuration config = HBaseConfiguration.create();

        config.set("hbase.zookeeper.quorum", "localhost");
        config.set("hbase.zookeeper.property.clientPort", "2181");

        Connection connection = ConnectionFactory.createConnection(config);
        for (String tableName : args) {
            Table table = connection.getTable(TableName.valueOf(tableName));

            Scan scan = new Scan();
            for (String p : userProperties)
                scan.addColumn(Bytes.toBytes("user"), Bytes.toBytes(p));
            for (String t : tweetProperties)
                scan.addColumn(Bytes.toBytes("tweet"), Bytes.toBytes(t));
            for (String f : feelingProperties)
                scan.addColumn(Bytes.toBytes("feeling"), Bytes.toBytes(f));

            System.err.format("Processing %s\n", tableName);

            ArrayList<Put> puts = new ArrayList<Put>();

            int rows = 0;
            ResultScanner scanner = table.getScanner(scan);
            for (Result result : scanner) {
                byte[] rowKey = result.getRow();

                // Put update
                Put put = new Put(rowKey);
                for (String p : userProperties)
                    processColumn(put, Bytes.toBytes("user"), Bytes.toBytes(p), result.getValue(Bytes.toBytes("user"), Bytes.toBytes(p)));
                for (String p : tweetProperties)
                    processColumn(put, Bytes.toBytes("tweet"), Bytes.toBytes(p), result.getValue(Bytes.toBytes("tweet"), Bytes.toBytes(p)));
                for (String p : feelingProperties)
                    processColumn(put, Bytes.toBytes("feeling"), Bytes.toBytes(p), result.getValue(Bytes.toBytes("feeling"), Bytes.toBytes(p)));
                puts.add(put);

                if (rows % 100 == 0) {
                    table.put(puts);

                    puts = new ArrayList<Put>();
                }
            }

            table.put(puts);

            table.close();
            System.err.format("Changed %d rows\n", rows);
        }

        connection.close();
    }

    private static void processColumn(Put put, byte[] users, byte[] qualifier, byte[] value) {
        try {
            String col = Bytes.toString(qualifier);

            for (String longColumn : longColumns) {
                if (longColumn.equals(col)) {
                    String s = Bytes.toString(value);
                    long l = Long.parseLong(s);
                    put.addColumn(users, qualifier, Bytes.toBytes(l));
                    return;
                }
            }

            put.addColumn(users, qualifier, value);
        } catch (NumberFormatException ex) {
            put.addColumn(users, qualifier, value);
        }
    }
}