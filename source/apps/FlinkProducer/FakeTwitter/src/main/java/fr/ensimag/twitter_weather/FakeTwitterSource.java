package fr.ensimag.twitter_weather;

import org.apache.flink.streaming.api.functions.source.SourceFunction;
import org.apache.sling.commons.json.JSONException;
import org.apache.sling.commons.json.JSONObject;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.util.Properties;
import java.util.Random;

public class FakeTwitterSource implements SourceFunction<StringPair> {
    private int rate;
    private double lastCheck;
    private String fakeTweet;
    private Random rnd = new Random();
    private boolean runLoop;

    private final String[] topics = new String[] {"paris", "london", "nyc"};

    public FakeTwitterSource(Properties props, int rate) throws IOException, JSONException {
        this.rate = rate;
        this.lastCheck = System.currentTimeMillis() / 1000.0;

        /* read the fake tweet */
        File file = new File("/usr/local/flink/fake_tweet.json");
        FileInputStream fis = new FileInputStream(file);
        byte[] data = new byte[(int) file.length()];
        fis.read(data);
        fis.close();
        /* format it as a single line */
        this.fakeTweet = new JSONObject(new String(data, "UTF-8")).toString();
    }

    @Override
    public void run(SourceContext<StringPair> sourceContext) throws Exception {
        // Initialize main loop
        runLoop = true;
        while (runLoop) {
            // Compute passed time
            double current = System.currentTimeMillis() / 1000.0;
            double timePassed = current - this.lastCheck;

            if (timePassed >= this.rate) {
                synchronized(sourceContext.getCheckpointLock()) {
                    String topic = topics[rnd.nextInt(topics.length)];
                    StringPair ds = new StringPair(topic, this.generateTweet());
                    sourceContext.collect(ds);
                    this.lastCheck = current;
                }
            } else {
                // Do not busy-wait
                Thread.sleep((long) ((this.rate - timePassed) / 2));
            }
        }
    }

    public String generateTweet() {
        return this.fakeTweet;
    }

    @Override
    public void cancel() {
        runLoop = false;
    }
}
