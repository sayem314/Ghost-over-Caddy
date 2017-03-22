#!/bin/bash
#
# Use this automated bash script to install Ghost blog on Ubuntu, Debian or CentOS,
# with Caddy Web Server (as a reverse proxy).
#
# DO NOT RUN THIS SCRIPT ON YOUR PC OR MAC!
#
# Copyright (C) 2017 Sayem314
# Based on the work of Lin Song
#
# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
# PARTICULAR PURPOSE. See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# this program. If not, see http://www.gnu.org/licenses/.

version='1.0 beta (22 Mar 2017)'

max_blogs=10

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

echoerr() { echo "Error: $1" >&2; }

os_type="$(lsb_release -si 2>/dev/null)"
os_ver="$(lsb_release -sr 2>/dev/null)"
if [ -z "$os_type" ] && [ -f "/etc/lsb-release" ]; then
  os_type="$(. /etc/lsb-release && echo "$DISTRIB_ID")"
  os_ver="$(. /etc/lsb-release && echo "$DISTRIB_RELEASE")"
fi
if [ "$os_type" = "Ubuntu" ]; then
  if [ "$os_ver" != "16.04" ] && [ "$os_ver" != "14.04" ] && [ "$os_ver" != "12.04" ]; then
    echoerr "This script only supports Ubuntu 16.04/14.04/12.04."
    exit 1
  fi
elif [ "$os_type" = "Debian" ]; then
  os_ver="$(sed 's/\..*//' /etc/debian_version 2>/dev/null)"
  if [ "$os_ver" != "8" ]; then
    echoerr "This script only supports Debian 8 (Jessie)."
    exit 1
  fi
else
  if [ ! -f /etc/redhat-release ]; then
    echoerr "This script only supports Ubuntu, Debian and CentOS."
    exit 1
  elif ! grep -qs -e "release 6" -e "release 7" /etc/redhat-release; then
    echoerr "This script only supports CentOS 6 and 7."
    exit 1
  else
    os_type="CentOS"
  fi
fi

if [ "$(id -u)" != 0 ]; then
  echoerr "Script must be run as root. Try 'sudo bash $0'"
  exit 1
fi

phymem="$(free -m | awk '/^Mem:/{print $2}')"
[ -z "$phymem" ] && phymem=0
if [ "$phymem" -lt 470 ]; then
  echoerr "A minimum of 512 MB RAM is required for Ghost blog install."
  exit 1
fi

FQDN_REGEX='^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$'
if ! printf %s "$1" | grep -Eq "$FQDN_REGEX"; then
  echo ""
  echoerr "Invalid parameter. You must enter a fully qualified domain name (FQDN)."
  echo ""
  exit 1
fi

if id -u "ghost$max_blogs" >/dev/null 2>&1; then
  echoerr "Maximum number of Ghost blogs ($max_blogs) reached."
  exit 1
fi

ghost_num=1
ghost_user=ghost
ghost_port=2368
if id -u ghost >/dev/null 2>&1; then
  echo 'It looks like this server already has Ghost blog installed! '
  if [ -d "/var/caddywww/$1" ]; then
    echo
    echo "To install additional blogs, you must use a new full domain name."
    exit 1
  fi
  
  for count in $(seq 2 $max_blogs); do
    if ! id -u "ghost$count" >/dev/null 2>&1; then
      ghost_num="$count"
      ghost_user="ghost$count"
      let ghost_port=$ghost_port+$count
      let ghost_port=$ghost_port-1
      break
    fi
  done
  
  echo
  read -r -p "Install another Ghost blog on this server? [y/N] " response
  case $response in
    [yY][eE][sS]|[yY])
      echo
      ;;
    *)
      echo "Aborting."
      exit 1
      ;;
  esac
  
  phymem_req=250
  let phymem_req1=$phymem_req*$ghost_num
  let phymem_req2=$phymem_req*$ghost_num*1000
  
  if [ "$phymem" -lt "$phymem_req2" ]; then
    echo "This server might not have enough RAM to install another Ghost blog."
    echo "It is estimated that at least $phymem_req1 MB total RAM is required."
    echo
    echo 'WARNING! If you continue, the install could fail and your blog will NOT work!'
    echo
    read -r -p "Do you REALLY want to continue (at your own risk)? [y/N] " response
    case $response in
      [yY][eE][sS]|[yY])
        echo
        ;;
      *)
        echo "Aborting."
        exit 1
        ;;
    esac
    
  fi
fi

  # Get email for caddyfile
  echo ""
  echo "  Enter your email for automated ssl"
  read -p "  Email: " domainmail
  until [[ "$domainmail" == *@*.* || "$domainmail" == off ]]; do
    echo ""
    echo "  Invalid email"
    read -p "  Email: " domainmail
  done

