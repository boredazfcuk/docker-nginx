#!/bin/ash

##### Functions #####
Initialise(){
   echo -e "\n"
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    ***** Configuring NGINX container launch environment *****"
   docker_lan_ip="$(hostname -i)"
   docker_lan_ip_subnet="$(ip -4 route | grep "${lan_ip}" | grep -v via | awk '{print $1}')"
   {
      echo "allow ${nginx_lan_ip_subnet};"
      echo "allow ${docker_lan_ip_subnet};"
   } > /etc/nginx/local_networks.conf
   if [ ! -f "/usr/share/GeoIP/GeoIP.dat" ]; then echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    ***** GeoIP Country database does not exist, waiting for it to be created ****"; while [ ! -f "/usr/share/GeoIP/GeoIP.dat" ]; do sleep 2; done; fi
   if [ "${group_id}" ]; then
      if [ "$(grep -c ":{group_id}:{group_id}:" /etc/passwd)" = 0 ]; then
         echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Change Group ID to: ${group_id}"
         groupmod -o nginx -g "${group_id}"
      fi
   fi
   if [ "${user_id}" ]; then
      if [ "$(grep -c ":{user_id}:{user_id}:" /etc/passwd)" = 0 ]; then
         echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Change User ID to: ${user_id}"
         usermod -o nginx -u "${user_id}"
      fi
   fi
   if [ "${media_access_domain}" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Media access domain name: ${media_access_domain}"
   else
      echo "$(date '+%Y-%m-%d %H:%M:%S') ERROR:   Media access domain name not set, cannot continue"
      sleep 60
      exit 1
   fi
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Username: ${stack_user:=stackman}"
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Password: ${stack_password:=Skibidibbydibyodadubdub}"
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Local IP address: $(hostname -i)"
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Host LAN IP subnet: ${nginx_lan_ip_subnet}"
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Docker LAN IP subnet: ${docker_lan_ip_subnet}"
   if [ ! -L "/var/log/nginx/access.log" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Configure access log to log to stdout"
      if [ -f "/var/log/nginx/access.log" ]; then rm "/var/log/nginx/access.log"; fi
      ln -sf "/dev/stdout" "/var/log/nginx/access.log"
   fi
   if [ ! -L "/var/log/nginx/error.log" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Configure access log to log to stderr"
      if [ -f "/var/log/nginx/error.log" ]; then rm "/var/log/nginx/error.log"; fi
      ln -sf "/dev/stderr" "/var/log/nginx/error.log"
   fi
}

DownloadFavouritesIcon(){
   if [ ! -f "/etc/nginx/html/favicon.ico" ]; then
      if [ ! -d "/etc/nginx/html" ]; then mkdir "/etc/nginx/html"; fi
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Favicon.ico missing. Downloading from iconfinder.com"
      wget -q "https://www.iconfinder.com/icons/81001/download/ico/64" -O "/tmp/temp.ico"
      mv "/tmp/temp.ico" "/etc/nginx/html/favicon.ico"
   fi
}

SetPassword(){
   if [ ! -f "/etc/nginx/users.htpasswd" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Creating users.htpasswd file and adding user ${stack_user}"
      htpasswd -bc "/etc/nginx/users.htpasswd" "${stack_user}" "${stack_password}" >/dev/null 2>&1
   fi
   if [ -f "/etc/nginx/users.htpasswd" ] && [ "$(grep -c ${stack_user} /etc/nginx/users.htpasswd)" = 0 ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') WARNING: users.htpasswd file exists but does not contain current user. Removing and recreating password file"
      rm "/etc/nginx/users.htpasswd"
      echo "$(date '+%Y-%m-%d %H:%M:%S') WARNING: Creating users.htpasswd file and adding user ${stack_user}"
      htpasswd -bc "/etc/nginx/users.htpasswd" "${stack_user}" "${stack_password}" >/dev/null 2>&1
   fi
}

ConfigureServerNames(){
   if [ -z "${nextcloud_access_domain}" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Setting default HTTP server to respond on ${media_access_domain} "
      sed -i \
         -e "s%server_name .*%server_name ${media_access_domain};%" \
         /etc/nginx/conf.d/http.conf
   elif [ "${nextcloud_enabled}" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Setting default HTTP server to respond on ${media_access_domain} and ${nextcloud_access_domain}"
      sed -i \
         -e "s%server_name .*%server_name ${media_access_domain} ${nextcloud_access_domain};%" \
         /etc/nginx/conf.d/http.conf
   fi
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Setting media server to respond on ${media_access_domain}"
   sed -i \
      -e "s%server_name .*$%server_name ${media_access_domain};%" \
      /etc/nginx/conf.d/media.conf
   if [ "${nextcloud_enabled}" ] && [ "${nextcloud_access_domain}" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Setting Nextcloud server to respond on ${nextcloud_access_domain}"
      sed -i \
         -e "s%server_name .*%server_name ${nextcloud_access_domain};%" \
         /etc/nginx/conf.d/nextcloud.conf
   fi
}

ConfigurePacFileMimeTypes(){
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Configure mime types"
   {
      echo 'types {'
      echo '   application/x-ns-proxy-autoconfig   pac;'
      echo '   application/x-ns-proxy-autoconfig   dat;'
      echo '   application/x-ns-proxy-autoconfig   da;'
      echo '}'
   } > "/etc/nginx/wpad_mime.types"
}

ConfigureCertificates(){
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Setting certificate file location for ${media_access_domain}"
   sed -i \
      -e "s%/etc/letsencrypt/live/.*/%/etc/letsencrypt/live/${media_access_domain}/%g" \
      /etc/nginx/certificates.conf
   if [ "${nextcloud_access_domain}" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Setting certificate file location for ${nextcloud_access_domain}"
      sed -i \
         -e "s%/etc/letsencrypt/live/.*/%/etc/letsencrypt/live/${nextcloud_access_domain}/%g" \
         /etc/nginx/nextcloud_certificates.conf
   fi
}

LANLogging(){
   if [ "${nginx_lan_logging}" = "True" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Log traffic from local networks"
      {
         echo 'map $remote_addr $ignore_ips {'
         echo '   default 1;'
         echo '}'
      } > /etc/nginx/logging.conf
   else
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Exclude networks from logging: ${nginx_lan_ip_subnet}, ${docker_lan_ip_subnet}"
      {
         echo 'map $remote_addr $ignore_ips {'
         echo "   ${nginx_lan_ip_subnet} 0;"
         echo "   ${docker_lan_ip_subnet} 0;"
         echo '   default 1;'
         echo '}'
      } > /etc/nginx/logging.conf
   fi
}

Xenophobia(){
   if [ "${nginx_xenophobia}" ] && [ -f "/usr/share/GeoIP/GeoIP.dat" ]; then
      nginx_xenophobia="$(echo ${nginx_xenophobia} | tr [:lower:] [:upper:])"
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Restricting access to following country codes: ${nginx_xenophobia}"
      {
         echo 'geoip_country /usr/share/GeoIP/GeoIP.dat;'
         echo 'map $geoip_country_code $allowed_country {'
         echo '   default no;'
         for country in ${nginx_xenophobia}; do
            echo -e "   ${country} yes;"
         done
         echo '}'
         echo
         echo 'geo $allowed_network {'
         echo '   default no;'
         echo "   ${nginx_lan_ip_subnet} yes;"
         echo "   ${docker_lan_ip_subnet} yes;"
         echo '   # www.ssllabs.com'
         echo '   64.41.200.0/24 yes;'
         echo '   # securityheaders.com'
         echo '   167.172.196.35/32 yes;'
         echo '}'
      } > /etc/nginx/xenophobia.conf
   else
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Global connections allowed"
      {
         echo 'geoip_country /usr/share/GeoIP/GeoIP.dat;'
         echo 'map $geoip_country_code $allowed_country { default yes; }'
         echo 'geo $allowed_network { default yes; }'
      } > /etc/nginx/xenophobia.conf
   fi
}

SABnzbd(){
   if [ "${sabnzbd_enabled}" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    SABnzbd proxying enabled"
      sed -i -e "/^# .*include.*sabnzbd.conf/ s/^# / /" "/etc/nginx/conf.d/media.conf"
   else
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    SABnzbd proxying disabled"
      sed -i -e "/^ .*include.*sabnzbd.conf/ s/^ /# /" "/etc/nginx/conf.d/media.conf"
   fi
}

Deluge(){
   if [ "${deluge_enabled}" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Deluge proxying enabled"
      sed -i -e "/^# .*include.*deluge.conf/ s/^# / /" "/etc/nginx/conf.d/media.conf"
   else
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Deluge proxying disabled"
      sed -i -e "/^ .*include.*deluge.conf/ s/^ /# /" "/etc/nginx/conf.d/media.conf"
   fi
}

CouchPotato(){
   if [ "${couchpotato_enabled}" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    CouchPotatoServer proxying enabled"
      sed -i -e "/^# .*include.*couchpotato.conf/ s/^# / /" "/etc/nginx/conf.d/media.conf"
   else
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    CouchPotatoServer proxying disabled"
      sed -i -e "/^ .*include.*couchpotato.conf/ s/^ /# /" "/etc/nginx/conf.d/media.conf"
   fi
}

SickGear(){
   if [ "${sickgear_enabled}" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    SickGear proxying enabled"
      sed -i -e "/^# .*include.*sickgear.conf/ s/^# / /" "/etc/nginx/conf.d/media.conf"
   else
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    SickGear proxying disabled"
      sed -i -e "/^ .*include.*sickgear.conf/ s/^ /# /" "/etc/nginx/conf.d/media.conf"
   fi
}

Headphones(){
   if [ "${headphones_enabled}" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Headphones proxying enabled"
      sed -i -e "/^# .*include.*headphones.conf/ s/^# / /" "/etc/nginx/conf.d/media.conf"
   else
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Headphones proxying disabled"
      sed -i -e "/^ .*include.*headphones.conf/ s/^ /# /" "/etc/nginx/conf.d/media.conf"
   fi
}

Subsonic(){
   if [ "${subsonic_enabled}" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Subsonic proxying enabled"
      sed -i -e "/^# .*include.*subsonic.conf/ s/^# / /" "/etc/nginx/conf.d/media.conf"
   else
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Subsonic proxying disabled"
      sed -i -e "/^ .*include.*subsonic.conf/ s/^ /# /" "/etc/nginx/conf.d/media.conf"
   fi
}

Nextcloud(){
   if [ "${nextcloud_enabled}" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Nextcloud proxying enabled"
      if [ "${nextcloud_access_domain}" ]; then
         echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Setting Nextcloud access domain to ${nextcloud_access_domain}"
         sed -i \
            -e "/^# .*include.*nextcloud.conf/ s/^# / /" \
            /etc/nginx/nginx.conf
         sed -i \
            -e "/^ .*include.*nextcloud.conf/ s/^ /# /" \
            /etc/nginx/conf.d/media.conf
      else
         echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Setting Nextcloud access domain to ${media_access_domain}"
         sed -i \
            -e "/^ .*include.*nextcloud.conf/ s/^ /# /" \
            /etc/nginx/nginx.conf
         sed -i \
            -e "/^# .*include.*nextcloud.conf/ s/^# /  /" \
            /etc/nginx/conf.d/media.conf
      fi
   else
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Nextcloud proxying disabled"
      sed -i \
         -e "/^ .*include.*nextcloud.conf/ s/^ /# /" \
         /etc/nginx/nginx.conf
   fi
}

ProxyConfig(){
   if [ "${proxyconfig_enabled}" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Proxy configuration enabled essential files served from /proxyconfig/"
      sed -i -e "/^# .*include.*proxyconfig.conf/ s/^# / /" "/etc/nginx/conf.d/http.conf"
      sed -i -e "/^# .*include.*proxyconfig.conf/ s/^# / /" "/etc/nginx/conf.d/media.conf"
   else
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Proxy configuration disabled"
      sed -i -e "/^ .*include.*proxyconfig.conf/ s/^ /# /" "/etc/nginx/conf.d/http.conf"
      sed -i -e "/^ .*include.*proxyconfig.conf/ s/^ /# /" "/etc/nginx/conf.d/media.conf"
   fi
}

SetOwnerAndGroup(){
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Correct owner and group of application files, if required"
   if [ "${user_id}" ]; then
      find "/etc/nginx" ! -user "${user_id}" -exec chown "${user_id}" {} \;
      find "/var/cache/nginx" ! -user "${user_id}" -exec chown "${user_id}" {} \;
   fi
   if [ "${group_id}" ]; then 
      find "/etc/nginx" ! -group "${group_id}" -exec chgrp "${group_id}" {} \;
      find "/var/cache/nginx" ! -group "${group_id}" -exec chgrp "${group_id}" {} \;
   fi
}

LaunchNGINX(){
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    ***** Configuration of NGINX container launch environment complete *****"
   if [ -z "${1}" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Starting NGINX"
      exec "/usr/sbin/nginx"
   else
      exec "$@"
   fi
}

Initialise
DownloadFavouritesIcon
SetPassword
ConfigureServerNames
ConfigurePacFileMimeTypes
ConfigureCertificates
LANLogging
Xenophobia
SABnzbd
Deluge
CouchPotato
SickGear
Headphones
Subsonic
Nextcloud
ProxyConfig
SetOwnerAndGroup
LaunchNGINX