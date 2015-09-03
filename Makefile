.PHONY: cluster ami

cluster:
	bash cluster.sh

ami:
	cd amibuilder && bash build.sh