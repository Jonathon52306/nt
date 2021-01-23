FROM node:14.15.4 as builder-node
COPY ./web .
RUN  npm install -g cnpm \
    && cnpm install \
    && npm run build

FROM golang:alpine as builder

ENV GO111MODULE=on

ENV GOPROXY=https://goproxy.io,direct

WORKDIR /app

COPY . .
COPY --from=builder-node . ./web

RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.ustc.edu.cn/g' /etc/apk/repositories \
    && apk add gcc g++ \
    && go env && CGO_ENABLED=1 GOOS=linux GOARCH=amd64 go build -a -ldflags '-linkmode external -extldflags "-static"' -o next-terminal main.go

FROM guacamole/guacd:1.2.0

LABEL MAINTAINER="helloworld1024@foxmail.com"

RUN sed -i 's/deb.debian.org/mirrors.ustc.edu.cn/g' /etc/apt/sources.list \
    && apt-get update && apt-get -y install supervisor \
    && mkdir -p /var/log/supervisor
COPY --from=builder /app/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

ENV DB sqlite
ENV SQLITE_FILE 'next-terminal.db'
ENV SERVER_PORT $PORT
ENV SERVER_ADDR 0.0.0.0:$SERVER_PORT
ENV TIME_ZONE=Asia/Shanghai
RUN ln -snf /usr/share/zoneinfo/$TIME_ZONE /etc/localtime && echo $TIME_ZONE > /etc/timezone

WORKDIR /usr/local/next-terminal

COPY --from=builder /app/next-terminal ./
COPY --from=builder /app/web/build ./web/build
COPY --from=builder /app/web/src/fonts/Menlo-Regular-1.ttf /usr/share/fonts/

RUN mkfontscale && mkfontdir && fc-cache

EXPOSE $SERVER_PORT

RUN mkdir recording && mkdir drive
ENTRYPOINT /usr/bin/supervisord