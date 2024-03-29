;;;; xlog.asd

(asdf:defsystem #:xlog
  :description "Application logger with several features"
  :author "Your Name <wgl@ciex-security>"
  :license  "Copyright (c) 2008-2021 Ciex, Inc"
  :version "1.3.25"
  :serial t
  :components ((:file "xlog-pkg")
               (:file "xlog")))
