package fr.ensimag.twitter_weather;

/**
 * Created by willol on 07/12/16.
 */
/*
 * Licensed to the Apache Software Foundation (ASF) under one or more
 * contributor license agreements.  See the NOTICE file distributed with
 * this work for additional information regarding copyright ownership.
 * The ASF licenses this file to You under the Apache License, Version 2.0
 * (the "License"); you may not use this file except in compliance with
 * the License.  You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */


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


/**
 * Read Strings from Kafka and print them to standard out.
 * Note: On a cluster, DataStream.print() will print to the TaskManager's .out file!
 * <p>
 * Please pass the following arguments to run the example:
 * --topic test --bootstrap.servers localhost:9092 --zookeeper.connect localhost:2181 --group.id myconsumer
 */
public class KafkaHBaseBridge {
	public static void main(String[] args) throws Exception {
		// parse input arguments
		final ParameterTool parameterTool = ParameterTool.fromArgs(args);

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
	 * This class implements an OutputFormat for HBase
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

		@Override
		public void writeRecord(String record) throws IOException {
            StreamObject obj = this.parse(record);
            //Put put = new Put(Bytes.toBytes(taskNumber + UUID.randomUUID()));
            Put put = new Put(Bytes.toBytes(System.currentTimeMillis() + "_" + obj.name));
            put.addColumn(Bytes.toBytes("place"), Bytes.toBytes(""), System.currentTimeMillis(), Bytes.toBytes(obj.name));
            put.addColumn(Bytes.toBytes("datas"), Bytes.toBytes(""), System.currentTimeMillis(), Bytes.toBytes(obj.content));
            put.addColumn(Bytes.toBytes("feeling"), Bytes.toBytes(""), System.currentTimeMillis(), Bytes.toBytes(obj.feeling.toString()));
			table.put(put);
		}

		@Override
		public void close() throws IOException {
			table.close();
			connection.close();
		}

        public StreamObject parse(String in) {
            StreamObject obj = new StreamObject();
            obj.name = "something";
            obj.content = in;
            obj.feeling = 50.00;
            return obj;
        }
    }
}

