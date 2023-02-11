FROM certbot/dns-cloudflare
COPY ./certbot-entrypoint.sh /
RUN chmod +x /certbot-entrypoint.sh
ENTRYPOINT ["/certbot-entrypoint.sh"]