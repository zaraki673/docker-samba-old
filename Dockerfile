#Samba share for Raspberry Pi
FROM ubuntu:14:04

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends samba-common-bin samba

ADD run.sh /run.sh
RUN chmod u+x /run.sh

EXPOSE 445

ENTRYPOINT ["/run.sh"]
CMD ["-h"]
