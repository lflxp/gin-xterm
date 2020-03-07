.PHONY: push install clean all

push: 
	git add .
	git commit -m "`date`"
	git push origin master

all: install
	npm run dev

run: 
	npm run dev

install: Makefile pre
	npm install

pre:
	@echo 检查安装环境
	npm version

clean:
	rm -rf node_modules