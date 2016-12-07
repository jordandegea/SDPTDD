

consumer:
	./bin/kafka-console-consumer.sh --topic test --zookeeper localhost:2181

zookeeper:
	./bin/zookeeper-server-start.sh ./config/zookeeper.properties 

kafka:
	./bin/kafka-server-start.sh ./config/server.properties 

create_test:
	./bin/kafka-topics.sh --create --topic test --zookeeper localhost:2181 --partitions 1 --replication-factor 1


producer:
	./bin/kafka-console-producer.sh --topic test --broker-list localhost:9092