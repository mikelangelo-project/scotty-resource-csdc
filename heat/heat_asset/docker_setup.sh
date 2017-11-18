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

host_ip=$(sudo /sbin/ifconfig eth0| grep 'inet addr:' | cut -d: -f2 | awk '{print $1}')


#                                                                       #
#                D O C K E R   C O N F I G U R A T I O N                #
#                                                                       #

docker_config () {

echo -e "[+] Setting up $role"
if [[ $role == "keystore" ]]; then
  sudo service docker restart
  sudo docker stop consul
  sudo docker rm -f consul
  sudo docker rmi $(sudo docker images -q)
  sudo docker run -d -p 8500:8500 --name=consul progrium/consul -server -bootstrap
fi

if [[ $role != "keystore" ]]; then
export $CONSUL_HOST_IP=$keyValue
sudo bash -c 'cat >> /etc/default/docker <<EOL
DOCKER_OPTS="-H unix:///var/run/docker.sock -H tcp://0.0.0.0:2375 \
                --cluster-store consul:/$CONSUL_HOST_IP:8500 \
                --cluster-advertise eth0:2375"
EOL'
sudo service docker restart
sleep 5
fi

if [[ $role != "keystore" ]]; then
ps=$(sudo docker ps --filter "name=$role" -a -q)
ru=$(sudo docker ps --filter "name=$role" -q)
fi

if [ -n "$ps" ]
then
  echo -e "[+] Stopping & Removing Previous containers\n"
  sudo docker rm -f $ps > /dev/null
  echo -e "---> containers removed"
fi

if [[ $role == "manager" ]]; then
sudo docker run -d -p 22222:2375 --name swarm_$role  swarm manage consul://$CONSUL_HOST_IP:8500 &&
echo -e "[+] Swarm manager is ready"
fi
## if you want that manager takes role as a member in cluster change role to !=keystore
if [[ $role = "client" ]]; then
sudo docker run -d --name swarm_$role_node swarm join --advertise=${host_ip}:2375 consul://$CONSUL_HOST_IP:8500 &&
echo -e "[+] $HOST joined as node"
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
	-h|--help)
	  echo "Usage: sudo ${0} <-r ROLE> <-c PATH/TO/FILE>"
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
docker_config $role $keyValue
echo "Docker setup completed successfully."

# EOF
