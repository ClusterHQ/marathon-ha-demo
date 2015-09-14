.PHONY: nodes destroy ami app

cluster:
	@bash createcluster.sh

destroy:
	@bash destroycluster.sh

ami:
	@cd amibuilder && bash build.sh

app:
	@bash createapp.sh

info:
	@bash getinfo.sh