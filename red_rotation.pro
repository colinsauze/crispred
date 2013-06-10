; docformat = 'rst'

;+
; 
; 
; :Categories:
;
;    CRISP pipeline
; 
; 
; :author:
; 
; 
; 
; 
; :returns:
; 
; 
; :Params:
; 
;    img : 
;   
;   
;   
;    angle : 
;   
;   
;   
;    sdx : 
;   
;   
;   
;    sdy : 
;   
;   
;   
; 
; :Keywords:
; 
;    cubic : in, optional, type=float
;
;      Set this to a value to use bicubic interpolation, -0.5 is
;      recommended. Otherwise bilinear interpolation is used.
; 
; :history:
; 
;    2013-06-04 : Split from monolithic version of crispred.pro.
; 
; 
;-
function red_rotation, img, angle, sdx, sdy, cubic = cubic

  if n_elements(sdx) eq 0 then sdx = 0.0
  if n_elements(sdy) eq 0 then sdy = 0.0

  dim = size(img, /dim)

  ;; get the index of each matrix element

  xgrid = findgen(dim[0]) # (fltarr(dim[1]) + 1.0)
  ygrid = (fltarr(dim[0]) + 1.0) # findgen(dim[1])
  
  ;; get rotation of indexes

  xsi = dim[0] * 0.5
  ysi = dim[1] * 0.5
  dx = cos(angle) * (xgrid - xsi) - sin(angle) * (ygrid - ysi) + xsi - sdx
  dy = sin(angle) * (xgrid - xsi) + cos(angle) * (ygrid - ysi) + ysi - sdy
  
  ;; Interpolation onto new grid
  
  return, interpolate(img, dx, dy, missing = median(img), cubic = cubic)
end
