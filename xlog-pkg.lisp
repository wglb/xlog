;;;; package.lisp

(defpackage #:xlog
  (:use #:cl #:uiop)
  (:export #:xlog
           #:xlogf
		   #:*epoch-offset*
		   #:xlog-version
		   #:xalert
		   #:xalertf
           #:xlogf
           #:xlogft
           #:xlognt
           #:xlogntf
           #:xlogntft
           #:xlogff
		   #:with-open-log-file
		   #:set-alert-file-name
           #:formatted-current-time
		   #:formatted-current-time-micro 
		   #:formatted-file-time
           #:the-log-file
           #:xlogfin
           #:*debug-level*
           #:dates-ymd
		   #:calc-elapsed-time
           #:debugc))
