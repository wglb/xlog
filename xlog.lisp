;;;; xlog.lisp
;; Application logging.
;; Features:
;; 1. Optinally Time-stamped formatted log enttries
;;    2021-10-27 13:55:36.423013 xlog: end of log-file 2021-10-27_dispatch-rescancanm.log
;; 2. Log files can be appended to or superseded
;;    
;; 3. Log directory can be specified
;;    (with-open-log-file (<filespec> :dir "<log file directory>") ... )
;; 4. Log file extension can be specified
;;    (with-open-log-file (<filespec> :extension "out") ... )
;; 5. Log entry can be also pushed to standard out
;;    Usual output is (xlogf "<format string>" <val1> <val2>) ;; in the manner of (format ...)
;;    Also to standard output is (xlogft "<format string>" ... _) ;; goes to standard out
;; 6. Alert file support for status reporting
;;    Set alert file name: (set-alert-file-name "<name of alert file>").
;;    (xalert "simple string") ;; opens alert file, writes values, closes alert file
;;    (xlalertf "format string" <val1> ... )
;; 7. Support for date-stamped file names with options for hour,minute,second resulution, hour resolution, date only, or no date.
;;    (with-open-log-file ("filespec" :dates (t :hms :hour :dates)
;; 8. Log files can be nested. TODO -- explain this better
;;    The 'with-open-log-file' macro wraps code in the manner of 'with-open-file'. If you nest the calls, upon closing the nested
;;    open, the original one resumes. This can ease reading detail processes within a global process.

(in-package #:xlog)

(declaim (optimize (speed 0) (safety 3) (debug 3) (space 0)))

(in-package #:xlog)


(defvar *log-file*)

(defvar *the-log-file-name*)

(defparameter *log-file-stack* nil)

(defparameter *log-file-name-stack* nil)

(defvar *alertfile*)

(defparameter *epoch-offset* 2208988800 #+nil (- (get-universal-time) (sb-ext:get-time-of-day)))

(defun unpack-utc-with-hyphens(utc)
  " note that this expects hyphens, and does local time, not z"
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
  "answer the mtime (formatted) of a file"
  (if (probe-file lockname)
	  (let ((seconds (sb-posix:stat-mtime (sb-posix:stat lockname))))
		(multiple-value-bind (s min h d m y)
			(decode-universal-time (+ *epoch-offset* seconds))
		  (declare (ignorable s))
		  (let ((old (- (sb-ext:get-time-of-day) seconds)))
			(format nil "~4,'0D-~2,'0d-~2,'0d-~2,'0d-~2,'0d, ~a seconds old" y m d h min old))))
	  (format nil "~a does not exist" lockname)))

(defun formatted-current-time ()
  (multiple-value-bind (seconds microsec)
      (sb-ext:get-time-of-day)
    (declare (ignorable microsec))
    (multiple-value-bind (s min h d m y)
        (decode-universal-time (+ *epoch-offset* seconds))
      (declare (ignorable s))
      (format nil "~4,'0D-~2,'0d-~2,'0d-~2,'0d-~2,'0d" y m d h min))))

(defun dates-ymd (dates)
  "Create a file name from the current time, including optionally hour, or hours minutes and seconds as part of the file name"
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
                           y m d 
						   h))
                  (dates (format nil
                                 "~4,'0D-~2,'0D-~2,'0D_"
                                 y m d))
                  (t (format nil "")))))
      filename)))

(defparameter *debug-level* 4)

(defmacro debugc (val stmt)
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
  "Answer the log file"
  (if (boundp '*alertfile*)
	  *alertfile*
	  nil))

(defmacro xlogf (fmt &rest vars)
  "Write with format to log file"
  `(xlog (format nil ,fmt ,@vars)))

(defun xalert (str)
  (open-alert-file)
  (write-line (formatted-current-time-micro str)
			  (the-alert-file))
  (xlog str)
  (close-alert-file))

(defmacro xalertf (fmt &rest vars)
  "Write with format to log file"
  `(xalert (format nil ,fmt ,@vars)))

(defmacro xlogff (fmt &rest vars)
  "Write with format to log file"
  `(prog1
    (xlog (format nil ,fmt ,@vars))
    (force-output (the-log-file))))

(defmacro xlogft (fmt &rest vars) 
  "write formatted to log file and console"
  (let ((str (gensym)))
    `(let ((,str (format nil ,fmt ,@vars)))
	   (let ((rv (xlogf "~A" ,str)))
		 (format t "~A~%" rv)
		 (xlogfin)
		 rv))))

