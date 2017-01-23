package fr.ensimag.twitter_weather;

import org.apache.flink.api.common.io.OutputFormat;
import org.apache.flink.configuration.Configuration;
import org.apache.hadoop.hbase.HBaseConfiguration;
import org.apache.hadoop.hbase.TableName;
import org.apache.hadoop.hbase.client.Connection;
import org.apache.hadoop.hbase.client.ConnectionFactory;
import org.apache.hadoop.hbase.client.Table;
import org.apache.sling.commons.json.JSONException;
import org.apache.sling.commons.json.JSONObject;

import java.io.IOException;

/**
 * Process each line and write in HBase
 */
class HBaseOutputFormat implements OutputFormat<String> {
    public static final String HBASE_CONFIGURATION_ZOOKEEPER_QUORUM = "hbase.zookeeper.quorum";
    public static final String HBASE_CONFIGURATION_ZOOKEEPER_CLIENTPORT = "hbase.zookeeper.property.clientPort";
    private static final long serialVersionUID = 1L;
    private org.apache.hadoop.conf.Configuration conf;
    private Table table;
    private Connection connection;
    private String tableName;
    private String hbaseZookeeperQuorum;
    private int hbaseZookeeperClientPort;

    public HBaseOutputFormat(String tablename, String quorum, int port) {
        this.tableName = tablename;
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
        table = connection.getTable(TableName.valueOf(tableName));
    }

    /**
     * Pour chaque ligne, parse le contenu de la ligne et ecrit le resultat dans HBase
     */
    @Override
    public void writeRecord(String record) throws IOException {
        this.parse(record).put(table);
    }

    @Override
    public void close() throws IOException {
        table.close();
        connection.close();
    }

    /* Parse la ligne de kafka pour un sortir un objet pour HBase */
    public StreamObject parse(String in) {
        StreamObject obj;
        try {
            JSONObject json = new JSONObject(in);
            obj = new StreamObject(json);
        } catch (JSONException e) {
            obj = new StreamObject(e);
        }
        return obj;
    }
}
