# High Avaibility with Flocker and Mesos



## Demo

To simplify this demonstation, we have put together a Git repository with useful utilities such as Vagrantfiles and a Makefile. 

```bash
git clone https://github.com/ClusterHQ/marathon-ha-demo.git
```

From within this repository you will first need to set your AWS credentials and the path to your SSH keypair. 
We have included a sample configuration file which you will need to alter and save as `.aws_secrets`. 
This is located at `.aws_secrets.example`.


### Bringing the Cluster Online

Once you have set your configuration, you can begin. 
To initially get the cluster up we simply run

```bash
make cluster
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
