#!/bin/bash

# Script to create a virtual environment for, and (re)install, a particular lalsuite branch

LALSUITE_LOCATION=${HOME}/lscsoft/lalsuite

# command lines arguments:
#   -b branchname (the git branch name) [required]
#   -n (do not install additional python packages)
#   -p python (the path to the required python version)
#   -u uninstall previous install (rather than just doing a distclean)
#   -c only re-run 'make install' with running 'make distclean' beforehand
#   -g perform 'git clean -dxf' to remove superfluous files 
#   -v (path to the virtualenvwrapper.sh script)
#   -o compile with further optimisation
#   -C perform a "make check"
#   -h (print this info)

usage="Usage $0 -b (-n -u -c -g -p -v -o -d -C --disable-lal[packagename] --disable-doxygen -h):\n\t-b\t\t\t\tbranchname (the git branch name) [required]\n\
\t-n\t\t\t\tdo not install a selection of additional python packages [optional]\n\
\t-u\t\t\t\tuninstall previous lalsuite install (rather than just doing a 'make distclean') [optional]\n\
\t-c\t\t\t\tonly re-run 'make install' without 'make distclean' beforehand [optional]\n\
\t-g\t\t\t\tperform 'git clean -dxf' to remove superfluous files (BE CAREFUL!) [optional]\n\
\t-p\t\t\t\tpython (the path to the required python executable for installing\n\t\t\t\t\tthe virtual environment) [optional]\n\
\t-v\t\t\t\tpath to the virtualenvwrapper.sh script [optional]\n\
\t-o\t\t\t\tcompile lalsuite with the -O3 optimisation [optional]\n\
\t--disable-doxygen\t\tcompile lalsuite without doxygen documentation (this is enabled by default)\n\
\t--disable-lal[packagename]\tdisable comilation of a particular LAL package (all enabled by default)\n\
\t-C\t\t\t\trun 'make check' after installation\n\
\t-h\t\t\t\thelp\n"

if [[ $# -eq 0 ]]; then
  echo -e $usage
  cd $CURDUR
  exit 0
fi

nopython=0 # by default install additional python packages
pythonexe=""
isbranch=0
vewscript=""
optimise=0
unintsall=0
gitclean=0
distclean=1
withdoc=1
withcheck=0
disablepkgs=""
thisbranch=""

# use getopt to parse command line rather than inbuilt bash getopts (https://stackoverflow.com/a/7948533/1862861)
TEMP=`getopt -o b:nucgp:v:odCh --longoptions disable-doxygen,disable-lalframe,disable-lalxml,disable-lalmetaio,disable-lalsimulation,disable-lalburst,disable-laldetchar,disable-lalinspiral,disable-lalstochastic,disable-lalpulsar,disable-lalinference -- "$@"`

if [ $? != 0 ]; then
  echo -e $usage
  exit 1
fi

# Note the quotes around `$TEMP': they are essential!
eval set -- "$TEMP"

echo $TEMP

#while getopts ":b:p:v:nougcdCh" opt; do
while true; do
  case "$1" in
    -b )
      thisbranch=$2
      shift 2
      ;;
    -p )
      pythonexe=$2
      shift 2
      ;;
    -v )
      vewscript=$2
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
      cd $CURDIR
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
  cd $CURDIR
  exit 0
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

# check if a virtualenvwrapper script is given
if [[ ! -z $vewscript ]]; then
  if [[ ! -x "$vewscript" ]]; then
    echo "$2: this virtualenvwrapper.sh script does not exist or is not executable"
    cd $CURDIR
    exit 0
  fi
fi

# check the python executable
if [[ ! -z "$pythonexe" ]]; then
  if [[ ! -x "$pythonexe" ]]; then
    echo "$2: this python executable does not exist or is not executable"
    cd $CURDIR
    exit 0
  fi
  pythonexe="-p $pythonexe"
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
  
baseenv=${HOME}/lscsoft/.virtualenvs

# use virtualenvwrapper
export WORKON_HOME=$baseenv

