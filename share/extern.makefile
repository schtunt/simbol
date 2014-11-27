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
	@find ${LIBPY} -name '*.pyc' -exec rm -f {} \;
	@find ${LIBPY} -name '*.pyo' -exec rm -f {} \;
	@rmdir ${LIBSH} ${LIBRB} ${LIBPY} ${LIBPL} lib
	@rmdir libexec
	@echo "DONE"

uninstall: $(EXTERN:%=%.uninstall) unprepare
	@rm -f .install
	@echo "Uninstallation (extern) complete!"

purge: $(EXTERN:%=%.purge)
	rm -rf src
	rm -rf scm
	rm -rf lib
	rm -rf libexec
	rm -f .install
#. }=-

#. shflags -={
TGZ_SHFLAGS := src/shflags-1.0.3.tgz
SRC_SHFLAGS := $(TGZ_SHFLAGS:.tgz=)
shflags.purge: shflags.uninstall
	@-rm -r ${TGZ_SHFLAGS}
shflags.uninstall:
	@-rm ${LIBSH}/shflags
	@-rm -r ${SRC_SHFLAGS}
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
	@${DLA} http://shflags.googlecode.com/files/$(@F) > $@
	@echo "DONE"
#. }=-
#. shunit2 -={
TGZ_SHUNIT2 := src/shunit2-2.1.6.tgz
SRC_SHUNIT2 := $(TGZ_SHUNIT2:.tgz=)
shunit2.purge: shunit2.uninstall
	@-rm -r ${TGZ_SHUNIT2}
shunit2.uninstall:
	@-rm libexec/shunit2
	@-rm -r ${SRC_SHUNIT2}
shunit2.install: libexec/shunit2
libexec/shunit2: ${SRC_SHUNIT2}
	@ln -sf ${HOME}/.simbol/var/$</src/shunit2 $@
${SRC_SHUNIT2}: ${TGZ_SHUNIT2}
	@printf "Untarring $< into $(@D)..."
	@tar -C $(@D) -xzf $<
	@touch $@
	@echo "DONE"
${TGZ_SHUNIT2}:
	@printf "Downloading $@..."
	@${DLA} http://shunit2.googlecode.com/files/$(@F) > $@
	@echo "DONE"
#. }=-
#. vimpager -={
.PHONY: vimpager.install vimpager.uninstall vimpager.purge
vimpager.purge: vimpager.uninstall
	-rm -rf scm/vimpager.git
vimpager.uninstall:
	@-rm libexec/vimpager
	@-rm libexec/vimcat
vimpager.install: scm/vimpager.git
	@ln -sf $(CURDIR)/$</vimpager libexec/vimpager
	@ln -sf $(CURDIR)/$</vimcat libexec/vimcat
scm/vimpager.git:
	@echo "Cloning $(@F)..."
	@git clone -q http://github.com/rkitover/vimpager $@
#. }=-
#. pyobjpath -={
pyobjpath.uninstall:
	@-rm ${LIBPY}/pyobjpath/core
	@-rm ${LIBPY}/pyobjpath/utils
	@-rm ${LIBPY}/pyobjpath/__init__.py
	@-rmdir ${LIBPY}/pyobjpath/
pyobjpath.install: scm/pyobjpath.git
	@mkdir ${LIBPY}/pyobjpath
	@touch ${LIBPY}/pyobjpath/__init__.py
	@ln -sf $(CURDIR)/$</ObjectPathPy/core ${LIBPY}/pyobjpath/core
	@ln -sf $(CURDIR)/$</ObjectPathPy/utils ${LIBPY}/pyobjpath/utils
scm/pyobjpath.git:
	@echo "Cloning $@..."
	@git clone -q https://github.com/adriank/ObjectPath.git $@
#. }=-

#. -={
else
$(warning "No appropriate downloaded found in your PATH.")
endif
#. }=-
#. }=-
