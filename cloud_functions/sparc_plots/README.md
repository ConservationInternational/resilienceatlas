# sparc_plots

Functions to facilitate access to GEE assets for usage in plotting statistics 
for SPARC.

# Setting up

To install dependencies, run:
    
    invoke install-deps

This will create the folder `libraries` with the necessary files to run the 
plugin. To add new dependencies, modify the `requirements.txt` file, and then 
re-run `invoke install-deps`.

# Deploying to AWS

To deploy the code to AWS, run:
    
    invoke deploy

To package the code for AWS without deploying, run:

    invoke package

Running `invoke package` is not necessary if you have run `invoke deploy`, as 
that function already packages the code into a zipfile. But running `invoke 
package` can be useful if you intend to upload the zipfile to AWS directly 
through the console.
