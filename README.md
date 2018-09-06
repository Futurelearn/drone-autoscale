# Drone Autoscale

This is a service which operates in either `server` or `agent` mode, both which
provide two different functions.

It is intended to provide everything required to configure AWS autoscaling
groups. The autoscaling configuration should be applied independently.

The service is provided as a
[container](https://hub.docker.com/r/futurelearn/drone-autoscale/), and I
recommend running it this way alongside Drone.

The installation instructions are based upon working with [Docker
Compose](https://docs.docker.com/compose/).

It assumes the use of IAM credentials attached to an EC2 instance rather than
using IAM user access keys.

## Server mode

Pushes server statistics to [Amazon
Cloudwatch](https://aws.amazon.com/cloudwatch/) as gathered using the [Drone
API](http://docs.drone.io/api-overview/).

This mode assumes that your server instance has access to write metrics to
Cloudwatch. It does not provide any dimensions and simply adds 4 basic metrics:

- `IdleWorkers`
- `RunningJobs`
- `PendingJobs`
- `TotalJobs`

The following IAM role should be sufficient:

`cloudwatch:PutMetricData`

By default these will be written under the `Drone` namespace, and the API will
be polled every 20 seconds. These can be amended by setting the
`DRONE_AUTOSCALE_NAMESPACE` and `DRONE_AUTOSCALE_POLLING_TIME` environment
variables.

It requires a [Drone API token](http://docs.drone.io/api-authentication/) for an
user. Set this under `DRONE_AUTOSCALE_API_TOKEN`.

To install, add the configuration alongside your Drone server in the Docker
Compose file:

```
version: '2'

services:
  drone-server:
    image: drone/drone:0.8
    ports:
      - 80:8000
      - 9000:9000
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
      DRONE_AUTOSCALE_HOST: http://drone-server:8000
      DRONE_AUTOSCALE_API_TOKEN: <provide a Drone user API token>
```

## Agent mode

Sets the [Instance
Protection](https://docs.aws.amazon.com/autoscaling/ec2/userguide/as-instance-termination.html)
status of an EC2 instance depending on whether a job is running on the agent,
using the `/varz` agent endpoint.

This mode requires the instance to have the following IAM permissions set:

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

It will find the correct autoscaling group by searching what is set by
`DRONE_AUTOSCALE_GROUP_NAME_QUERY`. The reason it does a lookup is to help the
automation of deleting and recreating autoscaling groups where the name may
change (for example, when using the
[`name_prefix`](https://www.terraform.io/docs/providers/aws/r/autoscaling_group.html#name_prefix)
setting).

Set your Compose file:

```
services:
  drone-agent:
    image: drone/agent:0.8
    ports:
      - 3000:3000
    command: agent
    restart: always
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
  drone-autoscale:
    image: futurelearn/drone-autoscale
    restart: on-failure
    depends_on:
      - drone-agent
    environment:
      DRONE_AUTOSCALE_HOST: http://drone-agent:3000
      DRONE_AUTOSCALE_GROUP_NAME_QUERY: drone-agent
```

## Configuring autoscaling policies

See the [AWS documentation on
autoscaling](https://docs.aws.amazon.com/autoscaling/ec2/userguide/GettingStartedTutorial.html).

Below I describe how I have configured autoscaling for our requirements. This
may not suit your needs.

The instance protection will stop instances being terminated when they are
running a build so scaling in is safe to use.

To scale out, I monitor the `PendingJobs` metric and add an instance if the
metric `> 0` (using 1 datapoint per period for the quickest possible boot).

To scale in, I monitor the `IdleWorkers` metric and **slowly** remove one
instance at a time if the metric is `> 0`.
