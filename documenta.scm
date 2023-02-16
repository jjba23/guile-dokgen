#!/run/current-system/profile/bin/guile -s
!#

(use-modules (documenta cli))


(call (command-line) spec)
