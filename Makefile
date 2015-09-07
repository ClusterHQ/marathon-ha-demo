.PHONY: cluster ami

cluster:
	bash cluster.sh

destroy:
	vagrant destroy -f

ami:
	cd amibuilder && bash build.sh