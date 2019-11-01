#!/bin/bash

h1ip=192.168.122.11

ssh h1 "docker swarm init --advertise-addr $h1ip"
manager_token=`ssh h1 "docker swarm join-token manager -q"`
worker_token=`ssh h1 "docker swarm join-token worker -q"`

for manager in h{2..3}; do
	ssh $manager "docker swarm join --token $manager_token $h1ip:2377" &
done

for worker in n{1..4}; do
	ssh $worker "docker swarm join --token $worker_token $h1ip:2377" &
done

wait

ssh h1 "docker node ls"

