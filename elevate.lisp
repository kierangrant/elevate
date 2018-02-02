(require :sb-posix)
(require :uiop)
(load-shared-object "libcrypt.so.1")
(define-alien-routine crypt c-string (key c-string) (salt c-string))

(defparameter *secrets* "/etc/elevate/secret")
(defparameter *exec-to-run* "/bin/bash")

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
    (format t "Password: ")
    (force-output)
    (setf response (read-line))
    (tty-echo)
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
  (disable-debugger)
  (handler-case
      (process)
    (error ()
      (format *error-output* "An error occured~%")
      (uiop/image:quit -1)))
  (uiop/image:quit 0))
