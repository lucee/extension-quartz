# Lucee with the Quartz extension and its MCP interface, see README.md
# The build context is the root of this repository (docker-compose.yml takes care of that),
# the extension is expected in target/ (mvn clean install).
ARG LUCEE_IMAGE=lucee/lucee:7.1.0.204-light
FROM ${LUCEE_IMAGE}

# the extension, Lucee installs everything in the deploy folder on startup
COPY target/ /tmp/target/
RUN set -e; \
    lex="$(ls /tmp/target/quartz-extension-*.lex | grep -v '\.lite\.lex$' | head -n 1)"; \
    echo "installing $lex"; \
    mkdir -p /opt/lucee/server/lucee-server/deploy; \
    cp "$lex" /opt/lucee/server/lucee-server/deploy/; \
    rm -rf /tmp/target

# Lucee configuration (scheduler log to the console)
COPY examples/docker/lucee-config.json /opt/lucee/server/lucee-server/context/.CFConfig.json

# scheduler configuration with the dummy jobs and the MCP settings
COPY examples/docker/config.json /opt/quartz/config.json
ENV QUARTZ_CONFIGFILE=/opt/quartz/config.json

# webroot with the page to try the MCP interface
COPY examples/docker/www/ /var/www/

EXPOSE 8888
