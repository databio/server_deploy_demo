# Refgenieserver auto-deploy demo

This repository contains everything you need to automatically deploy refgenie server on AWS ECS using GitHub Actions when the repository is updated. It contains a few dummy fasta files that serve as the basis for the assets to serve. The code uses refgenie and refgenieserver to build assets, archive them, and serve them.

## Repository contents

- `.github/workflows` - workflows for Github Actions to auto-deploy new config files.
- `asset_pep` - annotation table describing the assets to serve
- `config` - refgenie config files that will be used to populate the server. Automatically updated by deploy commands below
- `fasta` - some demo fasta files.
- `Dockerfiles` - for a master and staging server; these just take the official [dockerhub databio/refgenieserver](https://hub.docker.com/r/databio/refgenieserver) image, and then add the local config file in. We'll build these files automatically using GitHub Actions when the config file changes.
- `pipeline_interfaces` - for looper to download, build, and archive assets.
- `task_defs` - AWS Task Definition files used to deploy the new containers onto an AWS ECS cluster.


There are 2 sets of instructions here: the *basic* instructions just show you how to load up a little demo refgenieserver instance. The *complete* instructions walk you through the whole thing.

## 1. Basic demo (basic example for running a local dev server)

Here are some basic instructions to just run a local refgenie server. Skip this if you are interested in the auto-deploy stuff.

### Init refgenie config

```
bulker activate databio/lab
export REFGENIE='genomes/rg.yaml'
refgenie init -c $REFGENIE
```

### Build

```
refgenie build demo/fasta --files fasta=fasta/demo.fa.gz
refgenie build demo2/fasta --files fasta=fasta/demo2.fa.gz
refgenie list
```

### Archive

We have to add the archive location to the config.

```
echo "genome_archive: $PWD/archive" >> $REFGENIE
cat $REFGENIE
refgenieserver archive
```

### Serve

```
refgenieserver serve -p 5000
```

### In container:

```
docker run docker build -t databio/reftest .
docker run --rm -d -p 80:80 databio/reftest
```

## 2. Complete demo (full automation with looper and AWS deployment)

This complete demo walks you through the whole process, which consists of these steps:

1. Download raw input files for assets
2. Build assets with `refgenie build`
3. Archive assets with `refgenieserver archive`
4. Deploy assets to active server on AWS.

### Setup
```
#export BASEDIR=$HOME/code/sandbox/refgenie_deploy
#export REFGENIE_RAW=$BASEDIR/refgenie_raw
export BASEDIR=$PROJECT/deploy/rg.databio.org
export REFGENIE_RAW=/project/shefflab/www/refgenie_raw
cd $BASEDIR
git clone git@github.com:refgenie/server_deploy_demo.git
```

GENOMES points to pipeline output (referenced in the project config)

```
export GENOMES=$BASEDIR/genomes
```

### Download

Download all required files, placing them in 
this renames them to a systematic naming, based on genome name, 
asset name, input type, and input name

```
cd server_deploy_demo
mkdir -p $REFGENIE_RAW
looper run asset_pep/refgenie_build_cfg.yaml -p local --amend getfiles
```

### Build

Now run the actual asset build jobs. You need to make sure the required executables are in your path. You can do this by installing them natively, or by activating a bulker crate like this:

```
bulker activate databio/refgenie:0.7.3
```

Or you can use `-p bulker_local` and use the crate already specified in the pipeline interface.

```
export REFGENIE=$BASEDIR/server_deploy_demo/config/master.yaml
looper run asset_pep/refgenie_build_cfg.yaml -p local
```

### Archive

```
looper runp asset_pep/refgenie_build_cfg.yaml -p local
export REFGENIE_ARCHIVE=$GENOMES/archive
aws s3 sync $REFGENIE_ARCHIVE s3://cloud.databio.org/refgenie
```

### Deploy

Changes to the refgenie config files with automatically trigger deploy jobs to push the updates to AWS ECS. There's a workflow for each the *master* and *staging* config file; if you change one, it will automatically deploy the correct thing.

```
ga -A; gcm "Deploy to ECS"; gpoh
```

Monitor the action feedback at the [actions tab](/actions). You can view the results at these URLS:

- master: [http://rg.databio.org](http://rg.databio.org)
- staging: [http://rg.databio.org:81](http://rg.databio.org:81)



## Notes and tips

### Deploy to amazon

You can create the AWS resources using the console, or these commands on the command line:

```
aws ecr create-repository --repository-name my-ecr-repo
aws ecs register-task-definition --cli-input-json file://FargateActionDemo/task-def.json
aws ecs create-cluster --cluster-name default
aws ecs create-service --service-name fargate-service --task-definition sample-fargate:6 --desired-count 2 --launch-type "FARGATE" --network-configuration "awsvpcConfiguration={subnets=[subnet-1d296378],securityGroups=[sg-da0875a5]}"
```
Follow instructions here: https://aws.amazon.com/blogs/opensource/github-actions-aws-fargate/

If you change the config/master.yaml or config/staging.yaml, it will automatically deploy a new container.


When creating the service, at first it worked using minimum set to 100 and maximum to 200. This would allow it to create another one.
But when I started mapping the ports, then this stopped working and it gives an error of "aws ecs s already using a port required by your task." So, it can't do a rolling deploy because it tries to get it up to 200%, which fails, so the deploy fails. Setting the minimum to 0 solves the problem, because now it can kill the container to start the next one. to do it with the 2-container version, you need dynamic port mapping, which I think will require (or at least be greatly simplified by) an application load balancer (which costs $20/month).

https://stackoverflow.com/questions/48931823/i-cant-deploy-a-new-container-to-my-ecs-cluster-because-of-ports-in-use


