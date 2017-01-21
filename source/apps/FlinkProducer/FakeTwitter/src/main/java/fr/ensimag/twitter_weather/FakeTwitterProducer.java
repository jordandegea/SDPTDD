package fr.ensimag.twitter_weather;

import org.apache.flink.api.common.restartstrategy.RestartStrategies;
import org.apache.flink.streaming.api.datastream.DataStreamSource;
import org.apache.flink.streaming.api.environment.StreamExecutionEnvironment;

import java.util.Properties;

public class FakeTwitterProducer {

    public static void main(String[] argv) throws Exception {
        if (argv.length < 2) {
            throw new IllegalArgumentException("Usage: arg 1 : rate\nArg 2 : kafka_address:9092");
        }
        int rate = Integer.parseInt(argv[0]);

        /* Kafka properties */
        Properties props = new Properties();
        props.put("bootstrap.servers", argv[1]);
        props.put("acks", "all");
        props.put("retries", 0);
        props.put("batch.size", 16384);
        props.put("linger.ms", 1);
        props.put("buffer.memory", 33554432);
        props.put("key.serializer", "org.apache.kafka.common.serialization.StringSerializer");
        props.put("value.serializer", "org.apache.kafka.common.serialization.StringSerializer");
        props.put("fakeTweetPath", "/usr/local/flink/fake_tweet.json");

        /* Configure the environnement with
         * - create a checkpoint every 5 seconds
         * - make parameters available in the web interface
         */
        StreamExecutionEnvironment env = StreamExecutionEnvironment.getExecutionEnvironment();

        env.getConfig().disableSysoutLogging();
        env.getConfig().setRestartStrategy(RestartStrategies.fixedDelayRestart(4, 10000));
        env.enableCheckpointing(5000);

        /* Connecte Kafka en entrée sur le topic spécifié */
        DataStreamSource<StringPair> messageStream = env.addSource(new FakeTwitterSource(props, rate));
        messageStream.name("twitter_fake_source");

        /* Passe chaque ligne dans la class HBaseOutputFormat */
        messageStream.writeUsingOutputFormat(new KafkaOutputFormat(props)).name("twitter_fake_kafka_sink");

        env.execute("Twitter Fake Producer");
    }
}

