;;;; package.lisp

(defpackage #:xlog
  (:use #:cl )
  (:export #:xlog
           #:xlogf
		   #:xalert
		   #:xalertf
           #:xlogf
           #:xlogft
           #:xlognt
           #:xlogntf
           #:xlogntft
           #:xlogff
		   #:open-log-file
		   #:with-open-log-file
		   #:set-alert-file-name
		   #:maybe-open-log-file
		   #:maybe-close-log-file
           #:formatted-current-time
		   #:formatted-current-time-micro 
		   #:formatted-file-time
           #:the-log-file
           #:xlogfin
           #:close-log-file
           #:*debug-level*
           #:dates-ymd
		   #:pathname-as-directory
		   #:calc-elapsed-time
           #:debugc))
