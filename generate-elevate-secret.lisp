(require :sb-posix)
(require :uiop)
(load-shared-object "libcrypt.so.1")
(define-alien-routine crypt c-string (key c-string) (salt c-string))


(defun tty-echo (&optional (echo-on T))
  (handler-case
      (uiop/run-program:run-program
       `("/bin/stty"
	 ,(if echo-on "echo" "-echo"))
       :force-shell nil
       :input :interactive
       :output :interactive
       :error-output t)
    (error ()
      (format *error-output* "Could not set tty controls~%")
      (uiop/image:quit -1))))

(defun prompt-password ()
  (let (response)
    (tty-echo nil)
    (format *error-output* "Password: ")
    (force-output *error-output*)
    (setf response (read-line))
    (tty-echo)
    (terpri *error-output*)
    response))

(defun process ()
  (let (password salt)
    (setf password (prompt-password))
    (setf salt
	  (let ((key (random 4096))
		(space
		 (append
		  (loop for i from 0 to 25 collecting (code-char (+ #x41 i)))
		  (loop for i from 0 to 25 collecting (code-char (+ #x61 i)))
		  (loop for i from 0 to 9 collecting (code-char (+ #x30 i)))
		  '(#\. #\/))))
	    (format nil "$6$~C~C"
		    (elt space (ldb (byte 6 6) key))
		    (elt space (ldb (byte 6 0) key)))))
    (format t "~a~%" (crypt password salt))))

(defun main ()
  (disable-debugger)
  (handler-case
      (process)
    (error ()
      (format *error-output* "An error occured~%")
      (uiop/image:quit -1)))
  (uiop/image:quit 0))
