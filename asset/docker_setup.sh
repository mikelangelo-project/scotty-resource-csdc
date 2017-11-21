#!/bin/bash
#set -x
#set -e

#                                                                       #
#                I N S T A L L I N G   D O C K E R                      #
#                                                                       #

docker_install () {

if which docker >/dev/null; then
  echo -e "[+] Docker is already installed"
else
  echo -e "[+] Installing Docker ....."
  curl -sSL https://get.docker.com/ | sh
  sudo usermod -aG docker $(whoami)
  sudo service docker stop
fi

}

#                                                                       #
#     R E M O V E   P R E V I O U S   D O C K E R   S E R V I C E       #
#                                                                       #

docker_daemon=$(sudo netstat -tulpn | grep dockerd | wc -l)
docker_service=$(sudo service docker status | cut -d' ' -f2)
host_ip=$(sudo /sbin/ifconfig eth0| grep 'inet addr:' | cut -d: -f2 | awk '{print $1}')

service_check (){
if  test "${docker_service#*"running"}" != ${docker_service}
	then
		sudo service docker stop
		sleep 2
  else
		if [ -f /var/lock/docker.pid ]; then
			sudo rm /var/lock/docker.pid
		fi
fi

if [ -n ${docker_daemon} ];
	then
		sudo pkill dockerd
		sleep 2
		if [ -f /var/lock/docker.pid ]; then

		sudo rm /var/lock/docker.pid
		fi
fi
}

#                                                                       #
#                D O C K E R   C O N F I G U R A T I O N                #
#                                                                       #

docker_config () {

echo -e "[+] Setting up ${role}"
if [[ ${role} == "keystore" ]]; then
  sudo dockerd -H tcp://0.0.0.0:2375 -H unix:///var/run/docker.sock &
  sleep 2
  sudo docker stop consul
  sudo docker rm -f consul
  sudo docker rmi $(sudo docker images -q)
  sudo docker run -d -p 8500:8500 --name=consul progrium/consul -server -bootstrap
fi

if [[ ${role} != "keystore" ]]; then
sudo dockerd -H tcp://0.0.0.0:2375 -H unix:///var/run/docker.sock --cluster-store=consul://${keyValue}:8500  --cluster-advertise=${host_ip}:2376 &
sleep 5
fi

if [[ ${role} != "keystore" ]]; then
ps=$(sudo docker ps --filter "name=${role}" -a -q)
ru=$(sudo docker ps --filter "name=${role}" -q)
fi

if [ -n "$ps" ]
then
  echo -e "[+] Stopping & Removing Previous containers\n"
  sudo docker rm -f $ps > /dev/null
  echo -e "---> containers removed"
fi

if [[ ${role} == "manager" ]]; then
  sudo docker run -d --name swarm_${role} -p 4000:4000 swarm manage -H :4000 --replication --advertise ${host_ip}:4000 consul://${keyValue}:8500 > /dev/null &&
echo -e "[+] Swarm manager is ready"
fi
## if you want that manager take role as a member in cluster make roll to !=keystore
if [[ ${role} != "keystore" ]]; then
sudo docker run -d --name swarm_${role}_node swarm join --advertise=${host_ip}:2375 consul://${keyValue}:8500 > /dev/null &&
echo -e "[+] $HOST joined as node"
fi
}

#                                                                       #
#                    I N S T A L L I N G   S N A P                      #
#                                                                       #

snap_check () {

if which snaptel >/dev/null; then
  echo -e "[+] SNAP is already installed"
else
  echo -e "[+] Installing GO ....."
  echo $PWD
  echo $PWD | ls
  sudo chmod 700 $PWD/asset/goinstall.sh
  bash $PWD/asset/goinstall.sh --64
  echo -e "[+] GO installed ....."

  echo -e "[+] Installing SNAP ....."
  sudo curl -s https://packagecloud.io/install/repositories/intelsdi-x/snap/script.deb.sh | sudo bash
  sudo apt-get install -y snap-telemetry
  echo -e "[+] SNAP installed ....."
  sudo service snap-telemetry start && echo -e "[+] SNAP service is runing"
fi

}

prepare_env() {

echo -e "[+] Preparing Environment"

# if [[ ${role} == "client" ]]; then
#	 sudo bash asset/setup_nfs.sh -r client -ns ${nfs_srv} -nd /var/log/benchmark
# fi

if [[ ${role} == "manager" ]]; then
#	sudo bash asset/setup_nfs.sh -r server -c asset/clients.txt
	mkdir -p /var/log/benchmark
  sudo chmod 777 /var/log/benchmark/
  echo -e "0,0,0,0,0,0,0,0,0,0,0,0,0,0,0\n" >> /var/log/benchmark/detail.csv
	snap_check

fi
}

#                                                                       #
#                      D I S P L A Y   U S A G E                        #
#                                                                       #

while test $# -gt 0; do
  case $1 in
    -r|--role)
	  shift
	  if test $# -gt 0; then
	    role=${1}
	  else
	    echo "--- No role specified!!!"
	    exit 1
	  fi
	  shift
	  ;;
	-k|--keystore)
	  shift
	  if test $# -gt 0; then
	    keyValue=${1}
	  else
	    echo "--- No keystore IP is specified!!!"
		exit 1
	  fi
	  shift
	  ;;
    -n|--nfs-server)
      shift
      if test $# -gt 0; then
        nfs_srv=${1}
      else
        echo "--- No keystore IP is specified!!!"
      exit 1
      fi
      shift
      ;;
	-h|--help)
	  echo "Usage: sudo ${0} <-r ROLE> <-c PATH/TO/FILE> <-n NFS Server>(-h)"
	  echo "  -r, --role	the role of node, values can be 'keystore' or 'other'"
	  echo "  -k, --keystore	ip address of keystore server"
	  echo "  -h, --help	show usage"
	  exit 0
	  ;;
    \?)
      echo "--- Invalid option"
      ;;
     *)
      break
      ;;
  esac
done

docker_install
service_check
docker_config ${role} ${keyValue}
#prepare_env ${nfs_srv}
prepare_env
echo "Setup Completed Successfully."

# EOF
