# Drone Autoscale

This is a service which provides two functions:

 - Cloudwatch metric collection for use with AWS autoscaling group alarms
 - Automated enabling (and disabling) of instances running jobs

It is intended to provide everything required to configure AWS autoscaling
groups. The autoscaling configuration should be applied independently.

The service is provided as a
[container](https://hub.docker.com/r/futurelearn/drone-autoscale/), and I
recommend running it this way alongside Drone. It runs alongside the Drone
server, using the API to calculate the required number of workers.

The installation instructions are based upon working with [Docker
Compose](https://docs.docker.com/compose/).

> Note: It assumes the use of IAM credentials attached to an EC2 instance
> rather than using IAM user access keys.

## Metrics

Pushes server statistics to [Amazon
Cloudwatch](https://aws.amazon.com/cloudwatch/) as gathered using the [Drone
API](http://docs.drone.io/api-overview/).

This mode assumes that your server instance has access to write metrics to
Cloudwatch. It does not provide any dimensions and simply adds 5 basic metrics:

- `IdleWorkers`
- `RunningJobs`
- `PendingJobs`
- `TotalJobs`
- `RequiredWorkers`

The following IAM role should be sufficient:

`cloudwatch:PutMetricData`

By default these will be written under the `Drone` namespace, and the API will
be polled every 20 seconds. These can be amended by setting the
`DRONE_AUTOSCALE_NAMESPACE` and `DRONE_AUTOSCALE_POLLING_TIME` environment
variables.

It requires a [Drone API token](http://docs.drone.io/api-authentication/) for an
user. Set this under `DRONE_AUTOSCALE_API_TOKEN`.

## Instance protection

Sets the [Instance
Protection](https://docs.aws.amazon.com/autoscaling/ec2/userguide/as-instance-termination.html)
status of an EC2 instance depending on whether a job is running on the agent,
using the `/varz` agent endpoint.

This mode requires the Drone server instance to have the following IAM
permissions set:

```
{
    "Statement": [
        {
            "Action": [
                "autoscaling:SetInstanceProtection"
            ],
            "Effect": "Allow",
            "Resource": [
                "<agent autoscaling group arn>"
            ]
        },
        {
            "Action": [
                "autoscaling:DescribeAutoScalingGroups",
                "autoscaling:DescribeAutoScalingInstances"
            ],
            "Effect": "Allow",
            "Resource": [
                "*"
            ]
        }
    ],
    "Version": "2012-10-17"
}
```

## Install

To install, add the configuration alongside your Drone server in the Docker
Compose file:

```
version: '2'

services:
  drone-server:
    image: drone/drone:1.2
    ports:
      - 80:80
    volumes:
      - /var/lib/drone:/var/lib/drone/
    restart: always
  drone-autoscale:
    image: futurelearn/drone-autoscale
    restart: on-failure
    command: server
    depends_on:
      - drone-server
    environment:
      # API token to authenticate with Drone API
      DRONE_AUTOSCALE_API_TOKEN: <provide a Drone user API token>
      # AWS region
      DRONE_AUTOSCALE_AWS_REGION: eu-west-2
      # Find the agent autoscaling group based upon the name
      DRONE_AUTOSCALE_GROUP_NAME_QUERY: drone-agent
      # Endpoint for the Drone API
      DRONE_AUTOSCALE_HOST: http://drone-server
      # Cloudwatch namespace where metrics will be published
      DRONE_AUTOSCALE_NAMESPACE: Drone
```

## Configuring autoscaling policies

See the [AWS documentation on
autoscaling](https://docs.aws.amazon.com/autoscaling/ec2/userguide/GettingStartedTutorial.html).

It publishes a metric named "RequiredWorkers" which can be used as a guage for
how many workers to create or remove. It publishes both positive and negative
numbers.
