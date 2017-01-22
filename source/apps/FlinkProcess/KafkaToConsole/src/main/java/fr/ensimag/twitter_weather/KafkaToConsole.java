package fr.ensimag.twitter_weather;

import org.apache.flink.api.common.io.OutputFormat;
import org.apache.flink.api.common.restartstrategy.RestartStrategies;
import org.apache.flink.api.java.utils.ParameterTool;
import org.apache.flink.configuration.Configuration;
import org.apache.flink.streaming.api.datastream.DataStream;
import org.apache.flink.streaming.api.environment.StreamExecutionEnvironment;
import org.apache.flink.streaming.api.functions.sink.PrintSinkFunction;
import org.apache.flink.streaming.connectors.kafka.FlinkKafkaConsumer08;
import org.apache.flink.streaming.util.serialization.SimpleStringSchema;
import org.apache.sling.commons.json.JSONException;
import org.apache.sling.commons.json.JSONObject;

import java.io.IOException;


/**
 * Read Strings from Kafka and print them to standard out.
 * Note: On a cluster, DataStream.print() will print to the TaskManager's .out file!
 * <p>
 * Please pass the following arguments to run the example:
 * --topic test --bootstrap.servers localhost:9092 --zookeeper.connect localhost:2181 --group.id myconsumer
 */
public class KafkaToConsole {
    public static void main(String[] args) throws Exception {
        // parse input arguments
        final ParameterTool parameterTool = ParameterTool.fromArgs(args);

        if (parameterTool.getNumberOfParameters() < 7) {
            System.out.println("Missing parameters!\n" +
                    "Usage: Kafka --topic <topic> " +
                    "--bootstrap.servers <kafka brokers> " +
                    "--zookeeper.connect <zk quorum> " +
                    "--group.id <some id> ");
            return;
        }

        StreamExecutionEnvironment env = StreamExecutionEnvironment.getExecutionEnvironment();
        env.getConfig().disableSysoutLogging();
        env.getConfig().setRestartStrategy(RestartStrategies.fixedDelayRestart(4, 10000));
        env.enableCheckpointing(5000); // create a checkpoint every 5 seconds
        env.getConfig().setGlobalJobParameters(parameterTool); // make parameters available in the web interface

        DataStream<String> messageStream = env
                .addSource(new FlinkKafkaConsumer08(
                        parameterTool.getRequired("topic"),
                        new SimpleStringSchema(),
                        parameterTool.getProperties()));

        // write kafka stream to standard out.
        //messageStream.print();

			/* Passe chaque ligne dans la class HBaseOutputFormat */
        messageStream.addSink(new ConsoleOutputFormat());

        env.execute(String.format("Flink console consumer %s", topic));
    }

    public static class StreamObject {
        public String name;
        public String content;
        public Number feeling;
    }

    /**
     * Process each line and write in HBase
     */
    private static class ConsoleOutputFormat extends PrintSinkFunction<String> {

        @Override
        public void invoke(String record) {
            StreamObject so = this.parse(record);
            record += so.name + so.feeling.toString();
            super.invoke(record);
        }

        /* Parse la ligne de kafka pour un sortir un objet pour HBase */
        public StreamObject parse(String in) {
            StreamObject obj = null;
            try {
                JSONObject json = new JSONObject(in);
                String text = (String) json.get("text");
                obj = new StreamObject();
                obj.name = "randomname";
                obj.content = in;
                if (text.contains("\\ud")) {
                    String substr = text.substring(text.indexOf("\\ud") + 3, text.indexOf("\\ud") + 5);
                    obj.feeling = Math.abs(Character.digit(substr.charAt(0), 10)) * 10 + Math.abs(Character.digit(substr.charAt(1), 10));
                }else{
                    obj.feeling = 50;
                }
            } catch (JSONException e) {
                e.printStackTrace();
            }
            return obj;
        }
    }
}

