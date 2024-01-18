#lang racket/gui

(require racket/draw
         ffi/unsafe
         ffi/unsafe/objc
         mred/private/wx/cocoa/types
         mred/private/wx/cocoa/const
         framework
         framework/notify
         string-constants
         ffi/unsafe/atomic
         "ocr.rkt"
         "translate.rkt"
         "capture.rkt")

(import-class NSScreen NSWindow NSApplication NSObject NSColor NSNotificationCenter)

(define my-frame% 
  (class frame% (super-new)
    (inherit set-status-text get-width get-height get-client-handle)
    (define/override (on-size width height) 
      (set-status-text (~a "Size: (" (get-width) (get-height) ")" #:separator " "))
      )    
    ))

(define frame
  (new my-frame% 
       [label "macoto"]   
       [width 500] 
       [height 500] 
       [x 100] 
       [y 100]))

(send frame create-status-line)
             
(new button% [parent frame]
     [label "領域選択"]
     [callback (lambda (button event)
                 (send (send button get-parent) client->screen 0 0)
                 (let ([p (send (send button get-parent) get-parent)])
                   (call-as-nonatomic
                  (capture-screenshot p)))
                 )])

(define c1 (new editor-canvas% [parent frame]))
(define t1 (new text%))
(send c1 set-editor t1)

(new button% [parent frame]
     [label "翻訳"]
     [callback (lambda (button event)
                 (let ([text (send t1 get-text 0 'eof)])
                 (send t2 insert (translate text "ja"))))])

(define mb (new menu-bar% [parent frame]))
(define m-edit (new menu% [label "Edit"] [parent mb]))
;(define m-font (new menu% [label "Font"] [parent mb]))
(append-editor-operation-menu-items m-edit #f)
;(append-editor-font-menu-items m-font)
(send t1 undo)
(send t1 set-max-undo-history 1000)


(define c2 (new editor-canvas% [parent frame]))
(define t2 (new text%))
(send c2 set-editor t2)

(define-objc-class AppController NSObject
  [_app]
  (- _void (init)
     (log-error (format "app init"))
     (let* ([nc (tell NSNotificationCenter defaultCenter)])
        (tell nc addObserver: self selector: #:type _SEL (selector ocr:) name: #:type _NSString "ocr" object: #f))
      (send frame show #t)
      )
   (- _void (ocr: [ _id center])
     (log-error (format "ocr"))
     (let* ([save-file-path (build-path (find-system-path 'doc-dir) "screenshot.png")]
            [text (ocr save-file-path)])
       (send t1 insert text)
       ;(send t2 insert (translate text "ja"))
       )
     )
  )

(define appcontroller (tell AppController alloc))
(tellv appcontroller init)

(define (add-prefs-panel)
  (preferences:add-panel
   (string-constant tool-prefs-panel-title)
   (lambda (parent)
     #t
     )))

