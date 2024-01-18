#lang racket


(require ffi/unsafe
         ffi/unsafe/define
         racket/runtime-path)

;brew list tesseract
(define-runtime-path libtesseract
  "./lib/libtesseract.5.dylib")

(define tesseract-lib (ffi-lib libtesseract))
(define-ffi-definer define-tesseract tesseract-lib)

(define-cstruct _Pix  ([w _uint32 ]
                       [h _uint32] 
                       [wpl _uint32]
                       [refcount _uint32]
                       [xres _uint32]
                       [yres _uint32]
                       [informat _uint32]
                       [text _string]
                       [PixColormap _pointer]
                       [data _pointer]
                       ))

(define-cpointer-type _TessBaseAPI)
;(define-cpointer-type _Pix)
;https://qiita.com/ekzemplaro/items/61da97b3a27389e2951c

;https://github.com/tesseract-ocr/tesseract/blob/main/include/tesseract/baseapi.h
;https://github.com/tesseract-ocr/tesseract/blob/main/src/api/capi.cpp
(define-tesseract tesseract-create
    (_fun -> _TessBaseAPI)
    #:c-id TessBaseAPICreate)

(define-tesseract tesseract-init
    (_fun _pointer _string _string -> _int)
    #:c-id TessBaseAPIInit3)

(define set-image
    (get-ffi-obj "TessBaseAPISetImage2" tesseract-lib
                 (_fun _TessBaseAPI _Pix-pointer -> _void)))

(define pix-read
    (get-ffi-obj "pixRead" tesseract-lib
                 (_fun _string -> _Pix-pointer)))

(define pix-destroy
    (get-ffi-obj "pixDestroy" tesseract-lib
                 (_fun _pointer -> _void)))

(define recognize
    (get-ffi-obj "TessBaseAPIRecognize" tesseract-lib
                 (_fun _TessBaseAPI -> _void)))

(define get-text
    (get-ffi-obj "TessBaseAPIGetUTF8Text" tesseract-lib
                 (_fun _TessBaseAPI -> _pointer )))

(define (ocr target)
  (define ctx (tesseract-create))
  (tesseract-init ctx "" "eng")
  (define img (pix-read target))
  (set-image ctx img)
  ;(recognize api)
  (define char* (get-text ctx))
  (define str (cast char* _pointer _string))
  str)

(provide ocr)


