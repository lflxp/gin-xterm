.PHONY: push node_modules

push: node_modules
	git add .
	git commit -m "`date`"
	git push

node_modules: Makefile
	npm install