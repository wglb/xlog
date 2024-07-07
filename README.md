# xlog

Application logging library

Quick look at features:

* Optionally Time-stamped formatted log entries
   2021-10-27 13:55:36.423013 xlog: end of log-file 2021-10-27_dispatch-rescancanm.log
* Log files can be appended to or superseded
   
* Log directory can be specified `(with-open-log-file (<filespec> :dir "<log file directory>") ... )`
* Log file extension can be specified

  `(with-open-log-file (<filespec> :extension "out") ... )`

* Log entry can be also pushed to standard out
   Usual output is (xlogf "<format string>" <val1> <val2>) ; in the manner of (format ...)
   Copy to standard output is 
   
   `(xlogft "<format string>" ... _)`
* Alert file support for status reporting
   Set alert file name: `(set-alert-file-name "<name of alert file>").`
   
   `(xalert "simple string")` ; opens alert file, writes values, closes alert file
   `(xlalertf "format string" <val1> ... )`
* Support for date-stamped file names with options for hour,minute,second resulution, hour resolution, date only, or no date.
   `(with-open-log-file ("filespec" :dates (t :hms :hour :dates)`
* Log files can be nested. 
   The `with-open-log-file` macro wraps code in the manner of `with-open-file`. If you nest the calls, upon closing the nested
   open, the original one resumes. This can ease reading detail processes within a global process.

## Stackable log files

Log files can be nested.  A second consecutive log file opening will push the existing log file and name onto a stack. 
If `show-log-file-name` is set, the name of the new log file will be written to the existing one. Once the new log
file is opened, the name of the previously opened log file will be logged.

## Alert file

The purpose of the alert file is to provide a short status for other programs to inspect without analyzing the log file.

```common-lisp
set-alert-file-name (name)
```

```common-lisp
xalertf(fmt vars)
```
Write an alert to the alert file and to the log file.

Functions:

### Answer the version  

```common-lisp
(xlog-version)
```

### Unpack a utc time that has hyphens.

For an example string `2024-05-30 00:00:01.593760`, answer multi-value seconds and milliseconds.

```common-lisp
unpack-utc-with-hyphens(utc-string)
```


### For a timestampe formatted by how long ago was the 'tim' timestamp,

`2024-05-30 00:00:01.593760`

```common-lisp
calc-elapsed-time (tim)
```
### Produce a formatted timestamp from the current time 

```common-lisp
formatted-current-time-micro (str)
```

### Answer the mtime (formatted) of a file and its age

```common-lisp
formatted-file-time (filename)
```

### Format the current time

```common-lisp
formatted-current-time ()
```

### Format dates

```common-lisp
dates-ymd (datecmd)
```

For values of `datecmd` 

* `:hms` Format the date with month, day, year, hours, minutes, and seconds.
* `:hour` Format the date with month, day, year, and hour
* `t` Format the date year, month, day

### Conditional debug macro

```common-lisp
debugc (val stmt)
```

If `val` is less than or equal to `*debug-level*`, evaluate `stmt`.


### Write line to log 

```common-lisp
xlog(str)
```

Write a time-stamped line to the log file. All log entries come through this function. Items written the log file
end with a new line. Lines are forced to begin at the first position by the use of `fresh-line`.

### Write a line without time prefix to the log file.

```common-lisp
xlognt
```

As `xlog`, but without time prefix.

### Flush the log file

```common-lisp
xlogfin
```

### Write a line to the log file using a specified format.

```common-lisp
xlogf (fmt vars)
```

### Write a formatted line to the log file, and flush the output.

```common-lisp
xlogff(fmt vars)
```

### Write a formatted time-stamped line to the log file and to standard output

```common-lisp
xlogft(fmt vars)
```

### Write a formatted non-time-stamped line to log file


```common-lisp
xlogntf(fmt vars)
```

### Write a non-time-stamped formatted line to the log file and standard output.

```common-lisp
xlogntft
```

## Portability
