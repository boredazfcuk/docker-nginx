#!/bin/ash

##### Functions #####
Initialise(){
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    ***** Starting NGINX container *****"
   if [ ! -z "${GID}" ]; then echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    New group ID set, changing to ${GID}"; groupmod -o nginx -g "${GID}"; fi
   if [ ! -z "${UID}" ]; then echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    New user ID set, changing to ${UID}"; usermod -o nginx -u "${UID}"; fi
   if [ ! -z "${GID}" ] && [ ! -z "${UID}" ]; then echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    New group and user ID set, changing to ${UID}:${GID}"; usermod -o nginx -u "${UID}" -g "${GID}"; fi
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
   sed -i -e "s%^   include /etc/nginx/conf.d/https.conf;$%#&%g" /etc/nginx/nginx.conf
   sed -i -e "s%^   include /etc/nginx/locations/.*;$%#&%" \
      -e "s%^   server_name .*;$%   server_name _;%" /etc/nginx/conf.d/http.conf
   sed -i -e "s%^   include /etc/nginx/locations/.*;$%#&%" \
      -e "s%^   server_name .*;$%   server_name _;%" /etc/nginx/conf.d/https.conf
   sed -i "s%/etc/letsencrypt/live/.*/%/etc/letsencrypt/live/xDOMAINx/%g" /etc/nginx/tls_certificates.conf
}

SetDomainName(){
   if [ ! -z "${DOMAINNAME}" ]; then
      sed -i "s%^   server_name .*;$%   server_name ${DOMAINNAME};%" /etc/nginx/conf.d/http.conf
      sed -i "s%^   server_name .*;$%   server_name ${DOMAINNAME};%" /etc/nginx/conf.d/https.conf
      sed -i "s%/etc/letsencrypt/live/.*/%/etc/letsencrypt/live/${DOMAINNAME}/%g" /etc/nginx/tls_certificates.conf
   fi
}

SetHTTPS(){
   if [ ! -z "${HTTPS}" ] && [ "${HTTPS}" = "True" ]; then
      sed -i -e "s%^#   include /etc/nginx/conf.d/https.conf;$%   include /etc/nginx/conf.d/https.conf;%g" /etc/nginx/nginx.conf
   fi
}

