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

# Using conda and `git worktree`

A cleaner/easier way than all of the above, and the method currently used in the script, is to use [conda](https://conda.io/docs/) to manage virtual
environments and the [`git worktree`](https://git-scm.com/docs/git-worktree) command to manage installations from multiple LALSuite branches.

Firstly, make sure that you do not have a `PYTHONPATH` envinoment variable set, or any `LAL*` environment variables set.
This may require cleaning out your `.bashrc`, `.bash_profile` (or other equivalent shell configuration scripts) of any place
where these variables might be getting set.

The instructions below assume you have installed miniconda and have your LALSuite repository in a directory `/home/name/repositories/lalsuite`.

**Create a new branch and worktree**

If you create a new LALSuite branch it is worth having it in a worktree. This will be a seperate directory that contains that
particular branch, and therefore allows you to have several different branches checked out at once. It also means that any
files created during installation of a particualar branch will be in a seperate directory and not get overwritten when you
build a different branch.

The command below will create a new branch of LALSuite called `my_new_branch` and add a worktree for that branch in the
directory `/home/name/repositories/lalsuite_my_new_branch`.

```bash
$ export LALSUITE_BASE=/home/name/repositories/lalsuite
$ cd /home/name/repositories/lalsuite
$ export NEW_BRANCH=my_new_branch
$ git checkout -b $NEW_BRANCH
$ git worktree add ${LALSUITE_BASE}_${NEW_BRANCH}
```

**Create an environment for the new branch**

Now use conda to create a virtual environment for installing the new branch. The command below will create an environment
(with Python 3) called `my_new_branch`.

```bash
$ cd ${LALSUITE_BASE}_${NEW_BRANCH}
$ conda create -n $NEW_BRANCH python=3
```

You should also install some things that are required/useful for LALSuite in the environment.

```bash
$ conda install -n $NEW_BRANCH pip ipython numpy scipy matplotlib h5py swig astropy
```

**Installing LALSuite**

Now you can actiavte and install LALSuite in the new environment.

```bash
$ source activate $NEW_BRANCH
$(my_new_branch) cd ${LALSUITE_BASE}_${NEW_BRANCH}
$(my_new_branch) ./00boot && ./configure --prefix=${CONDA_PREFIX} --enable-swig-python && make install -j3
```

Install `glue` and some oether requirements.

```bash
pip install lscsoft-glue
pip install shapely
```

**Removing worktrees and environments**

If you want to remove a worktree you can delete the worktree path and then prune it, e.g.

```bash
$ rm -rf ${LALSUITE_BASE}_${NEW_BRANCH}
$ cd $LALSUITE_BASE
$ git worktree prune
```

You can delete the virtual environment with

```bash
$ conda env remove -n $NEW_BRANCH
```
