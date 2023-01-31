#lang racket/base

(require (for-syntax racket/base
                     racket/syntax
                     "exptime/syntax.rkt"))
(provide (rename-out [make-a-unit make-unit]) unit? unit-import-sigs unit-export-sigs unit-go unit-deps
         unit-export check-unit check-no-imports check-sigs check-deps check-helper)

;; for named structures
(define insp (current-inspector))

;; Note [Signature runtime representation]
;; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
;; At runtime, signatures largely do not exist: they are quite
;; second-class. But we do need a unique value to identify each
;; signature by, as the linker needs to be able to match up linkages
;; by their signature. No other information is necessary, so a gensym
;; per signature will do; we call this gensym the *signature id*.
;;
;; However, two things complicate the story slightly:
;;
;;   1. Multiple linkages for the same signature can be distinguished
;;      using tags.
;;
;;   2. Signatures support inheritance, which allows an import linkage
;;      to be satisfied by an export linkage of a sub-signature.
;;
;; The first point is managed easily by possibly combining each
;; signature gensym with a tag symbol, yielding the definition of a
;; *signature key*:
;;
;;     signature-id?  = (and/c symbol? symbol-uninterned?)
;;     tag-symbol?    = (and/c symbol? symbol-interned?)
;;     signature-key? = (or/c signature-id?
;;                            (cons/c tag-symbol? signature-key?))
;;
;; The second point is somewhat more subtle, but our solution is
;; simple: each signature is associated with a *list* of signature ids,
;; and a sub-signature includes the signature ids of all of its super-
;; signatures. Each signature id uniquely identifies the new bindings
;; introduced by *that particular* signature, and those bindings can
;; be stored in separate vectors and linked largely independently.

;; Runtime representation of a unit
(define-struct unit
  ;; Note: the additional symbols in `import-sigs` and `export-sigs`
  ;; are the symbolic names of the signatures, for error reporting.
  (import-sigs ; (vectorof (cons/c symbol? (vectorof signature-key?)))
   export-sigs ; (vectorof (cons/c symbol? (vectorof signature-key?)))
   deps        ; (listof signature-key?)
   go))        ; (-> (values (-> import-table any) export-table ...))

;; For units with inferred names, generate a struct that prints using the name:
(define (make-naming-constructor type name)
  (let-values ([(struct: make- ? -accessor -mutator)
                (make-struct-type name type 0 0 #f null insp)])
    make-))

;; Make a unit value (call by the macro expansion of `unit')
(define (make-a-unit name num-imports exports deps go)
  ((if name 
       (make-naming-constructor 
        struct:unit
        (string->symbol (format "unit:~a" name)))
       make-unit)
   num-imports exports deps go))

;; Helper for building the export table
(define-syntax (unit-export stx)
  (syntax-case stx ()
    [(_ ((esig ...) elocs) ...)
     (with-syntax (((((k . v) ...) ...)
                    (map 
                     (lambda (esigs eloc)
                       (map
                        (lambda (esig) (cons esig eloc))
                        (syntax->list esigs)))
                     (syntax->list #'((esig ...) ...))
                     (syntax->list #'(elocs ...)))))
       #'(make-immutable-hash (list (cons k v) ... ...)))]))

;; check-unit : X symbol -> 
;; ensure that u is a unit value
(define (check-unit u name)
  (unless (unit? u)
    (raise
     (make-exn:fail:contract
      (format "~a: result of unit expression was not a unit: ~e" name u)
      (current-continuation-marks)))))

;; check-helper : (vectorof (cons symbol (vectorof (cons symbol symbol)))))
;                 (vectorof (cons symbol (vectorof (cons symbol symbol)))))
;;                symbol symbol -> 
;; ensure that the unit's signatures match the expected signatures.
(define (check-helper sub-sig super-sig name import?)
  (define t (make-hash))
  (let loop ([i (sub1 (vector-length sub-sig))])
    (when (>= i 0)
      (let ([v (cdr (vector-ref sub-sig i))])
        (let loop ([j (sub1 (vector-length v))])
          (when (>= j 0)
            (let ([vj (vector-ref v j)])
              (hash-set! t vj
                         (if (hash-ref t vj #f)
                             'amb
                             #t)))
            (loop (sub1 j)))))
      (loop (sub1 i))))
  (let loop ([i (sub1 (vector-length super-sig))])
    (when (>= i 0)
      (let* ([v0 (vector-ref (cdr (vector-ref super-sig i)) 0)]
             [r (hash-ref t v0 #f)])
        (when (or (eq? r 'amb) (not r))
          (let ([tag (if (pair? v0) (car v0) #f)]
                [sub-name (car (vector-ref super-sig i))]
                [err-str (if r
                             "supplies multiple times"
                             "does not supply")])
            (raise
             (make-exn:fail:contract
              (cond
                [(and import? tag)
                 (format "~a: unit argument expects an import for tag ~a with signature ~a, which this usage context ~a"
                         name
                         tag
                         sub-name
                         err-str)]
                [import?
                 (format "~a: unit argument expects an untagged import with signature ~a, which this usage context ~a"
                         name
                         sub-name
                         err-str)]
                [tag
                 (format "~a: this usage context expects a unit with an export for tag ~a with signature ~a, which the given unit ~a"
                         name
                         tag
                         sub-name
                         err-str)]
                [else
                 (format "~a: this usage context expects a unit with an untagged export with signature ~a, which the given unit ~a"
                         name
                         sub-name
                         err-str)])
              (current-continuation-marks))))))
      (loop (sub1 i)))))

;; check-deps : (hash/c signature-key? (cons/c symbol? symbol?)) unit? symbol? -> void?
;; The hash table keys are signature keys (see Note [Signature runtime representation]).
;; The values are the name of the signature and the link-id.
(define (check-deps dep-table unit name)
  (for ([dep-key (in-list (unit-deps unit))])
    (define r (hash-ref dep-table dep-key #f))
    (when r
      (raise
       (make-exn:fail:contract
        (if (pair? dep-key)
            (format "~a: initialization dependent signature ~a with tag ~a is supplied from a later unit with link ~a"
                    name (car r) (car dep-key) (cdr r))
            (format "~a: untagged initialization dependent signature ~a is supplied from a later unit with link ~a"
                    name (car r) (cdr r)))
        (current-continuation-marks))))))

;; check-no-imports : unit symbol ->
;; ensures that the unit has no imports
(define (check-no-imports unit name)
  (check-helper (vector) (unit-import-sigs unit) name #t))

;; check-sigs : unit
;;              (vectorof (cons symbol (vectorof (cons symbol symbol)))))
;;              (vectorof (cons symbol (vectorof (cons symbol symbol)))))
;;              symbol ->
;; ensures that unit has the given signatures
(define (check-sigs unit expected-imports expected-exports name)
  (check-helper expected-imports (unit-import-sigs unit) name #t)
  (check-helper (unit-export-sigs unit) expected-exports name #f))