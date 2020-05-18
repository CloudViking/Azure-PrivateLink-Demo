# Usage:
# make        		  # deploy full private link example, including web app
# make clean  		  # delete PL-ResourceGroup from Azure env

.PHONY: deploy_all deploy_PLS deploy_WebApp deploy_PE clean

deploy_all: deploy_PLS deploy_WebApp deploy_PE

deploy_PLS:
	@bash create-privateLinkService.sh

deploy_WebApp:
	@bash create-HelloWorldApp.sh

deploy_PE:
	@bash create-privateEndpoint.sh

clean:
	@bash destroy_env.sh
