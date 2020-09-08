FROM dlanguage/dmd:2.080.0

ENV DEBIAN_FRONTEND noninteractive

EXPOSE 8080

RUN apt-get update \
 && apt-get install -y --no-install-recommends libcurl4-gnutls-dev libevent-dev libssl-dev libmysqlclient-dev \
 && apt-get clean && rm -rf /var/lib/apt/lists/* /var/cache/apt \
 && dub upgrade

USER nobody

ENTRYPOINT ["/api"]