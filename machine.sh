#!/bin/bash

# TODO add net mgmt?

set -eu

domain=swarm.tvb-ins.fr
disk_path=/home/vm-storage/swarm

mkdir -p ${disk_path}

virsh destroy swarm_base || true
virsh undefine swarm_base || true

if [[ ! -f ${disk_path}/base.qcow2 ]]
then
virt-builder \
	centos-7.7 \
	-o ${disk_path}/base.qcow2 \
	--format qcow2 \
	--root-password password:qwerty \
	--install epel-release,nfs-utils,psmisc \
	--install docker \
	--selinux-relabel \
	--firstboot-command '
systemctl disable --now firewalld
systemctl enable --now docker
sleep 1
docker pull alpine
docker pull nginx
docker pull python
shutdown -h now
'	
# virt-install \
# 	--name swarm_base \
# 	--vcpus 2 \
# 	--memory 2048 \
# 	--network default,mac=52:54:00:12:20:11,model=virtio \
# 	--disk ${disk_path}/base.qcow2 \
# 	--os-variant rhel7.7 \
# 	--import
fi

 
#	--hostname ${name}.${domain} \
# TODO make qcwo2 snapshot
hosts=$(echo h{1..3} n{1..4})

for name in $hosts
do
	img=${disk_path}/${name}.qcow2
	vmname=swarm_${name}
	virsh destroy $vmname || true
	rm -f $img
	qemu-img create -f qcow2 -b ${disk_path}/base.qcow2 $img
	virt-sysprep -a $img \
		--hostname ${name} \
		--run-command 'systemctl enable --now sshd || true' \
		--run-command "sed -i 's/enforcing/permissive/' /etc/selinux/config" \
		--ssh-inject root:file:/home/user/.ssh/id_rsa.pub > ${name}.sysprep.log &
done
wait
# 
# TODO set hostname in snapshot
# TODO virt-install w/ dhcp ip entry in virsh

function run()
{
	name=$1
	macend=$2
	img=${disk_path}/${name}.qcow2
	vmname=swarm_${name}
	virsh destroy $vmname || true
	virsh undefine $vmname || true
	net="--network network=swarm-internal,mac=52:54:00:12:20:$macend"
	if [[ $name =~ ^h[1-3]$ ]]; then
		net="--network network=swarm-external,mac=52:54:00:12:30:$macend $net"
	fi
	echo $name $net
	virt-install \
		--name $vmname \
		--vcpus 2 \
		--memory 2048 \
		$net \
		--disk $img \
		--os-variant rhel7.7 \
		--import \
		--wait 0
}

run h1 11 &
run h2 12 &
run h3 13 &
run n1 21 &
run n2 22 &
run n3 23 &
run n4 24 &
wait
