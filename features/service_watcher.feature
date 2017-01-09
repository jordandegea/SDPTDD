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
