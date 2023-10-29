;;; elwm.el --- Emacs Window Manager Integration.
;;; Commentary:
;;; Code:

(provide 'elwm)

(require 'bindat)
(require 'json)
(require 'jsonrpc)

(defvar wayfire--proc nil)
(defvar wayfire--trace-buf nil)
(defvar wayfire--res nil)
(defvar-local view-id nil)

(defun wayfire--trace (string &rest objects)
  (with-current-buffer wayfire--trace-buf
    (goto-char (point-max))
    (insert (format string objects))
    (newline)))

(defun wayfire-connect ()
  (interactive)
  (setq wayfire--proc (make-network-process
	               :name "wayfire"
	               :filter #'wayfire--filter
                       :remote (getenv "WAYFIRE_SOCKET")))
  (setq wayfire--trace-buf (generate-new-buffer "*Wayfire Trace*")))

(defun wayfire--filter (proc res)
  (setq wayfire--res (json-read-from-string (substring res 4))))

(defun wayfire-request (method &optional data)
  (let* ((msg `(:method ,method :data ,data))
	 (smsg (json-encode msg)))
    (wayfire--trace "--> %s" msg)
    (send-string wayfire--proc (string-pad (unibyte-string (length smsg)) 4 ?\0))
    (send-string wayfire--proc smsg))
  (accept-process-output wayfire--proc)
  (wayfire--trace "<-- %s" wayfire--res)
  wayfire--res)

(defun elwm-refresh (&optional dummy)
  (interactive)
  (cl-loop for i in (buffer-list)
           when (with-current-buffer i (eq major-mode 'elwm-mode))
	   do (elwm--update-buffer i)))

(defun elwm--update-buffer (buf)
  (let ((vid (with-current-buffer buf view-id)))
    (if-let ((win (get-buffer-window buf)))
        (progn
          (wayfire-request "wm-actions/set-minimized"
                       `(:view_id ,vid :state :json-false))
          (pcase-let ((`(,ax ,ay ,bx ,by)
                       (window-absolute-body-pixel-edges win)))
            (wayfire-request
             "window-rules/configure-view"
             `(:id ,vid
               :geometry
               (:x ,ax :y ,ay :width ,(- bx ax) :height ,(- by ay))))))

      (wayfire-request "wm-actions/set-minimized" `(:view_id ,vid :state t)))))

(defun elwm-init ()
  (interactive)
  (wayfire-connect)
  (add-hook 'window-state-change-functions #'elwm-refresh)
  (add-hook 'move-frame-functions #'elwm-refresh))

(defun elwm-add-view (vid)
  (interactive "nView ID: ")
  (with-current-buffer
      (generate-new-buffer
       (alist-get
        'title (alist-get 'info (wayfire-request
                                 "window-rules/view-info" `(:id ,vid)))))
    (elwm-mode)
    (setq-local view-id vid)
    (wayfire-request "wm-actions/set-always-on-top" `(:view_id ,vid :state t))))

(define-derived-mode elwm-mode nil "elwm")

(provide 'elwm)

;;; elwm.el ends here
