# LALSuite installer

This bash script will (re)install the LSC Algorithm Library suite [(LALSuite)](https://wiki.ligo.org/DASWG/LALSuite)
(a suite of software for gravitational wave data analysis). It assumes that LALSuite has been
cloned from the [git repository](https://wiki.ligo.org/DASWG/LALSuite#Git_Repository).

The install will be within a [Virtual Environment](http://virtualenv.readthedocs.org/en/latest/index.html) project,
and requires [pipenv](https://docs.pipenv.org/index.html) to be installed.

## Usage

This script will install LALSuite for a given git branch as a virtual enviroment project. The project directories
will be within a user specified location, and the virtual enviroments will by default be located in 
`${HOME}/.local/share/virtualenvs/`, but the location can also be specified by, for example, setting the
`WORKON_HOME` environment variables to the desired location (as used by
[virtualenvwrapper](http://virtualenvwrapper.readthedocs.io/en/latest/) and [pew](https://github.com/berdario/pew)).
Desipte [pipenv](https://docs.pipenv.org/index.html) being fairly shell agnositic this script assumes the use of bash.

To create a new project, for, e.g., the `master` branch of LALSuite you could run:

    virtualenv_reinstall -b master -x ${HOME}/lalsuite_projects

This will create a project directory called `master` in the directory `${HOME}/lalsuite_projects`, which contains
`Pipfile`,  `Pipfile.lock`, and `.env`. It will also create a virtual environment called `master-HASH`
where `HASH` is a randomly generated hash string. By default to virtual environment will have the following python modules
(the latest versions on pypi)
installed: `numpy`, `scipy`, `matplotlib`, `shapely`, `corner`, `astropy`, `python-crontab`, `h5py`, `healpy`, `pandas`,
`scotchcorner`, `sklearn`, and `statsmodels`. It will also configure, make and install LALSuite into that enviroment.
To enter the environment do the following:

    $ cd ${HOME}/lalsuite_projects/master
    $ pipenv shell

To exit the environment just type `exit`.