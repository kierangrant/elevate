SECRETS:=/etc/elevate/secret
EXEC_TO_RUN=/bin/bash

all: elevate generate-elevate-secret

elevate: elevate.lisp
	sbcl --noinform --load "elevate.lisp" --eval "(progn (setf *secrets* \"${SECRETS}\" *exec-to-run* \"${EXEC_TO_RUN}\") (save-lisp-and-die \"elevate\" :executable t :toplevel #'main :save-runtime-options t))"

generate-elevate-secret: generate-elevate-secret.lisp
	sbcl --noinform --load "generate-elevate-secret.lisp" --eval "(save-lisp-and-die \"generate-elevate-secret\" :executable t :toplevel #'main :save-runtime-options t)"

clean:
	rm -fv generate-elevate-secret elevate

install: all
	install -o root -g sudo -m 0750 -v elevate /sbin
	setcap cap_setuid,cap_dac_override+eip /sbin/elevate
	install -o root -g root -m 0700 -v generate-elevate-secret /sbin

uninstall:
	rm -fv /sbin/elevate
	rm -fv /sbin/generate-elevate-secret

.PHONY=clean install uninstall