LANLogging(){
   if [ "${LANLOGGING}" = "True" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Include local networks in log files"
      echo 'access_log  /var/log/nginx/access.log main;' > /etc/nginx/logging.conf
   else
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Exclude local netwoks from log files"
      echo 'map $remote_addr $ignore_ips { "~172.1[6-9]..*" 0; "~172.2[0-9]..*" 0; "~172.3[0-1]..*" 0; "~192.168..*" 0; "~10..*" 0; default 1; }' > /etc/nginx/logging.conf
      echo 'access_log  /var/log/nginx/access.log main if=$ignore_ips;' >> /etc/nginx/logging.conf
   fi
}

Xenophobia(){
   if [ ! -z "${XENOPHOBIA}" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Connections from foreign countries blocked. Allowed country code is ${XENOPHOBIA}"
      sed -i "s%^#   if (\$allowed_country = no) { return 444; }$%   if (\$allowed_country = no) { return 444; }%" /etc/nginx/conf.d/http.conf
      sed -i "s%^#   if (\$allowed_country = no) { return 444; }$%   if (\$allowed_country = no) { return 444; }%" /etc/nginx/conf.d/https.conf
      echo 'geoip_country /usr/share/GeoIP/GeoIP.dat;' > /etc/nginx/xenophobia.conf
      echo 'geoip_city    /usr/share/GeoIP/GeoLiteCity.dat;' >> /etc/nginx/xenophobia.conf
      echo 'map $geoip_country_code $allowed_country { default no; '\'\'' yes; '"${XENOPHOBIA}"' yes; }' >> /etc/nginx/xenophobia.conf
   else
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Global connections allowed"
      sed -i "s%^   if (\$allowed_country = no) { return 444; }$%#   if (\$allowed_country = no) { return 444; }%" /etc/nginx/conf.d/http.conf
      sed -i "s%^   if (\$allowed_country = no) { return 444; }$%#   if (\$allowed_country = no) { return 444; }%" /etc/nginx/conf.d/https.conf
      echo 'geoip_country /usr/share/GeoIP/GeoIP.dat;' > /etc/nginx/xenophobia.conf
      echo 'geoip_city    /usr/share/GeoIP/GeoLiteCity.dat;' >> /etc/nginx/xenophobia.conf
      echo 'map $geoip_country_code $allowed_country { default yes; }' >> /etc/nginx/xenophobia.conf
   fi
}

UserAgentAuthentication(){
   if [ ! -z "${UA}" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Disabling external authentication for specified user agent: ${UA}"
      echo -e "map \x24http_user_agent \x24auth_type { default \x22Restricted\x22; ~^nzbUnity \x22off\x22; }" > /etc/nginx/password_protection.conf
      echo >> /etc/nginx/password_protection.conf
      echo "satisfy    any;" >> /etc/nginx/password_protection.conf
      echo "allow      192.168.0.0/16;" >> /etc/nginx/password_protection.conf
      echo "allow      172.16.0.0/16;" >> /etc/nginx/password_protection.conf
      echo "allow      10.0.0.0/8;" >> /etc/nginx/password_protection.conf
      echo "deny       all;" >> /etc/nginx/password_protection.conf
      echo  >> /etc/nginx/password_protection.conf
      echo -e "auth_basic              \x22Restricted Access\x22;" >> /etc/nginx/password_protection.conf
      echo "auth_basic_user_file    /etc/nginx/.htpasswd;" >> /etc/nginx/password_protection.conf
   else
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Allowing LAN only connections"
      echo "satisfy    any;"  > /etc/nginx/password_protection.conf
      echo "allow      192.168.0.0/16;" >> /etc/nginx/password_protection.conf
      echo "allow      172.16.0.0/16;" >> /etc/nginx/password_protection.conf
      echo "allow      10.0.0.0/8;" >> /etc/nginx/password_protection.conf
      echo "deny       all;" >> /etc/nginx/password_protection.conf
      echo  >> /etc/nginx/password_protection.conf
      echo -e "auth_basic              \x22Restricted Access\x22;" >> /etc/nginx/password_protection.conf
      echo "auth_basic_user_file    /etc/nginx/.htpasswd;" >> /etc/nginx/password_protection.conf
   fi
}

SABnzbd(){
   if [ ! -z "${SABNZBD}" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    SABnzbd proxying enabled to ${SABNZBD}"
      sed -i -e "s%proxy_pass          http://.*:8080;$%proxy_pass          http://${SABNZBD}:8080;%g" /etc/nginx/locations/sabnzbd.conf
      sed -i "s%^#   include /etc/nginx/locations/sabnzbd.conf;$%   include /etc/nginx/locations/sabnzbd.conf;%" "/etc/nginx/conf.d/${PROTOCOL}.conf"
   else
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    SABnzbd proxying disabled"
      sed -i "s%^   include /etc/nginx/locations/sabnzbd.conf;$%#   include /etc/nginx/locations/sabnzbd.conf;%" "/etc/nginx/conf.d/${PROTOCOL}.conf"
   fi
}

Deluge(){
   if [ ! -z "${DELUGE}" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Deluge proxying enabled"
      sed -i -e "s%proxy_pass          http://.*:8112;$%proxy_pass          http://${DELUGE}:8112;%g" /etc/nginx/locations/deluge.conf
      sed -i "s%^#   include /etc/nginx/locations/deluge.conf;$%   include /etc/nginx/locations/deluge.conf;%" "/etc/nginx/conf.d/${PROTOCOL}.conf"
   else
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Deluge proxying disabled"
      sed -i "s%^   include /etc/nginx/locations/deluge.conf;$%#   include /etc/nginx/locations/deluge.conf;%" "/etc/nginx/conf.d/${PROTOCOL}.conf"
   fi
}

CouchPotato(){
   if [ ! -z "${COUCHPOTATO}" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    CouchPotatoServer proxying enabled"
      sed -i -e "s%proxy_pass          http://.*:5050;$%proxy_pass          http://${COUCHPOTATO}:5050;%g" /etc/nginx/locations/couchpotato.conf
      sed -i "s%^#   include /etc/nginx/locations/couchpotato.conf;$%   include /etc/nginx/locations/couchpotato.conf;%" "/etc/nginx/conf.d/${PROTOCOL}.conf"
   else
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    CouchPotatoServer proxying disabled"
      sed -i "s%^   include /etc/nginx/locations/couchpotato.conf;$%#   include /etc/nginx/locations/couchpotato.conf;%" "/etc/nginx/conf.d/${PROTOCOL}.conf"
   fi
}

SickGear(){
   if [ ! -z "${SICKGEAR}" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    SickGear proxying enabled"
      sed -i -e "s%proxy_pass          http://.*:8081;$%proxy_pass          http://${SICKGEAR}:8081;%g" /etc/nginx/locations/sickgear.conf
      sed -i "s%^#   include /etc/nginx/locations/sickgear.conf;$%   include /etc/nginx/locations/sickgear.conf;%" "/etc/nginx/conf.d/${PROTOCOL}.conf"
   else
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    SickGear proxying disabled"
      sed -i "s%^   include /etc/nginx/locations/sickgear.conf;$%#   include /etc/nginx/locations/sickgear.conf;%" "/etc/nginx/conf.d/${PROTOCOL}.conf"
   fi
}

Headphones(){
   if [ ! -z "${HEADPHONES}" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Headphones proxying enabled"
      sed -i -e "s%proxy_pass          http://.*:8181;$%proxy_pass          http://${HEADPHONES}:8181;%g" /etc/nginx/locations/headphones.conf
      sed -i "s%^#   include /etc/nginx/locations/headphones.conf;$%   include /etc/nginx/locations/headphones.conf;%" "/etc/nginx/conf.d/${PROTOCOL}.conf"
   else
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Headphones proxying disabled"
      sed -i "s%^   include /etc/nginx/locations/headphones.conf;$%#   include /etc/nginx/locations/headphones.conf;%" "/etc/nginx/conf.d/${PROTOCOL}.conf"
   fi
}

MusicBrainz(){
   if [ ! -z "${MUSICBRAINZ}" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    MusicBrainz proxying enabled"
      sed -i -e "s%proxy_pass          http://.*:5000;$%proxy_pass          http://${MUSICBRAINZ}:5000;%g" /etc/nginx/locations/musicbrainz.conf
      sed -i "s%^#   include /etc/nginx/locations/musicbrainz.conf;$%   include /etc/nginx/locations/musicbrainz.conf;%" "/etc/nginx/conf.d/${PROTOCOL}.conf"
   else
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    MusicBrainz proxying disabled"
      sed -i "s%^   include /etc/nginx/locations/musicbrainz.conf;$%#   include /etc/nginx/locations/musicbrainz.conf;%" "/etc/nginx/conf.d/${PROTOCOL}.conf"
   fi
}

Subsonic(){
   if [ ! -z "${SUBSONIC}" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Subsonic proxying enabled"
      sed -i -e "s%proxy_pass          http://.*:4040;$%proxy_pass          http://${SUBSONIC}:4040;%g" /etc/nginx/locations/subsonic.conf
      sed -i "s%^#   include /etc/nginx/locations/subsonic.conf;$%   include /etc/nginx/locations/subsonic.conf;%" "/etc/nginx/conf.d/${PROTOCOL}.conf"
   else
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Subsonic proxying disabled"
      sed -i "s%^   include /etc/nginx/locations/subsonic.conf;$%#   include /etc/nginx/locations/subsonic.conf;%" "/etc/nginx/conf.d/${PROTOCOL}.conf"
   fi
}

Nextcloud(){
   if [ ! -z "${NEXTCLOUD}" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Nextcloud proxying enabled"
      sed -i -e "s%fastcgi_pass .*:9000;$%fastcgi_pass ${NEXTCLOUD}:9000;%g" /etc/nginx/locations/nextcloud.conf
      sed -i "s%^#   include /etc/nginx/locations/nextcloud.conf;$%   include /etc/nginx/locations/nextcloud.conf;%" "/etc/nginx/conf.d/${PROTOCOL}.conf"
   else
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Nextcloud proxying disabled"
      sed -i "s%^   include /etc/nginx/locations/nextcloud.conf;$%#   include /etc/nginx/locations/nextcloud.conf;%" "/etc/nginx/conf.d/${PROTOCOL}.conf"
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
#MusicBrainz
#Subsonic
Nextcloud
LaunchNGINX