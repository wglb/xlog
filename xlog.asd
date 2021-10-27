;;;; xlog.asd

(asdf:defsystem #:xlog
  :description "Application logger with several features"
  :author "Your Name <wgl@ciex-security>"
  :license  "Copyright (c) 2008-2021 Ciex, Inc"
  :version #.(with-open-file
                 (vers (merge-pathnames "system-version.expr" *load-truename*))
               (read vers))
			   
  :serial t
  :components ((:file "xlog-pkg")
               (:file "xlog")))
