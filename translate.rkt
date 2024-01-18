#lang racket

(require net/http-client json)
(require net/uri-codec)

(define (request domain path)
  (define-values (status header response)
    (http-sendrecv domain path))
  response)

;"http://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&tl=ja&dt=t&q=text"
(define (translate input tolang)
  (let ([path (string-append "/translate_a/single?client=gtx&sl=auto&tl=" tolang "&dt=t&q=" (uri-encode input))])
    (let ([response (request "translate.googleapis.com" path)])
      (let ([data (read-json response)]) 
        (string-join (map (lambda (token)
               (car token))
             (car data)) "")))))

;(translate "hello" "ja")

(provide translate)


