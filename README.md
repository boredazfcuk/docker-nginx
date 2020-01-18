# docker-nginx

# An Alpine Linux based Docker container for NGINX to reverse proxy specific web services

## MANDATORY VARIABLES

DOMAINNAME: If the HTTPS variable is set to 'True', then the DOMAINNAME variable becomes mandatory. It should then be set to be the primary domain that your certificate is valid for. It will also use this domainname in the path to the LetsEncrypt certificates

## OPTIONAL VARIABLES

user_id: If you wish to change the user ID of the nginx account within the container, you can set the new value in this variable.

GID: If you wish to change the group ID of the nginx account within the container, you can set the new value in this variable.

DOMAINNAME: The default configuration of this NGINX container is to respond to all requests. Setting the DOMAINNAME option will restrict the server to only respond to requests for that domain. This option becomes mandatory if HTTPS is set to 'True'

HTTPS: If this is set to 'True', NGINX will be configured to use https instead of http. It will also requre a domain name to be set.

nginx_lan_logging: If this is set to 'True', NGINX will be configured to log all traffic. The default setting for this container is to ignore all requests from 10.x.x.x, 172.16-31.x.x and 192.168.x.x

nginx_xenophobia: If this option is present, NGINX will be configured to ignore traffic from all countries except the one specified in the variable. The country should be identified by the ISO 3166-1 alpha-2 two character country code. The full list can be foucn [here](https://en.wikipedia.org/wiki/ISO_3166-1_alpha-2)

SABNZBD: If this variable is present, NGINX will be configured to act as a reverse proxy to a Sabnzbd image. The variable should be the name of the SABnzbd container.

DELUGE: If this variable is present, NGINX will be configured to act as a reverse proxy to a Deluge image. The variable should be the name of the Deluge container.

COUCHPOTATO: If this variable is present, NGINX will be configured to act as a reverse proxy to a CouchPotatoServer image. The variable should be the name of the SickGear container.

SICKGEAR: If this variable is present, NGINX will be configured to act as a reverse proxy to a SickGear image. The variable should be the name of the SickGear container.

HEADPHONES: If this variable is present, NGINX will be configured to act as a reverse proxy to a Headphones image. The variable should be the name of the Headphones container.

NEXTCLOUD: If this variable is present, NGINX will be configured to serve a Nextcloud installation. The variable should be the name of the Nextcloud container. The container will also need to be created with the 'volumes-from' option set to the name of your Nextcloud container.

## VOLUME CONFIGURATION

The container doesn't need any volumes as it will reset and recreate the configuration each time the container is launched. However, if you want to make modifications and have then persist when the container is recreated, then it is best to creat a named volume and map it to /etc/nginx inside the container.

Example:
```
   --volume nginx_config:/etc/nginx \
```

IF you wish the container to have a persistent cache, map a volume to this location inside the container.

Example:
```
   --volume nginx_cache:/var/cache/nginx \
```

If the NGINX container is configured to block access from foreign countries it will require a GeoIP database to lookup the country of the connecting IP address. The database will need to be a legacy MaxMind database stored in /usr/share/GeoIP. If your host computer has the DB installed, you can use a bind mount to map it inside the container.

Example:
```
   --volume /usr/share/GeoIP/:/usr/share/GeoIP/ \
```

If the NGINX container is configured to use HTTPS, then it will need to be configured with certificates issued by LetsEncrypt. If the host has certificates installed, you can map them into the container using a bind mount.

Example:
```
   --volume /etc/letsencrypt/:/etc/letsencrypt/ \
```

If the NGINX container is configured to serve a Nextcloud installation, then it will need to have the Nextcloud volumes attached to it. Do this by specifying

--volumes-from <Nextcloud container name> \

## CREATING A CONTAINER

This is the command I use to create my NGINX container:

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
   --env DOMAINNAME=notreallymydomain.com \
   --env HTTPS=True \
   --env nginx_lan_logging=True \
   --env nginx_xenophobia=GB \
   --env SABNZBD=OpenVPNPIA \
   --env DELUGE=OpenVPNPIA \
   --env COUCHPOTATO=OpenVPNPIA \
   --env SICKGEAR=OpenVPNPIA \
   --env HEADPHONES=OpenVPNPIA \
   --env NEXTCLOUD=Nextcloud \
   --volume nginx_config:/etc/nginx \
   --volume nginx_cache:/var/cache/nginx \
   --volume /usr/share/GeoIP/:/usr/share/GeoIP/ \
   --volume /etc/letsencrypt/:/etc/letsencrypt/ \
   --volumes-from Nextcloud \
   boredazfcuk/nginx
```