clear

cat <<EOF
Welcome! This script will install the latest v0.11-LTS version of Ghost blog
on your server, with Caddy (as a reverse proxy).

The full domain name for your new blog is:

 $(tput setaf 2)$1$(tput sgr0)

Please double check. This MUST be correct for it to work!

IMPORTANT: DO NOT RUN THIS SCRIPT ON YOUR PC OR MAC!

This script should ONLY be used on a VPS or dedicated server, with
freshly installed Ubuntu 16.04/14.04/12.04, Debian 8 or CentOS 6/7.

EOF

read -r -p "Confirm and proceed with the install? [y/N] " response
case $response in
  [yY][eE][sS]|[yY])
    echo
    echo "Please be patient. Setup is continuing..."
    echo
    ;;
  *)
    echo "Aborting."
    sleep 1
    exit 1
    ;;
esac

BLOG_FQDN=$1

# Create and change to working dir
mkdir -p /opt/src
cd /opt/src || exit 1

if [ "$os_type" = "CentOS" ]; then

  # Add the EPEL repository
  yum -y install epel-release || { echoerr "Cannot add EPEL repo."; exit 1; }

  # We need some more software
  yum -y install unzip gcc gcc-c++ make openssl-devel \
    wget curl sudo libxml2-devel curl-devel httpd-devel pcre-devel \
    || { echoerr "'yum install' failed."; exit 1; }

else

  # Update package index
  export DEBIAN_FRONTEND=noninteractive
  apt-get -yq update || { echoerr "'apt-get update' failed."; exit 1; }

  # We need some more software
  apt-get -yq install unzip \
    build-essential apache2-dev libxml2-dev wget curl sudo \
    libcurl4-openssl-dev libpcre3-dev libssl-dev \
    || { echoerr "'apt-get install' failed."; exit 1; }

fi

  if [ "$os_type" != "CentOS" ]; then
    echo "exit 0" >> /etc/rc.local
  fi
  chmod +x /etc/rc.local

# Next, we need to install Node.js.
# Ref: https://github.com/nodesource/distributions
if [ "$ghost_num" = "1" ] || [ ! -f /usr/bin/node ]; then
  if [ "$os_type" = "CentOS" ]; then
    curl -sL https://rpm.nodesource.com/setup_4.x | bash -
    sed -i '/gpgkey/a exclude=nodejs' /etc/yum.repos.d/epel.repo
    yum -y --disablerepo=epel install nodejs || { echoerr "Failed to install 'nodejs'."; exit 1; }
  else
    curl -sL https://deb.nodesource.com/setup_4.x | bash -
    apt-get -yq install nodejs || { echoerr "Failed to install 'nodejs'."; exit 1; }
  fi
fi

# To keep your Ghost blog running, install "forever".
npm install forever -g

# Global config
caddyname="Caddy Web Server"
caddypath="/opt/caddyserver"
caddyuser="caddy"
caddyfile="/etc/Caddyfile"
caddywww="/var/caddywww"
caddylog="/var/log/caddy"

  # Detetcting Caddy installed or not
  echo ""
  if [[ -e "$caddypath/caddy" ]]; then
    echo "  $caddyname is already installed on"
    echo "  $caddypath/caddy"
    echo ""
  else
    # Detect architecture
    if [ -n "$(uname -m | grep 64)" ]; then
      cpubits="arch=amd64"
      cpubitsname="for (64bit)..."
    elif [ -n "$(uname -m | grep 86)" ]; then
      cpubits="arch=386"
      cpubitsname="for (32bit)..."
    elif [ -n "$(uname -m | grep armv5)" ]; then
      cpubits="arch=arm&arm=5"
      cpubitsname="for (ARM 5)..."
    elif [ -n "$(uname -m | grep armv6l)" ]; then
      cpubits="arch=arm&arm=6"
      cpubitsname="for (ARM 6)..."
    elif [ -n "$(uname -m | grep armv7l)" ]; then
      cpubits="arch=arm&arm=7"
      cpubitsname="for (ARM 7)..."
    else
      echo ""
      echo "  unsupported or unknown architecture"
      echo ""
      exit;
    fi

  nocert="--no-check-certificate"

  # Installing Caddy
  echo -n "  Downloading $caddyname $cpubitsname" #Caddy linux
  wget -q $nocert "https://caddyserver.com/download/build?os=linux&$cpubits&features=" -O "caddy_linux_custom.tar.gz"
  echo "  [$(tput setaf 2)DONE$(tput sgr0)]"

  # Creating folders
  echo ""
  mkdir -p $caddypath
  mkdir -p $caddylog
  
  # Extract Caddy on created folder
  echo -n "  Extracting $caddyname to $caddypath..."
  tar xzf caddy_linux_custom.tar.gz -C $caddypath #Extracting Caddy
  echo " $(tput setaf 2)[DONE]$(tput sgr0)"
  rm -rf caddy_linux_custom.tar.gz #Deleting Caddy archive
  echo ""

  # Creating non-root user
  useradd -r -d $caddypath -s /bin/false $caddyuser
  chown $caddyuser $caddypath
  chown $caddyuser $caddylog

  # Port setup
  APT_GET_CMD="/usr/bin/apt-get"
  echo -n "  Binding port using setcap..."
  if [[ ! -z $APT_GET_CMD ]]; then
    apt-get install libcap2-bin -y &>/dev/null
  fi
  setcap cap_net_bind_service=+ep $caddypath/caddy &>/dev/null
  # Insert required IPTables rules
  if ! iptables -C INPUT -p tcp --dport 80 -j ACCEPT 2>/dev/null; then
    iptables -I INPUT -p tcp --dport 80 -j ACCEPT
  fi
  if ! iptables -C INPUT -p tcp --dport 443 -j ACCEPT 2>/dev/null; then
    iptables -I INPUT -p tcp --dport 443 -j ACCEPT
  fi
  echo "  [$(tput setaf 2)DONE$(tput sgr0)]"
  fi

