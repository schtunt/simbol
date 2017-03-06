#. -={
#. Web Getter -={
WGET := $(shell which wget)
ifeq (${WGET},)
CURL := $(shell which curl)
DLA := ${CURL} -s
else
DLA := ${WGET} -q -O-
endif
ifneq (${DLA},)
#. }=-

flycatcher:
	@echo "Do not run make here unless you know what you're doing."

EXTERN := shflags shunit2
EXTERN += vimpager

LIBSH  := lib/libsh
LIBRB  := lib/librb
LIBPY  := lib/libpy
LIBPL  := lib/libpl

#. Installation -={
.PHONY: prepare install $(EXTERN:%=%.install)
install: .install; @echo "Installation (extern) complete!"
.install: prepare $(EXTERN:%=%.install); @touch .install

prepare:
	@printf "Preparing extern build..."
	@mkdir -p libexec
	@mkdir -p ${LIBSH} ${LIBRB} ${LIBPY} ${LIBPL}
	@mkdir -p src scm
	@echo "DONE"
#. }=-
#. Uninstallation -={
.PHONY: unprepare uninstall $(EXTERN:%=%.uninstall)
unprepare:
	@printf "Unpreparing extern build..."
	@echo "DONE"

uninstall: $(EXTERN:%=%.uninstall) unprepare
	@rm -fr ${LIBSH} ${LIBRB} ${LIBPY} ${LIBPL} lib
	@rm -fr libexec
	@rm -f  .install
	@echo "Uninstallation (extern) complete!"

purge: $(EXTERN:%=%.purge)
	rm -fr src
	rm -fr scm
	rm -fr lib
	rm -fr libexec
	rm -f  .install
#. }=-

#. shflags -={
.PHONY: shflags.purge shflags.uninstall shflags.install
VER_SHFLAGS := 1.0.3
TGZ_SHFLAGS := src/shflags-${VER_SHFLAGS}.tgz
SRC_SHFLAGS := $(TGZ_SHFLAGS:.tgz=)
shflags.purge: shflags.uninstall
	@rm -f  ${TGZ_SHFLAGS}
	@rm -fr ${SRC_SHFLAGS}
	@rm -fr ${LIBSH}/shflags
shflags.uninstall:
shflags.install: ${LIBSH}/shflags
${LIBSH}/shflags: ${SRC_SHFLAGS}
	@ln -sf ${HOME}/.simbol/var/$</src/shflags $@
${SRC_SHFLAGS}: ${TGZ_SHFLAGS}
	@printf "Untarring $< into $(@D)..."
	@tar -C $(@D) -xzf $<
	@touch $@
	@echo "DONE"
${TGZ_SHFLAGS}:
	@printf "Downloading $@..."
	@${DLA} https://github.com/kward/shflags/archive/${VER_SHFLAGS}.tar.gz > $@
	@echo "DONE"
#. }=-
#. shunit2 -={
.PHONY: shunit2.purge shunit2.uninstall shunit2.install
VER_SHUNIT2 := 2.1.6
TGZ_SHUNIT2 := src/shunit2-${VER_SHUNIT2}.tgz
SRC_SHUNIT2 := $(TGZ_SHUNIT2:.tgz=)
shunit2.purge: shunit2.uninstall
	@rm -f  ${TGZ_SHUNIT2}
	@rm -fr ${SRC_SHUNIT2}
	@rm -fr libexec/shunit2
shunit2.uninstall:
shunit2.install: libexec/shunit2
libexec/shunit2: ${SRC_SHUNIT2}
	@ln -sf ${HOME}/.simbol/var/src/shunit2-source/${VER_SHUNIT2}/src/$(@F) $@
${SRC_SHUNIT2}: ${TGZ_SHUNIT2}
	@printf "Untarring $< into $(@D)..."
	@tar -C $(@D) -xzf $<
	@touch $@
	@echo "DONE"
${TGZ_SHUNIT2}:
	@printf "Downloading $@..."
	@${DLA} https://github.com/kward/shunit2/archive/source.tar.gz > $@
	@echo "DONE"
#. }=-
#. vimpager -={
.PHONY: vimpager.install vimpager.uninstall vimpager.purge
vimpager.purge: vimpager.uninstall
	@rm -f  libexec/vimpager
	@rm -f  libexec/vimcat
	@rm -fr scm/vimpager.git
vimpager.uninstall:
vimpager.install: scm/vimpager.git
	@ln -sf $(CURDIR)/$</vimpager libexec/vimpager
	@ln -sf $(CURDIR)/$</vimcat libexec/vimcat
scm/vimpager.git:
	@echo "Cloning $(@F)..."
	@git clone -q http://github.com/rkitover/vimpager $@
#. }=-

#. -={
else
$(warning "No appropriate downloaded found in your PATH.")
endif
#. }=-
#. }=-
