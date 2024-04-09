
(load-relative "loadtest.rktl")

(Section 'treelist)

(require racket/treelist
         racket/mutable-treelist
         racket/stream)

(test #f treelist? 10)
(test #t treelist? empty-treelist)
(test #t treelist? (treelist))
(test #t treelist? (treelist 1 2 3))

(test (treelist) treelist)
(test (treelist 1 2 3) treelist 1 2 3)
(test #t equal-always? (treelist 1 2 3) (treelist 1 2 3))
(test #f equal-always? (treelist "a") (treelist (string #\a)))
(err/rt-test (treelist #:oops 10))

(define big-N (* 1024 1024))
(define big-treelist (vector->treelist (for/vector ([i (in-range big-N)])
                                         i)))
(test big-N 'len (treelist-length big-treelist))
(test #t 'content
      (for/and ([i (in-range big-N)])
        (eqv? i (treelist-ref big-treelist i))))
(test big-N 'content
      (for/fold ([v 0]) ([e (in-treelist big-treelist)])
        (and (= v e)
             (add1 v))))
(test #t 'rebuild
      (equal? (for/treelist ([i (in-range big-N)])
                i)
              big-treelist))
(test (treelist 1 -1 2 -2 3 -3) 'for*
      (for*/treelist ([i (in-range 1 4)]
                      [m '(1 -1)])
        (* i m)))

(test (make-treelist 0 567) "make-treelist 0" (treelist))
(test (eq? (make-treelist 0 567) (treelist)) "eq make-treelist" #t)
(test (make-treelist 1 #f) "make-treelist 1" (treelist #f))
(test (make-treelist 2 #f) "make-treelist 2" (treelist #f #f))
(test (equal? (make-treelist 100 #f) (vector->treelist (make-vector 100 #f))) "make-treelist 100" #t)
(test (equal? (make-treelist 100 'other) (vector->treelist (make-vector 100 'other))) "make-treelist 100" #t)
(test (equal? (make-treelist 101 #f) (vector->treelist (make-vector 101 #f))) "make-treelist 101" #t)
(test (equal? (make-treelist 1000 #f) (vector->treelist (make-vector 1000 #f))) "make-treelist 1000" #t)
(test (equal? (make-treelist 1001 #f) (vector->treelist (make-vector 1001 #f))) "make-treelist 1001" #t)
(test (equal? (make-treelist 10000 #f) (vector->treelist (make-vector 10000 #f))) "make-treelist 10000" #t)
(test (equal? (make-treelist 10001 #f) (vector->treelist (make-vector 10001 #f))) "make-treelist 10001" #t)
(test (equal? (make-treelist 12321 #f) (vector->treelist (make-vector 12321 #f))) "make-treelist 12321" #t)

(define-syntax-rule (test-bad (op arg ...))
  (err/rt-test (op arg ...) exn:fail:contract? (regexp (string-append "^"
                                                                      (regexp-quote (symbol->string 'op))
                                                                      ":"))))

(define small-treelist (treelist 0 "a" 'b '#:c))
(define (treelist-tests small-treelist)
  (test #f treelist-empty? small-treelist)
  (test #t equal? small-treelist small-treelist)
  (test 0 treelist-first small-treelist)
  (test '#:c treelist-last small-treelist)
  (test (treelist 0 "a" 'B '#:c) treelist-set small-treelist 2 'B)
  (test (treelist 0 "a" 'b '#:c #xD) treelist-add small-treelist #xD)
  (test (treelist -1 0 "a" 'b '#:c) treelist-cons small-treelist -1)
  (test (treelist 0 "a" 'b '#:c 0 "a" 'b '#:c) treelist-append small-treelist small-treelist)
  (test (treelist 0 "a" 'b "bzz" '#:c) treelist-insert small-treelist 3 "bzz")
  (test (treelist "neg" 0 "a" 'b '#:c) treelist-insert small-treelist 0 "neg")
  (test (treelist 0 "a" 'b '#:c #xD) treelist-insert small-treelist 4 #xD)
  (test (treelist 0 "a" '#:c) treelist-delete small-treelist 2)
  (test (treelist "a" 'b '#:c) treelist-delete small-treelist 0)
  (test (treelist 0 "a" 'b) treelist-delete small-treelist 3)
  (test (treelist 0 "a" 'b) treelist-take small-treelist 3)
  (test empty-treelist treelist-take small-treelist 0)
  (test (treelist '#:c) treelist-drop small-treelist 3)
  (test empty-treelist treelist-drop small-treelist 4)
  (test (treelist "a" 'b '#:c) treelist-take-right small-treelist 3)
  (test empty-treelist treelist-take-right small-treelist 0)
  (test (treelist 0) treelist-drop-right small-treelist 3)
  (test empty-treelist treelist-drop-right small-treelist 4)
  (test (treelist "a" 'b) treelist-sublist small-treelist 1 3)
  (test empty-treelist treelist-sublist small-treelist 1 1)
  (test (treelist "a" 'b '#:c) treelist-sublist small-treelist 1 4)
  (test (treelist "a" 'b '#:c) treelist-rest small-treelist)
  (test (treelist '#:c 'b "a" 0) treelist-reverse small-treelist)
  (test '#(0 "a" b #:c) treelist->vector small-treelist)
  (test '(0 "a" b #:c) treelist->list small-treelist)
  (test small-treelist vector->treelist '#(0 "a" b #:c))
  (test small-treelist list->treelist '(0 "a" b #:c))
  (test (treelist '(0) '("a") '(b) '(#:c)) treelist-map small-treelist list)
  (let ([v #f])
    (test (void) treelist-for-each small-treelist (lambda (e)
                                                    (set! v (cons e v))))
    (test '(#:c b "a" 0 . #f) values v))
  (test #t treelist-member? small-treelist "a")
  (test #f treelist-member? small-treelist 'x)
  (test #t treelist-member? (treelist-add small-treelist #f) #f)
  (test #t treelist-member? small-treelist (string #\a))
  (test #f treelist-member? small-treelist (string #\a) equal-always?)
  (test "a" treelist-find small-treelist string?)
  (test '#:c treelist-find small-treelist keyword?)
  (test #f treelist-find small-treelist list?)
  (test (treelist 1 2 3 5) treelist-sort (treelist 5 3 1 2) <)
  (test (treelist 5 3 2 1) treelist-sort (treelist 5 3 1 2) < #:key -)
  (test (treelist 5 3 2 1) treelist-sort (treelist 5 3 1 2) < #:key - #:cache-keys? #t)

  (test-bad (treelist-empty? 0))
  (test-bad (treelist-first 0))
  (test-bad (treelist-first empty-treelist))
  (test-bad (treelist-last 0))
  (test-bad (treelist-last empty-treelist))
  (test-bad (treelist-rest 0))
  (test-bad (treelist-rest empty-treelist))
  (test-bad (treelist-set 0 0 0))
  (test-bad (treelist-set small-treelist -1 0))
  (test-bad (treelist-set small-treelist #f 0))
  (test-bad (treelist-set small-treelist 100 0))
  (test-bad (treelist-add 0 0))
  (test-bad (treelist-cons 0 0))
  (test-bad (treelist-append 0 0))
  (test-bad (treelist-append 0 small-treelist))
  (test-bad (treelist-append small-treelist 0))
  (test-bad (treelist-insert 0 0 0))
  (test-bad (treelist-insert small-treelist #f 0))
  (test-bad (treelist-insert small-treelist -1 0))
  (test-bad (treelist-insert small-treelist 100 0))
  (test-bad (treelist-delete 0 0))
  (test-bad (treelist-delete small-treelist #f))
  (test-bad (treelist-delete small-treelist -1))
  (test-bad (treelist-delete small-treelist 100))
  (test-bad (treelist-take 0 0))
  (test-bad (treelist-take small-treelist #f))
  (test-bad (treelist-take small-treelist -1))
  (test-bad (treelist-take small-treelist 100))
  (test-bad (treelist-drop 0 0))
  (test-bad (treelist-drop small-treelist #f))
  (test-bad (treelist-drop small-treelist -1))
  (test-bad (treelist-drop small-treelist 100))
  (test-bad (treelist-take-right 0 0))
  (test-bad (treelist-take-right small-treelist #f))
  (test-bad (treelist-take-right small-treelist -1))
  (test-bad (treelist-take-right small-treelist 100))
  (test-bad (treelist-drop-right 0 0))
  (test-bad (treelist-drop-right small-treelist #f))
  (test-bad (treelist-drop-right small-treelist -1))
  (test-bad (treelist-drop-right small-treelist 100))
  (test-bad (treelist-sublist 0 0 0))
  (test-bad (treelist-sublist small-treelist #f 0))
  (test-bad (treelist-sublist small-treelist -1 0))
  (test-bad (treelist-sublist small-treelist 0 #f))
  (test-bad (treelist-sublist small-treelist 0 -1))
  (test-bad (treelist-sublist small-treelist 100 101))
  (test-bad (treelist-sublist small-treelist 2 1))
  (test-bad (treelist-reverse 0))
  (test-bad (treelist->vector 0))
  (test-bad (treelist->list 0))
  (test-bad (vector->treelist 0))
  (test-bad (list->treelist 0))
  (test-bad (treelist-map 0 0))
  (test-bad (treelist-map treelist 0))
  (test-bad (treelist-map 0 void))
  (test-bad (treelist-map treelist cons))
  (test-bad (treelist-for-each 0 0))
  (test-bad (treelist-for-each treelist 0))
  (test-bad (treelist-for-each 0 void))
  (test-bad (treelist-for-each treelist cons))
  (test-bad (treelist-member? 0 0))
  (test-bad (treelist-member? 0 0 0))
  (test-bad (treelist-member? small-treelist 0 0))
  (test-bad (treelist-member? small-treelist 0 add1))
  (test-bad (treelist-find 0 0))
  (test-bad (treelist-find small-treelist 0 0))
  (test-bad (treelist-find small-treelist 0 cons))
  (test-bad (treelist-sort 0 0))
  (test-bad (treelist-sort small-treelist 0))
  (test-bad (treelist-sort small-treelist add1))
  (test-bad (treelist-sort small-treelist cons #:key cons))
  (test-bad (chaperone-treelist 0 #:state #f #:ref void #:set void #:insert void #:append void #:prepend void #:delete void #:take void #:drop void))
  (test-bad (chaperone-treelist small-treelist #f #:state #f #:ref #f #:set void #:insert void #:append void #:prepend void #:delete void #:take void #:drop void))
  (test-bad (chaperone-treelist small-treelist #:state #f #:ref (lambda (x) x) #:set void #:insert void #:append void #:prepend void #:delete void #:take void #:drop void))
  (test-bad (chaperone-treelist small-treelist #:state #f #:ref void #:set (lambda (x) x) #:insert void #:append void #:prepend void #:delete void #:take void #:drop void))
  (test-bad (chaperone-treelist small-treelist #:state #f #:ref void #:set void #:insert (lambda (x) x) #:append void #:prepend void #:delete void #:take void #:drop void))
  (test-bad (chaperone-treelist small-treelist #:state #f #:ref void #:set void #:insert void #:append (lambda (x) x) #:prepend void #:delete void #:take void #:drop void))
  (test-bad (chaperone-treelist small-treelist #:state #f #:ref void #:set void #:insert void #:append void #:prepend  (lambda (x) x) #:delete void #:take void #:drop void))
  (test-bad (chaperone-treelist small-treelist #:state #f #:ref void #:set void #:insert void #:append void #:prepend void #:delete void #:take (lambda (x) x) #:drop void))
  (test-bad (chaperone-treelist small-treelist #:state #f #:ref void #:set void #:insert void #:append void #:prepend void #:delete void #:take void #:drop (lambda (x) x)))
  (test-bad (chaperone-treelist small-treelist #:state #f #:ref void #:set void #:insert void #:append void #:prepend void #:delete void #:take void #:drop void 0))
  (test-bad (chaperone-treelist small-treelist #:state #f #:ref void #:set void #:insert void #:append void #:prepend void #:delete void #:take void #:drop void 0 1))
  (void))

(treelist-tests small-treelist)
(treelist-tests (chaperone-treelist small-treelist
                                    #:state #false
                                    #:ref (lambda (t i v state) v)
                                    #:set (lambda (t i v state) (values v state))
                                    #:insert (lambda (t i v state) (values v state))
                                    #:append (lambda (t o state) (values o state))
                                    #:prepend (lambda (o t state) (values o state))
                                    #:delete (lambda (t i state) state)
                                    #:take (lambda (t i state) state)
                                    #:drop (lambda (t i state) state)))

;; ----------------------------------------

(define small-mutable-treelist (make-mutable-treelist 4))
(mutable-treelist-set! small-mutable-treelist 0 0)
(mutable-treelist-set! small-mutable-treelist 1 "a")
(mutable-treelist-set! small-mutable-treelist 2 'b)
(mutable-treelist-set! small-mutable-treelist 3 '#:c)
(test small-treelist mutable-treelist-snapshot small-mutable-treelist)

(test #t mutable-treelist-empty? (make-mutable-treelist 0))

(define (mutable-treelist-tests small-treelist wrap)
  (define test!
    (make-keyword-procedure
     (lambda (kws kw-args expect op! mtl . args)
       (define copy (wrap (mutable-treelist-copy mtl)))
       (test #t void? (keyword-apply op! kws kw-args copy args))
       (test expect `(,op!) (mutable-treelist-snapshot copy)))))
  (test #f mutable-treelist-empty? small-treelist)
  (test #t equal? small-treelist small-treelist)
  (test (treelist 0 "a" 'b '#:c) mutable-treelist-snapshot small-treelist)
  (test (treelist 0 "a" 'b '#:c) mutable-treelist-snapshot small-treelist 0 #f)
  (test (treelist "a" 'b '#:c) mutable-treelist-snapshot small-treelist 1)
  (test (treelist "a" 'b '#:c) mutable-treelist-snapshot small-treelist 1 #f)
  (test (treelist "a" 'b) mutable-treelist-snapshot small-treelist 1 3)
  (test empty-treelist mutable-treelist-snapshot small-treelist 3 3)
  (test 0 mutable-treelist-first small-treelist)
  (test '#:c mutable-treelist-last small-treelist)
  (test! (treelist 0 "a" 'B '#:c) mutable-treelist-set! small-treelist 2 'B)
  (test! (treelist 0 "a" 'b '#:c #xD) mutable-treelist-add! small-treelist #xD)
  (test! (treelist -1 0 "a" 'b '#:c) mutable-treelist-cons! small-treelist -1)
  (test! (treelist 0 "a" 'b '#:c 0 "a" 'b '#:c) mutable-treelist-append! small-treelist small-treelist)
  (test! (treelist 0 "a" 'b "bzz" '#:c) mutable-treelist-insert! small-treelist 3 "bzz")
  (test! (treelist "neg" 0 "a" 'b '#:c) mutable-treelist-insert! small-treelist 0 "neg")
  (test! (treelist 0 "a" 'b '#:c #xD) mutable-treelist-insert! small-treelist 4 #xD)
  (test! (treelist 0 "a" '#:c) mutable-treelist-delete! small-treelist 2)
  (test! (treelist "a" 'b '#:c) mutable-treelist-delete! small-treelist 0)
  (test! (treelist 0 "a" 'b) mutable-treelist-delete! small-treelist 3)
  (test! (treelist 0 "a" 'b) mutable-treelist-take! small-treelist 3)
  (test! empty-treelist mutable-treelist-take! small-treelist 0)
  (test! (treelist '#:c) mutable-treelist-drop! small-treelist 3)
  (test! empty-treelist mutable-treelist-drop! small-treelist 4)
  (test! (treelist "a" 'b '#:c) mutable-treelist-take-right! small-treelist 3)
  (test! empty-treelist mutable-treelist-take-right! small-treelist 0)
  (test! (treelist 0) mutable-treelist-drop-right! small-treelist 3)
  (test! empty-treelist mutable-treelist-drop-right! small-treelist 4)
  (test! (treelist "a" 'b) mutable-treelist-sublist! small-treelist 1 3)
  (test! empty-treelist mutable-treelist-sublist! small-treelist 1 1)
  (test! (treelist "a" 'b '#:c) mutable-treelist-sublist! small-treelist 1 4)
  (test! (treelist '#:c 'b "a" 0) mutable-treelist-reverse! small-treelist)
  (test '#(0 "a" b #:c) mutable-treelist->vector small-treelist)
  (test '(0 "a" b #:c) mutable-treelist->list small-treelist)
  (test small-treelist vector->mutable-treelist '#(0 "a" b #:c))
  (test small-treelist list->mutable-treelist '(0 "a" b #:c))
  (test! (treelist '(0) '("a") '(b) '(#:c)) mutable-treelist-map! small-treelist list)
  (let ([v #f])
    (test (void) mutable-treelist-for-each small-treelist (lambda (e)
                                                            (set! v (cons e v))))
    (test '(#:c b "a" 0 . #f) values v))
  (test #t mutable-treelist-member? small-treelist "a")
  (test #f mutable-treelist-member? small-treelist 'x)
  (let ([mt (mutable-treelist-copy small-treelist)])
    (mutable-treelist-add! mt #f)
    (test #t mutable-treelist-member? mt #f))
  (test #t mutable-treelist-member? small-treelist (string #\a))
  (test #f mutable-treelist-member? small-treelist (string #\a) equal-always?)
  (test "a" mutable-treelist-find small-treelist string?)
  (test '#:c mutable-treelist-find small-treelist keyword?)
  (test #f mutable-treelist-find small-treelist list?)
  (test! (treelist 1 2 3 5) mutable-treelist-sort! (mutable-treelist 5 3 1 2) <)
  (test! (treelist 5 3 2 1) mutable-treelist-sort! (mutable-treelist 5 3 1 2) < #:key -)
  (test! (treelist 5 3 2 1) mutable-treelist-sort! (mutable-treelist 5 3 1 2) < #:key - #:cache-keys? #t)
  
  (test-bad (mutable-treelist-snapshot 0))
  (test-bad (mutable-treelist-snapshot 0 0))
  (test-bad (mutable-treelist-snapshot 0 0 0))
  (test-bad (mutable-treelist-snapshot small-treelist #f))
  (test-bad (mutable-treelist-snapshot small-treelist #f #f))
  (test-bad (mutable-treelist-snapshot small-treelist 5))
  (test-bad (mutable-treelist-snapshot small-treelist 5 #f))
  (test-bad (mutable-treelist-snapshot small-treelist 5 5))
  (test-bad (mutable-treelist-snapshot small-treelist 3 2))
  (test-bad (mutable-treelist-empty? 0))
  (test-bad (mutable-treelist-first 0))
  (test-bad (mutable-treelist-first (make-mutable-treelist 0)))
  (test-bad (mutable-treelist-last 0))
  (test-bad (mutable-treelist-last (make-mutable-treelist 0)))
  (test-bad (mutable-treelist-set! 0 0 0))
  (test-bad (mutable-treelist-set! small-treelist -1 0))
  (test-bad (mutable-treelist-set! small-treelist #f 0))
  (test-bad (mutable-treelist-set! small-treelist 100 0))
  (test-bad (mutable-treelist-add! 0 0))
  (test-bad (mutable-treelist-cons! 0 0))
  (test-bad (mutable-treelist-append! 0 0))
  (test-bad (mutable-treelist-append! 0 small-treelist))
  (test-bad (mutable-treelist-append! small-treelist 0))
  (test-bad (mutable-treelist-insert! 0 0 0))
  (test-bad (mutable-treelist-insert! small-treelist #f 0))
  (test-bad (mutable-treelist-insert! small-treelist -1 0))
  (test-bad (mutable-treelist-insert! small-treelist 100 0))
  (test-bad (mutable-treelist-delete! 0 0))
  (test-bad (mutable-treelist-delete! small-treelist #f))
  (test-bad (mutable-treelist-delete! small-treelist -1))
  (test-bad (mutable-treelist-delete! small-treelist 100))
  (test-bad (mutable-treelist-take! 0 0))
  (test-bad (mutable-treelist-take! small-treelist #f))
  (test-bad (mutable-treelist-take! small-treelist -1))
  (test-bad (mutable-treelist-take! small-treelist 100))
  (test-bad (mutable-treelist-drop! 0 0))
  (test-bad (mutable-treelist-drop! small-treelist #f))
  (test-bad (mutable-treelist-drop! small-treelist -1))
  (test-bad (mutable-treelist-drop! small-treelist 100))
  (test-bad (mutable-treelist-take-right! 0 0))
  (test-bad (mutable-treelist-take-right! small-treelist #f))
  (test-bad (mutable-treelist-take-right! small-treelist -1))
  (test-bad (mutable-treelist-take-right! small-treelist 100))
  (test-bad (mutable-treelist-drop-right! 0 0))
  (test-bad (mutable-treelist-drop-right! small-treelist #f))
  (test-bad (mutable-treelist-drop-right! small-treelist -1))
  (test-bad (mutable-treelist-drop-right! small-treelist 100))
  (test-bad (mutable-treelist-sublist! 0 0 0))
  (test-bad (mutable-treelist-sublist! small-treelist #f 0))
  (test-bad (mutable-treelist-sublist! small-treelist -1 0))
  (test-bad (mutable-treelist-sublist! small-treelist 0 #f))
  (test-bad (mutable-treelist-sublist! small-treelist 0 -1))
  (test-bad (mutable-treelist-sublist! small-treelist 100 101))
  (test-bad (mutable-treelist-sublist! small-treelist 2 1))
  (test-bad (treelist-reverse! 0))
  (test-bad (mutable-treelist->vector 0))
  (test-bad (mutable-treelist->list 0))
  (test-bad (mutable-vector->treelist 0))
  (test-bad (mutable-list->treelist 0))
  (test-bad (mutable-treelist-map! 0 0))
  (test-bad (mutable-treelist-map! treelist 0))
  (test-bad (mutable-treelist-map! 0 void))
  (test-bad (mutable-treelist-map! treelist cons))
  (test-bad (mutable-treelist-for-each 0 0))
  (test-bad (mutable-treelist-for-each treelist 0))
  (test-bad (mutable-treelist-for-each 0 void))
  (test-bad (mutable-treelist-for-each treelist cons))
  (test-bad (mutable-treelist-member? 0 0))
  (test-bad (mutable-treelist-member? 0 0 0))
  (test-bad (mutable-treelist-member? small-treelist 0 0))
  (test-bad (mutable-treelist-member? small-treelist 0 add1))
  (test-bad (mutable-treelist-find 0 0))
  (test-bad (mutable-treelist-find small-treelist 0 0))
  (test-bad (mutable-treelist-find small-treelist 0 cons))
  (test-bad (mutable-treelist-sort! 0 0))
  (test-bad (mutable-treelist-sort! small-treelist 0))
  (test-bad (mutable-treelist-sort! small-treelist add1))
  (test-bad (mutable-treelist-sort! small-treelist cons #:key cons))

  (void))

(mutable-treelist-tests small-mutable-treelist values)
(let ([chap (lambda (mtl)
              (chaperone-mutable-treelist mtl
                                          #:ref (lambda (t i v) v)
                                          #:set (lambda (t i v) v)
                                          #:insert (lambda (t i v) v)
                                          #:append (lambda (t o) o)))])
  (mutable-treelist-tests (chap small-mutable-treelist) chap))

;; ----------------------------------------

(let* ([tl (treelist (vector 1 2 3)
                     (vector 4 5)
                     (vector 6 7 8 9))])
  (define (check n)
    (unless (even? n) (error "no" n)))
  (define (exn:no? v)
    (and (exn:fail? v)
         (regexp-match? #rx"^no" (exn-message v))))

  (define real-chaperone-treelist chaperone-treelist)
  
  (define (check-chaperone mk-tl
                           treelist-length
                           treelist-ref
                           treelist-cons
                           treelist-add
                           treelist-first
                           treelist-last
                           treelist-rest
                           treelist-drop
                           treelist-append
                           treelist-find
                           impersonate?)
    (define (inc n)
      (if impersonate?
          (add1 n)
          n))
    (define (chaperone-val v)
      (chaperone-vector v
                        (lambda (i v n) (check n) n)
                        (lambda (i v n) (check n) n)))
    (define (impersonate-val v)
      (impersonate-vector v
                          (lambda (i v n) (check n) (inc n))
                          (lambda (i v n) (check n) (inc n))))
    (define (get-mode tl)
      (cond
        [(treelist? tl)
         (values chaperone-treelist chaperone-val #f)]
        [(not impersonate?)
         (values chaperone-mutable-treelist chaperone-val #t)]
        [else
         (values impersonate-mutable-treelist impersonate-val #t)]))
    (define (check-on-read tl)
      (define-values (chaperone-treelist chaperone-val mutable?) (get-mode tl))
      (if mutable?
          (chaperone-treelist tl
                              #:ref (lambda (t i v) (chaperone-val v))
                              #:set (lambda (t i v) v)
                              #:insert (lambda (t i v) v)
                              #:append (lambda (t o) o))
          (chaperone-treelist tl
                              #:state #false
                              #:state-key 'check-on-read
                              #:ref (lambda (t i v s) (chaperone-val v))
                              #:set (lambda (t i v s) (values v s))
                              #:insert (lambda (t i v s) (values v s))
                              #:append (lambda (t o s) (values o s))
                              #:append2 (lambda (t o s s2) (values o (list s s2)))
                              #:prepend (lambda (o t s) (values o s))
                              #:delete (lambda (t i s) s)
                              #:take (lambda (t i s) s)
                              #:drop (lambda (t i s) s))))
    (define (check-on-write tl)
      (define-values (chaperone-treelist chaperone-val mutable?) (get-mode tl))
      (if mutable?
          (chaperone-treelist tl
                              #:ref (lambda (t i v) v)
                              #:set (lambda (t i v) (chaperone-val v))
                              #:insert (lambda (t i v) (chaperone-val v))
                              #:append (lambda (t o) (check-on-read o)))
          (chaperone-treelist tl
                              #:state #false
                              #:state-key 'check-on-write
                              #:ref (lambda (t i v s) v)
                              #:set (lambda (t i v s) (values (chaperone-val v) s))
                              #:insert (lambda (t i v s) (values (chaperone-val v) s))
                              #:append (lambda (t o s) (values (check-on-read o) s))
                              #:prepend (lambda (o t s) (values (check-on-read o) s))
                              #:delete (lambda (t i s) s)
                              #:take (lambda (t i s) s)
                              #:drop (lambda (t i s) s))))
    (printf "checking ~s~a\n" (mk-tl) (if impersonate? " impersonator" ""))
    (test (inc 2) 'ok (vector-ref (treelist-ref (check-on-read (mk-tl)) 0) 1))
    (err/rt-test (vector-ref (treelist-ref (check-on-read (mk-tl)) 0) 0) exn:no?)
    (test 2 'len (treelist-length (treelist-drop (check-on-read (mk-tl)) 1)))
    (test (inc 4) 'ok (vector-ref (treelist-ref (treelist-drop (check-on-read (mk-tl)) 1) 0) 0))
    (err/rt-test (vector-ref (treelist-ref (treelist-drop (check-on-read (mk-tl)) 1) 0) 1) exn:no?)
    (err/rt-test (vector-ref (treelist-ref (treelist-rest (check-on-read (mk-tl))) 0) 1) exn:no?)
    (err/rt-test (vector-ref (treelist-ref (treelist-cons (check-on-read (mk-tl)) (vector)) 2) 1) exn:no?)
    (err/rt-test (vector-ref (treelist-ref (treelist-add (check-on-read (mk-tl)) (vector)) 1) 1) exn:no?)
    (test (inc 2) 'ok (vector-ref (treelist-find (check-on-read (mk-tl)) (lambda (v) (= 3 (vector-length v)))) 1))
    (err/rt-test (treelist-find (check-on-read (mk-tl)) (lambda (v) (vector-ref v 0))) exn:no?)
    (err/rt-test (vector-ref (treelist-last (treelist-append (mk-tl) (check-on-read (treelist (vector 1 1 1))))) 0) exn:no?)
    (test 2 'ok (vector-ref (treelist-last (treelist-append (mk-tl) (check-on-read (treelist (vector 1 2 1))))) 1))
    (err/rt-test (vector-ref (treelist-ref (treelist-append (check-on-read (treelist (vector 1 2 1))) (mk-tl)) 2) 1) exn:no?)
    (test 4 'len (treelist-length (treelist-append (check-on-read (mk-tl)) (check-on-read (treelist (vector 1 1 1))))))
    (test 4 'len (treelist-length (treelist-append (check-on-read (mk-tl)) (check-on-read (treelist (mk-tl))))))
    (unless (mutable-treelist? (mk-tl))
      (test '(#f #f) 'keys (treelist-chaperone-state (treelist-append (check-on-read (mk-tl)) (check-on-read (treelist (vector 1 1 1))))
                                                     'check-on-read)))

    (test 2 'ok (vector-ref (treelist-ref (check-on-write (mk-tl)) 0) 1))
    (test 3 'ok (vector-ref (treelist-ref (check-on-write (mk-tl)) 0) 2))
    (test 4 'len (treelist-length (treelist-add (check-on-write (mk-tl)) (vector 1 1 1))))
    (err/rt-test (vector-ref (treelist-first (treelist-cons (check-on-write (mk-tl)) (vector 1 1 1))) 0) exn:no?)
    (test (inc 0) 'ok (vector-ref (treelist-first (treelist-cons (check-on-write (mk-tl)) (vector 1 0 1))) 1))
    (err/rt-test (vector-ref (treelist-last (treelist-append (check-on-write (mk-tl)) (treelist (vector 1 1 1)))) 0) exn:no?)
    (test 2 'ok (vector-ref (treelist-last (treelist-append (check-on-write (mk-tl)) (treelist (vector 1 2 1)))) 1))
    (test 4 'len (treelist-length (treelist-append (check-on-write (mk-tl)) (check-on-write (treelist (vector 1 1 1))))))

    (unless (mutable-treelist? (mk-tl))
      (test #f 'rdc (treelist-chaperone-state (check-on-read (mk-tl)) 'check-on-read))
      (test #f 'wrc (treelist-chaperone-state (check-on-write (mk-tl)) 'check-on-write))
      (test #f 'rd2 (treelist-chaperone-state (check-on-write (check-on-read (mk-tl))) 'check-on-read))
      (test #f 'wr2 (treelist-chaperone-state (check-on-write (check-on-read (mk-tl))) 'check-on-write))
      (err/rt-test (treelist-chaperone-state (check-on-write (mk-tl)) 'check-on-read))
      (test 'nope 'rdx (treelist-chaperone-state (check-on-write (mk-tl)) 'check-on-read (lambda () 'nope)))))

   (check-chaperone (lambda () tl)
                    treelist-length
                    treelist-ref
                    treelist-cons
                    treelist-add
                    treelist-first
                    treelist-last
                    treelist-rest
                    treelist-drop
                    treelist-append
                    treelist-find
                    #f)

   (define (check-mutable-chaperone impersonate?)
     (check-chaperone (lambda () (treelist-copy tl))
                      mutable-treelist-length
                      mutable-treelist-ref
                      (lambda (tl v) (mutable-treelist-cons! tl v) tl)
                      (lambda (tl v) (mutable-treelist-add! tl v) tl)
                      mutable-treelist-first
                      mutable-treelist-last
                      (lambda (tl) (mutable-treelist-drop! tl 1) tl)
                      (lambda (tl n) (mutable-treelist-drop! tl n) tl)
                      (lambda (tl o) (mutable-treelist-append! tl o) tl)
                      mutable-treelist-find
                      impersonate?))
   (check-mutable-chaperone #f)
   (check-mutable-chaperone #t)

  (void))

;; ----------------------------------------

(test #t sequence? (treelist 1 2 3))
(test #t sequence? (mutable-treelist 1 2 3))
(test '(1 2 3) sequence->list (treelist 1 2 3))
(test '(1 2 3) sequence->list (mutable-treelist 1 2 3))

(test #t stream? (treelist 1 2 3))
(test #f stream? (mutable-treelist 1 2 3))
(test 1 stream-first (treelist 1 2 3))
(test (treelist 2 3) stream-rest (treelist 1 2 3))
(test #f stream-empty? (treelist 1 2 3))
(test #t stream-empty? (treelist))

;; ----------------------------------------

(report-errs)