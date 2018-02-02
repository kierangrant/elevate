(require :sb-posix)
(require :uiop)
(load-shared-object "libcrypt.so.1")
(define-alien-routine crypt c-string (key c-string) (salt c-string))

(defparameter *secrets* "/etc/elevate/secret")
(defparameter *exec-to-run* "/bin/bash")

(defun echo-off ()
  (let ((tm (sb-posix:tcgetattr sb-sys:*tty*)))
    (setf (sb-posix:termios-lflag tm)
	  (logandc2 (sb-posix:termios-lflag tm) sb-posix:echo))
    (sb-posix:tcsetattr sb-sys:*tty* sb-posix:tcsanow tm)))

(defun echo-on ()
  (let ((tm (sb-posix:tcgetattr sb-sys:*tty*)))
    (setf (sb-posix:termios-lflag tm)
	  (logior (sb-posix:termios-lflag tm) sb-posix:echo))
    (sb-posix:tcsetattr sb-sys:*tty* sb-posix:tcsanow tm)))

(defun prompt-password ()
  (let (response)
    (echo-off)
    (format t "Password: ")
    (force-output)
    (unwind-protect
	 (setf response (read-line))
      (echo-on))
    (terpri)
    response))

(defun process ()
  (let (orig-password salt password)
    (setf orig-password
	  (with-open-file (f *secrets* :direction :input)
	    (read-line f)))
    (if (not (search "$" orig-password :from-end t))
	(progn
	  (format *error-output* "secret file is corrupted!~%")
	  (uiop/image:quit -1)))
    (setf salt (subseq orig-password 0 (search "$" orig-password :from-end t)))
    (setf password (prompt-password))
    (if (not (string= orig-password (crypt password salt)))
	(progn
	  (format *error-output* "Invalid Password~%")
	  (return-from process)))
    (handler-case
	(sb-posix:setresuid 0 0 0)
      (error ()
	(format *error-output* "Could not set UID's to 0~%")
	(uiop/image:quit -1)))
    (uiop/run-program:run-program
     `(,*exec-to-run*)
     :force-shell nil
     :input :interactive
     :output :interactive
     :error-output t)))

(defun main ()
  (setf *debugger-hook* (lambda (c e) (declare (ignore c e)) (continue)))
  (handler-case
      (process)
    (error ()
      (format *error-output* "An error occured~%")
      (uiop/image:quit -1)))
  (uiop/image:quit 0))
