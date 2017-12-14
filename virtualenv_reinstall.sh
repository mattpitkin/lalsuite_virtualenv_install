#!/bin/bash

# Script to create a virtual environment for, and (re)install, a particular lalsuite branch
# This has been overhauled to use pew https://github.com/berdario/pew rather than virtualenvwrapper
# (following from this discussion https://gist.github.com/datagrok/2199506), so pew must be
# installed, i.e., using "sudo pip install pew" or "pip install --user pew"

LALSUITE_LOCATION=${HOME}/lscsoft/lalsuite

# command lines arguments:
#   -b branchname (the git branch name) [required]
#   -x project directory (the base directory into which the virtual env project will be added) [required]
#   -n (do not install additional python packages)
#   -p python (the path to the required python version)
#   -u uninstall previous install (rather than just doing a distclean)
#   -c only re-run 'make install' with running 'make distclean' beforehand
#   -g perform 'git clean -dxf' to remove superfluous files
#   -o compile with further optimisation
#   -C perform a "make check"
#   -h (print this info)

usage="Usage $0 -b -x (-n -u -c -g -p -v -o -d -C --disable-lal[packagename] --disable-doxygen -h):\n\t-b\t\t\t\tbranchname (the git branch name) [required]\n\
\t-x\t\t\t\tproject directory (the ) base directory into which the virtual env project will be added) [required]\n\
\t-n\t\t\t\tdo not install a selection of additional python packages [optional]\n\
\t-u\t\t\t\tuninstall previous lalsuite install (rather than just doing a 'make distclean') [optional]\n\
\t-c\t\t\t\tonly re-run 'make install' without 'make distclean' beforehand [optional]\n\
\t-g\t\t\t\tperform 'git clean -dxf' to remove superfluous files (BE CAREFUL!) [optional]\n\
\t-p\t\t\t\tpython (the path to the required python executable for installing\n\t\t\t\t\tthe virtual environment) [optional]\n\
\t-o\t\t\t\tcompile lalsuite with the -O3 optimisation [optional]\n\
\t--disable-doxygen\t\tcompile lalsuite without doxygen documentation (this is enabled by default)\n\
\t--disable-lal[packagename]\tdisable comilation of a particular LAL package (all enabled by default)\n\
\t-C\t\t\t\trun 'make check' after installation\n\
\t-h\t\t\t\thelp\n"

if [[ $# -eq 0 ]]; then
  echo -e $usage
  exit 0
fi

nopython=0 # by default install additional python packages
pythonexe=""
projdir=""
isbranch=0
optimise=0
unintsall=0
gitclean=0
distclean=1
withdoc=1
withcheck=0
disablepkgs=""
thisbranch=""

# use getopt to parse command line rather than inbuilt bash getopts (https://stackoverflow.com/a/7948533/1862861)
TEMP=`getopt -o b:x:nucgp:v:odCh --longoptions disable-doxygen,disable-lalframe,disable-lalxml,disable-lalmetaio,disable-lalsimulation,disable-lalburst,disable-laldetchar,disable-lalinspiral,disable-lalstochastic,disable-lalpulsar,disable-lalinference -- "$@"`

if [ $? != 0 ]; then
  echo -e $usage
  exit 1
fi

# Note the quotes around `$TEMP': they are essential!
eval set -- "$TEMP"

echo $TEMP

#while getopts ":b:x:p:v:nougcdCh" opt; do
while true; do
  case "$1" in
    -b )
      thisbranch=$2
      shift 2
      ;;
    -x )
      projdir=$2
      shift 2
      ;;
    -p )
      pythonexe=$2
      shift 2
      ;;
    -o )
      optimise=1
      shift
      ;;
    -n )
      nopython=1
      shift
      ;;
    -u )
      uninstall=1
      shift
      ;;
    -c )
      distclean=0 # remove distclean
      shift
      ;;
    -g )
      gitclean=1
      shift
      ;;
    --disable-doxygen )
      withdoc=0 # don't compile with doxygen documentation
      shift
      ;;
    --disable-lalframe )
      disablepkgs="$disablepkgs --disable-lalframe"
      shift
      ;;
    --disable-lalmetaio )
      disablepkgs="$disablepkgs --disable-lalmetaio"
      shift
      ;;
    --disable-lalxml )
      disablepkgs="$disablepkgs --disable-lalxml"
      shift
      ;;
    --disable-lalsimulation )
      disablepkgs="$disablepkgs --disable-lalsimulation"
      shift
      ;;
    --disable-lalburst )
      disablepkgs="$disablepkgs --disable-lalburst"
      shift
      ;;
    --disable-laldetchar )
      disablepkgs="$disablepkgs --disable-laldetchar"
      shift
      ;;
    --disable-lalinspiral )
      disablepkgs="$disablepkgs --disable-lalinspiral"
      shift
      ;;
    --disable-lalstochastic )
      disablepkgs="$disablepkgs --disable-lalstochastic"
      shift
      ;;
    --disable-lalpulsar )
      disablepkgs="$disablepkgs --disable-lalpulsar"
      shift
      ;;
    --disable-lalinference )
      disablepkgs="$disablepkgs --disable-lalinference"
      shift
      ;;
    --disable-lalapps )
      disablepkgs="$disablepkgs --disable-lalapps"
      shift
      ;;
    -C )
      withcheck=1 # run 'make check' after installation
      shift
      ;;
    -h )
      echo -e $usage
      exit 0
      ;;
    -- )
      shift
      break
      ;;
    * ) break ;;
  esac
