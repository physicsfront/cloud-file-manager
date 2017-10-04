SHELL:=/bin/bash
PATHREGEX:=(:|^)\./node_modules/\.bin(:|$$)
ifeq "$(shell [[ $$PATH =~ $(PATHREGEX) ]] && echo 'y' || echo 'n' )" "n"
	export PATH:=./node_modules/.bin:$(PATH)
endif

all: build

again: rebuild

rebuild:
	gulp clean-and-build

build:
	gulp build-all

clean:
	gulp clean

deploy: rebuild
	@echo ''
	@echo 'NOTE: If you are seeing this message, the rebuild must have been completed.'
	@echo '      However, this script is intentionally not doing anything for deploy per se,'
	@echo '      which needs to be taken care of by gitlab-ci instead.'

watch:
	gulp watch

live-server: build
	live-server --open=dist/examples
