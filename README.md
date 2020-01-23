# docker-nginx

# An Alpine Linux based Docker container for NGINX to reverse proxy other components of the stack

## MANDATORY VARIABLES

media_access_domain: This is the domain name that nginx will be configured to respond on for HTTPS requests. It will also be used for locating the Let's Encrypt certificate

## OPTIONAL VARIABLES

nextloud_access_domain: If this is specified, it will configure the Nextcloud access domain to be different to the media access domain.

user_id: If you wish to change the user ID of the nginx account within the container, you can set the new value in this variable.

group_id: If you wish to change the group ID of the nginx account within the container, you can set the new value in this variable.

nginx_lan_logging: If this is set to 'True', NGINX will be configured to log all traffic. The default setting for this container is to ignore all requests from 10.x.x.x, 172.16-31.x.x and 192.168.x.x

nginx_xenophobia: If this option is present, NGINX will be configured to ignore traffic from all countries except the one specified in the variable. The country should be identified by the ISO 3166-1 alpha-2 two character country code. The full list can be found [here](https://en.wikipedia.org/wiki/ISO_3166-1_alpha-2)

sabnzbd_enabled: If this variable is present, NGINX will be configured to act as a reverse proxy to a boredazfcuk/sabnzbd container.

deluge_enabled: If this variable is present, NGINX will be configured to act as a reverse proxy to a boredazfcuk/deluge container.

couchpotato_enabled: If this variable is present, NGINX will be configured to act as a reverse proxy to a boredazfcuk/couchpotatoserver container.

sickgear_enabled: If this variable is present, NGINX will be configured to act as a reverse proxy to a boredazfcuk/sickgear container.

headphones_enabled: If this variable is present, NGINX will be configured to act as a reverse proxy to a boredazfcuk/headphones container.

subsonic_enabled: If this variable is present, NGINX will be configured to act as a reverse proxy to a boredazfcuk/subsonic container.

nextcloud_enabled: If this variable is present, NGINX will be configured to server a boredazfcuk/nextcloud container. It will also require volumes mapping as per volumes section below

## VOLUME CONFIGURATION

The container doesn't need any volumes as it will reset and recreate the configuration each time the container is launched. However, if you want to make modifications and have then persist when the container is recreated, then it is best to creat a named volume and map it to /etc/nginx inside the container.

Example:
```
   --volume nginx_config:/etc/nginx/ \
```

If you wish the container to have a persistent cache, map a volume to this location inside the container.

Example:
```
   --volume nginx_cache:/var/cache/nginx/ \
```

This NGINX container requires a GeoIP database to lookup the country of the connecting IP address. The database will need to be a legacy MaxMind database stored in /usr/share/GeoIP/. If your host computer has the DB installed, you can use a bind mount to map it inside the container. If you do not have the GeoIP Db installed on the host computer one can be created using the boredazfcuk/geoipdb container

Example:
```
   --volume /usr/share/GeoIP/:/usr/share/GeoIP/ \
```

This NGINX container requires a LetsEncrypt certificate for your media_access_domain and also you nextcloud_access_domain if one is configured. If the certificates exist on the host, you can map them into the container using a bind mount. If you do not have Let's Encrypt certificates for your domain you can create and maintain them using boredazfcuk/letsencrypt

Example:
```
   --volume /etc/letsencrypt/:/etc/letsencrypt/ \
```

If the NGINX container is configured to serve a Nextcloud installation, the container will need the nextcloud website and data directories mapped locally

Example:
```
   --volume nextcloud_website:/var/www/html/
   --volume /mnt/hd1/nextcloud_data/:/nextcloud_data/
```

## CREATING A CONTAINER

This is an example command which could be used to create this NGINX container, but personally, I'd recommend using [steve](https://github.com/boredazfcuk/steve):

EXAMPLE:
```
docker create \
   --name NGINX \
   --hostname nginx \
   --network containers \
   --restart always \
   --env TZ=Europe/London \
   --publish 80:80 \
   --publish 443:443 \
   --env media_access_domain=notreallymydomain.com \
   --env nginx_lan_logging=True \
   --env nginx_xenophobia=GB \
   --env sabnzbd_enabled=True \
   --env deluge_enabled=True \
   --env couchpotato_enabled=True \
   --env sickgear_enabled=True \
   --env headphones_enabled=True \
   --env nextcloud_enabled=True \
   --volume nginx_config:/etc/nginx \
   --volume nginx_cache:/var/cache/nginx \
   --volume /usr/share/GeoIP/:/usr/share/GeoIP/ \
   --volume /etc/letsencrypt/:/etc/letsencrypt/ \
   --volume nextcloud_website:/var/www/html/ \
   --volume /mnt/hd1/nextcloud_data/:/nextcloud_data/ \
   boredazfcuk/nginx
```
