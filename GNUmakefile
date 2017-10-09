# bash required!
SHELL:=/bin/bash
# Make "./node_modules/bin" the first path entry if it is not already in PATH.
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
	@echo 'NOTE: If you are seeing this message, then rebuild must have succeeded.'
	@echo '      However, this script is intentionally not doing anything for deployment'
	@echo '      per se, as it will/should be taken care of by gitlab-ci instead.'

watch: build
	gulp watch

# Both "live-server" and "gulp watch" watch files.  Make sure that they are
# not watching the same folder(s).  In such a case, it has been observed that
# "gulp watch" drops out (after couple of initial successes) silently.
live: build
	live-server --open=examples dist &
	gulp watch
