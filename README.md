# Drone Autoscale

This is a service which operates in either `server` or `agent` mode, both which
provide two different functions.

## Server mode

Pushes server statistics to [Amazon Cloudwatch](https://aws.amazon.com/cloudwatch/)
as gathered using the [Drone API](http://docs.drone.io/api-overview/).

## Agent mode

Sets the [Instance
Protection](https://docs.aws.amazon.com/autoscaling/ec2/userguide/as-instance-termination.html)
status of an EC2 instance depending on whether a job is running on the agent,
using the `/varz` agent endpoint.
