FROM nginx:stable-alpine
MAINTAINER boredazfcuk
ARG nginx_version="1.20.0"
ARG build_dependencies="git build-base pcre-dev zlib-dev wget"
ARG app_dependencies="shadow apache2-utils"
ENV config_dir="/etc/nginx" 

RUN echo "$(date '+%d/%m/%Y - %H:%M:%S') | ***** BUILD STARTED FOR NGINX *****" && \
   mkdir "${config_dir}/locations/" && \
echo "$(date '+%d/%m/%Y - %H:%M:%S') | Install build dependencies" && \
   apk add --no-cache --no-progress --virtual=build-deps ${build_dependencies} && \
echo "$(date '+%d/%m/%Y - %H:%M:%S') | Install nginx dependencies" && \
   apk add --no-cache --no-progress ${app_dependencies} && \
echo "$(date '+%d/%m/%Y - %H:%M:%S') | Add nginx GeoIP module" && \
   apk add --no-cache --no-progress nginx-mod-http-geoip && \
echo "$(date '+%d/%m/%Y - %H:%M:%S') | Download and build nginx substitutions module" && \
   temp_dir="$(mktemp -d)" && \
   cd "${temp_dir}" && \
   nginx_version="$(nginx -v 2>&1 | awk 'BEGIN { FS = "/" } ; {print $2}')" && \
   wget -4 "https://nginx.org/download/nginx-${nginx_version}.tar.gz" && \
   tar -xzvf "nginx-${nginx_version}.tar.gz" && \
   git clone https://github.com/yaoweibin/ngx_http_substitutions_filter_module.git && \
   cd "nginx-${nginx_version}" && \
   ./configure --with-compat --add-dynamic-module=../ngx_http_substitutions_filter_module && \
   make modules && \
   cp objs/ngx_http_subs_filter_module.so /etc/nginx/modules/ && \
echo "$(date '+%d/%m/%Y - %H:%M:%S') | Backup default nginx config" && \
   mv -v "/usr/share/nginx/html" "/usr/share/nginx/html.default" && \
   mv -v "${config_dir}/nginx.conf" "${config_dir}/nginx.conf.default" && \
   mv -v "${config_dir}/conf.d/default.conf" "${config_dir}/conf.d/default.conf.default" && \
echo "$(date '+%d/%m/%Y - %H:%M:%S') | Remove build dependencies" && \
   apk del build-deps && \
   rm -r "${temp_dir}" && \
echo "$(date '+%d/%m/%Y - %H:%M:%S') | ***** BUILD COMPLETE *****"

COPY nginx/* "${config_dir}/"
COPY conf.d/* "${config_dir}/conf.d/"
COPY locations/* "${config_dir}/locations/"
COPY --chmod=0755 entrypoint.sh /usr/local/bin/entrypoint.sh
COPY --chmod=0755 healthcheck.sh /usr/local/bin/healthcheck.sh

HEALTHCHECK --start-period=10s --interval=1m --timeout=10s \
   CMD /usr/local/bin/healthcheck.sh

VOLUME "${config_dir}" /var/cache/nginx/

ENTRYPOINT "/usr/local/bin/entrypoint.sh"