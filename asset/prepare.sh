# name: Cloudsuite benchmark in cluster
# auth: Mohammad Sahihi <msahihi1 at gwdg.de>
# vim: ts=4 syntax= bash sw=4 sts=4 sr noet

#!/bin/bash
# set -x
# set -e

server_no=$1
server_threads=$2
memory=$3
object_size=$4

network() {
network_name="caching_network"
sudo docker -H:4000 network create --opt com.docker.network.driver.mtu=1450 --driver overlay $network_name
echo -e "[+] Network created"
}
create_server () {


	echo -e "\n[+] Creating Servers\n"
	for i in $(seq 1 1 $server_no)
	do
		sudo docker -H :4000 run --name dc-server$i --hostname dc-server$i -e constraint:node!=$(hostname) --network $network_name -d cloudsuite/data-caching:server -t $server_threads -m $memory -n $object_size
		echo -e "[+] Server $i is ready"
	done

}


#                                                                       #
#               B E N C H M A R K  C L I E N T  N O D E                 #
#                                                                       #

create_client () {

      # By default docker swarm manager join as docker swarm node \
			# to host cloudsuite datacaching client container.

	echo -e "\n[+]  Creating Client\n"

	sudo docker -H :4000 run -itd --name dc-client --hostname dc-client -e constraint:node==$(hostname) -v /var/log/benchmark:/home/log --network $network_name cloudsuite/data-caching:client bash
	echo -e "[+] Client dc-client is ready\n"
	sudo docker -H :4000 exec -d dc-client bash -c 'cd /usr/src/memcached/memcached_client/ && for i in $(seq 1 1 '"$n"'); do echo -e "dc-server$i, 11211" ; done > docker_servers.txt'
	sudo docker -H :4000 exec -d dc-client bash -c 'cd /usr/src/memcached/memcached_client/ && cat docker_servers.txt'


}


load_snap_plugin(){

echo -e "[+] Loading Collector Plugin ....."
snaptel plugin load $PWD/snap/snap-plugin-processor-tag > /dev/null
echo -e "[*] Tag Processor Plugin Loaded"
snaptel plugin load $PWD/snap/snap-plugin-publisher-influxdb > /dev/null
echo -e "[*] Influxdb Publisher Plugin Loaded"
snaptel plugin load $PWD/snap/snap-plugin-collector-cloudsuite-datacaching > /dev/null
echo -e "[*] Cloudsuite-datacaching Collector Plugin Loaded\n"

}
network
create_server
create_client
load_snap_plugin