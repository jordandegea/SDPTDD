package fr.ensimag.twitter_weather;

import org.apache.flink.api.common.functions.MapFunction;
import org.apache.flink.api.common.restartstrategy.RestartStrategies;
import org.apache.flink.api.java.utils.ParameterTool;
import org.apache.flink.streaming.api.datastream.DataStream;
import org.apache.flink.streaming.api.environment.StreamExecutionEnvironment;
import org.apache.flink.streaming.api.functions.sink.OutputFormatSinkFunction;
import org.apache.flink.streaming.api.functions.sink.SinkFunction;
import org.apache.flink.streaming.connectors.kafka.FlinkKafkaConsumer08;

import java.io.IOException;
import java.util.UUID;

import org.apache.flink.api.common.io.OutputFormat;
import org.apache.flink.configuration.Configuration;
import org.apache.flink.streaming.util.serialization.SimpleStringSchema;
import org.apache.hadoop.hbase.HBaseConfiguration;
import org.apache.hadoop.hbase.TableName;
import org.apache.hadoop.hbase.client.Connection;
import org.apache.hadoop.hbase.client.ConnectionFactory;
import org.apache.hadoop.hbase.client.Table;
import org.apache.hadoop.hbase.client.Put;
import org.apache.hadoop.hbase.util.Bytes;
import org.apache.sling.commons.json.JSONException;
import org.apache.sling.commons.json.JSONObject;


/**
 * Read Strings from Kafka representing Tweets; Process the values and store in HBase.
 */
public class KafkaHBaseBridge {
	public static void main(String[] args) throws Exception {
		
		final ParameterTool parameterTool = ParameterTool.fromArgs(args);

		/* Display the usage if the arguments are wrong */
		if(parameterTool.getNumberOfParameters() < 7) {
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

		/* Connecte Kafka en entrée sur le topic spécifié */
		DataStream<String> messageStream = env
				.addSource(new FlinkKafkaConsumer08(
						parameterTool.getRequired("topic"),
						new SimpleStringSchema(),
						parameterTool.getProperties()));

		/* Passe chaque ligne dans la class HBaseOutputFormat */
        messageStream.writeUsingOutputFormat(
                new HBaseOutputFormat(
                        parameterTool.getRequired("hbasetable"),
                        parameterTool.getRequired("hbasequorum"),
                        Integer.parseInt(parameterTool.getRequired("hbaseport"))
                ));

		env.execute();
	}

	public static class StreamObject{
        public String name;
        public String content;
        public Number feeling;
    }

	/**
	 * Process each line and write in HBase
	 */
	private static class HBaseOutputFormat implements OutputFormat<String> {

		private org.apache.hadoop.conf.Configuration conf = null;
		private Table table = null;
		private Connection connection = null;

		private static final long serialVersionUID = 1L;

        private String tablename = "table1";

        public static final String HBASE_CONFIGURATION_ZOOKEEPER_QUORUM                     = "hbase.zookeeper.quorum";
        public static final String HBASE_CONFIGURATION_ZOOKEEPER_CLIENTPORT                 = "hbase.zookeeper.property.clientPort";

        private String hbaseZookeeperQuorum = "localhost";
        private int hbaseZookeeperClientPort = 10000;

        public HBaseOutputFormat(String tablename, String quorum, int port){
            this.tablename = tablename;
            this.hbaseZookeeperQuorum = quorum;
            this.hbaseZookeeperClientPort = port;
        }

		@Override
		public void configure(Configuration parameters) {
			conf = HBaseConfiguration.create();

            conf.set(HBASE_CONFIGURATION_ZOOKEEPER_QUORUM, hbaseZookeeperQuorum);
            conf.setInt(HBASE_CONFIGURATION_ZOOKEEPER_CLIENTPORT, hbaseZookeeperClientPort);

			try {
				connection = ConnectionFactory.createConnection(conf);
			} catch (IOException e) {
				e.printStackTrace();
			}
		}

		@Override
		public void open(int taskNumber, int numTasks) throws IOException {
			table = connection.getTable(TableName.valueOf(tablename));
		}

		/**
		 * Pour chaque ligne, parse le contenu de la ligne et ecrit le resultat dans HBase
		 */
		@Override
		public void writeRecord(String record) throws IOException {
            StreamObject obj = this.parse(record);
            if (obj == null){
                Put put = new Put(Bytes.toBytes(System.currentTimeMillis() + "_error"));
                put.addColumn(Bytes.toBytes("place"), Bytes.toBytes(""), Bytes.toBytes("error"));
                put.addColumn(Bytes.toBytes("datas"), Bytes.toBytes(""), System.currentTimeMillis(), Bytes.toBytes(record));
                put.addColumn(Bytes.toBytes("feeling"), Bytes.toBytes(""), Bytes.toBytes("0"));
                table.put(put);
            }else {
                //Put put = new Put(Bytes.toBytes(taskNumber + UUID.randomUUID()));
                Put put = new Put(Bytes.toBytes(System.currentTimeMillis() + "_" + obj.name));
                put.addColumn(Bytes.toBytes("place"), Bytes.toBytes(""), System.currentTimeMillis(), Bytes.toBytes(obj.name));
                put.addColumn(Bytes.toBytes("datas"), Bytes.toBytes(""), System.currentTimeMillis(), Bytes.toBytes(obj.content));
                put.addColumn(Bytes.toBytes("feeling"), Bytes.toBytes(""), System.currentTimeMillis(), Bytes.toBytes(obj.feeling.toString()));
                table.put(put);
            }
		}

		@Override
		public void close() throws IOException {
			table.close();
			connection.close();
		}

        /* Parse la ligne de kafka pour un sortir un objet pour HBase */
        public StreamObject parse(String in) {
            StreamObject obj = null;
            try {
                JSONObject json = new JSONObject(in);
                String text = (String) json.get("text");
                if (text.contains("\\ud")) {
                    obj = new StreamObject();
                    obj.name = tablename;
                    obj.content = in;
                    String substr = text.substring(text.indexOf("\\ud") + 3, text.indexOf("\\ud") + 5);
                    obj.feeling = Math.abs(Character.digit(substr.charAt(0), 10)) * 10 + Math.abs(Character.digit(substr.charAt(1), 10));
                }
            } catch (JSONException e) {
                e.printStackTrace();
            }
            return obj;
        }
    }
}

