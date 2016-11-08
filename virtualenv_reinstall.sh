#!/bin/bash

# Script to create a virtual environment for, and (re)install, a particular lalsuite branch

LALSUITE_LOCATION=${HOME}/lscsoft/lalsuite

# current location
CURDIR=`pwd`

# get a list of the current git branch names
cd $LALSUITE_LOCATION

branches=$(git branch | cut -c 3-) # see http://stackoverflow.com/a/3846451/1862861

# command lines arguments:
#   -b branchname (the git branch name) [required]
#   -n (do not install additional python packages)
#   -p python (the path to the required python version)
#   -u uninstall previous install (rather than just doing a distclean)
#   -c only re-run 'make install' with running 'make distclean' beforehand
#   -g perform 'git clean -dxf' to remove superfluous files 
#   -v (path to the virtualenvwrapper.sh script)
#   -o compile with further optimisation
#   -h (print this info)

usage="Usage $0 -b (-n -u -c -g -p -v -o -m -h):\n\t-b\tbranchname (the git branch name) [required]\n\
\t-n\tdo not install a selection of additional python packages [optional]\n\
\t-u\tuninstall previous lalsuite install (rather than just doing a 'make distclean') [optional]\n\
\t-c\tonly re-run 'make install' without 'make distclean' beforehand [optional]\n\
\t-g\tperform 'git clean -dxf' to remove superfluous files (BE CAREFUL!) [optional]\n\
\t-p\tpython (the path to the required python executable for installing\n\t\tthe virtual environment) [optional]\n\
\t-v\tpath to the virtualenvwrapper.sh script [optional]\n\
\t-o\tcompile lalsuite with the -O3 optimisation [optional]\n\
\t-h\thelp\n"

if [[ $# -eq 0 ]]; then
  echo -e $usage
  cd $CURDUR
  exit 0
fi

nopython=0 # by default install additional python packages
pythonexe=""
isbranch=0
vewscript="jskgkgksbdkuylfzgslf" # some gibberish
optimise=0
unintsall=0
gitclean=0
distclean=1

while getopts ":b:p:v:nougch" opt; do
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
        echo "Specified branch \"${thisbranch}\" is not in the git repo. Use one of the following:"
        for branch in ${branches[@]}; do
          echo "  $branch"
        done
        cd $CURDIR
        exit 0
      fi
      ;;
    p)
      pythonexe=$OPTARG
      if [[ ! -x "$OPTARG" ]]; then
        echo "$OPTARG: this python executable does not exist or is not executable"
        cd $CURDIR
        exit 0
      fi
      pythonexe="-p $OPTARG"
      ;;
    v)
      vewscript=$OPTARG
      if [[ ! -x "$vewscript" ]]; then
      echo "$OPTARG: this virtualenvwrapper.sh script does not exist or is not executable"
        cd $CURDIR
        exit 0
      fi
      ;;
    o)
      optimise=1
      ;;
    n)
      nopython=1
      ;;
    u)
      uninstall=1
      ;;
    c)
      distclean=0 # remove distclean
      ;;
    g)
      echo "Are you sure you really want to run 'git clean -dxf'? (y/n):"
      read -n 1 ynanswer
      if [ "$ynanswer" == "y" ]; then
        gitclean=1
      fi
      ;;
    h)
      echo -e $usage
      cd $CURDIR
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
  cd $CURDIR
  exit 0
fi
 
baseenv=${HOME}/lscsoft/.virtualenvs

# use virtualenvwrapper
export WORKON_HOME=$baseenv

