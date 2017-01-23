Feature: service_watcher

Background:
    Given the "zookeeper" service is running
    And the "service_watcher" service is running

@development
Scenario: service_watcher starts dummy_global
    Then the "dummy_global" service should be running

@development
Scenario: service_watcher starts 2 instances of dummy_shared
    Then there should be 2 instances of the "dummy_shared" service running

Scenario: service_watcher starts kafka
    Then the "kafka" service should be running

Scenario: service_watcher starts haproxy
    Then the "haproxy" service should be running

Scenario: service_watcher starts 1 instances of flink@jobmanager
    Then there should be 1 instances of the "flink@jobmanager" service running

@production
Scenario: service_watcher starts flink@taskmanager
    Then the "flink@taskmanager" service should be running

@development
Scenario: service_watcher starts 1 instances of flink@taskmanager
    Then there should be 1 instances of the "flink@taskmanager" service running

Scenario: service_watcher starts 1 instances of hadoop@namenode
    Then there should be 1 instances of the "hadoop@namenode" service running

Scenario: service_watcher starts hadoop@datanode
    Then the "hadoop@datanode" service should be running

Scenario: service_watcher starts 1 instances of hbase@master
    Then there should be 1 instances of the "hbase@master" service running

@production
Scenario: service_watcher starts 2 instances of hbase@regionserver
    Then there should be 2 instances of the "hbase@regionserver" service running

@developement
Scenario: service_watcher starts 1 instances of hbase@regionserver
    Then there should be 1 instances of the "hbase@regionserver" service running

@production
Scenario: service_watcher starts 2 instances of zeppelin
    Then there should be 2 instances of the "zeppelin" service running

@developement
Scenario: service_watcher starts 1 instances of zeppelin
    Then there should be 1 instances of the "zeppelin" service running

Scenario: service_watcher starts 1 instances of flink_city@london
    Then there should be 1 instances of the "flink_city@london" service running

Scenario: service_watcher starts 1 instances of flink_city@nyc
    Then there should be 1 instances of the "flink_city@nyc" service running

Scenario: service_watcher starts 1 instances of flink_city@paris
    Then there should be 1 instances of the "flink_city@paris" service running