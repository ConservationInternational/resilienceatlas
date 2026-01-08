.PHONY: clean data lint requirements sync_data_to sync_data_from up inside

#################################################################################
# GLOBALS                                                                       #
#################################################################################

PROJECT_DIR := $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
PROJECT_NAME = test

# Read values as needed from .env
# If using the same variables in recipes that need to use a dotenv file other
# than .env, remember to check that no values from .env are being used
# inadvertently.
ENVFILE := $(if $(environment), .env-test-e2e, .env)
ifneq (,$(wildcard $(ENVFILE)))
    include $(ENVFILE)
    export
endif

ifeq (,$(shell which mamba))
HAS_MAMBA=False
else
HAS_MAMBA=True
endif


ifdef (,$(shell docker-compose --version))
DOCKER_CMD=docker-compose
else
DOCKER_CMD=docker compose
endif

#################################################################################
# COMMANDS                                                                      #
#################################################################################
## Initiate Docker compose and build services:
up:
	$(DOCKER_CMD) build && $(DOCKER_CMD) up test-notebooks

run-app:
	$(DOCKER_CMD) up --build app titiler

## Generate lockfile for Python dependencies:
## https://github.com/conda-incubator/conda-lock
generate-lockfile:
	rm -rf notebooks/environment.conda-lock.yaml && \
	 conda-lock --mamba -f notebooks/package.yaml --kind lock --lockfile notebooks/environment.conda-lock.yaml

## init the folder as a github repository https://kbroman.org/github_tutorial/pages/init.html
init-git:
	git init && git remote add origin git@github.com:Vizzuality/test

## init the github hooks set up https://pre-commit.com/ and test them.
init-prehooks:
	pre-commit install && pre-commit run --all-files

## autoformat your code with yapf and then lint it using flake8
lint:
	black test && flake8 test

# ## Run your code tests using tox
# test:
# 	tox
## Install Python Dependencies in your local if you dont want to use docker
requirements:
	mamba install --yes --file ./notebooks/requirements.txt

# ## Make Dataset
# data: requirements
# 	python3 src/data/make_dataset.py data/raw data/processed

## Delete all compiled Python files
clean:
	find . -type f -name "*.py[co]" -delete
	find . -type d -name "__pycache__" -delete


## S3 data sync
sync_data_to:
ifeq (,$(shell which aws))
	aws s3 sync data/ s3://$(BUCKET)/data/
else
	@echo "Not installed please https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
endif

sync_data_from:
ifeq (,$(shell which aws))
	aws s3 sync s3://$(BUCKET)/data/ data/
else
	@echo "Not installed please https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
endif



## Set up python interpreter environment
create_environment:
ifeq (True,$(HAS_MAMBA))
		@echo ">>> Detected mamba, creating mamba environment."
		mamba create --name $(PROJECT_NAME) && conda activate $(PROJECT_NAME) && \
		mamba install --yes --file ./notebooks/env.yml && \
		mamba clean --all --yes
		@echo ">>> New mamba env created. Activate with:\nsource activate $(PROJECT_NAME)"
else
	@echo "mamba is not installed. Please install it with 'conda install mamba -c conda-forge'"
endif

#################################################################################
# PROJECT RULES                                                                 #
#################################################################################



#################################################################################
# Self Documenting Commands                                                     #
#################################################################################

.DEFAULT_GOAL := help

# Inspired by <http://marmelab.com/blog/2016/02/29/auto-documented-makefile.html>
# sed script explained:
# /^##/:
# 	* save line in hold space
# 	* purge line
# 	* Loop:
# 		* append newline + line to hold space
# 		* go to next line
# 		* if line starts with doc comment, strip comment character off and loop
# 	* remove target prerequisites
# 	* append hold space (+ newline) to line
# 	* replace newline plus comments by `---`
# 	* print line
# Separate expressions are necessary because labels cannot be delimited by
# semicolon; see <http://stackoverflow.com/a/11799865/1968>
.PHONY: help
help:
	@echo "$$(tput bold)Available rules:$$(tput sgr0)"
	@echo
	@sed -n -e "/^## / { \
		h; \
		s/.*//; \
		:doc" \
		-e "H; \
		n; \
		s/^## //; \
		t doc" \
		-e "s/:.*//; \
		G; \
		s/\\n## /---/; \
		s/\\n/ /g; \
		p; \
	}" ${MAKEFILE_LIST} \
	| LC_ALL='C' sort --ignore-case \
	| awk -F '---' \
		-v ncol=$$(tput cols) \
		-v indent=19 \
		-v col_on="$$(tput setaf 6)" \
		-v col_off="$$(tput sgr0)" \
	'{ \
		printf "%s%*s%s ", col_on, -indent, $$1, col_off; \
		n = split($$2, words, " "); \
		line_length = ncol - indent; \
		for (i = 1; i <= n; i++) { \
			line_length -= length(words[i]) + 1; \
			if (line_length <= 0) { \
				line_length = ncol - indent - length(words[i]) - 1; \
				printf "\n%*s ", -indent, " "; \
			} \
			printf "%s ", words[i]; \
		} \
		printf "\n"; \
	}' \
	| more $(shell test $(shell uname) = Darwin && echo '--no-init --raw-control-chars')
