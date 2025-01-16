;;;; xlog.asd

(asdf:defsystem #:xlog
  :description "Application logger"
  :author "wglb <wgl@ciex-security>"
  :license  "Copyright (c) 2008-2024 Ciex, GNU licence v3"
  :version "1.3.33"
  :serial t
  :components ((:file "xlog-pkg")
               (:file "xlog")))
