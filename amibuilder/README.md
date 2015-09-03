## create AMI

This will use the Vagrant AWS plugin to provision a blank, new Ubuntu instance and get everything installed on it ready to produce an AMI.

You need 2 vagrant plugins for this to work:

```
$ vagrant plugin install vagrant-aws
$ vagrant plugin install vagrant-awsinfo
```

You also need [jq](http://stedolan.github.io/jq/download/) installed.

Before running the script - you need to create a `.aws_secrets` file in the root of this repo that will be used to configure EC2.
You can base this on the `.aws_secrets.example` file:

```yaml
access_key_id: KEY_ID_HERE
secret_access_key: SECRET_KEY_HERE
region: us-east-1
zone: us-east-1c
keypair_name: kai-demo
keypair_path: /Users/kai/.ssh/kai-demo.pem
instance_name_prefix: kai
builderami: ami-3cf8b154
runnerami: ami-290fe942
instance_type: c3.xlarge
```

IMPORTANT - you need to create a keypair in the region you intend to run the instances (.e.g US East 1)

Also - the `builderami` field needs to be an Ubuntu 14.04 box that is from the same region as the keypair

This keypair needs downloading and when you edit `.aws_secrets` - set the keypair_name and keypair_path accordingly.  When you run 

You also need the [aws cli](http://docs.aws.amazon.com/cli/latest/userguide/installing.html) installed and configured with your access credentials (the same as the ones above) - you can `aws configure` to do this.

When you run `aws configure` - ensure that the region is the same as the one in which you created the keypair.

Once this is setup - do this:

```
$ make build
```

which does:

```
$ bash build.sh
```

This will vagrant up - get the box provisioned and then spit out an AMI from it.

Once the ImageId has been printed - the image will still be pending - use the AWS console to see its current status.

When the Image is ready - edit the permissions to public so anyone can use it.

When the AMI has been generated - replace the `runnerami` field in the `.aws_secrets` file to be the generated AMI id.

This means the runner will use the AMI we just built.
