FROM nginxinc/nginx-unprivileged:1.29-alpine

COPY --chown=101:101 index.html styles.css app.js /usr/share/nginx/html/
COPY --chown=101:101 config.js.template /etc/nginx/templates/config.js.template
COPY --chown=101:101 nginx.conf /etc/nginx/conf.d/default.conf

ENV API_URL=""
EXPOSE 8080
USER 101

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -q -O - http://127.0.0.1:8080/health || exit 1
