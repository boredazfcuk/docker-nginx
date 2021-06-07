#!/bin/ash

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

echo "NGINX responding to HTTP and HTTPS requests"
exit 0