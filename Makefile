PREFIX = /usr

UNAMEA := $(shell uname -a)
COND_DARWIN := $(if $(findstring Darwin,$(UNAMEA)),1)
COND_CYGWIN := $(if $(findstring CYGWIN,$(UNAMEA)),1)
COND_LINUX  := $(if $(findstring Linux,$(UNAMEA)),1)
ifeq ($(COND_DARWIN),1)
  $(message This is homebrew)
  XML_CATALOG_FILES=/usr/local/etc/xml/catalog
  export XML_CATALOG_FILES
endif

# Kludge: add go-1.10 to PATH in case we're on ubuntu 16.04 and have golang-1.10 installed
PATH:=/usr/lib/go-1.10/bin:$(PATH)

all: bau.1 bau obs
ifneq ($(COND_CYGWIN),1)
all: renderizer gitlab-ci-linter
endif

%.1: %.1.txt
	# don't fail if manpage can't be formatted, e.g. on windows
	a2x --doctype manpage --format manpage $*.1.txt || touch $*.1

#VERSION := $(shell obs get-version)
# Integer version
# (version major * 1000 + version minor)
VERSIONOID_GIT := $(shell echo $$(( $$(sh ./obs.in get-major-version-git) * 1000 + $$(sh ./obs.in get-minor-version-git) )) )
# Alas, until we script brew updates differently, must hardcode version here.
# Must edit VERSIONOID in both Makefile and msys-install.sh
VERSIONOID := 1042

# gnu make double-colon means only applies if dependency exists
%:: %.in Makefile
	echo VERSIONOID is $(VERSIONOID)
	sed 's/@VERSIONOID@/$(VERSIONOID)/' < $< > $@
	chmod +x $@

renderizer:
	if test -x /usr/bin/go || test -x /usr/lib/go-1.10/bin; then \
	 go get github.com/dankegel/renderizer; \
	 cp ~/go/bin/renderizer .; \
	else \
         touch renderizer; \
	fi

gitlab-ci-linter:
	if test -x /usr/bin/go || test -x /usr/lib/go-1.10/bin; then \
	 go get github.com/orobardet/gitlab-ci-linter; \
	 cp ~/go/bin/gitlab-ci-linter .; \
	else \
         touch gitlab-ci-linter; \
	fi

check: check-apt check-bau check-obs check-ob-set-defaults check-uberbau check-version

# Note: check-filter and check-parse have been disabled and moved to a licensing
# subdirectory because scancode is undeployable, and can't reliably pass tests.
# It's still very useful interactively when doing source code licensing work,
# as long as you enable
# https://launchpad.net/~dank/+archive/ubuntu/python-fixes

check-version: obs
	# Assert they are equal
	# Skip if try or homebrew build
	if test "$(VERSIONOID)" != "$(VERSIONOID_GIT)"; then \
	   if ./obs is-try || env | grep HOMEBREW; then \
		echo "Note: VERSIONOID $(VERSIONOID) != VERSIONOID_GIT $(VERSIONOID_GIT)"; \
		echo "Don't forget to update VERSIONOID in Makefile when you tag a release."; \
	   else \
		echo "Error: VERSIONOID $(VERSIONOID) != VERSIONOID_GIT $(VERSIONOID_GIT)"; \
		echo "Probably need to update VERSIONOID in Makefile."; \
		exit 1; \
	   fi; \
	fi

# We should use 'bats foo.bats', but bats is just too stingy with
# output.  So instead write tests so they can run either as bats
# tests or normal shell scripts, and just run them as the latter.
# Feel free to run them with bats when testing by hand.
# FIXME: flip the default and just use bats someday.

check-apt: obs
	egrep -v '@test|^}$$' < apt.bats > apt-test.sh
	sh -xe apt-test.sh
	rm apt-test.sh

check-bau: obs bau
	egrep -v '@test|^}$$' < bau.bats > bau-test.sh
	sh -xe bau-test.sh
	rm bau-test.sh

check-obs: obs
	egrep -v '@test|^}$$' < obs.bats > obs-test.sh
	sh -xe obs-test.sh
	rm obs-test.sh


check-uberbau: obs bau
	egrep -v '@test|^}$$' < uberbau.bats > uberbau-test.sh
	sh -xe uberbau-test.sh
	rm uberbau-test.sh

