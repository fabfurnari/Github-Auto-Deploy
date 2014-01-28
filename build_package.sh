#!/bin/bash

GIT_DIST=wheezy
EXPORT_DIR=$HOME/build-area/
OTHER_GIT_OPTIONS=""
PACKAGE_NAME=$(grep Source ./debian/control | awk '{print $2}')
LOGFILE=$HOME/log/$PACKAGE_NAME-build.log
BUILD_TYPE=$1

logit () { echo "$(date): $@" >> $LOGFILE; }

logit "START"
if [[ "$BUILD_TYPE" == "stable" ]]; then
    logit "Setting incoming dir for stable releases"
    INCOMING_DIR=/srv/incoming
elif [[ "$BUILD_TYPE" == "dev" ]]; then
    logit "Setting incoming dir for development releases"
    INCOMING_DIR=/srv/devincoming
else
    logit "Unrecognizable argument"
    exit 2
fi

logit "Starting build..." 

if [ -z "$PACKAGE_NAME" ]; then
    logit "Cannot match package name, exiting ..." 
    exit 2
fi

WORKDIR=$EXPORT_DIR/$PACKAGE_NAME

if [ -d $WORKDIR ];
then
    logit "$WORKDIR existing, removing..." 
    rm -fr $WORKDIR
    mkdir $WORKDIR
fi

logit "Starting building amd64 package..." 
/usr/bin/git-buildpackage --git-arch=amd64 --git-pbuilder --git-dist=$GIT_DIST --git-export-dir=$WORKDIR 

logit "Starting building i386 package" 
/usr/bin/git-buildpackage --git-arch=i386 --git-pbuilder --git-dist=$GIT_DIST --git-export-dir=$WORKDIR 

cd $WORKDIR
CHANGES64=$(ls *amd64*changes)
CHANGES32=$(ls *i386*changes)

logit "Merging changes..." 
mergechanges -f $CHANGES32 $CHANGES64
MULTI_CHANGES=$(ls *multi*changes)
logit "Created merged changes file: $MULTI_CHANGES" 

logit "Running lintian on $MULTI_CHANGES..." 
lintian $MULTI_CHANGES 

logit "Copying files to $INCOMING_DIR..." 
cp $(cat $MULTI_CHANGES | awk '/Files:/,0' | tail -n +2 | awk '{print $5}') $INCOMING_DIR
cp $MULTI_CHANGES $INCOMING_DIR

logit "END" 
echo
 