# check if workon function is defined (if not then source the virtualenvwrapper script
if [ ! -n "$(type -t workon)" ] || [ ! "$(type -t workon)" = function ]; then
  # see if virtualenvwrapper.sh script has been given
  if [ ! -z $vewscript ] && [ -r $vewscript ]; then
    source $vewscript
  else
    # try and find script
    venvwrapper=`which virtualenvwrapper.sh`
    if [[ $? -eq 0 ]]; then
      source $venvwrapper
    else
      # could not find a virtualenvwrapper
      echo "Could not find virtualenvwrapper.sh in your PATH"
      cd $CURDIR
      exit 0
    fi
  fi
fi

# following http://virtualenvwrapper.readthedocs.org/en/latest/scripts.html#postactivate add an extra space to command prompt between env and prompt
echo "#!/bin/bash" > $VIRTUALENVWRAPPER_HOOK_DIR/postactivate
echo 'PS1="(`basename \"$VIRTUAL_ENV\"`) $_OLD_VIRTUAL_PS1"' >> $VIRTUALENVWRAPPER_HOOK_DIR/postactivate

postmkvirtualenv=$VIRTUALENVWRAPPER_HOOK_DIR/postmkvirtualenv

if [[ $nopython -eq 0 ]]; then
  # some things to install (upgrade distribute if possible) in all virtual enviroments
  pipinstalls=("--upgrade distribute" "numpy" "scipy" "matplotlib" "shapely" "corner" "astropy" "python-crontab" "h5py" "healpy" "pandas" "scotchcorner" "sklearn")
  echo "#!/bin/bash" > $postmkvirtualenv
  for pr in "${pipinstalls[@]}"; do
    # add work around for very old pip on atlas cluster that does not have --no-cache-dir option
    if [[ $HOSTNAME == "atlas"* ]]; then
      echo "pip install $pr" >> $postmkvirtualenv
    else
      echo "pip install --no-cache-dir $pr" >> $postmkvirtualenv
    fi
  done
fi

# set path to virtual environment
ENV=$thisbranch

# components of lalsuite
lalsuite=("lal" "lalframe" "lalmetaio" "lalxml" "lalsimulation" "lalburst" "lalinspiral" "lalpulsar" "lalstochastic" "laldetchar" "lalinference" "lalapps")
lalsuitepy=("glue" "pylal")

# check if virtual environment already exists - if not create it otherwise activate it
if [[ ! -e $baseenv/$ENV/bin/activate ]]; then
  # create virtual environment
  workon # run workon
  mkvirtualenv $ENV $pythonexe

  # add postactive script to source lalsuite setup scripts
  postactivate=$VIRTUAL_ENV/bin/postactivate
  echo "#!/bin/bash" > $postactivate
  echo "export LSCSOFT_LOCATION=$VIRTUAL_ENV" >> $postactivate
  
  # store previous environment variables in string (canot use associative array as they cannot be exported!)
  echo "PREVENVS=\"\"" >> $postactivate
  echo "while IFS='=' read -r envname envvalue; do" >> $postactivate
  echo "  PREVENVS=\${PREVENVS}\"\$envname=\$envvalue;\"" >>  $postactivate
  echo "done < <(env)" >> $postactivate
  echo "PREVENVS=\${PREVENVS:0:\${#PREVENVS}-1}" >> $postactivate # remove final ; (NOTE: ${PREVENVS::-1} doesn't seem to work on bash on the RAVEN cluster!)
  echo "export PREVENVS" >> $postactivate

  # tell post activate to source lalsuiterc
  echo "if [ -r \$LSCSOFT_LOCATION/etc/lalsuiterc ]; then
  . \$LSCSOFT_LOCATION/etc/lalsuiterc
fi" >> $postactivate

  # try source python package scripts 
  for lalc in ${lalsuitepy[@]}; do
    echo "if [ -r \$LSCSOFT_LOCATION/etc/${lalc}-user-env.sh ]; then
  . \$LSCSOFT_LOCATION/etc/${lalc}-user-env.sh
