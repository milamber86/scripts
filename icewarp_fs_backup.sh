#!/bin/bash
# ----------------------------------------------------------------------
# based on mikes handy rotating-filesystem-snapshot utility
# ----------------------------------------------------------------------
# modified for linux IceWarp backups by
# beranek@icewarp.cz
# ----------------------------------------------------------------------

unset PATH	# suggestion from H. Milz: avoid accidental use of $PATH

# ------------- system commands used by this script --------------------

ID=/usr/bin/id;
ECHO=/bin/echo;

MOUNT=/bin/mount;
RM=/bin/rm;
MV=/bin/mv;
CP=/bin/cp;
TOUCH=/bin/touch;
RSYNC=/usr/bin/rsync;

# ------------- file locations and vars --------------------------------

# Backup target
SNAPSHOT_RW="/opt/icewarp/backup/mail"
mkdir -p ${SNAPSHOT_RW}
# Backup source
DATAPATH=/opt/icewarp/mail;
# How many versions of backups to keep
BCOUNT=7;

# ------------- the script itself --------------------------------------

# make sure we're running as root
if (( `$ID -u` != 0 )); then { $ECHO "Sorry, must be root.  Exiting..."; exit; } fi

# rotating snapshots of $DATAPATH

# step 1: delete the oldest snapshot, if it exists:
if [ -d $SNAPSHOT_RW/daily.${BCOUNT} ] ; then			\
$RM -rf $SNAPSHOT_RW/daily.${BCOUNT} ;  				\
fi ;

# step 2: shift the middle snapshots(s) back by one, if they exist
let BCOUNT-=1;
until [ $BCOUNT -lt 1 ]; do
		if [ -d $SNAPSHOT_RW/daily.${BCOUNT} ] ; then
		let NEXTDAY=BCOUNT+1
		$MV $SNAPSHOT_RW/daily.${BCOUNT} $SNAPSHOT_RW/daily.${NEXTDAY}
		fi
	let BCOUNT-=1
done;
# step 3: make a hard-link-only (except for dirs) copy of the latest snapshot,
# if that exists
if [ -d $SNAPSHOT_RW/daily.0 ] ; then			\
$CP -al $SNAPSHOT_RW/daily.0 $SNAPSHOT_RW/daily.1 ;	\
fi;

# step 4: rsync from the system into the latest snapshot (notice that
# rsync behaves like cp --remove-destination by default, so the destination
# is unlinked first.  If it were not so, this would copy over the other
# snapshot(s) too!
$RSYNC -va --delete ${DATAPATH}/ ${SNAPSHOT_RW}/daily.0/ ;

# step 5: update the mtime of hourly.0 to reflect the snapshot time
$TOUCH $SNAPSHOT_RW/daily.0 ;

# and thats it for $DATAPATH.
exit 0;
