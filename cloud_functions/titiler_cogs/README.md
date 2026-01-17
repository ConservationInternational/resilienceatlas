# TiTiler COGs - Dynamic Tile Server

## What is TiTiler?

[TiTiler](https://developmentseed.org/titiler/) is a dynamic tile server for Cloud Optimized GeoTIFFs (COGs). It renders map tiles on-the-fly from raster data stored in S3, eliminating the need to pre-generate tile pyramids.

**Current Version:** TiTiler 1.1.0 on Python 3.14

### Adding a New Bucket

TiTiler only serves tiles from whitelisted S3 or GCS buckets. To add a new bucket:

1. Go to **GitHub → Settings → Secrets and variables → Actions → Variables**
2. Edit `TITILER_ALLOWED_BUCKETS`
3. Add your bucket URI (comma-separated): `s3://existing-bucket,s3://new-bucket,gs://gcs-bucket`
4. Redeploy TiTiler

### Purpose in Resilience Atlas

TiTiler powers the raster layer visualization in Resilience Atlas, enabling:

- **Dynamic tile rendering**: Generates map tiles from COG files in real-time as users pan and zoom
- **Efficient data access**: COGs support HTTP range requests, so only the needed portions of large raster files are read
- **Flexible visualization**: Apply rescaling, color mapping, and band combinations without regenerating data
- **Cost-effective scaling**: AWS Lambda automatically scales to handle traffic spikes

### API Endpoints

Once deployed, TiTiler provides these endpoints:

| Endpoint | Description |
|----------|-------------|
| `/tiles/WebMercatorQuad/{z}/{x}/{y}` | Get map tiles for a COG |
| `/info` | Get metadata about a COG |
| `/statistics` | Get statistics for a COG |
| `/preview` | Generate a preview image |
| `/point/{lon}/{lat}` | Query a point value |
| `/healthz` | Health check endpoint |
| `/docs` | Interactive API documentation |

**Example tile request:**
```
GET /tiles/WebMercatorQuad/10/512/384?url=https://storage.googleapis.com/bucket/layer.tif&bidx=1&colormap={"1":[255,0,0,255]}
```

**Example with URL encoding (for browsers):**
```
GET /tiles/WebMercatorQuad/10/512/384?url=https%3A%2F%2Fstorage.googleapis.com%2Fbucket%2Flayer.tif&bidx=1&colormap=%7B%221%22%3A%5B255%2C0%2C0%2C255%5D%7D
```

### Architecture

```
Frontend → CloudFront CDN → API Gateway → Lambda (TiTiler) → S3/GCS (COG files)
```

The service is deployed as an AWS Lambda function behind API Gateway with CloudFront CDN for global edge caching (24-hour default TTL).

### Configuring COG Layers in Backend Admin

When creating a COG layer in the Resilience Atlas admin panel, set the `layer_config` JSON with the tile URL template. The frontend substitutes `{z}`, `{x}`, `{y}` and `{{colormap}}` parameters at runtime.

**Example `layer_config` for a COG layer:**
```json
{
  "type": "tileLayer",
  "body": {
    "url": "https://staging.titiler.resilienceatlas.org/tiles/WebMercatorQuad/{z}/{x}/{y}?url=https://storage.googleapis.com/trendsearth-public/data/layer.tif&bidx=1&colormap={{colormap}}"
  },
  "params": {
    "colormap": {"1": [255, 0, 0, 255], "2": [0, 255, 0, 255]}
  }
}
```

**Key fields:**
- `body.url`: The TiTiler tile URL template with `{z}/{x}/{y}` placeholders
- `params.colormap`: Color mapping for raster values (optional)
- `bidx`: Band index parameter (1-based, e.g., `bidx=1` for first band)

**Important:** Use the new TiTiler 1.1.0 endpoint format `/tiles/WebMercatorQuad/{z}/{x}/{y}` - the old `/cog/tiles/{z}/{x}/{y}` format is no longer supported.

---

## Project Structure

This project contains source code and supporting files for a serverless application that you can deploy with the SAM CLI. It includes the following files and folders.

- titiler_cogs - Code for the application's Lambda function and Project Dockerfile.
- events - Invocation events that you can use to invoke the function.
- tests - Unit tests for the application code.
- template.yaml - A template that defines the application's AWS resources.

The application uses several AWS resources, including Lambda functions and an API Gateway API. These resources are defined in the `template.yaml` file in this project. You can update the template to add AWS resources through the same deployment process that updates your application code.

## Deploy the sample application

The Serverless Application Model Command Line Interface (SAM CLI) is an extension of the AWS CLI that adds functionality for building and testing Lambda applications. It uses Docker to run your functions in an Amazon Linux environment that matches Lambda. It can also emulate your application's build environment and API.

To use the SAM CLI, you need the following tools.

- SAM CLI - [Install the SAM CLI](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/serverless-sam-cli-install.html)
- Docker - [Install Docker community edition](https://hub.docker.com/search/?type=edition&offering=community)

You may need the following for local testing.

- [Python 3 installed](https://www.python.org/downloads/)

To build and deploy your application for the first time, run the following in your shell:

```bash
sam build
sam deploy --guided
```

The first command will build a docker image from a Dockerfile and then copy the source of your application inside the Docker image. The second command will package and deploy your application to AWS, with a series of prompts:

- **Stack Name**: The name of the stack to deploy to CloudFormation. This should be unique to your account and region, and a good starting point would be something matching your project name.
- **AWS Region**: The AWS region you want to deploy your app to.
- **Confirm changes before deploy**: If set to yes, any change sets will be shown to you before execution for manual review. If set to no, the AWS SAM CLI will automatically deploy application changes.
- **Allow SAM CLI IAM role creation**: Many AWS SAM templates, including this example, create AWS IAM roles required for the AWS Lambda function(s) included to access AWS services. By default, these are scoped down to minimum required permissions. To deploy an AWS CloudFormation stack which creates or modifies IAM roles, the `CAPABILITY_IAM` value for `capabilities` must be provided. If permission isn't provided through this prompt, to deploy this example you must explicitly pass `--capabilities CAPABILITY_IAM` to the `sam deploy` command.
- **Save arguments to samconfig.toml**: If set to yes, your choices will be saved to a configuration file inside the project, so that in the future you can just re-run `sam deploy` without parameters to deploy changes to your application.

You can find your API Gateway Endpoint URL in the output values displayed after deployment.

## Use the SAM CLI to build and test locally

Build your application with the `sam build` command.

```bash
sam build
```

The SAM CLI builds a docker image from a Dockerfile and then installs dependencies defined in `titiler_cogs/requirements.txt` inside the docker image. The processed template file is saved in the `.aws-sam/build` folder.

Test a single function by invoking it directly with a test event. An event is a JSON document that represents the input that the function receives from the event source. Test events are included in the `events` folder in this project.

Run functions locally and invoke them with the `sam local invoke` command.

```bash
sam local invoke TitilerCogsFunction --event events/event.json
```

The SAM CLI can also emulate your application's API. Use the `sam local start-api` to run the API locally on port 3000.

```bash
sam local start-api
curl http://localhost:3000/
```

The SAM CLI reads the application template to determine the API's routes and the functions that they invoke. The `Events` property on each function's definition includes the route and method for each path.

```yaml
      Events:
        HelloWorld:
          Type: Api
          Properties:
            Path: /hello
            Method: get
```

## Add a resource to your application

The application template uses AWS Serverless Application Model (AWS SAM) to define application resources. AWS SAM is an extension of AWS CloudFormation with a simpler syntax for configuring common serverless application resources such as functions, triggers, and APIs. For resources not included in [the SAM specification](https://github.com/awslabs/serverless-application-model/blob/master/versions/2016-10-31.md), you can use standard [AWS CloudFormation](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-template-resource-type-ref.html) resource types.

## Fetch, tail, and filter Lambda function logs

To simplify troubleshooting, SAM CLI has a command called `sam logs`. `sam logs` lets you fetch logs generated by your deployed Lambda function from the command line. In addition to printing the logs on the terminal, this command has several nifty features to help you quickly find the bug.

`NOTE`: This command works for all AWS Lambda functions; not just the ones you deploy using SAM.

```bash
sam logs -n HelloWorldFunction --stack-name lambda-python3.9 --tail
```

You can find more information and examples about filtering Lambda function logs in the [SAM CLI Documentation](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/serverless-sam-cli-logging.html).

## Unit tests

Tests are defined in the `tests` folder in this project. Use PIP to install the [pytest](https://docs.pytest.org/en/latest/) and run unit tests from your local machine.

```bash
pip install pytest pytest-mock --user
python -m pytest tests/ -v
```

## Cleanup

To delete the sample application that you created, use the AWS CLI. Assuming you used your project name for the stack name, you can run the following:

```bash
aws cloudformation delete-stack --stack-name titiler_cogs
```

## Resources

See the [AWS SAM developer guide](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/what-is-sam.html) for an introduction to SAM specification, the SAM CLI, and serverless application concepts.

Next, you can use AWS Serverless Application Repository to deploy ready to use Apps that go beyond hello world samples and learn how authors developed their applications: [AWS Serverless Application Repository main page](https://aws.amazon.com/serverless/serverlessrepo/)

## data migration

```bash
# install migration script dependencies
pip install --upgrade google-auth google-auth-oauthlib google-auth-httplib2 google-api-python-client requests boto3
```

```bash
# run migration script
python layers_migration.py
```
