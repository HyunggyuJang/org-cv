;;; ox-altacv.el --- LaTeX altacv Back-End for Org Export Engine -*- lexical-binding: t; -*-

;; Copyright (C) 2018 Free Software Foundation, Inc.

;; Author: Oscar Najera <hi AT oscarnajera.com DOT com>, Hyunggyu Jang
;; Keywords: org, wp, tex

;; This file is not part of GNU Emacs.

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
;; Boston, MA 02110-1301, USA.

;;; Commentary:
;;
;; This library implements a LaTeX altacv back-end, derived from the
;; LaTeX one, targeting https://www.overleaf.com/latex/examples/recreating-business-insiders-cv-of-marissa-mayer-using-altacv/gtqfpbwncfvp

;;; Code:
(require 'cl-lib)
(require 'ox-latex)
(require 'org-cv-utils)

;; Install a default set-up for altacv export.
(unless (assoc "altacv" org-latex-classes)
  (add-to-list 'org-latex-classes
               '("altacv"
                 "\\documentclass[10pt,a4paper,ragged2e,withhyper]{altacv}"
                 ("\n\\cvsection{%s}" . "\n\\cvsection*{%s}")
                 ("\\cvsubsection{%s}" . "\\cvsubsection*{%s}"))))


;;; User-Configurable Variables

(defgroup org-export-cv nil
  "Options specific for using the altacv class in LaTeX export."
  :tag "Org altacv"
  :group 'org-export
  :version "25.3")

;;; Define Back-End
(org-export-define-derived-backend 'altacv 'latex
  :options-alist
  '((:latex-class "LATEX_CLASS" nil "altacv" t)
    (:cvstyle "CVSTYLE" nil "classic" t)
    (:cvcolor "CVCOLOR" nil "blue" t)
    (:mobile "MOBILE" nil nil parse)
    (:homepage "HOMEPAGE" nil nil parse)
    (:address "ADDRESS" nil nil newline)
    (:photo "PHOTO" nil nil parse)
    (:github "GITHUB" nil nil parse)
    (:linkedin "LINKEDIN" nil nil parse)
    (:with-email nil "email" t t)
    (:latex-title-command nil nil "\\makecvheader")
    )
  :translate-alist '((template . org-altacv-template)
                     (headline . org-altacv-headline)))

