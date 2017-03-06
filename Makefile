export MAKEFLAGS := --no-print-directory --warn-undefined-variables

REQUIRED := make sed awk

#. === SIMBOL_USER_VAR
EXTERN_D := ${HOME}/.simbol/var
export EXTERN_D

export VCS_D=${CURDIR}

.DEFAULT: help

#. Site Bootstrap -={
#. Installation Status Check -={
#. Additional python modules that you want installed - this should be kept as
#. small as possible, and each simbol module should have it's own set of modules
#. defined via xplm.
VENV_PKGS :=
export VENV_PKGS

ifeq ($(wildcard .install),)
STATUS := "UNINSTALLED"
else
STATUS := "INSTALLED"
endif
#. }=-
#. Usage -={
.PHONY: help
help: require
	@echo "Current status  : ${STATUS}"
	@echo "Current profile : $(shell bin/activate)"
	@echo
	@echo "Usage:"
	@echo "    $(MAKE) install"
	@echo "    $(MAKE) uninstall"
#. }=-
#. REQUIRED Check -={
.PHONY: require
require:; @$(foreach req,$(REQUIRED:%.required=%),printf ${req}...;which ${req} || (echo FAIL && exit 1);)
#. }=-
#. Installation -={
.PHONY: install sanity
sanity:; @test ! -f .install
install: require sanity .install
	@echo "Installation complete!"

.install:
	@printf "Preparing ~/.simbol..."
	@mkdir -p $(HOME)/.simbol
	@ln -s ${HOME}/.simbol/profiles.d/ACTIVE/lib ${HOME}/.simbol/lib
	@ln -s ${HOME}/.simbol/profiles.d/ACTIVE/etc ${HOME}/.simbol/etc
	@ln -s ${HOME}/.simbol/profiles.d/ACTIVE/module ${HOME}/.simbol/module
	@ln -s ${HOME}/.simbol/profiles.d/ACTIVE/libexec ${HOME}/.simbol/libexec
	@echo "DONE"
	@printf "Setting up initial profile..."
	@ln -sf $(CURDIR) $(HOME)/.simbol/.scm
	@if ! bin/activate; then bin/activate DEFAULT; bin/activate; fi
	@
	@printf "Preparing ${EXTERN_D}..."
	@mkdir -p ${EXTERN_D}
	@mkdir -p ${EXTERN_D}/cache
	@mkdir -p ${EXTERN_D}/run
	@mkdir -p ${EXTERN_D}/log
	@mkdir -p ${EXTERN_D}/tmp
	@mkdir -p ${EXTERN_D}/lib
	@ln -sf $(CURDIR)/share/extern.makefile ${EXTERN_D}/Makefile
	@echo "DONE"
	@
	@printf "Populating ${EXTERN_D}...\n"
	@$(MAKE) -f $(CURDIR)/share/extern.makefile -C ${EXTERN_D} install
	@
	@printf "Installing symbolic links in $(HOME)/bin/..."
	@mkdir -p $(HOME)/.simbol/bin
	@ln -sf $(CURDIR)/bin/simbol $(HOME)/.simbol/bin/simbol
	@ln -sf $(CURDIR)/bin/ssh $(HOME)/.simbol/bin/ssm
	@ln -sf $(CURDIR)/bin/ssh $(HOME)/.simbol/bin/ssp
	@ln -sf $(CURDIR)/bin/activate $(HOME)/.simbol/bin/activate
	@mkdir -p $(HOME)/bin
	@ln -sf $(HOME)/.simbol/bin/simbol $(HOME)/bin/simbol
	@ln -sf $(HOME)/.simbol/bin/activate $(HOME)/bin/activate
	@echo "DONE"
	@
	@test -f ~/.simbolrc || touch .initialize
	@test ! -f .initialize || printf "Installing default ~/.simbolrc..."
	@test ! -f .initialize || cp share/examples/simbolrc.eg ${HOME}/.simbolrc
	@test ! -f .initialize || echo "DONE"
	@rm -f .initialize
	@
	@touch .install
#. }=-
#. Uninstallation -={
.PHONY: unsanity unsanity
unsanity:; @test -f .install
uninstall: unsanity
	@$(MAKE) -f $(CURDIR)/share/extern.makefile -C ${EXTERN_D} uninstall
	@
	find lib/libpy -name '*.pyc' -exec rm -f {} \;
	find lib/libpy -name '*.pyo' -exec rm -f {} \;
	@
	-rm $(HOME)/.simbol/lib
	-rm $(HOME)/.simbol/etc
	-rm $(HOME)/.simbol/module
	-rm $(HOME)/.simbol/libexec
	@
	-rm $(HOME)/bin/simbol
	-rm $(HOME)/bin/activate
	-rm $(HOME)/.simbol/bin/simbol
	-rm $(HOME)/.simbol/bin/ssm
	-rm $(HOME)/.simbol/bin/ssp
	-rm $(HOME)/.simbol/bin/activate
	-rmdir $(HOME)/.simbol/bin
	@
	-rm $(HOME)/.simbol/.scm
	@-rm .install
	@#rmdir $(HOME)/.simbol
	@
	@echo "Uninstallation complete!"
purge:
	@test ! -d ${EXTERN_D} || $(MAKE) -f $(CURDIR)/share/extern.makefile -C ${EXTERN_D} purge
	@test ! -d ~/.simbol || find ~/.simbol -type l -exec rm -f {} \;
	@#test ! -d ~/.simbol || find ~/.simbol -depth -type d -empty -exec rmdir {} \;
	rm -rf $(HOME)/.simbol/var
	rm -f .install
#. }=-
#. Devel -={
travis:
	@travis sync
	@while true; do clear; travis branches; sleep 10; done
#. }=-
#. }=-
