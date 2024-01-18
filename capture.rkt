#lang racket

(require racket/draw
         br/cond
         ffi/unsafe
         ffi/unsafe/objc
         ffi/unsafe/atomic
         mred/private/wx/cocoa/image
         mred/private/wx/cocoa/types
         mred/private/wx/cocoa/const
         mred/private/wx/cocoa/utils
         mred/private/wx/cocoa/cg
         mred/private/wx/cocoa/image
         framework/notify)

(import-class NSApplication NSDictionary NSNotification NSNotificationCenter NSWindowDelegate)
(import-class NSView)
(import-class NSScreen)
(import-class NSWindow)
(import-class NSObject)
(import-class NSColor)
(import-class NSGraphicsContext)
(import-class NSTrackingArea)
(import-class NSEvent)
(import-class NSImage)
(import-class NSArray)
(import-class UIView NSViewController)

(define quartz-lib (ffi-lib "/System/Library/Frameworks/Quartz.framework/Versions/Current/Quartz"))

(define capture-state (new notify:notify-box% (value #f)))

(provide 
 (protect-out capture-state))

(define << arithmetic-shift)

(define NSTrackingMouseEnteredAndExited #x01)
(define NSTrackingMouseMoved #x02)
(define NSTrackingActiveInKeyWindow #x20)
(define NSTrackingEnabledDuringMouseDrag #x400)
(define NSDesktopDirectory 12)
(define kCGWindowListOptionOnScreenBelowWindow (1 . << . 2))
(define _CGImageRef (_cpointer 'CGImageRef))
(define _NSScreenRef (_cpointer 'NSScreen))
(define _NSEventRef (_cpointer 'NSEvent))
(define _UIViewefRef (_cpointer 'UIView))

(define LeftMouseEventMask
  (bitwise-ior
   (1 . << . NSLeftMouseUp)
   (1 . << . NSLeftMouseDragged)))

(define TrackingAreaOptions
  (bitwise-ior NSTrackingMouseEnteredAndExited NSTrackingMouseMoved NSTrackingActiveInKeyWindow NSTrackingEnabledDuringMouseDrag))

(define CGWindowListCreateImage
  (get-ffi-obj "CGWindowListCreateImage" quartz-lib
               (_fun _NSRect _uint32 _uint32 _uint32 -> _CGImageRef)))

(define (cgimage->nsimage cgimage)
  ; convert the CGimage to a NSImage
  (tell (tell NSImage alloc) 
        initWithCGImage: #:type _CGImageRef cgimage 
        size: #:type _NSSize (make-NSSize 0 0)))

(define (cgimage->bitmap cgimage)
  (image->bitmap
   (cgimage->nsimage cgimage)))

(define app (tell NSApplication sharedApplication))

(define-cocoa NSRectFill (_fun _NSRect -> _void))

(define-objc-class AppDelegate NSObject
  []
  (-a _void (applicationDidFinishLaunching: [_id notification])
      (tellv app activateIgnoringOtherApps: #:type _BOOL #t)))

(define-objc-class FullScreenWindowController NSViewController
  [_fullscreen-window _app]
  (- _void (init)
     (log-error (format "init"))
      (let* ([nc (tell NSNotificationCenter defaultCenter)])
        (tell nc addObserver: self selector: #:type _SEL (selector captured:) name: #:type _NSString "Captured" object: #f))
      )
  (- _bool (acceptsFirstResponder)
     #t)
  (- _void (setapp: [_id app])
     (set! _app app))
  (- _void (keyDown: [_id theEvent])
     (log-error (format "ket event ~a") (tell theEvent keyCode)))
  (- _void (captured: [ _id center])
     (log-error (format "captured"))
     (when _fullscreen-window
       (tellv _fullscreen-window close)
       (set! _fullscreen-window #f)
       (let ([notify (tell NSNotification notificationWithName: #:type _NSString "ocr" object: #f)])
         (tell (tell NSNotificationCenter defaultCenter) postNotification: notify))
       )
     )
  (- _void (toggleWindow)
     (if _fullscreen-window
       (tellv _fullscreen-window close)
       (let* ([main-screen (tell NSScreen mainScreen)]
              [fullscreen-frame (tell #:type _NSRect main-screen frame)]
              [_fullscreen_view (tell (tell SelectView alloc)
                                      initWithFrame: #:type _NSRect fullscreen-frame)]
              )
         (set! _fullscreen-window (tell (tell NSWindow alloc)
                                        initWithContentRect: #:type _NSRect fullscreen-frame
                                        styleMask: #:type _uint32 NSBorderlessWindowMask
                                        backing: #:type _uint32 NSBackingStoreBuffered
                                        defer: #:type _BOOL NO
                                        screen: main-screen))
         (tellv _fullscreen-window setReleasedWhenClosed: #:type _BOOL NO)
         (tellv _fullscreen-window setDisplaysWhenScreenProfileChanges: #:type _BOOL YES)
         (tellv _fullscreen-window setDelegate: _app)
         (tellv _fullscreen-window setBackgroundColor: (tell NSColor clearColor))
         (tellv _fullscreen-window setOpaque: #:type _BOOL NO)
         (tellv _fullscreen-window setHasShadow: #:type _BOOL NO)
         (tellv _fullscreen-window setLevel: #:type _int 1)
         (tellv _fullscreen-window makeKeyAndOrderFront: _app)
         (tellv _fullscreen-window setContentView: _fullscreen_view)
         (tellv _fullscreen_view setNeedsDisplay: #:type _BOOL YES)
         )
       )
  ))

(define fswindow (tell FullScreenWindowController alloc))
(tellv fswindow init)

(define-objc-class SelectView NSView
  [spotrect state]
  (- _bool (isFlipped)
     #t)
  (- _void (drawRect: [_NSRect r])
     (tell (tell NSColor
                 colorWithDeviceRed: #:type _CGFloat 0
                 green: #:type _CGFloat 0
                 blue: #:type _CGFloat 0
                 alpha: #:type _CGFloat 0.75) setFill)
     (NSRectFill r)
     (super-tell drawRect: #:type _NSRect r)

     (when spotrect
       (tell (tell NSColor clearColor) set)
       (NSRectFill spotrect))
     )
  
  (- _id (initWithFrame: [_NSRect frame])
     (set! state #t)
     (let ([self (super-tell initWithFrame: #:type _NSRect frame)])
       (when self
         (let ([tracking-area (tell (tell NSTrackingArea alloc)
                                    initWithRect: #:type _NSRect (tell #:type _NSRect self bounds)
                                    options: #:type _uint32 TrackingAreaOptions
                                    owner: self
                                    userInfo: #f)])
           (tell self addTrackingArea: tracking-area))
         )
       self))
  (- _void (mouseDown: [_id theEvent])
     (log-error (format "theEvent: ~a" (tell #:type _NSUInteger theEvent type)))
     (let* ([start-point (tell #:type _NSPoint self convertPoint: #:type _NSPoint (tell #:type _NSPoint theEvent locationInWindow) fromView: #f)]
            [dic (tell NSDictionary dictionaryWithObject: #:type _NSString "Capture" forKey: #:type _NSString "MouseDown")])
       (while state
              (let* ([event (tell (tell self window) nextEventMatchingMask: #:type _NSUInteger LeftMouseEventMask)]
                     [current-point (tell #:type _NSPoint self convertPoint: #:type _NSPoint (tell #:type _NSPoint event locationInWindow) fromView: #f)]
                     [_spotrect (make-NSRect (make-NSPoint (min (NSPoint-x start-point) (NSPoint-x current-point))
                                                           (min (NSPoint-y start-point) (NSPoint-y current-point)))
                                             (make-NSSize (abs (- (NSPoint-x start-point) (NSPoint-x current-point)))
                                                          (abs (- (NSPoint-y start-point) (NSPoint-y current-point)))))])
             
                (set! spotrect _spotrect)
                (tellv self setNeedsDisplay: #:type _BOOL YES)

                (log-error (format "event ~a" (tell #:type _NSUInteger event type)))
               
                (when (= (tell #:type _NSUInteger event type) NSLeftMouseUp)
                  (log-error (format "event NSLeftMouseUp"))
                  (let* ([rect (make-NSRect
                                (NSRect-origin spotrect)
                                (make-NSSize (NSSize-width (NSRect-size spotrect))
                                             (NSSize-height (NSRect-size spotrect))))]
                         [window-id (tell #:type _NSInteger (tell self window) windowNumber)]
                         [cgimage (CGWindowListCreateImage rect window-id kCGWindowListOptionOnScreenBelowWindow 0)]
                         [bitmap (cgimage->bitmap cgimage)]
                         [notify (tell NSNotification notificationWithName: #:type _NSString "Captured" object: #f)]
                         [save-file-path (build-path (find-system-path 'doc-dir) "screenshot.png")]
                         )
                    (log-error (format "~a" notify))
                    
                    (send bitmap save-file save-file-path 'png)
                    (tell (tell NSNotificationCenter defaultCenter) postNotification: notify)
                    
                    (log-error (format "postNotification:"))
                    ;(send capture-state set #t)
                    ;(tell (tell self window) nextEventMatchingMask: #f)
                    (set! state #f)
                    )
                  
                  
                  (log-error (format "screenshot")))
                  
                )
              )))
  )

(define app-delegate (tell (tell AppDelegate alloc) init))

(define (selectview frame)
  (tell (tell SelectView alloc)
        initWithFrame: #:type _NSRect frame))

(define (capture-screenshot app)
  (tell fswindow setapp: app)
  (tell fswindow toggleWindow))

(provide capture-screenshot)
;(provide SelectView)
;(tellv app setDelegate: app-delegate)
;(capture-screenshot app)
;(tell app run)