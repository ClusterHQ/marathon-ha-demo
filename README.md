# High Avaibility with Flocker and Mesos



## Demo

To simplify this demonstation, we have put together a Git repository with useful utilities such as some bash files and a Makefile. 

```bash
git clone https://github.com/ClusterHQ/marathon-ha-demo.git
```


### Prerequisites


#### `aws cli`

To run this demonstation you should only require the AWS CLI, and have your keypair on AWS. 

Installation of the [AWS CLI](https://aws.amazon.com/cli/) is fairly simple. 
In most cases you can install AWS CLI by running:

```bash
pip install awscli
```

> **Note:** If this is not successful, refer to the [AWS CLI installation documentation](https://aws.amazon.com/cli/).

Before we can proceed, you will need to configure the AWS CLI with your AWS API credentials.

```bash
aws configure
```

You will need to input your AWS API credentials, you can find information on how to generate this information from the [AWS documentation](http://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSGettingStartedGuide/AWSCredentials.html). 
There's no need to specify default regions, however you may want to do this for other projects.


#### AWS Keypair

In order for us to communicate with the instances which you provisions, you will need to ensure your keypair is added to the [`US-East-1` region](https://console.aws.amazon.com/ec2/v2/home?region=us-east-1#KeyPairs:sort=keyName). 
We depend on this region as that is where our base AMI is located.


### Bringing the Cluster Online

Once you have set your configuration, you can begin. 
To initially get the cluster up we need to set a few environment variables and run `make nodes`.

```bash
KEY_NAME=<Key name as on AWS> KEY_PATH=<Path to private key> make nodes
```

This will build a Mesos cluster with three EC2 instances. 
One instance will run the Flocker control service along with the Mesos master, and the other two will run a Mesos client and a Flocker agent.

Once the cluster has completed building using `make`, it will print some useful information which you should save for use later on in this tutorial.


### Running an Application

We have included a basic application manifest, `app.json`. 
This configuration includes a single container with an attached volume running "Moby Counter", the idea here is very simple:

 * Moby Counter runs a webserver with a simple Javascript application.
 * When a client browser clicks anywhere on the page, the co-ordinates are sent to the server.
 * A Docker logo is displayed at that co-ordinate
 * The co-ordinates are saved on the server to the Flocker volume.
 * When the page is reloaded, all the Docker logos are displayed on the page in the place they were clicked.

The end result is a simple stateful application saving the places on a page where the client has clicked and displayed a Docker logo in its place.

We need to inform Marathon about this application, in order to do this we will post its application manifest (`app.json`) to the Marathon API with CURL.

> **Note:** You will need to change the IP `172.16.79.250` to the IP of your master server which was displayed when you made the cluster.

```bash
curl -i -H 'Content-type: application/json' --data @app.json http://172.16.79.250:8080/v2/groups
```