done

if [[ -z $thisbranch ]]; then
  echo -e "No branch has been given\n"
  echo -e $usage
  exit 0
fi

if [[ -z $projdir ]]; then
  echo -e "No project directory has been given\n"
  echo -e $usage
  exit 0
fi

# check that pipenv is installed
pipenvscript=`which pipenv`
if [[ $? -ne 0 ]]; then
  # could not find a virtualenvwrapper
  echo "Could not find pipenv in your PATH. Install using 'pip install pipenv'"
  exit 1
fi

# current location
CURDIR=`pwd`

# get a list of the current git branch names
cd $LALSUITE_LOCATION

branches=$(git branch | cut -c 3-) # see http://stackoverflow.com/a/3846451/1862861

# check argument is one of the current git branches
for branch in ${branches[@]}; do
  if [[ $branch == $thisbranch ]]; then
    isbranch=1
    break
  fi
done

if [[ $isbranch -eq 0 ]]; then # check if branch is found
  echo "Specified branch \"${thisbranch}\" is not in the git repo. Use one of the following:"
  for branch in ${branches[@]}; do
    echo "  $branch"
  done
  cd $CURDIR
  exit 0
fi

# check the python executable
if [[ ! -z "$pythonexe" ]]; then
  if [[ ! -x "$pythonexe" ]]; then
    echo "$2: this python executable does not exist or is not executable"
    cd $CURDIR
    exit 0
  fi
  pythonexe="--python $pythonexe"
fi

# check if you really want to do a git clean
if [[ $gitclean -eq 1 ]]; then
  echo "Are you sure you really want to run 'git clean -dxf'? (y/n):"
  read -n 1 ynanswer
  if [ "$ynanswer" == "y" ]; then
    gitclean=1
  else
    gitclean=0
  fi
fi

pi=""
if [[ $nopython -eq 0 ]]; then
  # some things to install (upgrade distribute if possible) in all virtual enviroments
  pipinstalls=("numpy" "scipy" "matplotlib" "shapely" "corner" "astropy" "python-crontab" "h5py" "healpy" "pandas" "scotchcorner" "sklearn")

  for pr in "${pipinstalls[@]}"; do
    pi=${pi}" -i ${pr}"
  done
fi

# set path to virtual environment
ENV=$thisbranch

# create project directory
projdir=${projdir}/$ENV

# try and create project (directory) if it does not exist
if [[ ! -d $projdir ]]; then
  mkdir -p $projdir # make parent directories if required as well
  if [[ $? -ne 0 ]]; then
    echo "Could not create project directory '$projdir'"
    exit 1
  fi
fi

# move into project directory
cd $projdir

# clear the PYTHONPATH
OLDPYTHONPATH=${PYTHONPATH}
PYTHONPATH=""

# check if Pipfile already exists in the project directory, if not create the project using pipenv
pipfile=${projdir}/Pipfile
if [ ! -f $pipfile ]; then
  pipenv install $pythonexe

  # install dependencies
  if [[ $nopython -eq 0 ]]; then
    #pipinstalls=("numpy" "scipy" "matplotlib" "shapely" "corner" "astropy" "python-crontab" "h5py" "healpy" "pandas" "scotchcorner" "sklearn")
    pipinstalls=("numpy")

    for pr in "${pipinstalls[@]}"; do
      pipenv install $pr
    done
  fi
fi

# enter virtual environment
pipenv run # need to put the rest of the stuff after the run command somehow

cd $LALSUITE_LOCATION

# make sure branch is checked out
git checkout $thisbranch

if [[ $? -ne 0 ]]; then
  echo "Could not check out \"$thisbranch\". Check for problems."
  deactivate
  cd $CURDIR
  exit 0
fi

eswig="--enable-swig-python" # set enable swig python flag
empi="--enable-mpi" # set enable MPI flag
eopenmp="--enable-openmp" # set enable openmp flag
edoxygen="" # set doxygen flag

if [[ $withdoc -eq 1 ]]; then
  edoxygen="--enable-doxygen" # set doxygen flag
fi
  
LSCSOFT_PREFIX=$VIRTUAL_ENV

extracflags=""
if [[ $optimise -eq 1 ]]; then
  extracflags=-O3
fi

enableflags="--enable-mpi --enable-cfitsio"

# perform git clean to remove old/superfluous files and directories from the repository
if [[ $gitclean -eq 1 ]]; then
  git clean -dxf
fi

# install components of lalsuite
if [[ $uninstall -eq 1 ]]; then
  make uninstall
fi

if [[ $distclean -eq 1 ]]; then
  make distclean
  ./00boot
  ./configure --prefix=$LSCSOFT_PREFIX $enableflags CFLAGS=$extracflags
fi

# make and install
make install -j4

# make and install documentation
if [[ $withdoc -eq 1 ]]; then
  make install-html -j4
fi

if [[ $withcheck -eq 1 ]]; then
  make check
fi

# move back into project directory
cd $projdir

source ${LSCSOFT_PREFIX}/etc/lalsuiterc

# create environment file (.env) to source lalsuiterc
if [ ! -f ".env" ]; then
  echo "source ${LSCSOFT_PREFIX}/etc/lalsuiterc" > .env
fi

cd $CURDIR

echo "You are in virtual environment \"$thisbranch\". Type \"exit\" to exit."

exit 0
