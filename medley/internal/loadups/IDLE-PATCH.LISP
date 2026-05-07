;;; Idle-CPU fix.  Loaded near the end of LOADUP-FULL so the patch is
;;; baked into full.sysout (and apps.sysout, which is built from it).
;;;
;;; Defines a new user-subr \BLOCK.UNTIL.EVENT that blocks the VM in
;;; select() until X / I/O activity arrives or MS milliseconds pass.
;;; See maiko/src/keyevent.c:block_until_event.
;;;
;;; Hooks it into the two paths the system spends idle CPU on:
;;;   - TTYBACKGROUNDFNS: run by \TTYBACKGROUND on every keyboard-wait
;;;     iteration.  Replaces the busy poll with a deep sleep.
;;;   - lispusers/BACKGROUND-YIELD: existing per-tick yield that does
;;;     a 833-microsecond nanosleep ~100 times per second.  Redirected
;;;     through the new sleep so it actually goes deep.
;;;
;;; CL:COMPILE NIL '(LAMBDA ...) is used in place of (COMPILE ...) so
;;; no interactive prompts ("listing? " / "output file? ") fire during
;;; the loadup.

(cl:in-package "INTERLISP")

;;; Direct MISCN USER-SUBR with literal index 1.  Avoids the (USER-SUBR ...)
;;; macro and its ADD-USER-SUBR registration step (which uses CL:CERROR
;;; and would risk breaking the loadup if the entry already exists).

(PUTD '|\BLOCK.UNTIL.EVENT|
      (CL:COMPILE NIL '(LAMBDA (MS) (MISCN USER-SUBR 1 MS))))

;;; Idle sleep hook.  Added to TTYBACKGROUNDFNS so the existing
;;; \TTYBACKGROUND iteration calls it on each keyboard-wait pass.
;;; 100 ms keeps caret-flash and Lisp periodic timers responsive.
;;; Note: SIGVTALRM has SA_RESTART and ITIMER_VIRTUAL pauses during
;;; sleep, so the actual block ends only on real X / I/O activity or
;;; on the timeout.

(PUTD '|\IDLE.SLEEP.HOOK|
      (CL:COMPILE NIL '(LAMBDA NIL (|\BLOCK.UNTIL.EVENT| 100))))

(SETQ TTYBACKGROUNDFNS
      (APPEND (REMOVE '|\IDLE.SLEEP.HOOK| TTYBACKGROUNDFNS)
              '(|\IDLE.SLEEP.HOOK|)))

;;; Replace lispusers/BACKGROUND-YIELD: instead of a 833-microsecond
;;; nanosleep called ~100 times per second, do a single deeper block.

(PUTD 'BACKGROUND-YIELD
      (CL:COMPILE NIL '(LAMBDA NIL
                         (LET ((|\BACKGROUND| T))
                           (DECLARE (SPECVARS |\BACKGROUND|))
                           (|\BLOCK.UNTIL.EVENT| 100)
                           (SUBRCALL CAUSE-INTERRUPT)))))
