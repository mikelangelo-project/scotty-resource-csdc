#!/bin/bash
#set -x
#set -e

#                                                                       #
#                    I N S T A L L I N G   S N A P                      #
#
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

