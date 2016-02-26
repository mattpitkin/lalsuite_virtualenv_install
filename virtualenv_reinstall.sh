#!/bin/bash

# Script to create a virtual environment for, and (re)install, a particular lalsuite branch

LALSUITE_LOCATION=${HOME}/lscsoft/lalsuite

# get a list of the current git branch names
cd $LALSUITE_LOCATION

branches=$(git branch | cut -c 3-) # see http://stackoverflow.com/a/3846451/1862861

# command lines arguments:
#   -b branchname (the git branch name) [required]
#   -n (do not install additional python packages)
#   -p python (the path to the required python version
#   -h (print this info)

usage="Usage $0 -b (-n -p -m -h):\n\t-b\tbranchname (the git branch name) [required]\n\
\t-n\tdo not install a selection of additional python packages [optional]\n\
\t-p\tpython (the path to the required python executable for installing\n\t\tthe virtual environment) [optional]\n\
\t-m\tbasemap (install libgeos and basemap directly) [optional]\n\
\t-h\thelp\n"

if [[ $# -eq 0 ]]; then
  echo -e $usage
  exit 0
fi

nopython=0 # by default install additional python packages
pythonexe=""
isbranch=0
basemap=0

while getopts ":b:p:nh" opt; do
  case $opt in
    b)
      thisbranch=$OPTARG
      # check argument is one of the current git branches
      for branch in ${branches[@]}; do
        if [[ $branch == $thisbranch ]]; then
          isbranch=1
          break
        fi
      done

      if [[ $isbranch -eq 0 ]]; then # check if branch is found
        echo "Specifed branch \"${thisbranch}\" is not in the git repo. Use one of the following:"
        for branch in ${branches[@]}; do
          echo "  $branch"
        done
        cd ..
        exit 0
      fi
      ;;
    p)
      pythonexe=$OPTARG
      if [[ ! -x "$OPTARG" ]]; then
        echo "$OPTARG: this python exectuable does not exist or is not executable"
        exit 0
      fi
      pythonexe="-p $OPTARG"
      ;;
    n)
      nopython=1
      ;;
    m)
      basemap=1
      ;;
    h)
      echo -e $usage
      exit 0
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
  esac
done

if [[ $isbranch -eq 0 ]]; then
  echo -e "No branch has been given\n"
  echo -e $usage
  exit 0
fi
  
baseenv=${HOME}/lscsoft/.virtualenvs

# use virtualenvwrapper
export WORKON_HOME=$baseenv

# check if virtualenvwrapper.sh hasn't already been sourced
if [[ -z "$VIRTUALENVWRAPPER_SCRIPT" ]]; then
  # try and find script
  venvwrapper=`which virtualenvwrapper.sh`
  if [[ $? -eq 0 ]]; then
    source $venvwrapper
  else
    # could not find a virtualenvwrapper
    echo "Could not find virtualenvwrapper.sh in your PATH"
    exit 0
  fi
fi

# following http://virtualenvwrapper.readthedocs.org/en/latest/scripts.html#postactivate add an extra space to command prompt between env and prompt
echo "#!/bin/bash" > $VIRTUALENVWRAPPER_HOOK_DIR/postactivate
echo 'PS1="(`basename \"$VIRTUAL_ENV\"`) $_OLD_VIRTUAL_PS1"' >> $VIRTUALENVWRAPPER_HOOK_DIR/postactivate

if [[ $nopython -eq 0 ]]; then
  # some things to install (upgrade distribute if possible) in all virtual enviroments
  pipinstalls=("--upgrade distribute" "numpy" "scipy" "matplotlib" "corner" "astropy" "python-crontab" "healpy" "scotchcorner")
  postmkvirtualenv=$VIRTUALENVWRAPPER_HOOK_DIR/postmkvirtualenv
  echo "#!/bin/bash" > $postmkvirtualenv
  for pr in "${pipinstalls[@]}"; do
    echo "pip install $pr" >> $postmkvirtualenv
  done
  
  if [[ $basemap -eq 1 ]]; then
  # for matplotlib 1.5.1 there are problems with basemap, so here's a work around for installing it
  # install libgeos (see http://stackoverflow.com/questions/29333431/importerror-when-importing-basemap):
  #   for Ubuntu/Debian run e.g.:
  #     >> sudo apt-get install libgeos-3.4.2 libgeos-dev
  #   otherwise download and install libgeos e.g.:
  #     >> wget http://download.osgeo.org/geos/geos-3.5.0.tar.bz2
    echo "# install libgeos and basemap" >> $postmkvirtualenv
    echo "mkdir $VIRTUAL_ENV/opt" >> $postmkvirtualenv
    echo "CURDIR=`pwd`" >> $postmkvirtualenv 
    echo "cd $VIRTUAL_ENV/opt" >> $postmkvirtualenv
    echo "wget http://download.osgeo.org/geos/geos-3.5.0.tar.bz2" >> $postmkvirtualenv
  #     >> tar xvjf geos-3.5.0.tar.bz2
    echo "tar xvjf geos-3.5.0.tar.bz2" >> $postmkvirtualenv
  #     >> cd geos-3.5.0
    echo "cd geos-3.5.0"
  #     >> ./configure --prefix=$VIRTUAL_ENV --enable-python
    echo "./configure --prefix=$VIRTUAL_ENV --enable-python" >> $postmkvirtualenv
  #     >> make; make install
    echo "make; make install" >> $postmkvirtualenv
  #     >> export GEOS_DIR=$VIRTUAL_ENV
    echo "export GEOS_DIR=$VIRTUAL_ENV" >> $postmkvirtualenv
  # Now install basemap directly from the matplotlib github page
  #     >> pip install https://github.com/matplotlib/basemap/archive/master.zip
    echo "pip install https://github.com/matplotlib/basemap/archive/master.zip" >> $postmkvirtualenv
    echo "cd $CURDIR" >> $postmkvirtualenv
