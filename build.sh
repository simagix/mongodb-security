#! /bin/bash
# Copyright 2019 Kuei-chun Chen. All rights reserved.

docker-compose down

export ver="4.2"
docker build -t simagix/kerberos -f kerberos/Dockerfile .
docker build -t simagix/openldap -f openldap/Dockerfile .
docker build -t simagix/mongo-kerberos:latest -t simagix/mongo-kerberos:${ver} -f mongo/Dockerfile .

docker rmi -f $(docker images -f "dangling=true" -q)