# Create a user to run Ghost:
mkdir -p $caddywww/$BLOG_FQDN
useradd -r -d "$caddywww/$BLOG_FQDN" -s /bin/false "$ghost_user"
chown -R $ghost_user $caddywww/$BLOG_FQDN

# Stop running Ghost blog processes, if any.
su - "$ghost_user" -s /bin/bash -c "forever stopall"

# Create temporary swap file to prevent out of memory errors during install
# Do not create if OpenVZ VPS
  tram=$( free -m | grep Mem | awk 'NR=1 {print $2}' )
  if [[ $tram -lt 950 ]]; then
    tswap=$( cat /proc/meminfo | grep SwapTotal | awk 'NR=1 {print $2$3}' )
    if [ "$tswap" = '0kB' ]; then
      swap_tmp="/swapfile"
      if [ ! -f /proc/user_beancounters ]; then
        echo
        echo "Creating temporary swap file, please wait ..."
        echo
        dd if=/dev/zero of="$swap_tmp" bs=1M count=512 2>/dev/null || /bin/rm -f "$swap_tmp"
        chmod 600 "$swap_tmp" && mkswap "$swap_tmp" &>/dev/null && swapon "$swap_tmp"
      fi
    fi
  fi

# Switch to Ghost blog user. We use a "here document" to run multiple commands as this user.
cd "$caddywww/$BLOG_FQDN" || exit 1
sudo -u "$ghost_user" BLOG_FQDN="$BLOG_FQDN" ghost_num="$ghost_num" ghost_port="$ghost_port" HOME="$caddywww/$BLOG_FQDN" /bin/bash <<'SU_END'

# Get the Ghost blog source (latest v0.11-LTS version), unzip and install.
ghost_releases="https://api.github.com/repos/TryGhost/Ghost/releases"
ghost_url="$(wget -t 3 -T 15 -qO- $ghost_releases | grep browser_download_url | grep 'Ghost-0\.11\.' | head -n 1 | cut -d '"' -f 4)"
if ! wget -t 3 -T 30 -nv -O ghost-latest.zip "$ghost_url"; then
  echo "Error: Cannot download Ghost blog source." >&2
  exit 1
fi
unzip -o -qq ghost-latest.zip && rm -f ghost-latest.zip
npm install --production

# Generate config file and make sure that Ghost uses your actual domain name
/bin/cp -f config.js config.js.old 2>/dev/null
sed "s/my-ghost-blog.com/$BLOG_FQDN/" <config.example.js >config.js
sed -i "s/port: '2368'/port: '$ghost_port'/" config.js

# We need to make certain that Ghost will start automatically after a reboot
cat > starter.sh <<'EOF'
#!/bin/sh
pgrep -u ghost -f "/usr/bin/node" >/dev/null
if [ $? -ne 0 ]; then
  export PATH=/usr/local/bin:$PATH
  export NODE_ENV=production
  NODE_ENV=production forever start --sourceDir www/YOUR.DOMAIN.NAME index.js >> /var/log/nodelog.txt 2>&1
else
  echo "Already running!"
fi
EOF

# Replace placeholder with your actual domain name:
sed -i "s/www/$caddywww/" starter.sh
sed -i "s/YOUR.DOMAIN.NAME/$BLOG_FQDN/" starter.sh

if [ "$ghost_num" != "1" ]; then
  sed -i "/^pgrep/s/ghost/ghost$ghost_num/" starter.sh
  sed -i "s/nodelog\.txt/nodelog$ghost_num.txt/" starter.sh
