package fr.ensimag.twitter_weather;

import org.apache.hadoop.hbase.client.Put;
import org.apache.hadoop.hbase.client.Table;
import org.apache.hadoop.hbase.util.Bytes;
import org.apache.sling.commons.json.JSONException;
import org.apache.sling.commons.json.JSONObject;

import java.io.IOException;
import java.text.ParseException;
import java.text.SimpleDateFormat;
import java.util.Map;
import java.util.UUID;

/**
 * An object to be streamed to HBase
 */
public class StreamObject {
    private JSONObject rawTweet;
    private JSONException parsingException;

    private static final String[] userProperties = new String[] { "name", "profile_sidebar_border_color", "profile_sidebar_fill_color", "profile_background_tile", "profile_image_url", "created_at", "location", "is_translator", "follow_request_sent", "id_str", "profile_link_color", "entities", "default_profile", "contributors_enabled", "url", "favourites_count", "utc_offset", "id", "profile_image_url_https", "profile_use_background_image", "listed_count", "profile_text_color", "protected", "lang", "followers_count", "time_zone", "profile_background_image_url_https", "verified", "profile_background_color", "notifications", "description", "geo_enabled", "statuses_count", "default_profile_image", "friends_count", "profile_background_image_url", "show_all_inline_media", "screen_name", "following" };
    private static final String[] tweetProperties = new String[] { "coordinates", "favorited", "created_at", "truncated", "id_str", "entities", "in_reply_to_user_id_str", "text", "contributors", "retweet_count", "id", "in_reply_to_status_id_str", "geo", "retweeted", "in_reply_to_user_id", "place", "source", "in_reply_to_screen_name", "in_reply_to_status_id" };

    private static final SimpleDateFormat twitterFormat = new SimpleDateFormat("EEE MMM d HH:mm:ss Z yyyy");

    public void put(Table table) throws IOException {
        Put put = new Put(Bytes.toBytes(UUID.randomUUID().toString()));

        if (parsingException != null) {
            putString(put, "feeling", "error", parsingException.getMessage());
            table.put(put);
            return;
        }

        parseDate(rawTweet);

        try {
            parseDate(rawTweet.getJSONObject("user"));
        } catch (JSONException e) {
            // ignore
        }

        // User properties
        for (String property : userProperties) {
            putProperty(put, "user", property);
        }

        // Tweet properties
        for (String property : tweetProperties) {
            putProperty(put, "tweet", rawTweet, property);
        }

        // Analyzed properties
        try {
            for (Map.Entry<String, String> kv : FeelingAnalyzer.getInstance().getFeelingProperties("en", rawTweet.getString("text")).entrySet()) {
                putString(put, "feeling", kv.getKey(), kv.getValue());
            }
        } catch (JSONException e) {
            putString(put, "feeling", "error", e.getMessage());
        }

        // Put to table
        table.put(put);
    }

    private void parseDate(JSONObject object) {
        try {
            object.put("created_at", twitterFormat.parse(object.getString("created_at")).getTime());
        } catch (JSONException e) {
            // ignore
        } catch (ParseException e) {
            // ignore
        }
    }

    private void putProperty(Put put, String object, String prop) {
        try {
            putProperty(put, object, rawTweet.getJSONObject(object), prop);
        } catch (JSONException e) {
            // Missing property
            putString(put, object, prop, "");
        }
    }

    private void putProperty(Put put, String object, JSONObject rawObject, String prop) {
        try {
            putString(put, object, prop, rawObject.getString(prop));
        } catch (JSONException e) {
            // Missing property
            putString(put, object, prop, "");
        }
    }

    private void putString(Put put, String family, String column, String value) {
        put.addColumn(Bytes.toBytes(family), Bytes.toBytes(column), System.currentTimeMillis(), Bytes.toBytes(value));
    }

    public StreamObject(JSONObject rawTweet) {
        this.rawTweet = rawTweet;
    }

    public StreamObject(JSONException parsingException) {
        this.parsingException = parsingException;
    }
}
