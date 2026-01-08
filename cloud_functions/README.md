# Resilience Atlas cloud functions

This repository contains the AWS Lambda functions and Google Cloud Functions used by the Resilience Atlas.

## Deployment instructions

### Google Cloud Functions

This applies to the following functions:
- analysis_histogram
- download_image
- raster_interaction

Google Cloud Functions are deployed using Terraform. The Terraform code is included `infrastructure/base` directory of this project.
Terraform will package content of each respective folder and deploy it to GCP, so be sure to:
- remove any unnecessary files (`node_modules`, etc) before deploying
- include the `privatekey.json` file in the respective folder

IAM access to Earth Engine is not yet implemented (it probably should).

### TiTiler

This applies to the following functions:
- titiler_cogs

TiTiler is deployed to infrastructure set up using the included Terraform code in the `infrastructure/titiler` directory of the project.
Actual deployment is done automatically on merge/push to git branches, through GitHub Actions (which is configured through a mix of files in the `.github` directory and the above-mentioned Terraform code).