(defun colorconf ()
  "puts color"
  "% Change the page layout if you need to
\\geometry{left=1.25cm,right=1.25cm,top=1.5cm,bottom=1.5cm,columnsep=1.2cm}

% The paracol package lets you typeset columns of text in parallel
\\usepackage{paracol}

% Change the font if you want to, depending on whether
% you're using pdflatex or xelatex/lualatex
% WHEN COMPILING WITH XELATEX PLEASE USE
% xelatex -shell-escape -output-driver=\"xdvipdfmx -z 0\" mmayer.tex
\\ifxetexorluatex
  % If using xelatex or lualatex:
  \\setmainfont{Lato}
\\else
  % If using pdflatex:
  \\usepackage[default]{lato}
\\fi

% Change the colours if you want to
\\definecolor{VividPurple}{HTML}{3E0097}
\\definecolor{SlateGrey}{HTML}{2E2E2E}
\\definecolor{LightGrey}{HTML}{666666}
\\colorlet{heading}{VividPurple}
\\colorlet{headingrule}{VividPurple}
\\colorlet{accent}{VividPurple}
\\colorlet{emphasis}{SlateGrey}
\\colorlet{body}{LightGrey}

% Change the bullets for itemize and rating marker
% for \cvskill if you want to
\\renewcommand{\\cvItemMarker}{{\\small\\textbullet}}
\\renewcommand{\\cvRatingMarker}{\\faCircle}
")
;;;; Template
;;
;; Template used is similar to the one used in `latex' back-end,
;; excepted for the table of contents and altacv themes.

(defun org-altacv-template (contents info)
  "Return complete document string after LaTeX conversion.
CONTENTS is the transcoded contents string.  INFO is a plist
holding export options."
  (let ((title (org-export-data (plist-get info :title) info))
        (spec (org-latex--format-spec info)))
    (concat
     ;; Time-stamp.
     (and (plist-get info :time-stamp-file)
          (format-time-string "%% Created %Y-%m-%d %a %H:%M\n"))
     ;; LaTeX compiler.
     (org-latex--insert-compiler info)
     ;; Document class and packages.
     (org-latex-make-preamble info)
     (colorconf)
     ;; Possibly limit depth for headline numbering.
     (let ((sec-num (plist-get info :section-numbers)))
       (when (integerp sec-num)
         (format "\\setcounter{secnumdepth}{%d}\n" sec-num)))

     ;; Title and subtitle.
     (let* ((subtitle (plist-get info :subtitle))
            (formatted-subtitle
             (when subtitle
               (format (plist-get info :latex-subtitle-format)
                       (org-export-data subtitle info))))
            (separate (plist-get info :latex-subtitle-separate)))
       (concat
        (format "\\tagline{%s%s}\n" title
                (if separate "" (or formatted-subtitle "")))
        (when (and separate subtitle)
          (concat formatted-subtitle "\n"))))
     ;; Hyperref options.
     (let ((template (plist-get info :latex-hyperref-template)))
       (and (stringp template)
            (format-spec template spec)))
     ;; Document start.
     "\\begin{document}\n\n"
     ;; Author.
     (let ((author (and (plist-get info :with-author)
                        (let ((auth (plist-get info :author)))
                          (and auth (org-export-data auth info))))))
       (format "\\name{%s}\n" author))
     ;; photo
     (let ((photo (org-export-data (plist-get info :photo) info)))
       (when (org-string-nw-p photo) (format "\\photo{2.8cm}{%s}\n" photo)))

     "\\personalinfo{\n"
     ;; address
     (let ((address (org-export-data (plist-get info :address) info)))
       (when (org-string-nw-p address)
         (format "\\mailaddress{%s}\n" (mapconcat (lambda (line)
                                                    (format "%s" line))
                                                  (split-string address "\n") " -- "))))
     ;; email
     (let ((email (and (plist-get info :with-email)
                       (org-export-data (plist-get info :email) info))))
       (when (org-string-nw-p email)
         (format "\\email{%s}\n" email)))
     ;; phone
     (let ((mobile (org-export-data (plist-get info :mobile) info)))
       (when (org-string-nw-p mobile)
         (format "\\phone{%s}\n" mobile)))
     ;; homepage
     (let ((homepage (org-export-data (plist-get info :homepage) info)))
       (when (org-string-nw-p homepage)
         (format "\\homepage{%s}\n" homepage)))
     (mapconcat (lambda (social-network)
                  (let ((command (org-export-data (plist-get info
                                                             (car social-network))
                                                  info)))
                    (and command (format "\\%s{%s}\n"
                                         (nth 1 social-network)
                                         command))))
                '((:github "github")
                  (:linkedin "linkedin"))
                "")
     "}\n"
     ;; Title command.
     (let* ((title-command (plist-get info :latex-title-command))
            (command (and (stringp title-command)
                          (format-spec title-command spec))))
       (org-element-normalize-string
        (cond ((not (plist-get info :with-title)) nil)
              ((string= "" title) nil)
              ((not (stringp command)) nil)
              ((string-match "\\(?:[^%]\\|^\\)%s" command)
               (format command title))
              (t command))))
     "%% Depending on your tastes, you may want to make fonts of itemize environments slightly smaller
\\AtBeginEnvironment{itemize}{\\small}

%% Set the left/right column width ratio to 6:4.
\\columnratio{0.6}


% Start a 2-column paracol. Both the left and right columns will automatically
% break across pages if things get too long.
\\begin{paracol}{2}\n\n"
     ;; Document's body.
     contents
     ;; Creator.
     (and (plist-get info :with-creator)
          (concat (plist-get info :creator) "\n"))
     ;; Document end.
     "\\end{paracol}\n\n\\end{document}")))


(defun org-altacv--format-cventry (headline contents info)
  "Format HEADLINE as as cventry.
CONTENTS holds the contents of the headline.  INFO is a plist used
as a communication channel."
  (let* ((entry (org-cv-utils--parse-cventry headline info))
         (divider (if (org-export-last-sibling-p headline info) "\n" "\\divider")))
    (format "\n\\cvevent{%s}{%s}{%s}{%s}%s\n%s\n\n"
            (alist-get 'title entry)
            (alist-get 'host entry)
            (alist-get 'date entry)
            (alist-get 'location entry) contents divider)))

;;;; Headline
(defun org-altacv-headline (headline contents info)
  "Transcode HEADLINE element into altacv code.
CONTENTS is the contents of the headline.  INFO is a plist used
as a communication channel."
  (unless (org-element-property :footnote-section-p headline)
    (let ((environment (cons (org-element-property :CV_ENV headline)
                             (org-export-get-tags headline info))))
      (cond
       ;; is a cv entry
       ((member "cventry" environment)
        (org-altacv--format-cventry headline contents info))
       ((org-export-with-backend 'latex headline contents info))))))

(provide 'ox-altacv)
;;; ox-altacv ends here
