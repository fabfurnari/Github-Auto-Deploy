#!/bin/bash

GIT_DIST=wheezy
EXPORT_DIR=$HOME/build-area/
OTHER_GIT_OPTIONS=""
PACKAGE_NAME=$(grep Source ./debian/control | awk '{print $2}')
LOGFILE=$HOME/log/$PACKAGE_NAME-build.log
BUILD_TYPE=$1

log() 
{
  while read data
  do
      echo "[ $(date +"%D %T")] $data" >> $LOGFILE
  done
}

say () { echo "$(date): $@" >> $LOGFILE; }

say "START"
if [[ "$BUILD_TYPE" == "stable" ]]; then
    say "Setting incoming dir for stable releases"
    INCOMING_DIR=/srv/incoming
elif [[ "$BUILD_TYPE" == "dev" ]]; then
    say "Setting incoming dir for development releases"
    INCOMING_DIR=/srv/devincoming
else
    say "Unrecognizable argument"
    exit 2
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
    rm -fr $WORKDIR
    mkdir $WORKDIR
fi

say "Starting building amd64 package..." 
/usr/bin/git-buildpackage --git-arch=amd64 --git-pbuilder --git-dist=$GIT_DIST --git-export-dir=$WORKDIR | log

say "Starting building i386 package" 
/usr/bin/git-buildpackage --git-arch=i386 --git-pbuilder --git-dist=$GIT_DIST --git-export-dir=$WORKDIR | log

cd $WORKDIR
CHANGES64=$(ls *amd64*changes)
CHANGES32=$(ls *i386*changes)

say "Merging changes..." 
mergechanges -f $CHANGES32 $CHANGES64
MULTI_CHANGES=$(ls *multi*changes)
say "Created merged changes file: $MULTI_CHANGES" 

say "Running lintian on $MULTI_CHANGES..." 
lintian $MULTI_CHANGES | log

say "Copying files to $INCOMING_DIR..." 
cp -v $(cat $MULTI_CHANGES | awk '/Files:/,0' | tail -n +2 | awk '{print $5}') $INCOMING_DIR | log
cp -v $MULTI_CHANGES $INCOMING_DIR | log

say "END" 
echo
