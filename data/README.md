test
==============================

Project Organization
------------

``` txt
├── LICENSE                       <- The LICENSE using this project.
├── README.md                     <- The top-level README for developers using this project.
├── CHANGELOG.md                  <- The top-level CHANGELOG for developers using this project.
├── env.default                   <- Environment vars definition
├── Makefile                      <- Makefile with commands
├──.pre-commit-config             <- Helps setup github basic precommit hooks
├── docker-compose.yml            <- Docker configs environment definition
├── .gitignore                    <- files don't want to copy in githubs
├── data
│   ├── processed                 <- The final, canonical data sets.
│   └── raw                       <- The original data.
|
└── notebooks                     <- Naming convention is a number (for ordering),
    │                                the creator's initials, and a short `-` delimited e.g.
    │                                `1.0-jqp-initial-data-exploration`.
    ├──.env
    ├──.dockerignore
    ├──environment.conda-lock.yaml<- Notebook env.lock that will be used to quick install dependencies
    ├──package.yaml               <- Notebooks requirements base on conda env
    ├──Dockerfile                 <- Sets up Jupyter notebooks environment
    ├──jupyter_server_config.py   <- Configure Jupyter notebooks
    ├──template_notebooks         <- where the notebooks template will live.
    │
    └──Lab                        <- Notebooks for reports/ designers /
                                     developers etc.

```

--------

## Steps for use

#### First, setup one of your environments

- With [docker]() and [docker compose]() in your system, you can develop inside containers:

``` bash
make up
```

And if you want to get into the main container:

``` bash
make inside
```

------------

- Install requirements on your machine:

``` bash
make requirements
```

- Set up a new environment in your machine

``` bash
make create_environment && make requirements
```

------------

#### Second, Init git and initialize the github pre-hooks

``` bash
make init-prehooks
```

By default this will treat your project remote branch as `git@github.com:Vizzuality/test` if you need to change it don't forget to modify the `Makefile` before running this command. Take into account that this will create a new repository under the vizzuality organization once you `git push -u origin master`

#### Happy coding and science

You can run your tests:

``` bash
make test
```

You can lint and reformat your code:

``` bash
make lint
```

or up and serve the documentation:

``` bash
make serve-doc
```

--------
<p><small>Project based on the <a target="_blank" href="https://drivendata.github.io/cookiecutter-data-science/">cookiecutter data science project template</a>. #cookiecutterdatascience</small></p>
