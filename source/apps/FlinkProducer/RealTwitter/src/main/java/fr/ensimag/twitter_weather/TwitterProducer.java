package fr.ensimag.twitter_weather;

import org.apache.flink.api.common.functions.FlatMapFunction;
import org.apache.flink.api.common.restartstrategy.RestartStrategies;
import org.apache.flink.streaming.api.datastream.DataStream;
import org.apache.flink.streaming.api.datastream.DataStreamSource;
import org.apache.flink.streaming.api.environment.StreamExecutionEnvironment;
import org.apache.flink.streaming.connectors.twitter.TwitterSource;
import org.apache.flink.util.Collector;

import java.util.Properties;
import java.util.Random;

public class TwitterProducer {

    public static class getTopicFlatMap implements FlatMapFunction<String, StringPair> {
        Random random = new Random();

        private String getCity() {
            int result = random.nextInt(100);
            if (result < 20) {
                return "paris";
            } else if (result < 60) {
                return "london";
            } else {
                return "nyc";
            }
        }

        @Override
        public void flatMap(String value, Collector<StringPair> out) {
            String city = this.getCity();
            out.collect(new StringPair(city, value));
        }
    }

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

        /* Configure the environnement with
         * - create a checkpoint every 5 seconds
         * - make parameters available in the web interface
         */
        StreamExecutionEnvironment env = StreamExecutionEnvironment.getExecutionEnvironment();

        env.getConfig().disableSysoutLogging();
        env.getConfig().setRestartStrategy(RestartStrategies.fixedDelayRestart(4, 10000));
        env.enableCheckpointing(5000);

        /* Connecte Twitter en entrée */
        DataStreamSource<String> streamTwitter = env.addSource(TwitterProducer.getSource());
        DataStream<StringPair> streamSource = streamTwitter.flatMap(new getTopicFlatMap());
//        streamSource.name("twitter_source");

        /* Passe chaque ligne dans la class KafkaOutputFormat */
        streamSource.writeUsingOutputFormat(new KafkaOutputFormat(props)).name("twitter_kafka_sink");

        env.execute("Twitter Producer");
    }

    private static TwitterSource getSource() {
        Properties p = new Properties();
        p.setProperty(TwitterSource.CONSUMER_KEY, "EXQ8uIU0Y39HfHxXxmlFPOqVI");
        p.setProperty(TwitterSource.CONSUMER_SECRET, "qZ3LSx62jFQW84PhrYmJJxaS3OHs093wjIgbwzrHPapRV8WuKm");
        p.setProperty(TwitterSource.TOKEN, "730398860540051456-kzb8h3yz2gC33IaMAMEjYTL94bVAsqC");
        p.setProperty(TwitterSource.TOKEN_SECRET, "Wmcf2Qfil0LkSYDJJ97c0sUbIoBpWtn7F03Kf6ac3amUk");

        TwitterSource source = new TwitterSource(p);
        TwitterSource.EndpointInitializer endFilt = new FilterImplements();
        source.setCustomEndpointInitializer(endFilt);
        return source;
    }
}

