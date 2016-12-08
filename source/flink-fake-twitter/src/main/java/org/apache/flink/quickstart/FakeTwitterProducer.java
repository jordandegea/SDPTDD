package org.apache.flink.quickstart;

import com.sun.org.apache.xpath.internal.functions.WrongNumberArgsException;
import org.apache.kafka.clients.producer.KafkaProducer;
import org.apache.kafka.clients.producer.ProducerRecord;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.util.Properties;

/**
 * Created by willol on 08/12/16.
 */
public class FakeTwitterProducer extends KafkaProducer<String, String> {
	private int rate;
	private double lastCheck;
	private String fakeTweet;

	public FakeTwitterProducer(Properties props, int rate) throws IOException {
		super(props);
		this.rate = rate;
		this.lastCheck = System.currentTimeMillis() / 1000.0;

		/* read the fake tweet */
		File file = new File("src/main/java/org/apache/flink/quickstart/fake_tweet.json");
		FileInputStream fis = new FileInputStream(file);
		byte[] data = new byte[(int) file.length()];
		fis.read(data);
		fis.close();
		this.fakeTweet = new String(data, "UTF-8");
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

	public void sendToKafka(String data) {
		this.send(new ProducerRecord<String, String>(
				"twitter",
				data
		));
	}

	public static void main(String[] argv) throws IOException, WrongNumberArgsException {
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

		FakeTwitterProducer provider = new FakeTwitterProducer(props, rate);
		provider.runProducer();
	}
}