fi

# set path to virtual environment
ENV=$thisbranch

# components of lalsuite
lalsuite=("lal" "lalframe" "lalmetaio" "lalxml" "lalsimulation" "lalburst" "lalinspiral" "lalpulsar" "lalstochastic" "laldetchar" "lalinference" "lalapps")

lalsuitepy=("glue" "pylal")

# check if virtual enviroment already exists - if not create it otherwise activate it
if [[ ! -e $baseenv/$ENV/bin/activate ]]; then
  # create virtual environment
  workon # run workon
  mkvirtualenv $ENV $pythonexe

  # add postactive script to source lalsuite setup scripts
  postactivate=$VIRTUAL_ENV/bin/postactivate
  echo "#!/bin/bash
export LSCSOFT_LOCATION=$VIRTUAL_ENV" > $postactivate
  for lalc in ${lalsuite[@]} ${lalsuitepy[@]}; do
    echo "if [ -r \$LSCSOFT_LOCATION/etc/${lalc}-user-env.sh ]; then
  . \$LSCSOFT_LOCATION/etc/${lalc}-user-env.sh
fi" >> $postactivate
  done

  # for postactivation make sure correct git repo is currently checked out
  echo "CURDIR=\$PWD" >> $postactivate
  echo "cd $LALSUITE_LOCATION" >> $postactivate
  echo "git checkout $ENV" >> $postactivate
  echo "cd \$CURDIR" >> $postactivate

  deactivate
fi

# enter virtual environment
workon $ENV

cd $LALSUITE_LOCATION

# make sure branch is checked out
git checkout $thisbranch

if [[ $? -ne 0 ]]; then
  echo "Could not check out \"$thisbranch\". Check for problems."
  deactivate
  exit 0
fi

eswig="--enable-swig-python" # set enable swig python flag
empi="--enable-mpi" # set enable MPI flag
eopenmp="--enable-openmp" # set enable openmp flag

# set the flags and prefix for each part of lalsuite
declare -A lalsuiteflags=(["lal"]="$eswig" \
                          ["lalframe"]="$eswig" \
                          ["lalmetaio"]="$eswig" \
                          ["lalxml"]="$eswig" \
                          ["lalsimulation"]="$eswig" \
                          ["lalburst"]="$eswig" \
                          ["lalinspiral"]="$eswig" \
                          ["lalpulsar"]="$eswig --enable-lalxml" \
                          ["lalstochastic"]="$eswig" \
                          ["laldetchar"]="$eswig" \
                          ["lalinference"]="$eswig $eopenmp" \
                          ["lalapps"]="--enable-lalxml $empi $eopenmp" \
                          ["glue"]="" \
                          ["pylal"]="")

LSCSOFT_PREFIX=$baseenv/$ENV

declare -A lalsuiteprefixes=(["lal"]="$LSCSOFT_PREFIX" \
                             ["lalframe"]="$LSCSOFT_PREFIX" \
                             ["lalmetaio"]="$LSCSOFT_PREFIX" \
                             ["lalxml"]="$LSCSOFT_PREFIX" \
                             ["lalsimulation"]="$LSCSOFT_PREFIX" \
                             ["lalburst"]="$LSCSOFT_PREFIX" \
                             ["lalinspiral"]="$LSCSOFT_PREFIX" \
                             ["lalpulsar"]="$LSCSOFT_PREFIX" \
                             ["lalstochastic"]="$LSCSOFT_PREFIX" \
                             ["laldetchar"]="$LSCSOFT_PREFIX" \
                             ["lalinference"]="$LSCSOFT_PREFIX" \
                             ["lalapps"]="$LSCSOFT_PREFIX" \
                             ["glue"]="$LSCSOFT_PREFIX" \
                             ["pylal"]="$LSCSOFT_PREFIX")

# install components of lalsuite
for lalc in ${lalsuite[@]}; do
  cd $lalc
  make distclean
  ./00boot
  ./configure --prefix=${lalsuiteprefixes["$lalc"]} ${lalsuiteflags["$lalc"]}
  make install -j4

  # source config scripts
  . ${lalsuiteprefixes["$lalc"]}/etc/${lalc}-user-env.sh
  cd ..
done

# install python-based components of lalsuite
for lalc in ${lalsuitepy[@]}; do
  cd $lalc
  python setup.py install --prefix=${lalsuiteprefixes["$lalc"]}

  # source config scripts
  . ${lalsuiteprefixes["$lalc"]}/etc/${lalc}-user-env.sh
  cd ..
done

cd ..

echo "You are in vitual environment \"$thisbranch\". Run \"deactivate\" to exit."

exit 0

