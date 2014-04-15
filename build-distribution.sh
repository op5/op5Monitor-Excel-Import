#!/bin/bash

BASENAME="op5Monitor-Excel-Import"

if [ "`uname -s`" = "Darwin" ]; then
	SED=`which gsed`
	if [ $? -ne 0 ]; then
		echo "Please install gnu-sed from homebrew first"
	fi
else
	SED=`which sed`
fi


# get the version string
VERSION=$(grep "use constant VERSION" op5Monitor-Excel-Import.pl | sed "s/^[^']*'//" | sed "s/'.*$//")

echo "version of the script is $VERSION"


# building the distribution tarball
ln -s . op5Monitor-Excel-Import-$VERSION

tar czf distribution/$BASENAME-$VERSION.tar.gz \
  op5Monitor-Excel-Import-$VERSION/op5Monitor-Excel-Import.pl \
  op5Monitor-Excel-Import-$VERSION/README.md \
  op5Monitor-Excel-Import-$VERSION/LICENSE \
  op5Monitor-Excel-Import-$VERSION/Hosts-Example.xlsx \
  op5Monitor-Excel-Import-$VERSION/api-scripts.config.yml \
  op5Monitor-Excel-Import-$VERSION/inc \
  op5Monitor-Excel-Import-$VERSION/op5Monitor-Excel-Import_README.pdf

rm op5Monitor-Excel-Import-$VERSION


# substitute version string in spec file
$SED -i "s/^Version:.*$/Version: $VERSION/" op5Monitor-Excel-Import.spec

# build the rpm
BUILDOUTPUT=`rpmbuild --target noarch-unknown-linux -bb op5Monitor-Excel-Import.spec 2>&1`


# find the resulting RPM file and copy it to the distribution directory
IFS='
'
for LINE in $BUILDOUTPUT; do
	echo $LINE
	if echo $LINE | grep -q "^Wrote:"; then
		RPMFILE=$(echo $LINE | sed "s/Wrote: *//")
	fi
done
unset IFS

cp $RPMFILE distribution/


# build the installer package
