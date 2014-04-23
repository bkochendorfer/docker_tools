#!/bin/bash
set -ev

GUESTNAME=$1

while read dev mnt fstype options dump fsck
do
    [ "$fstype" != "cgroup" ] && continue
    echo $options | grep -qw devices || continue
    CGROUPMNT=$mnt
done < /proc/mounts

[ "$CGROUPMNT" ] || {
    echo "Could not locate cgroup mount point."
    exit 1
}

N=$(find "$CGROUPMNT" -name "$GUESTNAME*" | wc -l)
case "$N" in
    0)
	echo "Could not find any container matching $GUESTNAME."
	exit 1
	;;
    1)
	true
	;;
    *)
	echo "Found more than one container matching $GUESTNAME."
	exit 1
	;;
esac

NSPID=$(head -n 1 $(find "$CGROUPMNT" -name "$GUESTNAME*" | head -n 1)/tasks)
[ "$NSPID" ] || {
    echo "Could not find a process inside container $GUESTNAME."
    exit 1
}

echo "ID is $NSPID"
echo "Want me to create the network namespace?"
read response
if [ response = "n" ]; then
  exit 0
fi

mkdir -p /var/run/netns
rm -f /var/run/netns/$NSPID
ln -s /proc/$NSPID/ns/net /var/run/netns/$NSPID

LOCAL_IFNAME=vethl$NSPID
GUEST_IFNAME=vethg$NSPID
ip link add name $LOCAL_IFNAME type veth peer name $GUEST_IFNAME
brctl addif br0 $LOCAL_IFNAME
ip link set $LOCAL_IFNAME up

ip link set $GUEST_IFNAME netns $NSPID
ip netns exec $NSPID ip link set $GUEST_IFNAME name eth1

