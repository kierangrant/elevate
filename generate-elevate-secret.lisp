(require :sb-posix)
(require :uiop)
(load-shared-object "libcrypt.so.1")
(define-alien-routine crypt c-string (key c-string) (salt c-string))

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
    (format *error-output* "Password: ")
    (force-output *error-output*)
    (unwind-protect
	 (setf response (read-line))
      (echo-on))
    (terpri *error-output*)
    response))

(defun process ()
  (let (password salt)
    (setf password (prompt-password))
    (setf salt
	  (let ((key (random (ash 1 96)))
		(space
		 (append
		  (loop for i from 0 to 25 collecting (code-char (+ #x41 i)))
		  (loop for i from 0 to 25 collecting (code-char (+ #x61 i)))
		  (loop for i from 0 to 9 collecting (code-char (+ #x30 i)))
		  '(#\. #\/))))
	    (format nil "$6$~{~C~}"
		    (loop for i from 0 to 15 collecting
			 (elt space (ldb (byte 6 (* 6 i)) key))))))
    (format t "~a~%" (crypt password salt))))

(defun main ()
  (setf *debugger-hook* (lambda (c e) (declare (ignore c e)) (continue)))
  (handler-case
      (process)
    (error ()
      (format *error-output* "An error occured~%")
      (uiop/image:quit -1)))
  (uiop/image:quit 0))
