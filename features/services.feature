Feature: services

Scenario Outline: Starting a service using rake
    Given the "<service>" service is not running
    When I run the rake task "services:start[,<service>]"
    Then the task should succeed
    And the "<service>" service should be running

    Examples:
        | service   |
        | zookeeper |
        | kafka     |
        # | flink     | TODO: Add when ready
        # | hbase     | TODO: Add when ready
        | zeppelin  |

Scenario: Starting a service on one host
    Given the "zookeeper" service is not running
    When I run the rake task "services:start[,zookeeper]" on the 1st host
    Then the task should succeed
    And the "zookeeper" service should be running on the 1st host
    But the "zookeeper" service should not be running on the 2nd host
    And the "zookeeper" service should not be running on the 3rd host