(defmacro xlogntf (fmt &rest vars) 
  "Write formatted to log file without time stamp"
  (let ((str (gensym)))
    `(let ((,str (format nil ,fmt ,@vars)))
       (xlognt ,str))))

(defmacro xlogntft (fmt &rest vars) 
  (let ((str (gensym)))
    `(let ((,str (format nil ,fmt ,@vars)))
       (format t "~a" ,str)
       (format t "~%")
       (xlognt ,str))))

(defun pathname-as-directory (pathspec)
  "Converts the non-wild pathname designator PATHSPEC to directory form. Stolen from gigamonkeys"
  (let ((pathname (pathname-name  pathspec)))
    (if pathname
		(when (wild-pathname-p pathname)
		  (error "Can't reliably convert wild pathnames.")))
    (cond ((not (uiop:directory-pathname-p pathspec))
           (make-pathname :directory (append (or (pathname-directory pathname)
                                                 (list :relative))
                                             (list (file-namestring pathname)))
                          :name nil
                          :type nil
                          :defaults pathname))
          (t pathname))))


(defun open-log-file (basename &key (dates t)  (extension "log") (dir nil) (show-log-file-name t) (append-or-replace :append))
  (let ((filename (format nil "~A~A" (dates-ymd dates) basename)))
	(when (the-log-file)
	  (if show-log-file-name
		  (xlogft "xlog: prev ~a current ~a to open new " *the-log-file-name* filename))
      (push (the-log-file) *log-file-stack*)
	  (push *the-log-file-name* *log-file-name-stack*))
	
	(let* ((*print-pretty* nil)
           (pathname 
			(cond (dir 
				   (debugc 5 (xlogntf "xlog: odd case of ~a ~s" dir (pathname-directory (pathname-as-directory  dir))))
				   #+nil (make-pathname :directory `(:relative ,dir) :name filename :type extension )
				   (let ((pth (make-pathname :directory `,dir :name filename :type extension )))
					 pth))
				  
                  (t 
				   (make-pathname :name filename :type extension))))) 
	  (setq *the-log-file-name* pathname)
      (when (equal show-log-file-name :both)
		(xlogntft "xlog: opening log pathname as ~a~%" pathname))
	  (handler-case
		  (setf *log-file* (open (ensure-directories-exist pathname)
							 :direction :output
							 :if-exists append-or-replace
							 :if-does-not-exist :create
							 :external-format :utf8))
		(error (d)
		  (format t "open-log-file: error ~a for log file ~a~%" d pathname)
		  (setf *log-file* nil)))
	  (xlogf "xlog: ~a  beginning of log-file ~%   ~a" append-or-replace pathname))))

(defun close-log-file ()
  (when (the-log-file)
	(xlogf "xlog: end of log-file ~a" *the-log-file-name*)
    (force-output (the-log-file))
    (close (the-log-file)))
  (setf *log-file* (pop *log-file-stack*))
  (setf *the-log-file-name* (pop *log-file-name-stack*)))

(defmacro with-open-log-file ((filespec &key (dates t)  (extension "log") (dir nil) (show-log-file-name t) (append-or-replace :append)) 
							  &body body)
  `(progn
#+nil	 (when ,dir
	   (ensure-directories-exist ,dir :verbose t))
	 
	 (open-log-file ,filespec :dates ,dates :extension  ,extension :dir ,dir :show-log-file-name ,show-log-file-name  :append-or-replace ,append-or-replace)
	 (unwind-protect (progn ,@body)
	   (close-log-file ))))

(defparameter *alert-file-name* "alert-file")

(defun  set-alert-file-name (which)
  (setf *alert-file-name* which))

(defun open-alert-file ()
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


(defun xlog (str)
  "write time-stamped to log file"
  (write-line (formatted-current-time-micro str) (the-log-file)))

(defun xlognt (str)
  "Write to  log file"
  (write-line str (the-log-file)))

(defun xlogfin ()
  "Flush the log file output"
  (force-output (the-log-file)))

(defun close-alert-file ()
  (when (the-alert-file)
    (force-output *alertfile*)
    (close *alertfile*))
  (setf *alertfile* nil))

(defun test-log-file ()
  (with-open-log-file ("radio")
	(xlogntf "this is a radio")
	(with-open-log-file ("deskdrawer")
	  (xlogntf "this is a deawer in the desk"))
	(xlogntf "this should be another radio"))
  (xlogntf "This should go nowhere"))
