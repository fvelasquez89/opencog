;
; mst-parser.scm
;
; Minimum Spanning Tree parser.
;
; Copyright (c) 2014 Linas Vepstas
;
; ---------------------------------------------------------------------
; OVERVIEW
; --------
; The scripts below implement a simple spanning-tree parser. The goal
; of this parser is to learn a base set of link-grammar disjuncts.
;
; Input to this should be a single sentence. It is presumed, as
; background, that a large number of word-pairs with associated mutual
; information is already avaialable from the atomspace (obtained
; previously).
;
; The algorithm implemented is a basic minimum spanning tree algorithm.
; Initially, a graph clique is constructed from the words in the
; sentence, with every word connected to every other word. The mutual
; information betweeen wrd-pairs is used to determine graph edge lengths.
; The spanning tree is then obtained. Finally, disjuncts are created from
; the resulting parse, by looking at how each word is attached to the
; other words.  The disjuncts are then recorded.
;
; ---------------------------------------------------------------------
;
(use-modules (srfi srfi-1))

; ---------------------------------------------------------------------
;
; Tokenize the text: take the input sentence, and return a list of the
; words in the sentence.  Words are always separated by white-space, so
; this is easy. This also makes a vague attempt to also separate commas,
; periods, and other punctuation.  Returned is a list of words.
;
(define (tokenize-text plain-text)
	; Prefix and suffix lists taken from the link-grammar ANY
	; language 4.0.affix file
	(define prefix "({[<«〈（〔《【［『「``„“‘'''…...¿¡$£₤€¤₳฿₡₢₠₫৳ƒ₣₲₴₭₺ℳ₥₦₧₱₰₹₨₪﷼₸₮₩¥៛호점†††‡§¶©®℗№#")
	(define suffix ")}]>»〉）〕》】］』」’'%,.。:;?!‽؟？！…”–‐、～¢₵™℠")
	(define prefix-list (string->list prefix))
	(define suffix-list (string->list suffix))

	; Tail-recursive helper function. Strip off any prefixes appearing
	; in the list prefli, and return a list of the stripped prefixes,
	; and the remaining word.
	(define (strip-prefli word prefli)
		(if (null? prefli)
			(list word)  ; prefix list is empty, return the word.
			(let* ((punct (car prefli))
					(head (string-ref word 0)))
				(if (eq? punct head) ; it there's a match, then split
					(append
						(list (string punct))
						(strip-prefix (substring word 1)) ; loop again.
					)
					(strip-prefli word (cdr prefli)) ; if no match, recurse.
				)
			)
		)
	)
	; Main entry point for the recursive prefix splitter
	(define (strip-prefix word) (strip-prefli word prefix-list))

	; Tail-recursive helper function. Strip off any suffixes appearing
	; in the list sufli, and return a list of the stripped prefixes,
	; the remaining word, and the stripped suffixes.
	(define (strip-sufli word sufli)
		(if (null? sufli)
			(strip-prefix word)
			(let* ((punct (car sufli))
					(len (- (string-length word) 1))
					(tail (string-ref word len)))
				(if (eq? punct tail)
					(append
						(strip-affix (substring word 0 len))
						(list (string punct))
					)
					(strip-sufli word (cdr sufli))
				)
			)
		)
	)
	; Main entry point for the recursive splitter
	(define (strip-affix word) (strip-sufli word suffix-list))

	(let* ((word-list (string-split plain-text #\ )))
		(concatenate (map strip-affix word-list))
	)
)

; ---------------------------------------------------------------------
; Return the mutual information for a pair of words.
;
; The pair of words are presumed to be connected by the relationship
; lg_rel.  The left and right words are presumed to be WordNodes, or nil.
; If either word is nill, or if the word-pair cannot be found, then a
; default value of -1000 is returned.

(define (get-pair-mi lg_rel left-word right-word)

	; Define a losing score.
	(define bad-mi -1000)

	; We take care here to not actually create the atoms,
	; if they aren't already in the atomspace. cog-node returns
	; nil if the atoms can't be found.
	(define wpr 
		(if (and (not (null? left-word)) (not (null? right-word)))
			(cog-link 'ListLink left-word right-word)
			'()))
	(define evl
		(if (not (null? wpr))
			(cog-link 'EvaluationLink lg_rel wpr)
			'()))
	(if (not (null? evl))
		(tv-conf (cog-tv evl))
		bad-mi
	)
)

; ---------------------------------------------------------------------
; Return the mutual information for a pair of words.
;
; The pair of words are presumed to be connected by the relationship
; lg_rel.  The left and right words are presumed to be strings.
; If the word-pair cannot be found, then a default value of -1000 is
; returned.

(define (get-pair-mi-str lg_rel left-word-str right-word-str)

	(get-pair-mi lg_rel
		(cog-node 'WordNode left-word-str)
		(cog-node 'WordNode right-word-str)
	)
)

; ---------------------------------------------------------------------
;
; Minimum Spanning Tree parser.
;
; Choice of algorithms:
; Prim is very easy; but seems too easy to give good results.
; Kruskal is good, but seems hard to control a no-link-cross contraint.
; Settle on a variant of Borůvka's algo, together with a no-links-cross
; constraint.

(define (mst-parse-text plain-text)
	(define lg_any (LinkGrammarRelationshipNode "ANY"))

	; Define a losing score.
	(define bad-mi -1000)

	; Given a left-word, and a list of words to the right of it, pick
	; a word from the list that has the highest-MI attachment to the left
	; word.  Return a list containing that cost and the selected word-pair
	; (i.e. the specified left-word, and the chosen right-word).
	; The search is made over word pairs united by lg_rel.
	(define (pick-best-cost-left-pair lg_rel left-word word-list)
		(fold
			(lambda (right-word max-pair)
				(define max-mi (car max-pair))
				(define best-pair (cdr max-pair))
				(define cur-mi (get-pair-mi lg_rel left-word right-word))
				(if (< max-mi cur-mi)
					(list cur-mi (list left-word right-word))
					max-pair
				)
			)
			(list bad-mi '())
			word-list
		)
	)

	; Given a right-word, and a list of words to the left of it, pick
	; a word from the list that has the highest-MI attachment to the 
	; right word.  Return a list containing that cost and the selected
	; word-pair (i.e. the chosen left-word, and the specified right-word).
	; The search is made over word pairs united by lg_rel.
	(define (pick-best-cost-right-pair lg_rel right-word word-list)
		(fold
			(lambda (left-word max-pair)
				(define max-mi (car max-pair))
				(define best-pair (cdr max-pair))
				(define cur-mi (get-pair-mi lg_rel left-word right-word))
				(if (< max-mi cur-mi)
					(list cur-mi (list left-word right-word))
					max-pair
				)
			)
			(list bad-mi '())
			word-list
		)
	)

	; Given a list of words, return a list containing the cost and the
	; word-pair with the best cost (highest MI, in this case). The search
	; is made over word pairs united by lg_rel.
	(define (pick-best-cost-pair lg_rel word-list)

		; scan from left-most word to the right.
		(define best-left (pick-best-cost-left-pair lg_rel (car word-list) (cdr word-list)))
		(if (eq? 2 (length word-list))
			; If the list is two words long, we are done.
			best-left
			; else the list is longer than two words. Pick between two
			; possibilities -- those that start with left-most word, and
			; something else.
			(let ((best-rest (pick-best-cost-pair lg_rel (cdr word-list))))
				(if (< (car best-left) (car best-rest))
					best-rest
					best-left
				)
			)
		)
	)

	; Given a word list, and a pair of two words from that list, split
	; the list into three parts: the part that is strictly to the left
	; of the pair, the part in the middle, and the part strictly to the
	; right of right of the pair. Return a list containing these three
	; lists.
	(define (split-list word-pair word-list)
		(define left-word (car word-pair))
		(define right-word (cadr word-pair))
		(define left-sp 
			(break (lambda (word) (equal? word left-word)) word-list)
		)
		(define lefty (car left-sp))
		(define rest (cadr left-sp))
		(define mid-sp
			(if (null? rest)
				(list '() '())
				(break (lambda (word) (equal? word right-word)) (car rest))
			)
		)
		(define midy (car mid-sp))
		(define rrest (cadr mid-sp))
		(define righty (if (null? rrest) '() (cdr rrest)))

		(list lefty midy righty)
	)

	(let* ((word-strs (tokenize-text plain-text))
			(word-list (map (lambda (str) (cog-node 'WordNode str)) word-strs))
			(start-pair (pick-best-cost-pair lg_any word-list))
		)
(display start-pair)
	)
)

; (define lg_any (LinkGrammarRelationshipNode "ANY"))
; (init-trace)
; (load-atoms-of-type item-type)
; (fetch-incoming-set lg_any)
; (mst-parse-text "faire un test")
; (mst-parse-text "Elle jouit notamment du monopole de la restauration ferroviaire")
;
; (define my-word-list (map (lambda (str) (cog-node 'WordNode str))
;      (tokenize-text "Elle jouit notamment du monopole de la restauration ferroviaire")))
; answer: du monopole 5.786411762237549
;      (tokenize-text "faire un test entre quelques mots")))
; answer: faire quelques 12.62707805633545
;      (tokenize-text "grande petit mot liste pour tout occasion")))
;
; (define my-start-pair (pick-best-cost-pair lg_any my-word-list))
; (split-list (cadr my-start-pair) my-word-list)
