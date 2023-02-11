FROM nginx
COPY ./nginx-entrypoint.sh /
RUN chmod +x /nginx-entrypoint.sh
RUN apt-get update
RUN apt-get -y install cron
RUN crontab -l | { cat; echo "@daily nginx -s reload"; } | crontab -
#RUN crontab -l | { cat; echo "* * * * * echo Running crontab >> /var/log/cron.log"; } | crontab -
ENTRYPOINT ["/nginx-entrypoint.sh"]