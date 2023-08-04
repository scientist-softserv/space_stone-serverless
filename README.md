# Space Stone - A Serverless PDF and Image Processing Setup

Welcome to the Space Rodeo!

The goal of Space Stone is to allow derivative preprocessing to take place in a serverless framework.

At the moment, only an AWS Lambda library is set up, but future versions may contain other distributions. This code is built with the [Serverless Framework](https://www.serverless.com/framework/docs), a powerful abstraction and CLI for dealing with various cloud function as code providers.

There are two files of primary interest for AWS:

- **./awslambda/serverless.yml** :: The configuration logic of serverless environment (resources, dependencies, and how we connect Lambda end-points to Ruby methods)
- **./awslambda/handler.rb** :: The Ruby functions that perform the business logic.

The primary code file of interest is [./awslambda/handler.rb](./awslambda/handler.rb).  <time datetime="2023-05-22">At present</time> it has very non-Object Oriented arrangement; which as with all things software, might change.

The `./awslambda/serverless.rb` has two types of methods types of methods:

- **handlers** :: a public method that is mapped to by our AWS serverless
                  configuration (see [./awslambda/serverless.yml](./awslambda/serverless.yml))
- **helpers** :: non-handlers, things that handlers will use to help get the job
                 done.

## Setup

```bash
npm install -g serverless
git submodule init
git submodule update
pushd serverless-ruby-layer
npm install
popd
pushd awslambda
npm install

# prime the docker image to make building faster
docker pull ghcr.io/scientist-softserv/space_stone/awsrubylayer:latest
```

AWS credentials are pulled from AWS_PROFILE. Make sure your `~/.aws/config` and `~/.aws/credentials` are set accordingly. See [AWS CLI docs](https://awscli.amazonaws.com/v2/documentation/api/latest/reference/configure/index.html)
 for more info.

### Updating Submodules

There are two submodules:

- derivative_rodeo
- serverless-ruby-layer

To update the SHA, `cd` into their respective directories and pull down those changes (e.g. `git pull origin main` to get latest changes).

### When you make changes to the Dockerfile

The deploy step is likely to be slow after changes to the Dockerfile as it rebuilds the docker image. To make sure others do not need to replicate the docker build, please push the built image afterward:

```
docker push ghcr.io/scientist-softserv/space_stone/awsrubylayer:latest
```

## Deploy

Make sure your AWS profile is set correctly.  You will deploy from the AWS Lambda directory (e.g. `cd awslambda`) then run one of the the following commands:

- `sls deploy` :: for dev which is the default
- `sls deploy -s STAGE_NAME` :: to set a custom stage like production

## Why call it Space Stone

In the Marvel Cinematic Universe, the Tesseract contains the Space Stone. That's it. The whole story. There's no other reason.
