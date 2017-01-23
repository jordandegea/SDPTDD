package fr.ensimag.twitter_weather;

import org.apache.flink.api.common.io.OutputFormat;
import org.apache.flink.configuration.Configuration;
import org.apache.kafka.clients.producer.KafkaProducer;
import org.apache.kafka.clients.producer.ProducerRecord;

import java.io.IOException;
import java.util.Properties;

public class KafkaOutputFormat implements OutputFormat<StringPair> {
    private Properties props;
    private KafkaProducer<String, String> producer;

    public KafkaOutputFormat(Properties props) {
        this.props = props;
    }

    @Override
    public void configure(Configuration parameters) {
    }

    @Override
    public void open(int taskNumber, int numTasks) throws IOException {
        producer = new KafkaProducer<String, String>(this.props);
    }

    @Override
    public void writeRecord(StringPair record) throws IOException {
        producer.send(new ProducerRecord<String, String>(
            record.s1,
            record.s2
        ));
    }

    @Override
    public void close() throws IOException {
        producer.close();
    }
}
