FROM debian:bullseye-slim

LABEL maintainer="NGINX Docker Maintainers <docker-maint@nginx.com>"

# Define NGINX versions for NGINX Plus and NGINX Plus modules
# Uncomment this block and the versioned nginxPackages block in the main RUN
# instruction to install a specific release
# ENV NGINX_VERSION   29
# ENV NJS_VERSION     0.7.12
# ENV PKG_RELEASE     1~bullseye

# Download certificate and key from the customer portal (https://account.f5.com)
# and copy to the build context
RUN --mount=type=secret,id=nginx-crt,dst=nginx-repo.crt \
  --mount=type=secret,id=nginx-key,dst=nginx-repo.key \
  set -x \
  # Create nginx user/group first, to be consistent throughout Docker variants
  && addgroup --system --gid 101 nginx \
  && adduser --system --disabled-login --ingroup nginx --no-create-home --home /nonexistent --gecos "nginx user" --shell /bin/false --uid 101 nginx \
  && apt-get update \
  && apt-get install --no-install-recommends --no-install-suggests -y \
  ca-certificates \
  gnupg1 \
  lsb-release \
  && \
  NGINX_GPGKEY=573BFD6B3D8FBC641079A6ABABF5BD827BD9BF62; \
  NGINX_GPGKEY_PATH=/usr/share/keyrings/nginx-archive-keyring.gpg; \
  export GNUPGHOME="$(mktemp -d)"; \
  found=''; \
  for server in \
  hkp://keyserver.ubuntu.com:80 \
  pgp.mit.edu \
  ; do \
  echo "Fetching GPG key $NGINX_GPGKEY from $server"; \
  gpg1 --keyserver "$server" --keyserver-options timeout=10 --recv-keys "$NGINX_GPGKEY" && found=yes && break; \
  done; \
  test -z "$found" && echo >&2 "error: failed to fetch GPG key $NGINX_GPGKEY" && exit 1; \
  gpg1 --export "$NGINX_GPGKEY" > "$NGINX_GPGKEY_PATH" ; \
  rm -rf "$GNUPGHOME"; \
  apt-get remove --purge --auto-remove -y gnupg1 && rm -rf /var/lib/apt/lists/* \
  # Install the latest release of NGINX Plus and/or NGINX Plus modules
  # Uncomment individual modules if necessary
  # Use versioned packages over defaults to specify a release
  && nginxPackages=" \
  nginx-plus \
  # nginx-plus=${NGINX_VERSION}-${PKG_RELEASE} \
  # nginx-plus-module-xslt \
  # nginx-plus-module-xslt=${NGINX_VERSION}-${PKG_RELEASE} \
  # nginx-plus-module-geoip \
  # nginx-plus-module-geoip=${NGINX_VERSION}-${PKG_RELEASE} \
  # nginx-plus-module-image-filter \
  # nginx-plus-module-image-filter=${NGINX_VERSION}-${PKG_RELEASE} \
  # nginx-plus-module-perl \
  # nginx-plus-module-perl=${NGINX_VERSION}-${PKG_RELEASE} \
  # nginx-plus-module-njs \
  # nginx-plus-module-njs=${NGINX_VERSION}+${NJS_VERSION}-${PKG_RELEASE} \
  " \
  && echo "Acquire::https::pkgs.nginx.com::Verify-Peer \"true\";" > /etc/apt/apt.conf.d/90nginx \
  && echo "Acquire::https::pkgs.nginx.com::Verify-Host \"true\";" >> /etc/apt/apt.conf.d/90nginx \
  && echo "Acquire::https::pkgs.nginx.com::SslCert     \"/etc/ssl/nginx/nginx-repo.crt\";" >> /etc/apt/apt.conf.d/90nginx \
  && echo "Acquire::https::pkgs.nginx.com::SslKey      \"/etc/ssl/nginx/nginx-repo.key\";" >> /etc/apt/apt.conf.d/90nginx \
  && printf "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] https://pkgs.nginx.com/plus/debian `lsb_release -cs` nginx-plus\n" > /etc/apt/sources.list.d/nginx-plus.list \
  && mkdir -p /etc/ssl/nginx \
  && cat nginx-repo.crt > /etc/ssl/nginx/nginx-repo.crt \
  && cat nginx-repo.key > /etc/ssl/nginx/nginx-repo.key \
  && apt-get update \
  && apt-get install --no-install-recommends --no-install-suggests -y \
  $nginxPackages \
  curl \
  gettext-base \
  && apt-get remove --purge -y lsb-release \
  && apt-get remove --purge --auto-remove -y && rm -rf /var/lib/apt/lists/* /etc/apt/sources.list.d/nginx-plus.list \
  && rm -rf /etc/apt/apt.conf.d/90nginx /etc/ssl/nginx \
  # Forward request logs to Docker log collector
  && ln -sf /dev/stdout /var/log/nginx/access.log \
  && ln -sf /dev/stderr /var/log/nginx/error.log

EXPOSE 80

STOPSIGNAL SIGQUIT

CMD ["nginx", "-g", "daemon off;"]
