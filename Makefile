.PHONY: nodes destroy ami

nodes:
	bash createnodes.sh

destroy:
	bash destroynodes.sh

ami:
	cd amibuilder && bash build.sh