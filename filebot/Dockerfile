FROM openjdk:8

ADD ./FileBot_4.7.9-portable.tar.xz /opt/filebot

RUN apt-get update && apt-get install -y libmediainfo-dev

WORKDIR /opt/filebot

ENTRYPOINT ["/opt/filebot/filebot.sh"]
