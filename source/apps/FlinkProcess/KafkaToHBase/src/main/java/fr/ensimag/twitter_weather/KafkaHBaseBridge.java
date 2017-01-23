package fr.ensimag.twitter_weather;

import org.apache.flink.api.common.restartstrategy.RestartStrategies;
import org.apache.flink.api.java.utils.ParameterTool;
import org.apache.flink.streaming.api.datastream.DataStreamSink;
import org.apache.flink.streaming.api.datastream.DataStreamSource;
import org.apache.flink.streaming.api.environment.StreamExecutionEnvironment;
import org.apache.flink.streaming.connectors.kafka.FlinkKafkaConsumer08;
import org.apache.flink.streaming.util.serialization.SimpleStringSchema;
import org.apache.hadoop.hbase.client.Put;
import org.apache.hadoop.hbase.client.Table;
import org.apache.hadoop.hbase.util.Bytes;
import org.apache.sling.commons.json.JSONObject;

import java.io.IOException;


/**
 * Read Strings from Kafka representing Tweets; Process the values and store in HBase.
 */
public class KafkaHBaseBridge {
    public static void main(String[] args) throws Exception {

        final ParameterTool parameterTool = ParameterTool.fromArgs(args);

		/* Display the usage if the arguments are wrong */
        if (parameterTool.getNumberOfParameters() < 7) {
            System.out.println("Missing parameters!\n" +
                "Usage: Kafka --topic <topic> " +
                "--bootstrap.servers <kafka brokers> " +
                "--zookeeper.connect <zk quorum> " +
                "--group.id <some id> " +
                "--hbasetable <hbase table> " +
                "--hbasequorum <hbase zookeeper quorum> " +
                "--hbaseport <hbase zookeeper port>");
            return;
        }

		/* Configure the environnement with 
         * - create a checkpoint every 5 seconds
		 * - make parameters available in the web interface
		 */
        StreamExecutionEnvironment env = StreamExecutionEnvironment.getExecutionEnvironment();
        env.getConfig().disableSysoutLogging();
        env.getConfig().setRestartStrategy(RestartStrategies.fixedDelayRestart(4, 10000));
        env.enableCheckpointing(5000);
        env.getConfig().setGlobalJobParameters(parameterTool);

        String topic = parameterTool.getRequired("topic");

		/* Connecte Kafka en entrée sur le topic spécifié */
        DataStreamSource<String> messageStream = env
            .addSource(new FlinkKafkaConsumer08<String>(
                topic,
                new SimpleStringSchema(),
                parameterTool.getProperties()));
        messageStream.name(String.format("kafka_source_%s", topic));

        //DataStreamSink<String> sink = messageStream.addSink(new ConsoleOutputFormat());
		/* Passe chaque ligne dans la class HBaseOutputFormat */
        DataStreamSink<String> sink = messageStream.writeUsingOutputFormat(
            new HBaseOutputFormat(
                parameterTool.getRequired("hbasetable"),
                parameterTool.getRequired("hbasequorum"),
                Integer.parseInt(parameterTool.getRequired("hbaseport"))
            ));
        sink.name(String.format("kafka_sink_%s", topic));

        env.execute(String.format("Flink consumer %s", topic));
    }

}

