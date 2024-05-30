# xlog

Application logging library

Features:

* Optinally Time-stamped formatted log enttries
   2021-10-27 13:55:36.423013 xlog: end of log-file 2021-10-27_dispatch-rescancanm.log
* Log files can be appended to or superseded
   
* Log directory can be specified `(with-open-log-file (<filespec> :dir "<log file directory>") ... )`
* Log file extension can be specified

  `(with-open-log-file (<filespec> :extension "out") ... )`

* Log entry can be also pushed to standard out
   Usual output is (xlogf "<format string>" <val1> <val2>) ;; in the manner of (format ...)
   Copy to standard output is 
   
   `(xlogft "<format string>" ... _)`
* Alert file support for status reporting
   Set alert file name: `(set-alert-file-name "<name of alert file>").`
   
   `(xalert "simple string")` ;; opens alert file, writes values, closes alert file
   `(xlalertf "format string" <val1> ... )`
* Support for date-stamped file names with options for hour,minute,second resulution, hour resolution, date only, or no date.
   `(with-open-log-file ("filespec" :dates (t :hms :hour :dates)`
* Log files can be nested. TODO -- explain this better
   The 'with-open-log-file' macro wraps code in the manner of 'with-open-file'. If you nest the calls, upon closing the nested
   open, the original one resumes. This can ease reading detail processes within a global process.


Functions:

### Answer the version  


```common-lisp
(xlog-version)```

### Unpack a utc time that has hyphens.

```common-lisp
unpack-utc-with-hyphens(utc-string)```