check-ob-set-defaults:
	egrep -v '@test|^}$$' < ob-set-defaults.bats > ob-set-defaults-test.sh
	sh -xe ob-set-defaults-test.sh
	rm ob-set-defaults-test.sh

ifeq ($(COND_CYGWIN),1)
check-win:
	egrep -v '@test|^}$$' < win.bats > win.sh
	sh -xe win.sh
	rm win.sh
endif

install: install-bau install-obs install-go

install-go: renderizer gitlab-ci-linter
ifneq ($(COND_CYGWIN),1)
	if test -x /usr/bin/go || test -x /usr/lib/go-1.10/bin; then \
	 install -m 755 renderizer $(DESTDIR)$(PREFIX)/bin; \
	 install -m 755 gitlab-ci-linter $(DESTDIR)$(PREFIX)/bin; \
	fi
endif

install-bau: bau.1 bau baugen.sh
	install -m 755 -d $(DESTDIR)$(PREFIX)/bin
	install -m 755 bau $(DESTDIR)$(PREFIX)/bin
	install -m 755 baugen.sh $(DESTDIR)$(PREFIX)/bin
	install -m 755 ob-coverage.sh $(DESTDIR)$(PREFIX)/bin
	install -m 755 uberbau $(DESTDIR)$(PREFIX)/bin
	install -m 755 -d $(DESTDIR)$(PREFIX)/share/man/man1
	install -m 644 bau.1 $(DESTDIR)$(PREFIX)/share/man/man1/bau.1
	# fixme: should install bau-defaults to share, but that's awkward for now
	install -m 755 -d $(DESTDIR)$(PREFIX)/bin/bau-defaults
	install -m 644 bau-defaults/buildshim-ubu $(DESTDIR)$(PREFIX)/bin/bau-defaults/buildshim-ubu
	install -m 644 bau-defaults/buildshim-osx $(DESTDIR)$(PREFIX)/bin/bau-defaults/buildshim-osx
	install -m 644 bau-defaults/buildshim-win $(DESTDIR)$(PREFIX)/bin/bau-defaults/buildshim-win
	install -m 644 bs_funcs.sh $(DESTDIR)$(PREFIX)/bin

install-obs: obs
	install -m 755 -d $(DESTDIR)$(PREFIX)/bin
	install -m 644 obs_funcs.sh $(DESTDIR)$(PREFIX)/bin
	install -m 755 ob-set-defaults $(DESTDIR)$(PREFIX)/bin
	install -m 755 ob-set-targets $(DESTDIR)$(PREFIX)/bin
	install -m 755 obs ob-remove.sh $(DESTDIR)$(PREFIX)/bin
	install -m 755 ob-list-dbg-pkgs $(DESTDIR)$(PREFIX)/bin
	install -m 755 licensing/ob-list-licenses $(DESTDIR)$(PREFIX)/bin
	install -m 755 licensing/ob-filter-licenses $(DESTDIR)$(PREFIX)/bin
	install -m 755 licensing/ob-parse-licenses $(DESTDIR)$(PREFIX)/bin
	install -m 755 ob-build-deps $(DESTDIR)$(PREFIX)/bin

uninstall: uninstall-bau uninstall-obs

uninstall-bau:
	rm -rf \
           $(DESTDIR)$(PREFIX)/bin/bau \
           $(DESTDIR)$(PREFIX)/bin/bau-defaults \
           $(DESTDIR)$(PREFIX)/bin/bs_funcs.sh \
           $(DESTDIR)$(PREFIX)/bin/ob-coverage.sh \
           $(DESTDIR)$(PREFIX)/bin/uberbau \
           $(DESTDIR)$(PREFIX)/share/man/man1/bau.1 \
           #

uninstall-obs:
	rm -rf \
           $(DESTDIR)$(PREFIX)/bin/ob-remove.sh \
           $(DESTDIR)$(PREFIX)/bin/obs \
           $(DESTDIR)$(PREFIX)/bin/ob-set-defaults \
           $(DESTDIR)$(PREFIX)/bin/ob-set-targets \
           $(DESTDIR)$(PREFIX)/bin/obs_funcs.sh \
           #

clean:
	rm -rf *.tmp bau.1 obs bau renderizer gitlab-ci-linter
