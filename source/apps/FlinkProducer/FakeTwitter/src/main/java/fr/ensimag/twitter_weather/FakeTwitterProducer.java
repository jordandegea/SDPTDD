package fr.ensimag.twitter_weather;

import com.sun.org.apache.xpath.internal.functions.WrongNumberArgsException;
import org.apache.flink.api.common.io.OutputFormat;
import org.apache.flink.api.common.restartstrategy.RestartStrategies;
import org.apache.flink.configuration.Configuration;
import org.apache.flink.streaming.api.datastream.DataStream;
import org.apache.flink.streaming.api.environment.StreamExecutionEnvironment;
import org.apache.flink.streaming.api.functions.source.SourceFunction;
import org.apache.kafka.clients.producer.KafkaProducer;
import org.apache.kafka.clients.producer.ProducerRecord;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.util.Properties;
import java.util.Random;

public class FakeTwitterProducer {

    public static void main(String[] argv) throws Exception {
        if (argv.length < 2) {
            throw new WrongNumberArgsException("Arg 1 : rate\nArg 2 : kafka_address:9092");
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
/*


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
*/
		/* Configure the environnement with
		 * - create a checkpoint every 5 seconds
		 * - make parameters available in the web interface
		 */
        StreamExecutionEnvironment env = StreamExecutionEnvironment.getExecutionEnvironment();
        env.getConfig().disableSysoutLogging();
        env.getConfig().setRestartStrategy(RestartStrategies.fixedDelayRestart(4, 10000));
        env.enableCheckpointing(5000);
        //env.getConfig().setGlobalJobParameters(parameterTool);

		/* Connecte Kafka en entrée sur le topic spécifié */
        DataStream<StringString> messageStream;
        messageStream = env.addSource(new FakeTwitterSource(props, rate));

		/* Passe chaque ligne dans la class HBaseOutputFormat */
        messageStream.writeUsingOutputFormat(
                new KafkaOutputFormat(props));

        env.execute();
    }
}

class StringString{
    public String s1, s2;
    public StringString(String s1, String s2){
        this.s1 = s1;
        this.s2 = s2;
    }
}

class FakeTwitterSource implements SourceFunction<StringString> {

    private int rate;
    private double lastCheck;
    private String fakeTweet;
    private Random rnd = new Random();

    public FakeTwitterSource(Properties props, int rate) throws IOException {
        this.rate = rate;
        this.lastCheck = System.currentTimeMillis() / 1000.0;

		/* read the fake tweet */
        File file = new File("fake_tweet.json");
        FileInputStream fis = new FileInputStream(file);
        byte[] data = new byte[(int) file.length()];
        fis.read(data);
        fis.close();
        this.fakeTweet = new String(data, "UTF-8");
        this.fakeTweet.replace('\n', ' ');
    }

    @Override
    public void run(SourceContext<StringString> sourceContext) throws Exception {
        String topic = "paris";
        StringString ds ;
        while (true) {
            double current = System.currentTimeMillis() / 1000.0;
            double timePassed = current - this.lastCheck;
            if (timePassed >= this.rate) {
                topic = "paris";
                switch(rnd.nextInt(3)){
                    case 1:
                        topic = "london";
                        break;
                    case 2:
                        topic = "nyc";
                        break;
                    default:
                        break;
                }
                ds = new StringString(topic, this.generateTweet());
                sourceContext.collect(ds);
                this.lastCheck = current;
            }
        }
    }

    public String generateTweet() {
        return this.fakeTweet;
    }

    @Override
    public void cancel() {

    }
}

class KafkaOutputFormat implements OutputFormat<StringString> {

    Properties props;

    public KafkaOutputFormat(Properties props){
        this.props = props;
    }
    @Override
    public void configure(Configuration parameters) {

    }

    @Override
    public void open(int taskNumber, int numTasks) throws IOException {
    }

    @Override
    public void writeRecord(StringString record) throws IOException {
        KafkaProducer<String, String> producer = new KafkaProducer(this.props);
        producer.send(new ProducerRecord<String, String>(
                record.s1,
                record.s2
        ));
    }

    @Override
    public void close() throws IOException {
    }
}
/*
public class FakeTwitterProducer extends KafkaProducer<String, String> {

	public FakeTwitterProducer(Properties props, int rate) throws IOException {
		super(props);
		this.rate = rate;
		this.lastCheck = System.currentTimeMillis() / 1000.0;

		File file = new File("fake_tweet.json");
		FileInputStream fis = new FileInputStream(file);
		byte[] data = new byte[(int) file.length()];
		fis.read(data);
		fis.close();
		this.fakeTweet = new String(data, "UTF-8");
        this.fakeTweet.replace('\n', ' ');
	}

	public String generateTweet() {
		return this.fakeTweet;
	}

	public void runProducer() {
		while (true) {
			double current = System.currentTimeMillis() / 1000.0;
			double timePassed = current - this.lastCheck;
			if (timePassed >= this.rate) {
				this.sendToKafka(this.generateTweet());
				this.lastCheck = current;
			}
		}
	}

	public void sendToKafka(String data){
        String topic = "paris";
        switch(rnd.nextInt(3)){
            case 1:
                topic = "london";
                break;
            case 2:
                topic = "nyc";
                break;
            default:
                break;
        }

		this.send(new ProducerRecord<String, String>(
				topic,
				data
		));
	}

}
*/
