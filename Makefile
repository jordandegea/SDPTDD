

all:
	@echo "Read me"

fulldevstart: 
	rake deploy run:format_hdfs services:start configure

dev: 
	export RAKE_ENV=development

prod: 
	export RAKE_ENV=development

reup:
	rake vagrant:reup

up:
	rake vagrant:up

deploy:
	rake deploy 

format:
	rake run:format_hdfs

start:
	rake services:start

configure:
	rake configure

