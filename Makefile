.PHONY: nodes destroy ami app

nodes:
	@bash createnodes.sh

destroy:
	@bash destroynodes.sh

ami:
	@cd amibuilder && bash build.sh

app:
	@bash createapp.sh

info:
	@bash getinfo.sh