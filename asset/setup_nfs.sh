#!/bin/bash
#set -x
#set -e

# first input: is it "keystore" or "other"
# second input: ip of keystore
IP=$(ip route get 1 | awk '{print $NF;exit}')

install_nfs_server(){
  existed=$( dpkg -la | grep nfs-kernel-server | head -n1 | awk '{print $1;}' )
# existed=$( dpkg-query -W -f='${Status}\n' nfs-kernel-server | head -n1 | awk '{print $3;}' )
  if [ -z $existed ]; then
    echo "--- installing nfs server..."
    sudo apt-get install -y nfs-kernel-server nfs-common > /dev/null 2>&1
  fi
}

install_nfs_client(){
  existed=$( dpkg -la | grep nfs-client | head -n1 | awk '{print $1;}' )
  # existed=$ ( dpkg-query -W -f='${Status}\n' nfs-common | head -n1 | awk '{print $3;}' )
  if [ -z $existed ]; then
    echo "--- installing nfs client..."
    sudo apt-get install -y nfs-client nfs-common > /dev/null 2>&1
  fi
}

add_host_to_nfs(){
  if [ ! -f /etc/exports.bak ]; then
    sudo cp /etc/exports /etc/exports.bak
  fi
  # $1 is the ip of node
  ip_existed=$( sudo cat /etc/exports | grep ${1} | awk '{print $2}')
  if [ -z $ip_existed ]; then
    sudo printf "\n/var/log/benchmark       ${1}(rw,no_subtree_check,sync)" >> /etc/exports
  fi
}

configure_nfs_server(){
  # $1 address of the file for nfs clients IPs
  echo "--- configuring nfs server..."
  #sudo rm -R /var/log/benchmark
  sudo mkdir -m 777 -p /var/log/benchmark

  # see the results
  while read in ; do add_host_to_nfs $in; done < $1
  sudo exportfs -a > nfs_server.log 2>&1
  sudo service nfs-kernel-server restart >> nfs_server.log 2>&1
}

start_nfs(){

  if [[ $1 == "server" ]]
  then
	install_nfs_server
	configure_nfs_server ${2}
  fi
  if [[ $1 == "client" ]]
  then
    install_nfs_client
	mkdir -p -m 0777 ${3}
	dir_stat=$( stat -f -L -c %R ${3} )
	if [[ $dir_stat != "nfs" ]];then
      $( sudo mount ${2}:/var/log/benchmark ${3} )
	fi
  fi
  echo "--- NFS setup completed successfully..."
}


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
	-c|--clients)
	  shift
	  if test $# -gt 0; then
	    client=${1}
	  else
	    echo "--- No file specified!!!"
	    exit 1
	  fi
	  shift
	  ;;
	-ns|--nfs-server)
	  shift
	  if test $# -gt 0; then
	    server_ip=${1}
	  else
	    echo "--- No keystore IP is specified!!!"
		exit 1
	  fi
	  shift
	  ;;
	-nd|--nfsdir)
      shift
	  if test $# -gt 0; then
	    nfs_dir=${1}
	  else
	    echo "--- No directory is specified!!!"
		exit 1
	  fi
      shift
	  ;;
	-h|--help)
	  echo "Usage: sudo ${0} <-r ROLE> <-c PATH/TO/FILE> (-h)"
	  echo "  -r, --role	the role of node, values can be 'server' or 'client'"
	  echo "  -c, --clients	the address of a file which has the ip address of clients for NFS server"
	  echo "  -ns, --nfs-server	ip address of nfs server"
	  echo "  -nd, --nfsdir	path for the nfs directory in clients"
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

if [[ ${role} == "server" ]]; then
  start_nfs ${role} ${client}
elif [[ ${role} == "client" ]]; then
  start_nfs ${role} ${server_ip} ${nfs_dir}
fi
# EOF
