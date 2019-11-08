#!/bin/ash

##### Functions #####
Initialise(){
   if [ ! -f "/etc/nginx/nginx.conf" ]; then echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    ***** Config does not exist, waiting for it to be created ****"; while [ ! -f "/etc/nginx/nginx.conf" ]; do sleep 2; done; fi
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    ***** Starting NGINX container *****"
   if [ ! -z "${UID}" ] && [ -z "${GID}" ]; then echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    New user ID set, changing to ${UID}"; usermod -o nginx -u "${UID}"; fi
   if [ ! -z "${GID}" ] && [ -z "${UID}" ]; then echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    New group ID set, changing to ${GID}"; groupmod -o nginx -g "${GID}"; fi
   if [ ! -z "${UID}" ] && [ ! -z "${GID}" ]; then echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    New group and user ID set, changing to ${UID}:${GID}"; usermod -o nginx -u "${UID}" -g "${GID}"; fi
   if [ ! -z "${DOMAINNAME}" ]; then echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Domain name set, configuring for ${DOMAINNAME}"; fi
   if [ -z "${DOMAINNAME}" ] && [ ! -z "${HTTPS}" ] && [ "${HTTPS}" = "True" ]; then echo "$(date '+%Y-%m-%d %H:%M:%S') WARNING: HTTPS enabled, but domain name not set. Cannot configure HTTPS"; fi
   if [ ! -z "${DOMAINNAME}" ] && [ ! -z "${HTTPS}" ] && [ "${HTTPS}" = "True" ]; then echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    HTTPS enabled"; PROTOCOL="https"; else PROTOCOL="http"; fi
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

ResetConfig(){
   sed -i -e "s%^   include /etc/nginx/conf.d/https.conf;$%   #include /etc/nginx/conf.d/https.conf;%" /etc/nginx/nginx.conf
   sed -i -e "s%^   include /etc/nginx/locations/.*;$%   #include /etc/nginx/locations/.*;%" \
      -e "s%^   server_name .*;%   server_name _;%" /etc/nginx/conf.d/http.conf
   sed -i -e "s%^  include /etc/nginx/locations/.*;$%   #include /etc/nginx/locations/.*;%" \
      -e "s%^   server_name .*;$%   server_name _;%" /etc/nginx/conf.d/https.conf
   sed -i "s%/etc/letsencrypt/live/.*/%/etc/letsencrypt/live/xDOMAINx/%g" /etc/nginx/tls_certificates.conf
}

SetDomainName(){
   if [ ! -z "${DOMAINNAME}" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Configuring server to respond on ${DOMAINNAME}"
      sed -i "s%server_name .*$%server_name ${DOMAINNAME};%" /etc/nginx/conf.d/http.conf
      sed -i "s%server_name .*$%server_name ${DOMAINNAME};%" /etc/nginx/conf.d/https.conf
      sed -i "s%/etc/letsencrypt/live/.*/%/etc/letsencrypt/live/${DOMAINNAME}/%g" /etc/nginx/tls_certificates.conf
   fi
}

SetHTTPS(){
   if [ ! -z "${HTTPS}" ] && [ "${HTTPS}" = "True" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    HTTPS enabled, configuring server to respond on port 443"
      sed -i -e "s%^   #include /etc/nginx/conf.d/https.conf;%   include /etc/nginx/conf.d/https.conf;%" /etc/nginx/nginx.conf
      sed -i -e "s%^   #location / { return 301 https%   location / { return 301 https%" /etc/nginx/conf.d/http.conf
   else
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    HTTPS enabled, configuring server to respond on port 80"
      sed -i -e "s%^   include /etc/nginx/conf.d/https.conf;%   #include /etc/nginx/conf.d/https.conf;%" /etc/nginx/nginx.conf
      sed -i -e "s%^   location / { return 301 https%   #location / { return 301 https%" /etc/nginx/conf.d/http.conf
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
      echo 'geoip_country /usr/share/GeoIP/GeoIP.dat;' > /etc/nginx/xenophobia.conf
      echo 'geoip_city    /usr/share/GeoIP/GeoLiteCity.dat;' >> /etc/nginx/xenophobia.conf
      echo -e 'map \x24geoip_country_code \x24allowed_country {\n   default no;\n   \x27\x27 yes;' >> /etc/nginx/xenophobia.conf
      for country in ${XENOPHOBIA}; do
         echo -e "   ${country} yes;" >> /etc/nginx/xenophobia.conf
      done
      echo '}' >> /etc/nginx/xenophobia.conf
   else
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Global connections allowed"
      echo 'geoip_country /usr/share/GeoIP/GeoIP.dat;' > /etc/nginx/xenophobia.conf
      echo 'geoip_city    /usr/share/GeoIP/GeoLiteCity.dat;' >> /etc/nginx/xenophobia.conf
      echo 'map $geoip_country_code $allowed_country { default yes; }' >> /etc/nginx/xenophobia.conf
   fi
}

UserAgentAuthentication(){
   if [ ! -z "${UA}" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Disabling authentication requirement for external clients with user agents that contain the following string: ${UA}"
      sed -i -e "s%#map \$http_user_agent \$auth_type { default \"Restricted\"; }$%map \$http_user_agent \$auth_type { default \"Restricted\"; ~*^""${UA}"" \"off\"; }%" /etc/nginx/nginx.conf
   else
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Enabling authentication for external clients"
      sed -i -e "s%map \$http_user_agent \$auth_type { default \"Restricted\";.*}$%#map \$http_user_agent \$auth_type { default \"Restricted\"; }%" /etc/nginx/nginx.conf
   fi
}

SABnzbd(){
   if [ ! -z "${SABNZBD}" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    SABnzbd proxying enabled"
      sed -i "s%^   #include /etc/nginx/locations/sabnzbd.conf;$%   include /etc/nginx/locations/sabnzbd.conf;%" "/etc/nginx/conf.d/${PROTOCOL}.conf"
   else
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    SABnzbd proxying disabled"
      sed -i "s%^   include /etc/nginx/locations/sabnzbd.conf;$%   #include /etc/nginx/locations/sabnzbd.conf;%" "/etc/nginx/conf.d/${PROTOCOL}.conf"
   fi
}

Deluge(){
   if [ ! -z "${DELUGE}" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Deluge proxying enabled"
      sed -i "s%^   #include /etc/nginx/locations/deluge.conf;$%   include /etc/nginx/locations/deluge.conf;%" "/etc/nginx/conf.d/${PROTOCOL}.conf"
   else
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Deluge proxying disabled"
      sed -i "s%   include /etc/nginx/locations/deluge.conf;$%   #include /etc/nginx/locations/deluge.conf;%" "/etc/nginx/conf.d/${PROTOCOL}.conf"
   fi
}

CouchPotato(){
   if [ ! -z "${COUCHPOTATO}" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    CouchPotatoServer proxying enabled"
      sed -i "s%^   #include /etc/nginx/locations/couchpotato.conf;$%   include /etc/nginx/locations/couchpotato.conf;%" "/etc/nginx/conf.d/${PROTOCOL}.conf"
   else
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    CouchPotatoServer proxying disabled"
      sed -i "s%^   include /etc/nginx/locations/couchpotato.conf;$%   #include /etc/nginx/locations/couchpotato.conf;%" "/etc/nginx/conf.d/${PROTOCOL}.conf"
   fi
}

SickGear(){
   if [ ! -z "${SICKGEAR}" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    SickGear proxying enabled"
      sed -i "s%^   #include /etc/nginx/locations/sickgear.conf;$%   include /etc/nginx/locations/sickgear.conf;%" "/etc/nginx/conf.d/${PROTOCOL}.conf"
   else
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    SickGear proxying disabled"
      sed -i "s%^   include /etc/nginx/locations/sickgear.conf;$%   #include /etc/nginx/locations/sickgear.conf;%" "/etc/nginx/conf.d/${PROTOCOL}.conf"
   fi
}

Headphones(){
   if [ ! -z "${HEADPHONES}" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Headphones proxying enabled"
      sed -i "s%^   #include /etc/nginx/locations/headphones.conf;$%   include /etc/nginx/locations/headphones.conf;%" "/etc/nginx/conf.d/${PROTOCOL}.conf"
   else
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Headphones proxying disabled"
      sed -i "s%^   include /etc/nginx/locations/headphones.conf;$%   #include /etc/nginx/locations/headphones.conf;%" "/etc/nginx/conf.d/${PROTOCOL}.conf"
   fi
}

Subsonic(){
   if [ ! -z "${SUBSONIC}" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Subsonic proxying enabled"
      sed -i "s%^   #include /etc/nginx/locations/subsonic.conf;$%   include /etc/nginx/locations/subsonic.conf;%" "/etc/nginx/conf.d/${PROTOCOL}.conf"
   else
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Subsonic proxying disabled"
      sed -i "s%^   include /etc/nginx/locations/subsonic.conf;$%   #include /etc/nginx/locations/subsonic.conf;%" "/etc/nginx/conf.d/${PROTOCOL}.conf"
   fi
}

Nextcloud(){
   if [ ! -z "${NEXTCLOUD}" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Nextcloud proxying enabled"
      sed -i "s%^   #include /etc/nginx/locations/nextcloud.conf;$%   include /etc/nginx/locations/nextcloud.conf;%" "/etc/nginx/conf.d/${PROTOCOL}.conf"
   else
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Nextcloud proxying disabled"
      sed -i "s%^   include /etc/nginx/locations/nextcloud.conf;$%   #include /etc/nginx/locations/nextcloud.conf;%" "/etc/nginx/conf.d/${PROTOCOL}.conf"
   fi
}

LaunchNGINX(){
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Starting NGINX"
   nginx -g "daemon off;"
}

Initialise
SetOwnerAndGroup
ResetConfig
SetDomainName
SetHTTPS
LANLogging
Xenophobia
SABnzbd
Deluge
CouchPotato
SickGear
Headphones
Subsonic
Nextcloud
LaunchNGINX