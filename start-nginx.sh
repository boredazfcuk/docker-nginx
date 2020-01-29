#!/bin/ash

##### Functions #####
Initialise(){
   echo -e "\n"
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    ***** Starting NGINX container *****"
   if [ ! -f "/etc/nginx/nginx.conf" ]; then echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    ***** Config does not exist, waiting for it to be created ****"; while [ ! -f "/etc/nginx/nginx.conf" ]; do sleep 2; done; fi
   if [ ! -f "/usr/share/GeoIP/GeoIP.dat" ]; then echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    ***** GeoIP Country database does not exist, waiting for it to be created ****"; while [ ! -f "/usr/share/GeoIP/GeoIP.dat" ]; do sleep 2; done; fi
   if [ "${group_id}" ]; then echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Group ID set: ${group_id}"; groupmod -o nginx -g "${group_id}"; fi
   if [ "${user_id}" ]; then echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    User ID set: ${user_id}"; usermod -o nginx -u "${user_id}"; fi
   if [ "${media_access_domain}" ] && [ -z "${nextcloud_access_domain}" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Media domain name set to ${media_access_domain}"
   elif [ "${media_access_domain}" ] && [ "${nextcloud_access_domain}" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Media domain name set to ${media_access_domain}"
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Nextcloud domain name set to ${nextcloud_access_domain}"
   else
      echo "$(date '+%Y-%m-%d %H:%M:%S') ERROR:   Media domain name not set, cannot continue"
      sleep 60
      exit 1
   fi
   if [ -z "${stack_user}" ]; then echo "$(date '+%Y-%m-%d %H:%M:%S') WARNING: User name not set, defaulting to 'stackman'"; stack_user="stackman"; fi
   if [ -z "${stack_password}" ]; then echo "$(date '+%Y-%m-%d %H:%M:%S') WARNING: Password not set, defaulting to 'Skibidibbydibyodadubdub'"; stack_password="Skibidibbydibyodadubdub"; fi
}

SetPassword(){
   if [ ! -f "/etc/nginx/.htpasswd" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Creating .htpasswd file"
      htpasswd -bc "/etc/nginx/.htpasswd" "${stack_user}" "${stack_password}"
   fi
   if [ -f "/etc/nginx/.htpasswd" ] && [ "$(grep -c ${stack_user} /etc/nginx/.htpasswd)" = 0 ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') WARNING: .htpasswd file does not contain current user. Removing and recreating password file"
      rm "/etc/nginx/.htpasswd"
      htpasswd -bc "/etc/nginx/.htpasswd" "${stack_user}" "${stack_password}"
   fi
}

SetDomainNames(){
   if [ "${media_access_domain}" ] && [ -z "${nextcloud_access_domain}" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Configuring server to respond on ${media_access_domain}"
      sed -i \
         -e "s%server_name .*$%server_name ${media_access_domain};%" \
         /etc/nginx/conf.d/http.conf
      sed -i \
         -e "s%server_name .*$%server_name ${media_access_domain};%" \
         -e "s%^   #include /etc/nginx/conf.d/nextcloud.conf;$%   include /etc/nginx/conf.d/nextcloud.conf;%" \
         /etc/nginx/conf.d/media.conf
      sed -i \
         -e "s%/etc/letsencrypt/live/.*/%/etc/letsencrypt/live/${media_access_domain}/%g" \
         /etc/nginx/certificates.conf
   elif [ "${media_access_domain}" ] && [ "${nextcloud_access_domain}" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Configuring nginx to respond on ${media_access_domain} for media related applications and ${nextcloud_access_domain} for Nextcloud"
      sed -i \
         -e "s%^   #include /etc/nginx/conf.d/nextcloud.conf;$%   include /etc/nginx/conf.d/nextcloud.conf;%" \
         /etc/nginx/nginx.conf
      sed -i \
         -e "s%server_name .*$%server_name ${media_access_domain} ${nextcloud_access_domain};%" \
         /etc/nginx/conf.d/http.conf
      sed -i \
         -e "s%server_name .*$%server_name ${nextcloud_access_domain};%" \
         /etc/nginx/conf.d/nextcloud.conf
      sed -i \
         -e "s%server_name .*$%server_name ${media_access_domain};%" \
         -e "s%^   include /etc/nginx/conf.d/nextcloud.conf;$%   #include /etc/nginx/conf.d/nextcloud.conf;%" \
         /etc/nginx/conf.d/media.conf
      sed -i \
         -e "s%/etc/letsencrypt/live/.*/%/etc/letsencrypt/live/${media_access_domain}/%g" \
         /etc/nginx/certificates.conf
      sed -i \
         -e "s%/etc/letsencrypt/live/.*/%/etc/letsencrypt/live/${nextcloud_access_domain}/%g" \
         /etc/nginx/nextcloud_certificates.conf
   fi
}

LANLogging(){
   if [ "${nginx_lan_logging}" = "True" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Include local networks in log files"
      echo 'access_log  /var/log/nginx/access.log main;' > /etc/nginx/logging.conf
   else
      lan_ip="$(hostname -i)"
      docker_network_ip_subnet="$(ip -4 r | grep "${lan_ip}" | grep -v via | awk '{print $1}')"
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Exclude networks from logging: ${nginx_lan_ip_subnet}, ${docker_network_ip_subnet}"
      echo -e "map \x24remote_addr \x24ignore_ips {\n   ${nginx_lan_ip_subnet} 1;\n   ${docker_network_ip_subnet} 1;\n   default 0;\n}" > /etc/nginx/logging.conf
      echo 'access_log  /var/log/nginx/access.log main if=$ignore_ips;' >> /etc/nginx/logging.conf
   fi
}

Xenophobia(){
   if [ "${nginx_xenophobia}" ]; then
      nginx_xenophobia="$(echo ${nginx_xenophobia} | tr [:lower:] [:upper:])"
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Restricting access to following country codes: ${nginx_xenophobia}"
      {
         echo 'geoip_country /usr/share/GeoIP/GeoIP.dat;'
         echo -e 'map \x24geoip_country_code \x24allowed_country {\n   default no;\n   \x27\x27 yes;'
         for country in ${nginx_xenophobia}; do
            echo -e "   ${country} yes;"
         done
         echo '}'
      } > /etc/nginx/xenophobia.conf
   else
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Global connections allowed"
      {
         echo 'geoip_country /usr/share/GeoIP/GeoIP.dat;'
         echo 'map $geoip_country_code $allowed_country { default yes; }'
      } > /etc/nginx/xenophobia.conf
   fi
}

SABnzbd(){
   if [ "${sabnzbd_enabled}" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    SABnzbd proxying enabled"
      sed -i "s%^   #include /etc/nginx/locations/sabnzbd.conf;$%   include /etc/nginx/locations/sabnzbd.conf;%" "/etc/nginx/conf.d/media.conf"
   else
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    SABnzbd proxying disabled"
      sed -i "s%^   include /etc/nginx/locations/sabnzbd.conf;$%   #include /etc/nginx/locations/sabnzbd.conf;%" "/etc/nginx/conf.d/media.conf"
   fi
}

Deluge(){
   if [ "${deluge_enabled}" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Deluge proxying enabled"
      sed -i "s%^   #include /etc/nginx/locations/deluge.conf;$%   include /etc/nginx/locations/deluge.conf;%" "/etc/nginx/conf.d/media.conf"
   else
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Deluge proxying disabled"
      sed -i "s%   include /etc/nginx/locations/deluge.conf;$%   #include /etc/nginx/locations/deluge.conf;%" "/etc/nginx/conf.d/media.conf"
   fi
}

qBittorrent(){
   if [ "${qbittorrent_enabled}" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    qBittorrent proxying enabled"
      sed -i "s%^   #include /etc/nginx/locations/qbittorrent.conf;$%   include /etc/nginx/locations/qbittorrent.conf;%" "/etc/nginx/conf.d/media.conf"
   else
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    qBittorrent proxying disabled"
      sed -i "s%   include /etc/nginx/locations/qbittorrent.conf;$%   #include /etc/nginx/locations/qbittorrent.conf;%" "/etc/nginx/conf.d/media.conf"
   fi
}

CouchPotato(){
   if [ "${couchpotato_enabled}" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    CouchPotatoServer proxying enabled"
      sed -i "s%^   #include /etc/nginx/locations/couchpotato.conf;$%   include /etc/nginx/locations/couchpotato.conf;%" "/etc/nginx/conf.d/media.conf"
   else
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    CouchPotatoServer proxying disabled"
      sed -i "s%^   include /etc/nginx/locations/couchpotato.conf;$%   #include /etc/nginx/locations/couchpotato.conf;%" "/etc/nginx/conf.d/media.conf"
   fi
}

SickGear(){
   if [ "${sickgear_enabled}" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    SickGear proxying enabled"
      sed -i "s%^   #include /etc/nginx/locations/sickgear.conf;$%   include /etc/nginx/locations/sickgear.conf;%" "/etc/nginx/conf.d/media.conf"
   else
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    SickGear proxying disabled"
      sed -i "s%^   include /etc/nginx/locations/sickgear.conf;$%   #include /etc/nginx/locations/sickgear.conf;%" "/etc/nginx/conf.d/media.conf"
   fi
}

Headphones(){
   if [ "${headphones_enabled}" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Headphones proxying enabled"
      sed -i "s%^   #include /etc/nginx/locations/headphones.conf;$%   include /etc/nginx/locations/headphones.conf;%" "/etc/nginx/conf.d/media.conf"
   else
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Headphones proxying disabled"
      sed -i "s%^   include /etc/nginx/locations/headphones.conf;$%   #include /etc/nginx/locations/headphones.conf;%" "/etc/nginx/conf.d/media.conf"
   fi
}

Subsonic(){
   if [ "${subsonic_enabled}" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Subsonic proxying enabled"
      sed -i "s%^   #include /etc/nginx/locations/subsonic.conf;$%   include /etc/nginx/locations/subsonic.conf;%" "/etc/nginx/conf.d/media.conf"
   else
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Subsonic proxying disabled"
      sed -i "s%^   include /etc/nginx/locations/subsonic.conf;$%   #include /etc/nginx/locations/subsonic.conf;%" "/etc/nginx/conf.d/media.conf"
   fi
}

Nextcloud(){
   if [ "${nextcloud_enabled}" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Nextcloud proxying enabled"
      sed -i "s%^   #include /etc/nginx/locations/nextcloud.conf;$%   include /etc/nginx/locations/nextcloud.conf;%" "/etc/nginx/nginx.conf"
   else
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Nextcloud proxying disabled"
      sed -i "s%^   include /etc/nginx/locations/nextcloud.conf;$%   #include /etc/nginx/locations/nextcloud.conf;%" "/etc/nginx/nginx.conf"
   fi
}

SetOwnerAndGroup(){
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Correct owner and group of application files, if required"
   if [ "${user_id}" ]; then
      find "/etc/nginx" ! -user "${user_id}" -exec chown "${user_id}" {} \;
   fi
   if [ "${group_id}" ]; then 
      find "/etc/nginx" ! -group "${group_id}" -exec chgrp "${group_id}" {} \;
   fi
   if [ "${user_id}" ]; then
      find "/var/cache/nginx" ! -user "${user_id}" -exec chown "${user_id}" {} \;
   fi
   if [ "${group_id}" ]; then 
      find "/var/cache/nginx" ! -group "${group_id}" -exec chgrp "${group_id}" {} \;
   fi
}

LaunchNGINX(){
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Starting NGINX"
   nginx -g "daemon off;"
}

Initialise
SetPassword
SetDomainNames
LANLogging
Xenophobia
SABnzbd
Deluge
qBittorrent
CouchPotato
SickGear
Headphones
Subsonic
SetOwnerAndGroup
LaunchNGINX