fi" >> $postactivate

    # pylal has been deprecated, so in the master branch a pylal-user-env.sh file no longer exists.
    # So, if you can to use it it has to be added manually to the python path
    if [[ ${lalc} == "pylal" ]]; then
      # get python major.minor version info
      PYV=`python -c "import sys;t='{v[0]}.{v[1]}'.format(v=list(sys.version_info[:2]));sys.stdout.write(t)";`
      lenpath=$((${#PYTHONPATH}-1))
      # check whether a ":" seperator is needed
      if [[ "${PYTHONPATH:$lenpath:1}" == ":" ]]; then
        sep=""
      else
        sep=":"
      fi
      echo "if [ ! -f \$LSCSOFT_LOCATION/etc/${lalc}-user-env.sh ]; then
export PYTHONPATH=\$PYTHONPATH${sep}\$LSCSOFT_LOCATION/lib/python${PYV}/site-packages/pylal:
fi" >> $postactivate
    fi
  done
  
  # for postactivation make sure correct git repo is currently checked out
  echo "CURDIR=\$PWD" >> $postactivate
  echo "cd $LALSUITE_LOCATION" >> $postactivate
  echo "git checkout $ENV" >> $postactivate
  echo "cd \$CURDIR" >> $postactivate

  # for postdeactivation restore all previous environment variables
  postdeactivate=$VIRTUAL_ENV/bin/postdeactivate
  echo "#!/bin/bash" > $postdeactivate
  echo "prevarr=(\${PREVENVS//;/ })" >> $postdeactivate # convert into an array
  echo "while IFS='=' read -r envname envvalue; do" >> $postdeactivate
  echo "  isnew=0" >> $postdeactivate
  echo "  # this if statement is specific to the ARCCA cluster" >> $postdeactivate
  echo "  if [[ \"\${envname}\" = *\"BASH_FUNC_module\"* || \"\${envname}\" = \"}\" ]]; then" >> $postdeactivate
  echo "    continue" >> $postdeactivate
  echo "  fi" >> $postdeactivate
  echo "  if [ \"\$envname\" != \"PREVENVS\" ]; then" >> $postdeactivate
  echo "    for keypair in \${prevarr[@]}; do" >> $postdeactivate
  echo "      keypairarr=(\${keypair//=/ })" >> $postdeactivate
  echo "      key=\${keypairarr[0]}" >> $postdeactivate
  echo "      if [ \"\$envname\" = \"\$key\" ]; then" >> $postdeactivate
  echo "        export \${envname}=\"\${envvalue}\"" >> $postdeactivate # overwrite new environment variable with old one
  echo "        isnew=1" >> $postdeactivate
  echo "        break" >> $postdeactivate
  echo "      fi" >> $postdeactivate
  echo "    done" >> $postdeactivate
  echo "    if [ \$isnew -eq 0 ]; then" >> $postdeactivate
  echo "      unset \$envname" >> $postdeactivate
  echo "    fi" >> $postdeactivate
  echo "  fi" >> $postdeactivate
  echo "done < <(env)" >> $postdeactivate
  echo "unset PREVENVS" >> $postdeactivate

  #deactivate
fi

# remove any previous postmkvirtualenv (so that things do not get reinstalled on new envs if not wanted)
if [ -a $postmkvirtualenv ]; then
  > $postmkvirtualenv # empty the file
fi

# enter virtual environment
workon $ENV

#echo $ENV
#echo $LALSUITE_LOCATION

cd $LALSUITE_LOCATION

#echo $PWD
#echo $thisbranch

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
  
LSCSOFT_PREFIX=$baseenv/$ENV

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

# install python-based components of lalsuite
for lalc in ${lalsuitepy[@]}; do
  cd $lalc
  # remove stuff in build directory
  rm -rf $lalc/build
  python setup.py install --prefix=$LSCSOFT_PREFIX

  # source config scripts
  if [ -f $LSCSOFT_PREFIX/etc/${lalc}-user-env.sh ]; then
    . $LSCSOFT_PREFIX/etc/${lalc}-user-env.sh
  fi
  cd ..
done

cd $CURDIR

echo "You are in virtual environment \"$thisbranch\". Run \"deactivate\" to exit."

exit 0

