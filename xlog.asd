;;;; xlog.asd

(asdf:defsystem #:xlog
  :description "Application logger with several features"
  :author "wglb <wgl@ciex-security>"
  :license  "Copyright (c) 2008-2024 Ciex, Inc All rights reserved"
  :version "1.3.28"
  :serial t
  :components ((:file "xlog-pkg")
               (:file "xlog")))
