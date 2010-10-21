#!/bin/sh
#
# By François SIMOND for project-voodoo.org
# License GPL v3
#
# generate 4 Voodoo ramdisks
# use a standard ramdisk directory as input, and make it Voodoo!
# recommanded to wipe the destination directory first
#
# usage: generate_voodoo_ramdisk.sh stock_ramdisk voodoo_ramdisks voodoo_ramdisk_parts stages_source
#

if ! test -d "$3" || ! test -n "$2" || ! test -d "$1" ; then
	echo "please specify 3 valid directories names"
	exit 1
fi

source=$1
dest=$2
voodoo_ramdisk_parts=$3
# FIXME: fix this messy stage source stuff
stages_source=$4

my_pwd=`pwd`


# create the destination directory
mkdir $dest 2>/dev/null


# test if stage2 and at least stage3-sound exist
# FIXME: paths madness
cd lagfix/stages_builder/stages
if ! test -f stage2* || ! test -f stage3-sound*; then
	echo "\n\n # Error, please build the Voodoo lagfix stages first\n\n"
	exit 1
fi
cd - > /dev/null


# copy the ramdisk source to the voodoo ramdisk directory
cp -ax $source $dest/uncompressed
cd $dest/uncompressed

mv init init_samsung


# copy ramdisk stuff
mkdir voodoo 2>/dev/null
cp -ax $my_pwd/$voodoo_ramdisk_parts/* voodoo/


# make sure su binary (Superuser.apk) is fully suid
chmod 06755 voodoo/root/sbin/su


# empty directories, probably not in gits
mkdir dev 2>/dev/null
mkdir proc 2>/dev/null
mkdir sys 2>/dev/null
mkdir system 2>/dev/null

mkdir dev/block
mkdir dev/snd
mkdir voodoo/tmp
mkdir voodoo/root/usr


# symlink to voodoo stuff
ln -s voodoo/root/bin .
ln -s voodoo/root/usr .
# etc symlink will be used only during extraction of stages
# after that it needs to be removed
ln -s voodoo/root/etc .
ln -s ../bin/busybox bin/insmod


# create the main init symlink
ln -s voodoo/scripts/init_logger.sh init
#ln -s init_samsung init


# extract stage1 busybox
tar xf ../../../lagfix/stages_builder/stages/stage1.tar


# clean git stuff
find -name '.git*' -exec rm {} \;


# generate signatures for the stage
# because you want to be able to load them from the sdcard
for x in ../../../lagfix/stages_builder/stages/*.lzma; do
	sha1sum "$x" | cut -d' ' -f1 >> voodoo/signatures/`basename "$x" .tar.lzma`	
done


# copy the uncompressed ramdisk to the compressed before decompressing
# stage images in it
cd ..
cp -a uncompressed compressed


# do the uncompressed one
# extract stages directly
cd uncompressed
for x in ../../../lagfix/stages_builder/stages/*.lzma; do
	lzcat "$x" | tar x
	> voodoo/run/`basename "$x" .tar.lzma`_loaded
done

# remove the etc symlink wich will causes problems when we boot
# directly on samsung_init
rm etc

cd ..


# do the smallest one. this one is wickely compressed!
cp -a uncompressed compressed-smallest
cd compressed-smallest
rm voodoo/run/*
rm bin
rm init
echo '#!/bin/sh
export PATH=/bin

archive=compressed_voodoo_ramdisk.tar.lzma
lzcat $archive | tar x
rm $archive
exec /voodoo/scripts/init.sh' > init
chmod 755 init
mv voodoo/root/bin .
rm -r voodoo/voices
stage0_list="lib/ sbin/ voodoo/ res/ *.rc init_samsung modules default.prop"
find $stage0_list | tar c | lzma -9 > compressed_voodoo_ramdisk.tar.lzma
rm -r $stage0_list
cd ..



# do the compressed one
cp -a ../../lagfix/stages_builder/stages/*.lzma compressed/voodoo/
cd compressed
rm -r voodoo/voices
# important: remove the etc symlink
rm etc
cd ..

cp -a compressed compressed-stage2-only
rm compressed-stage2-only/voodoo/stage3*



echo
