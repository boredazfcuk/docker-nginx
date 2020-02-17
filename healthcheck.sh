#!/bin/ash

if [ "$(nc -z "$(hostname -i)" 80; echo "${?}")" -ne 0 ]; then
   echo "HTTP server not available"
   exit 1
fi

if [ "$(nc -z "$(hostname -i)" 443; echo "${?}")" -ne 0 ]; then
   echo "HTTPS server not available"
   exit 1
fi

echo "NGINX responding to HTTP and HTTPS requests"
exit 0