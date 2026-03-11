;;;; xlog.lisp
;;;; Copyright (c) 2008-2026 Ciex-Security <wgl@ciex-security.com>
;;;;
;;;; Permission is hereby granted, free of charge, to any person obtaining a copy 
;;;; of this software and associated documentation files (the "Software"), to deal 
;;;; in the Software without restriction, including without limitation the rights 
;;;; to use, copy, modify, merge, publish, distribute, sublicense, and/or sell 
;;;; copies of the Software, and to permit persons to whom the Software is 
;;;; furnished to do so, subject to the following conditions:
;;;;
;;;; The above copyright notice and this permission notice shall be included in 
;;;; all copies or substantial portions of the Software.
;;;;
;;;; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
;;;; IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
;;;; FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE 
;;;; AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER 
;;;; LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, 
;;;; OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN 
;;;; THE SOFTWARE.

(in-package #:xlog)

(declaim (optimize (speed 0) (safety 3) (debug 3) (space 0)))

(defstruct log-stack-entry
  "Holds data for a single log file, including name, stream, and opening time."
  name
  stream
  (opened-at (get-universal-time) :type integer))

(defvar *current-log-entry* nil
  "The current log-stack-entry. NIL if no log file is open.")
(defparameter *log-stack* nil
  "A stack of parent log-stack-entry structures, for nested logging.")

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
				   ((equal dates :ymd)
					(format nil
                            "~4,'0D-~2,'0D-~2,'0D"
                            y m d))
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
  "Answer the log file stream from the current entry."
  (when *current-log-entry*
    (log-stack-entry-stream *current-log-entry*)))

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

(defun xlog-blast (message)
  "Write message to the current log and every log in the parent stack."
  (let ((targets (remove nil (cons (the-log-file)
                                   (mapcar #'log-stack-entry-stream *log-stack*)))))
    (dolist (out targets)
      (format out "~&[BLAST] ~A ~A~%" (formatted-current-time) message)
      (force-output out))))

(defun open-log-file (basename &key (dates t)  (extension "log") (dir nil) (show-log-file-name t) (append-or-replace :append))
  "Open a log file.
   'dates'              - include dates in log file name. See dates-ymd for format choices.
   'extension'          - (file type, in cl terminology) normally 'log'
   'dir'                - directory for log file
   'show-log-file-name' - Before opening the log file, show current log file name before opening. A value of :both
                          will also show new file to be opened
   'append-or-replace'  - What to do if the log file already exists"

  ;; TODO: this does not work for some reason "/home/data7/projects/mspurr-audits/fastapi/job-id-fastapi-part1.sxp"
  (let ((filename (format nil "~A~A" (dates-ymd dates) basename)))
	(when *current-log-entry*
      (push *current-log-entry* *log-stack*))
	(let* ((*print-pretty* nil)
           (pathname 
			(cond ((consp dir)
				   (make-pathname :directory `,dir :name filename :type extension ))

				  (dir 
				   (make-pathname :directory `,dir :name filename :type extension ))
				   
                  (t 
				   (make-pathname :name filename :type extension)))))
      (when (equal show-log-file-name :both)
		(xlogntft "xlog: opening log pathname as ~a" pathname))
	  (handler-case
		  (let ((nlf (open (ensure-directories-exist pathname)
						   :direction :output
						   :if-exists (if (eq append-or-replace :REPLACE)
										  :supersede
										  append-or-replace)
						   :if-does-not-exist :create
						   :external-format :utf8)))
            (setf *current-log-entry* (make-log-stack-entry :name pathname :stream nlf))
			(if show-log-file-name
				(xlogft "xlog: nest, new: ~s"
						(if nlf
							(probe-file nlf)
							"<none>")))
			(xlogf "xlog: ~a  beginning of log-file: ~a" append-or-replace pathname))
		(error (d)
		  (xlogf "open-log-file: error ~a for log file dir ~s pathname ~s~%" d dir pathname)
		  (setf *current-log-entry* (pop *log-stack*)))))))

(defun close-log-file ()
  "Close the the log file, make the previous log file current"
  (when *current-log-entry*
    (multiple-value-bind (s min h d m y)
        (decode-universal-time (log-stack-entry-opened-at *current-log-entry*))
      (xlogf "xlog: end of log-file ~a, opened at ~4,'0D-~2,'0d-~2,'0d ~2,'0d:~2,'0d:~2,'0d"
             (log-stack-entry-name *current-log-entry*) y m d h min s))
    (force-output (log-stack-entry-stream *current-log-entry*))
    (close (log-stack-entry-stream *current-log-entry*)))
  (setf *current-log-entry* (pop *log-stack*)))

(defmacro with-open-log-file ((filespec &key (dates t)  (extension "log") (dir nil) (show-log-file-name t) (append-or-replace :append)) 
							  &body body)
  "Wrap the log file open/close. See 'open-log-file' for parameters"
  `(progn
	 (let ()
	   (open-log-file ,filespec :dates ,dates :extension  ,extension :dir ,dir :show-log-file-name ,show-log-file-name  :append-or-replace ,append-or-replace)
	   (unwind-protect (progn ,@body)
		 (close-log-file )))))

(defmacro w/log (filespec &body body)
  "Minimalist wrapper for with-open-log-file."
  `(with-open-log-file ,filespec ,@body))

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
  "Test log file nesting, blast, and content verification."
  ;; 1. Clean up previous test files to ensure a fresh start.
  (uiop:delete-file-if-exists "original.log")
  (uiop:delete-file-if-exists "inner.log")

  ;; 2. Run the logging operations.
  (with-open-log-file ("original" :dates nil :show-log-file-name nil)
    (xlogntf "message for original")
    (with-open-log-file ("inner" :dates nil :show-log-file-name nil)
      (xlogntf "message for inner")
      (xlog-blast "this is a blast"))
    (xlogntf "another message for original"))
  (xlogntf "This should go to stdout, not a file.")

  ;; 3. Read the contents of the generated log files.
  (let ((original-content (uiop:read-file-string "original.log"))
        (inner-content (uiop:read-file-string "inner.log")))

    ;; 4. Define expected content for each file.
    (let ((original-expects '("message for original"
                              "[BLAST]"
                              "this is a blast"
                              "another message for original"))
          (original-forbids '("message for inner"))
          (inner-expects '("message for inner"
                           "[BLAST]"
                           "this is a blast"))
          (inner-forbids '("message for original"
                           "another message for original")))

      ;; 5. Perform assertions.
      (flet ((check-contents (content expects forbids filename)
               (dolist (e expects)
                 (assert (search e content) () "Missing expected string '~a' in ~a" e filename))
               (dolist (f forbids)
                 (assert (not (search f content)) () "Found forbidden string '~a' in ~a" f filename))))

        (check-contents original-content original-expects original-forbids "original.log")
        (check-contents inner-content inner-expects inner-forbids "inner.log")

        (format t "~&test-log-file: All assertions passed.~%")))))
