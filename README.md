# Space Stone - A Serverless PDF Processing Setup

The goal of Space Stone is to allow derivative preprocessing to take place in a serverless framework. At the moment, only an AWS Lambda library is set up, but future versions may contain other distributions. This code is built with the [Serverless Framework](https://www.serverless.com/framework/docs), a powerful abstraction and CLI for dealing with various cloud function as code providers.

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
```

AWS credentials are pulled from AWS_PROFILE. Make sure your ~/.aws/config and ~/.aws/credentials are set accordingly. See [AWS CLI docs](https://awscli.amazonaws.com/v2/documentation/api/latest/reference/configure/index.html)
 for more info.

## Deploy
Make sure your AWS profile is set correctly

`sls deploy` # for dev which is the default
`sls deploy -s STAGE_NAME` # to set a custom stage like production


## Why call it Space Stone
In the Marvel Cinematic Universe, the Tesseract contains the Space Stone. That's it. The whole story. There's no other reason.
