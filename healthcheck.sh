#!/bin/ash

check_container_startup_ip(){
   local container_name=$1
   grep "${container_name}" /tmp/startup_ips.txt | awk '{print $1}'
}

check_container_current_ip(){
   local container_name=$1
   getent hosts "${container_name}" | awk '{print $1}'
}

test_container_ip(){
   local container_name=$1
   if [ "$(check_container_startup_ip "${container_name}")" != "$(check_container_current_ip "${container_name}")" ]; then
      echo "IP address incorrect for ${container_name}"
      exit 1
   fi
}

if [ "$(nc -z "$(hostname -i)" 80; echo $?)" -ne 0 ]; then
   echo "HTTP server not available"
   exit 1
fi

if [ "$(nc -z "$(hostname -i)" 443; echo $?)" -ne 0 ]; then
   echo "HTTPS server not available"
   exit 1
fi

for lets_encrypt_domain in ${lets_encrypt_domains}; do
   letsencrypt_cert_name="$(ls -rt /etc/letsencrypt/archive/${lets_encrypt_domain}/cert*.pem | tail -n 1)"
   letsencrypt_md5_hash="$("$(which md5sum)" "${letsencrypt_cert_name}" | awk '{print $1}')"
   nginx_md5_hash="$(cat "${config_dir}/${lets_encrypt_domain}/cert.md5")"
   if [ "${letsencrypt_md5_hash}" != "${nginx_md5_hash}" ]; then
      echo "Certificate hash ${letsencrypt_md5_hash} for domain ${lets_encrypt_domain} does not match nginx certificate hash: ${nginx_md5_hash}."
      exit 1
   fi
done

test_container_ip sabnzbd
test_container_ip transmission
test_container_ip jellyfin
test_container_ip subsonic
test_container_ip lidarr
test_container_ip radarr
test_container_ip sonarr
test_container_ip nextcloud

echo "NGINX responding to HTTP & HTTPS requests and all containers using correct IPs"
exit 0