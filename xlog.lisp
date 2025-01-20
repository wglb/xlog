;;;; xlog.lisp
(in-package #:xlog)

(declaim (optimize (speed 0) (safety 3) (debug 3) (space 0)))

(in-package #:xlog)

(defvar *log-file*)

(defvar *the-log-file-name*)

(defparameter *log-file-stack* nil)

(defparameter *log-file-name-stack* nil)

(defvar *alertfile*)

(defparameter *epoch-offset* 2208988800 #+nil (- (get-universal-time) (sb-ext:get-time-of-day)))

(defun xlog-version ()
  "Answer the version"
  (slot-value (asdf:find-system 'xlog) 'asdf:version))

(defun unpack-utc-with-hyphens(utc)
  "Unpack a utc time that has hyphens.
    note that this expects hyphens, and does local time, not z"
  ;;             1111111111222222
  ;;   01234567890123456789012345
  ;;60=2007-09-07 13:27:53
  ;;60=2007-09-07 13:27:53.123
  ;;60=2007-09-07 13:27:53.123456
  (let* ((year (parse-integer (subseq utc 0 4) :junk-allowed t))
         (month (parse-integer (subseq utc 5 7) :junk-allowed t))
         (day (parse-integer (subseq utc 8 10) :junk-allowed t))
         (hour (parse-integer (subseq utc 11 13) :junk-allowed t))
         (minute (parse-integer (subseq utc 14 16) :junk-allowed t))
         (second (parse-integer (subseq utc 17 19) :junk-allowed t))
         (gmt (if (and second minute hour day month year)
				  (encode-universal-time second minute hour day month year)
				  0))
         (ms (if (> (length utc) 21)
                 (parse-integer (subseq utc 20 23) :junk-allowed t)
                 nil)))
    (values gmt ms)))

(defun calc-elapsed-time  (tim)
  "For a timestampe formatted by 'formatted-current-time-micro, how long ago was the 'tim' timestamp"
  (- (get-universal-time) (unpack-utc-with-hyphens tim)))

(defun formatted-current-time-micro (str)
  "Produce a formatted timestamp from the current time "
  (multiple-value-bind (seconds microsec)
      (sb-ext:get-time-of-day)
    (multiple-value-bind (s min h d m y)
        (decode-universal-time (+ *epoch-offset* seconds))
      (format nil "~4,'0D-~2,'0d-~2,'0d ~2,'0d:~2,'0d:~2,'0d.~6,'0d ~A" y m d h min s microsec str))))

(defun formatted-file-time (lockname)
  "answer the mtime (formatted) of a file and its age"
  (if (probe-file lockname)
	  (let ((seconds (sb-posix:stat-mtime (sb-posix:stat lockname))))
		(multiple-value-bind (s min h d m y)
			(decode-universal-time (+ *epoch-offset* seconds))
		  (declare (ignorable s))
		  (let ((old (- (sb-ext:get-time-of-day) seconds)))
			(format nil "~4,'0D-~2,'0d-~2,'0d-~2,'0d-~2,'0d, ~a seconds old" y m d h min old))))
	  (format nil "~a does not exist" lockname)))

(defun formatted-current-time ()
  "Answer the formatted current time"
  (multiple-value-bind (seconds microsec)
      (sb-ext:get-time-of-day)
    (declare (ignorable microsec))
    (multiple-value-bind (s min h d m y)
        (decode-universal-time (+ *epoch-offset* seconds))
      (declare (ignorable s))
      (format nil "~4,'0D-~2,'0d-~2,'0d-~2,'0d-~2,'0d" y m d h min))))

(defun dates-ymd (dates)
  "Create a file name from the current time, 
   including optionally hour, or hours minutes and seconds as part of the file name"
  (multiple-value-bind (s min h d m y doy dstflag offset)
      (decode-universal-time (get-universal-time))
    (declare (ignore doy))
    (let* ((filename 
			 (cond ((equal dates :hms)
					(format nil
							"~4,'0D-~2,'0D-~2,'0D-~2,'0D-~2,'0D-~2,'0D_"
							y m d 
							(+ h offset (if dstflag -1 0))
							min s))
				   ((equal dates :hour)
					(format nil
							"~4,'0D-~2,'0D-~2,'0D-~2,'0D_"
							y m d h))
				   ((equal dates :ym)
					(format nil
							"~4,'0D-~2,'0D_"
							y m))
                   (dates (format nil
                                  "~4,'0D-~2,'0D-~2,'0D_"
                                  y m d))
                   (t (format nil "")))))
      filename)))

(defparameter *debug-level* 4)

(declaim (fixnum *debug-level*))

(defmacro debugc (val stmt)
  "Conditional debug"
  `(when (<= ,val *debug-level*)
    ,stmt))

(defmacro xdebug (val stmt)
  (when (<= *debug-level* val)
	`,stmt))

(defun the-log-file ()
  "Answer the log file"
  (if (boundp '*log-file*)
	  *log-file*
	  nil))

(defun the-alert-file ()
  "Answer the alert file"
  (if (boundp '*alertfile*)
	  *alertfile*
	  nil))

(defun xalert (str)
  "Write an alert, copied to the log file"
  (open-alert-file)
  (write-line (formatted-current-time-micro str)
			  (the-alert-file))
  (xlog str)
  (close-alert-file))

(defmacro xalertf (fmt &rest vars)
  "Write with format to alsert"
  `(xalert (format nil ,fmt ,@vars)))

(defun xlog (str)
  "Write string 'str' time-stamped to the log file"
  (fresh-line (the-log-file))
  (write-line (formatted-current-time-micro str) (the-log-file)))

(defun xlognt (str)
  "Write string 'str' to the log file without time stamp. Ensure that the line is fresh."
  (fresh-line (the-log-file))
  (write-line str (the-log-file)))

(defun xlogfin ()
  "Flush the log file output"
  (force-output (the-log-file)))

(defmacro xlogf (fmt &rest vars)
  "Write with format to log file"
  `(xlog (format nil ,fmt ,@vars)))

(defmacro xlogff (fmt &rest vars)
  "Write with format to log file"
  `(prog1
    (xlog (format nil ,fmt ,@vars))
    (force-output (the-log-file))))

(defmacro xlogft (fmt &rest vars) 
  "Write formatted to log file and console"
  (let ((str (gensym)))
    `(let ((,str (format nil ,fmt ,@vars)))
	   (let ((rv (xlogf "~A" ,str)))
		 (fresh-line)
		 (format t "~A~%" rv)
		 (xlogfin)
		 rv))))

(defmacro xlogntf (fmt &rest vars) 
  "Write formatted to log file without time stamp"
  (let ((str (gensym)))
    `(let ((,str (format nil ,fmt ,@vars)))
       (xlognt ,str))))

(defmacro xlogntft (fmt &rest vars) 
  "Write formatted entry to log file and terminal without timestamp"
  (let ((str (gensym)))
    `(let ((,str (format nil ,fmt ,@vars)))
	   (fresh-line)
       (format t "~a" ,str)
       (format t "~%")
       (xlognt ,str))))

(defun open-log-file (basename &key (dates t)  (extension "log") (dir nil) (show-log-file-name t) (append-or-replace :append))
  "Open a log file.
   'dates'              - include dates in log file name. See dates-ymd for format choices.
   'extension'          - (file type, in cl terminology) normally 'log'
   'dir'                - directory for log file
   'show-log-file-name' - Before opening the log file, show current log file name before opening. A value of :both
                          will 
   'append-or-replace'  - What to do if the log file already exists"
  (let ((filename (format nil "~A~A" (dates-ymd dates) basename))
		(prev-log-file (the-log-file)))
	(declare (ignorable prev-log-file))
	(when (the-log-file)
      (push (the-log-file) *log-file-stack*)
	  (push *the-log-file-name* *log-file-name-stack*))
	(let* ((*print-pretty* nil)
           (pathname 
			 (cond ((consp dir)
					(make-pathname :directory `,dir :name filename :type extension ))

				   (dir 
					(let ((pth (make-pathname :directory `,dir :name filename :type extension )))
					  pth))
				   
                   (t 
					(make-pathname :name filename :type extension)))))
	  (setq *the-log-file-name* pathname)
      (when (equal show-log-file-name :both)
		(xlogntft "xlog: opening log pathname as ~a~%" pathname))
	  (handler-case
		  (let ((nlf (open (ensure-directories-exist pathname)
						   :direction :output
						   :if-exists (if (eq append-or-replace :REPLACE)
										  :supersede
										  append-or-replace)
						   :if-does-not-exist :create
						   :external-format :utf8)))
			(if show-log-file-name
				(xlogft "xlog: nest, new: ~s"
						(if nlf
							(probe-file nlf)
							"<none>")))
			(setf *log-file* nlf)
			(xlogf "xlog: ~a  beginning of log-file: ~a" append-or-replace pathname))
		(error (d)
		  (xlogf "open-log-file: error ~a for log file ~a~%" d pathname)
		  (setf *log-file* nil))))))

(defun close-log-file ()
  "Close the the log file, make the previous log file current"
  (when (the-log-file)
	(xlogf "xlog: end of log-file ~a" *the-log-file-name*)
    (force-output (the-log-file))
    (close (the-log-file)))
  (setf *log-file* (pop *log-file-stack*))
  (setf *the-log-file-name* (pop *log-file-name-stack*)))

(defmacro with-open-log-file ((filespec &key (dates t)  (extension "log") (dir nil) (show-log-file-name t) (append-or-replace :append)) 
							  &body body)
  "Wrap the log file open/close. See 'open-log-file' for parameters"
  `(progn
	 (let ()
	   (open-log-file ,filespec :dates ,dates :extension  ,extension :dir ,dir :show-log-file-name ,show-log-file-name  :append-or-replace ,append-or-replace)
	   (unwind-protect (progn ,@body)
		 (close-log-file )))))

(defparameter *alert-file-name* "alert-file")

(defun  set-alert-file-name (which)
  "Set the name of the alert file."
  (setf *alert-file-name* which))

(defun open-alert-file ()
  "Open the alert file using *alert-file-name*"
  (when (the-alert-file)
	(close-alert-file))
  (let* ((filename (format nil "~A" *alert-file-name*))
         (pathname (make-pathname :name filename :type "alog")))
	
    (debugc 5 (xlogntf "xlog: log pathname is ~a" (file-namestring pathname)))
    (setf *alertfile* (open (ensure-directories-exist pathname)
                            :direction :output
							:if-exists :supersede
							:if-does-not-exist :create
							:external-format :utf8))))
(defun close-alert-file ()
  "Finish and close the alert file"
  (when (the-alert-file)
    (force-output *alertfile*)
    (close *alertfile*))
  (setf *alertfile* nil))

(defun test-log-file ()
  "Test log file nesting"
  (with-open-log-file ("original")
	(xlogntf "this is a original")
	(with-open-log-file ("inner")
	  (xlogntf "this is a drawer in the desk"))
	(xlogntf "this should be another original"))
  (xlogntf "This should go nowhere"))