fi

# Make the script executable with:
chmod +x starter.sh

# We use crontab to start this script after a reboot:
crontab -r 2>/dev/null
crontab -l 2>/dev/null | { cat; echo "@reboot $caddywww/$BLOG_FQDN/starter.sh"; } | crontab -

NODE_ENV=production forever start index.js

SU_END

# Check if Ghost blog download was successful
[ ! -f "$caddywww/$BLOG_FQDN/index.js" ] && exit 1

# Create the logfile:
if [ "$ghost_num" = "1" ]; then
  touch /var/log/nodelog.txt
  chown ghost.ghost /var/log/nodelog.txt
else
  touch "/var/log/nodelog$ghost_num.txt"
  chown "ghost$ghost_num.ghost$ghost_num" "/var/log/nodelog$ghost_num.txt"
fi  

# Create the public folder which will hold robots.txt, etc.
mkdir -p "$caddywww/$BLOG_FQDN/public"

# Retrieve server IP for display below
PUBLIC_IP=$(wget -t 3 -T 15 -qO- http://ipv4.icanhazip.com)

  # Generate Caddyfile
  echo "$BLOG_FQDN {  
    proxy / 127.0.0.1:$ghost_port {
        header_upstream Host {host}
        header_upstream X-Real-IP {remote}
        header_upstream X-Forwarded-For {remote}
        header_upstream X-Forwarded-Proto {scheme}        
    }
    timeouts 3m
    tls $domainmail
    log $caddylog/$BLOG_FQDN-access.log
    errors $caddylog/$BLOG_FQDN-error.log
}
" >> $caddyfile

if [[ -e /etc/systemd/system/caddy.service || -e /etc/init.d/caddy.sh ]]; then
  echo "  Service already exists! Skipped."
else
  nocert="--no-check-certificate"
  init=`cat /proc/1/comm`
  echo -n "  Creating service..."
  if [ "$init" == 'systemd' ]; then
    MAIN="$"
    MAINPID="MAINPID"
    rm -f /etc/systemd/system/caddy.service
    cat <<EOF > /etc/systemd/system/caddy.service
[Unit]
Description=Caddy HTTP/2 web server
Documentation=https://caddyserver.com/docs
After=network.target

[Service]
User=$caddyuser
StartLimitInterval=86400
StartLimitBurst=5
LimitNOFILE=16535
ExecStart=$caddypath/caddy -conf=$caddyfile -quiet=true -pidfile=/var/run/caddy/caddy.pid
ExecReload=/bin/kill -USR1 $MAIN$MAINPID
ExecStop=/bin/kill $MAIN$MAINPID
PIDFile=/var/run/caddy/caddy.pid

[Install]
WantedBy=multi-user.target
EOF
    chmod 0644 /etc/systemd/system/caddy.service
    echo "  $(tput setaf 2)DONE$(tput sgr0)"
    systemctl daemon-reload
    systemctl enable caddy
  else
    # Download
    wget -q $nocert "https://raw.githubusercontent.com/sayem314/Caddy-Web-Server-Installer/master/php-fpm/runcaddy.sh" -O "/etc/init.d/caddy.sh"
    chmod +x /etc/init.d/caddy.sh
    # Enable
    YUM_CMD=$(which yum)
      APT_GET_CMD="/usr/bin/apt-get"
    if [[ ! -z $YUM_CMD ]]; then
      chkconfig caddy.sh on
      echo "  [$(tput setaf 2)DONE$(tput sgr0)]"
    elif [[ ! -z $APT_GET_CMD ]]; then
      echo "  [$(tput setaf 2)DONE$(tput sgr0)]"
      update-rc.d caddy.sh defaults
      else
      echo "  [$(tput setaf 1)FAILED$(tput sgr0)]"
    fi
  fi
fi
  
  service caddy start

cat <<EOF

=============================================================================

Setup is complete. Your new Ghost blog is now ready for use!

Ghost blog is installed in: $caddywww/$BLOG_FQDN
Caddy web server config: $caddyfile
Caddy web server logs: $caddylog

[Next Steps]

You must set up DNS (A Record) to point $BLOG_FQDN to this server $PUBLIC_IP

Browse to http://$BLOG_FQDN/ghost (alternatively, set up SSH port forwarding
and browse to http://localhost:$ghost_port/ghost) to complete the initial
configuration of your blog. Choose a very secure password.

To restart this Ghost blog:
su - $ghost_user -s /bin/bash -c 'forever stopall; ./starter.sh'

Ghost support: http://support.ghost.org
Real-time chat: https://ghost.org/slack

=============================================================================

EOF

exit 0