# check if workon function is defined (if not then source the virtualenvwrapper script
if [ ! -n "$(type -t workon)" ] || [ ! "$(type -t workon)" = function ]; then
  # see if virtialenvwrapper.sh script has been given
  if [ -r $vewscript ]; then
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
  pipinstalls=("--upgrade distribute" "numpy" "scipy" "matplotlib" "corner" "astropy" "python-crontab" "h5py" "healpy" "pandas" "scotchcorner")
  echo "#!/bin/bash" > $postmkvirtualenv
  for pr in "${pipinstalls[@]}"; do
    # add work around for very old pip on atlas cluster that does not have --no-cache-dir option
    if [[ $HOSTNAME == "atlas"* ]]; then
      echo "pip install $pr" >> $postmkvirtualenv
    else
      echo "pip install --no-cache-dir $pr" >> $postmkvirtualenv
    fi
  done
else # remove any previous postmkvirtualenv (so that things do not get reinstalled on new envs if not wanted)
  if [ -a $postmkvirtualenv ]; then
    > $postmkvirtualenv # empty the file
  fi
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
  echo "PREVENV=${PREVENVS::-1}" >> $postactivate # remove final 
  echo "export PREVENVS" >> $postactivate

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

  # for postdeactivation restore all previous environment variables
  postdeactivate=$VIRTUAL_ENV/bin/postdeactivate
  echo "#!/bin/bash" > $postdeactivate
  echo "prevarr=(\${PREVENVS//;/ })" >> $postdeactivate # convert into an array
  echo "while IFS='=' read -r envname envvalue; do" >> $postdeactivate
  echo "  isnew=0" >> $postdeactivate
  echo "  if [ \"\$envname\" != \"PREVENVS\" ]; then" >> $postdeactivate
  echo "    for keypair in \${prevarr[@]}; do" >> $postdeactivate
  echo "      keypairarr=(\${keypair//=/ })" >> $postdeactivate
  echo "      key=\${keypairarr[0]}" >> $postdeactivate
  echo "      keyval=\${keypairarr[1]}" >> $postdeactivate
  echo "      # first two parts of this if...elif block are specific to the ARCCA cluster" >> $postdeactivate
  echo "      if [[ "\$key" == *\"BASH_FUNC_module\"* ]]; then" >> $postdeactivate
  echo "        isnew=1" >> $postdeactivate
  echo "        break" >> $postdeactivate
  echo "      elif [[ -z \"\${keyval// }\" ]]; then" >> $postdeactivate
  echo "        isnew=1" >> $postdeactivate
  echo "        break" >> $postdeactivate
  echo "      elif [ \"\$envname\" = \"\$key\" ]; then" >> $postdeactivate
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
  cd $CURDIR
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

extracflags=""
if [[ $optimise -eq 1 ]]; then
  extracflags=-O3
fi

# perform git clean to remove old/superfluous files and directories from the repository
if [[ $gitclean -eq 1 ]]; then
  git clean -dxf
fi

# install components of lalsuite
for lalc in ${lalsuite[@]}; do
  cd $lalc

  if [[ $uninstall -eq 1 ]]; then
    make uninstall
  fi

  if [[ $distclean -eq 1 ]]; then
    make distclean
    ./00boot
    ./configure --prefix=${lalsuiteprefixes["$lalc"]} ${lalsuiteflags["$lalc"]} CFLAGS=$extracflags
  fi

  make install -j4

  # source config scripts
  if [ -f ${lalsuiteprefixes["$lalc"]}/etc/${lalc}-user-env.sh ]; then
    . ${lalsuiteprefixes["$lalc"]}/etc/${lalc}-user-env.sh
  fi
  cd ..
done

# install python-based components of lalsuite
for lalc in ${lalsuitepy[@]}; do
  cd $lalc
  # remove stuff in build directory
  rm -rf $lalc/build
  python setup.py install --prefix=${lalsuiteprefixes["$lalc"]}

  # source config scripts
  if [ -f ${lalsuiteprefixes["$lalc"]}/etc/${lalc}-user-env.sh ]; then
    . ${lalsuiteprefixes["$lalc"]}/etc/${lalc}-user-env.sh
  fi
  cd ..
done

cd $CURDIR

echo "You are in virtual environment \"$thisbranch\". Run \"deactivate\" to exit."

exit 0

