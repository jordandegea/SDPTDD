Feature: deployment

Scenario Outline: Deploying using rake
    When I run the rake task "deploy:<step>"
    Then the task should succeed

    Examples:
        | step      |
        | bootstrap |
        | system    |
        | software  |
        | settings  |
        | code      |

