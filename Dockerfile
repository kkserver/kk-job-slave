FROM alpine:latest

RUN apk add --update git bash && rm -rf /var/cache/apk/* 

RUN echo "Asia/shanghai" >> /etc/timezone

COPY ./main /bin/kk-job-slave

RUN chmod +x /bin/kk-job-slave

ENV KK_NAME kk.job.slave.*

ENV KK_ADDRESS kkmofang.cn:87

ENV KK_BASEURL kk.job.

ENV KK_TOKEN 1

VOLUME /workdir

CMD kk-job-slave $KK_NAME $KK_ADDRESS $KK_BASEURL $KK_TOKEN /workdir

