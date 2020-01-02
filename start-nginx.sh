#!/bin/ash

##### Functions #####
Initialise(){
   echo -e "\n"
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    ***** Starting NGINX container *****"
   if [ ! -f "/etc/nginx/nginx.conf" ]; then echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    ***** Config does not exist, waiting for it to be created ****"; while [ ! -f "/etc/nginx/nginx.conf" ]; do sleep 2; done; fi
   if [ ! -f "/usr/share/GeoIP/GeoIP.dat" ]; then echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    ***** GeoIP Country database does not exist, waiting for it to be created ****"; while [ ! -f "/usr/share/GeoIP/GeoIP.dat" ]; do sleep 2; done; fi
   if [ ! -z "${GID}" ]; then echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Group ID set: ${GID}"; groupmod -o nginx -g "${GID}"; fi
   if [ ! -z "${UID}" ]; then echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    User ID set: ${UID}"; usermod -o nginx -u "${UID}"; fi
   if [ ! -z "${MEDIAACCESSDOMAIN}" ] && [ -z "${NEXTCLOUDACCESSDOMAIN}" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Media domain name set to ${MEDIAACCESSDOMAIN}"
   elif [ ! -z "${MEDIAACCESSDOMAIN}" ] && [ ! -z "${NEXTCLOUDACCESSDOMAIN}" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Media domain name set to ${MEDIAACCESSDOMAIN}"
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Nextcloud domain name set to ${NEXTCLOUDACCESSDOMAIN}"
   else
      echo "$(date '+%Y-%m-%d %H:%M:%S') ERROR:   Media domain name not set, cannot continue"
      sleep 60
      exit 1
   fi
   if [ -z "${STACKUSER}" ]; then echo "$(date '+%Y-%m-%d %H:%M:%S') WARNING: User name not set, defaulting to 'stackman'"; STACKUSER="stackman"; fi
   if [ -z "${STACKPASSWORD}" ]; then echo "$(date '+%Y-%m-%d %H:%M:%S') WARNING: Password not set, defaulting to 'Skibidibbydibyodadubdub'"; STACKPASSWORD="Skibidibbydibyodadubdub"; fi
   if [ ! -f "/etc/nginx/.htpasswd" ]; then htpasswd -bc "/etc/nginx/.htpasswd" "${STACKUSER}" "${STACKPASSWORD}"; fi
}

SetPassword(){
   echo "$(date '+%Y-%m-%d %H:%M:%S') WARNING: .htpasswd file does not contain current user. Password must have been changed. Recreating password file with new password"
   rm "/etc/nginx/.htpasswd"
   htpasswd -bc "/etc/nginx/.htpasswd" "${STACKUSER}" "${STACKPASSWORD}"
}

SetDomainNames(){
   if [ ! -z "${MEDIAACCESSDOMAIN}" ] && [ -z "${NEXTCLOUDACCESSDOMAIN}" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Configuring server to respond on ${MEDIAACCESSDOMAIN}"
      sed -i -e "s%server_name .*$%server_name ${MEDIAACCESSDOMAIN};%" /etc/nginx/conf.d/http.conf
      sed -i -e "s%server_name .*$%server_name ${MEDIAACCESSDOMAIN};%" \
         -e "s%^   #include /etc/nginx/conf.d/nextcloud.conf;$%   include /etc/nginx/conf.d/nextcloud.conf;%" \
         /etc/nginx/conf.d/media.conf
      sed -i "s%/etc/letsencrypt/live/.*/%/etc/letsencrypt/live/${MEDIAACCESSDOMAIN}/%g" /etc/nginx/certificates.conf
   elif [ ! -z "${MEDIAACCESSDOMAIN}" ] && [ ! -z "${NEXTCLOUDACCESSDOMAIN}" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Configuring nginx to respond on ${MEDIAACCESSDOMAIN} for media related applications and ${NEXTCLOUDACCESSDOMAIN} for Nextcloud"
      sed -i \
         -e "s%^   #include /etc/nginx/conf.d/nextcloud.conf;$%   include /etc/nginx/conf.d/nextcloud.conf;%" \
         /etc/nginx/nginx.conf
      sed -i -e "s%server_name .*$%server_name ${MEDIAACCESSDOMAIN};%" /etc/nginx/conf.d/http.conf
      sed -i -e "s%server_name .*$%server_name ${NEXTCLOUDACCESSDOMAIN};%" /etc/nginx/conf.d/nextcloud.conf
      sed -i -e "s%server_name .*$%server_name ${MEDIAACCESSDOMAIN};%" \
         -e "s%^   include /etc/nginx/conf.d/nextcloud.conf;$%   #include /etc/nginx/conf.d/nextcloud.conf;%" \
         /etc/nginx/conf.d/media.conf
      sed -i -e "s%/etc/letsencrypt/live/.*/%/etc/letsencrypt/live/${MEDIAACCESSDOMAIN}/%g" /etc/nginx/certificates.conf
      sed -i -e "s%/etc/letsencrypt/live/.*/%/etc/letsencrypt/live/${NEXTCLOUDACCESSDOMAIN}/%g" /etc/nginx/nextcloud_certificates.conf
   fi
}

LANLogging(){
   if [ "${LANLOGGING}" = "True" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Include local networks in log files"
      echo 'access_log  /var/log/nginx/access.log main;' > /etc/nginx/logging.conf
   else
      LANIP="$(hostname -i)"
      DOCKERIPSUBNET="$(ip -4 r | grep "${LANIP}" | grep -v via | awk '{print $1}')"
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Exclude networks from logging: ${LANIPSUBNET}, ${DOCKERIPSUBNET}"
      echo -e "map \x24remote_addr \x24ignore_ips {\n   ${LANIPSUBNET} 1;\n   ${DOCKERIPSUBNET} 1;\n   default 0;\n}" > /etc/nginx/logging.conf
      echo 'access_log  /var/log/nginx/access.log main if=$ignore_ips;' >> /etc/nginx/logging.conf
   fi
}

Xenophobia(){
   if [ ! -z "${XENOPHOBIA}" ]; then
      XENOPHOBIA="$(echo ${XENOPHOBIA} | tr [:lower:] [:upper:])"
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Restricting access to following country codes: ${XENOPHOBIA}"
      {
         echo 'geoip_country /usr/share/GeoIP/GeoIP.dat;'
         echo -e 'map \x24geoip_country_code \x24allowed_country {\n   default no;\n   \x27\x27 yes;'
         for country in ${XENOPHOBIA}; do
            echo -e "   ${country} yes;"
         done
         echo '}'
         echo -e 'map \x24geoip_org \x24allowed_organisation {\n   default no;\n   LetsEncrypt yes;\n}'
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
   if [ ! -z "${SABNZBD}" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    SABnzbd proxying enabled"
      sed -i "s%^   #include /etc/nginx/locations/sabnzbd.conf;$%   include /etc/nginx/locations/sabnzbd.conf;%" "/etc/nginx/conf.d/media.conf"
   else
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    SABnzbd proxying disabled"
      sed -i "s%^   include /etc/nginx/locations/sabnzbd.conf;$%   #include /etc/nginx/locations/sabnzbd.conf;%" "/etc/nginx/conf.d/media.conf"
   fi
}

Deluge(){
   if [ ! -z "${DELUGE}" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Deluge proxying enabled"
      sed -i "s%^   #include /etc/nginx/locations/deluge.conf;$%   include /etc/nginx/locations/deluge.conf;%" "/etc/nginx/conf.d/media.conf"
   else
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Deluge proxying disabled"
      sed -i "s%   include /etc/nginx/locations/deluge.conf;$%   #include /etc/nginx/locations/deluge.conf;%" "/etc/nginx/conf.d/media.conf"
   fi
}

CouchPotato(){
   if [ ! -z "${COUCHPOTATO}" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    CouchPotatoServer proxying enabled"
      sed -i "s%^   #include /etc/nginx/locations/couchpotato.conf;$%   include /etc/nginx/locations/couchpotato.conf;%" "/etc/nginx/conf.d/media.conf"
   else
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    CouchPotatoServer proxying disabled"
      sed -i "s%^   include /etc/nginx/locations/couchpotato.conf;$%   #include /etc/nginx/locations/couchpotato.conf;%" "/etc/nginx/conf.d/media.conf"
   fi
}

SickGear(){
   if [ ! -z "${SICKGEAR}" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    SickGear proxying enabled"
      sed -i "s%^   #include /etc/nginx/locations/sickgear.conf;$%   include /etc/nginx/locations/sickgear.conf;%" "/etc/nginx/conf.d/media.conf"
   else
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    SickGear proxying disabled"
      sed -i "s%^   include /etc/nginx/locations/sickgear.conf;$%   #include /etc/nginx/locations/sickgear.conf;%" "/etc/nginx/conf.d/media.conf"
   fi
}

Headphones(){
   if [ ! -z "${HEADPHONES}" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Headphones proxying enabled"
      sed -i "s%^   #include /etc/nginx/locations/headphones.conf;$%   include /etc/nginx/locations/headphones.conf;%" "/etc/nginx/conf.d/media.conf"
   else
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Headphones proxying disabled"
      sed -i "s%^   include /etc/nginx/locations/headphones.conf;$%   #include /etc/nginx/locations/headphones.conf;%" "/etc/nginx/conf.d/media.conf"
   fi
}

Subsonic(){
   if [ ! -z "${SUBSONIC}" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Subsonic proxying enabled"
      sed -i "s%^   #include /etc/nginx/locations/subsonic.conf;$%   include /etc/nginx/locations/subsonic.conf;%" "/etc/nginx/conf.d/media.conf"
   else
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Subsonic proxying disabled"
      sed -i "s%^   include /etc/nginx/locations/subsonic.conf;$%   #include /etc/nginx/locations/subsonic.conf;%" "/etc/nginx/conf.d/media.conf"
   fi
}

Nextcloud(){
   if [ ! -z "${NEXTCLOUD}" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Nextcloud proxying enabled"
      sed -i "s%^   #include /etc/nginx/locations/nextcloud.conf;$%   include /etc/nginx/locations/nextcloud.conf;%" "/etc/nginx/nginx.conf"
   else
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Nextcloud proxying disabled"
      sed -i "s%^   include /etc/nginx/locations/nextcloud.conf;$%   #include /etc/nginx/locations/nextcloud.conf;%" "/etc/nginx/nginx.conf"
   fi
}

SetOwnerAndGroup(){
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Correct owner and group of application files, if required"
   if [ ! -z "${UID}" ]; then
      find "/etc/nginx" ! -user "${UID}" -exec chown "${UID}" {} \;
   fi
   if [ ! -z "${GID}" ]; then 
      find "/etc/nginx" ! -group "${GID}" -exec chgrp "${GID}" {} \;
   fi
   if [ ! -z "${UID}" ]; then
      find "/var/cache/nginx" ! -user "${UID}" -exec chown "${UID}" {} \;
   fi
   if [ ! -z "${GID}" ]; then 
      find "/var/cache/nginx" ! -group "${GID}" -exec chgrp "${GID}" {} \;
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
CouchPotato
SickGear
Headphones
Subsonic
Nextcloud
SetOwnerAndGroup
LaunchNGINX