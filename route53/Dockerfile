ARG BUILD_FROM
FROM $BUILD_FROM

ENV LANG C.UTF-8

RUN apk update 
RUN apk upgrade 
RUN apk add python3 groff less curl
RUN pip3 install awscli
RUN pip3 install --upgrade pip


# Copy data for add-on
COPY run.sh /usr/bin/
RUN chmod a+x /usr/bin/run.sh

CMD [ "/usr/bin/run.sh" ]

LABEL io.hass.version="VERSION" io.hass.type="addon" io.hass.arch="armhf|aarch64|i386|amd64"
