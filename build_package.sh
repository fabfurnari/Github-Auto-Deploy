#!/bin/bash

# PATHS
PIUPARTS=/usr/sbin/piuparts
MERGECHANGES=/usr/bin/mergechanges
LINTIAN=/usr/sbin/lintian
GIT_BUILDPACKAGE=/usr/bin/git-buildpackage

GIT_DIST=wheezy
EXPORT_DIR=$HOME/build-area/
OTHER_GIT_OPTIONS=""
PACKAGE_NAME=$(grep Source ./debian/control | awk '{print $2}')
LOGFILE=$HOME/log/$PACKAGE_NAME-build.log
BUILD_TYPE=$1
PIUPARTS_BASE=/home/builder/cache/piuparts-chroot
PIUPARTS_OPTIONS="-d wheezy -b $PIUPARTS_BASE "

log() 
{
  while read data
  do
      echo "[ $(date +"%D %T")] $data" >> $LOGFILE
  done
}

say () { echo "[ $(date +"%D %T")] $@" >> $LOGFILE; }

say "START"
if [[ "$BUILD_TYPE" == "stable" ]]; then
    say "Setting incoming dir for stable releases"
    INCOMING_DIR=/srv/incoming
elif [[ "$BUILD_TYPE" == "dev" ]]; then
    say "Setting incoming dir for development releases"
    INCOMING_DIR=/srv/devincoming
else
    say "No BUILD_TYPE specified, not moving to incoming dir after build"
    INCOMING_DIR=/dev/null
fi

say "Starting build..." 

if [ -z "$PACKAGE_NAME" ]; then
    say "Cannot match package name, exiting ..." 
    exit 2
fi

WORKDIR=$EXPORT_DIR/$PACKAGE_NAME

if [ -d $WORKDIR ];
then
    say "$WORKDIR existing, removing..." 
    /bin/rm -fr $WORKDIR
    /bin/mkdir $WORKDIR
fi

say "Starting building amd64 package..." 
$GIT_BUILDPACKAGE --git-arch=amd64 --git-pbuilder --git-dist=$GIT_DIST --git-export-dir=$WORKDIR | log

say "Starting building i386 package" 
$GIT_BUILDPACKAGE --git-arch=i386 --git-pbuilder --git-dist=$GIT_DIST --git-export-dir=$WORKDIR | log

cd $WORKDIR
CHANGES64=$(ls *amd64*changes)
CHANGES32=$(ls *i386*changes)

say "Merging changes..." 
$MERGECHANGES -f $CHANGES32 $CHANGES64
MULTI_CHANGES=$(ls *multi*changes)
say "Created merged changes file: $MULTI_CHANGES" 

say "Running lintian on $MULTI_CHANGES..." 
$LINTIAN $MULTI_CHANGES | log

say "Running piuparts on $MULTI_CHANGES"
$PIUPARTS $PIUPARTS_OPTIONS $MULTI_CHANGES | log

say "Copying files to $INCOMING_DIR..." 
/bin/cp -v $(cat $MULTI_CHANGES | awk '/Files:/,0' | tail -n +2 | awk '{print $5}') $INCOMING_DIR | log
/bin/cp -v $MULTI_CHANGES $INCOMING_DIR | log

say "END" 
echo
