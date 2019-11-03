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

export DOCKER_HOST=h1
docker node ls

# to build registry.tar (or other images):
# docker pull registry:2
# docker run -d --name registry-export
# docker export registry-export -o registry.tar

# ensure nodes have registry image
for h in h{1..3} n{1..4}; do DOCKER_HOST=$h docker import registry.tar registry:2 & done
wait

# bring up local registry
docker service create --name registry --publish published=5000,target=5000 registry:2

# import previously 
for image_name in nginx alpine
do
	docker import ${image_name}.tar 127.0.0.1:5000/${image_name}
	docker push 127.0.0.1:5000/${image_name}
done

docker stack deploy -c stack1.yml s1
