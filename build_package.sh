#!/bin/bash

GIT_DIST=wheezy
EXPORT_DIR=$HOME/build-area/
OTHER_GIT_OPTIONS=""
PACKAGE_NAME=$(grep Source ./debian/control | awk '{print $2}')
LOGFILE=$HOME/log/$PACKAGE_NAME-build.log

if [ $1 == 'stable' ]; then
    echo "Setting incoming dir for stable releases"
    INCOMING_DIR=/srv/incoming
elif [ $1 == 'dev' ]; then
    echo "Setting incoming dir for development releases"
    INCOMING_DIR=/srv/devincoming
else
    echo "Unrecognizable argument"
    exit 2
fi

echo "********* $(date) ***********" | tee -a $LOGFILE
echo "Starting build..." | tee -a $LOGFILE

if [ -z "$PACKAGE_NAME" ]; then
    echo "Cannot match package name, exiting ..." | tee -a $LOGFILE
    exit 2
fi

WORKDIR=$EXPORT_DIR/$PACKAGE_NAME

if [ -d $WORKDIR ];
then
    echo "$WORKDIR existing, removing..." | tee -a $LOGFILE
    rm -fr $WORKDIR
    mkdir $WORKDIR
fi

echo "********* $(date) ***********" | tee -a $LOGFILE
/usr/bin/git-buildpackage --git-arch=amd64 --git-pbuilder --git-dist=$GIT_DIST --git-export-dir=$WORKDIR | tee -a $LOGFILE

echo "********* $(date) ***********" | tee -a $LOGFILE
/usr/bin/git-buildpackage --git-arch=i386 --git-pbuilder --git-dist=$GIT_DIST --git-export-dir=$WORKDIR | tee -a $LOGFILE

cd $WORKDIR
CHANGES64=$(ls *amd64*changes)
CHANGES32=$(ls *i386*changes)

echo "********* $(date) ***********" | tee -a $LOGFILE
mergechanges -f $CHANGES32 $CHANGES64
MULTI_CHANGES=$(ls *multi*changes)
echo "Created merged changes file: $MULTI_CHANGES" | tee -a $LOGFILE

echo "********* $(date) ***********" | tee -a $LOGFILE
lintian $MULTI_CHANGES | tee -a $LOGFILE

echo "********* $(date) ***********" | tee -a $LOGFILE
echo "Copying files to $INCOMING_DIR" | tee -a $LOGFILE
cp $(cat $MULTI_CHANGES | awk '/Files:/,0' | tail -n +2 | awk '{print $5}') $INCOMING_DIR
cp $MULTI_CHANGES $INCOMING_DIR

echo "********* $(date) ***********" | tee -a $LOGFILE
echo
echo 

