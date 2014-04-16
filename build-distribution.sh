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
VERSION=$(grep "use constant VERSION" $BASENAME.pl | sed "s/^[^']*'//" | sed "s/'.*$//")

echo "version of the program to pack is $VERSION"


# building the distribution tarball
echo "building the distribution tarball"

ln -s . $BASENAME-$VERSION

tar czf distribution/$BASENAME-$VERSION.tar.gz \
  $BASENAME-$VERSION/$BASENAME.pl \
  $BASENAME-$VERSION/README.md \
  $BASENAME-$VERSION/LICENSE \
  $BASENAME-$VERSION/DEPENDENCIES \
  $BASENAME-$VERSION/Hosts-Example.xlsx \
  $BASENAME-$VERSION/api-scripts.config.yml \
  $BASENAME-$VERSION/inc \
  $BASENAME-$VERSION/${BASENAME}_README.pdf

rm $BASENAME-$VERSION


# substitute version string in spec file
echo "building rpm file for $BASENAME-$VERSION"
$SED -i "s/^Version:.*$/Version: $VERSION/" $BASENAME.spec

# build the rpm
BUILDOUTPUT=`rpmbuild --target noarch-unknown-linux -bb $BASENAME.spec 2>&1`


# find the resulting RPM file and copy it to the distribution directory
RPMFILE=""
IFS='
'
for LINE in $BUILDOUTPUT; do
	if echo $LINE | grep -q "^Wrote:"; then
		RPMFILE=$(echo $LINE | sed "s/Wrote: *//")
	fi
done
unset IFS

if [ "$RPMFILE" = "" ]; then
	echo "Error building RPM file, aborting!"
	exit 254
fi
echo "rpm file is $RPMFILE"

cp $RPMFILE distribution/


# build the installer package
echo "building the installer package"
rm -rf tmp/*
cp -r deps tmp/
cp $RPMFILE tmp/
cat >tmp/install.sh <<EEOF
#!/bin/bash
CURRENTDIR=\`pwd\`
cp /etc/yum.conf local-yum.conf
echo "[op5-excel-import]" >>local-yum.conf
echo "name=op5 Excel Import" >>local-yum.conf
echo "gpgcheck=0" >>local-yum.conf
echo "enabled=1" >>local-yum.conf
echo "baseurl=file://\${CURRENTDIR}/deps" >>local-yum.conf
if rpm --quiet -q op5Monitor-Excel-Import; then
	echo "doing an UPGRADE"
	yum -c local-yum.conf --enablerepo="op5-excel-import" localupdate op5Monitor-Excel-Import-*.rpm
else
	echo "doing an INSTALLATION"
	yum -c local-yum.conf --enablerepo="op5-excel-import" localinstall op5Monitor-Excel-Import-*.rpm
fi
EEOF
chmod 755 tmp/install.sh

cd tmp
ln -s . $BASENAME-$VERSION-installer
tar czf ../distribution/$BASENAME-$VERSION-installer.tar.gz \
	$BASENAME-$VERSION-installer/deps \
	$BASENAME-$VERSION-installer/*.rpm \
	$BASENAME-$VERSION-installer/install.sh 
rm $BASENAME-$VERSION-installer
cd ..
rm -rf tmp/*

# summary
echo "resulting files:"
ls -l distribution/*$VERSION*

