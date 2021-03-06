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
;    linear : in, optional, type=boolean
;
;      Set this to use bilinear interpolation. Otherwise bicubic
;      interpolation with cubic= -0.5 is used.
; 
; :history:
; 
;    2013-06-04 : Split from monolithic version of crispred.pro.
; 
;    2013-06-10 : Made using bicubic interpolation with -0.5 the
;    default and introduced a new flag for linear interpolation. MGL
;
;   2014-05-05 : Error in the definition of dx, dy found. The shifts
;   should be applied inside the parenthesis. JdlCR.
;
;   2014-11-29 : JdlCR, added support for fullframe cubes (aka,
;                despite rotation and shifts, the entire FOV is inside
;                the image
; 
;-
function red_rotation, img, angle, sdx, sdy, linear = linear, full = full

  if n_elements(sdx) eq 0 then sdx = 0.0
  if n_elements(sdy) eq 0 then sdy = 0.0

  dim = size(img, /dim)


  
  
  xsi = dim[0] * 0.5
  ysi = dim[1] * 0.5
                              
  
  ;; get the index of each matrix element
  if(n_elements(full) eq 0) then begin

     xgrid = findgen(dim[0]) # (fltarr(dim[1]) + 1.0)
     ygrid = (fltarr(dim[0]) + 1.0) # findgen(dim[1])
    ;dx = cos(angle) * (xgrid - xsi) - sin(angle) * (ygrid - ysi) + xsi - sdx
                                ; dy = sin(angle) * (xgrid - xsi) + cos(angle) * (ygrid - ysi) + ysi - sdy
     dx = cos(angle) * (xgrid - xsi - sdx) -  sin(angle) * (ygrid - ysi-sdy) + xsi
     dy = sin(angle)  * (xgrid - xsi - sdx) + cos(angle) * (ygrid - ysi-sdy) + ysi
     ima = img
  endif else begin
     
     xgrid = (findgen(dim[0]) # (fltarr(dim[1]) + 1.0)) 
     ygrid = ((fltarr(dim[0]) + 1.0) # findgen(dim[1]))

     dx = cos(full[0]) * (xgrid - xsi ) -  sin(full[0]) * (ygrid - ysi) +  xsi
     dy = sin(full[0])  * (xgrid - xsi ) + cos(full[0]) * (ygrid - ysi) +  ysi

     dim1 = dim
     xmin = round(abs(min(dx)) + abs(full[1]))
     xmax = round(abs(max(dx-dim[0]-1))  + abs(full[2]))
     ymin = round(abs(min(dy)) + abs(full[3]))
     ymax = round(abs(max(dy-dim[1]-1)) + abs(full[4]))
     
     dim1[0] +=  xmin + xmax
     dim1[1] +=  ymin + ymax

     ;;
     ;; Force an odd number to make things easier for
     ;; flipthecube to find a correct dimension.
     ;;
     if((dim1[0]/2)*2 ne dim1[0]) then begin
        dim1[0] += 1
        xmax += 1
     endif
     if((dim1[1]/2)*2 ne dim1[1]) then begin
        dim1[1] += 1
        ymax += 1
     endif
     
     xgrid = (findgen(dim1[0]) # (fltarr(dim1[1]) + 1.0)) * float(dim[0])/float(dim[0])
     ygrid = ((fltarr(dim1[0]) + 1.0) # findgen(dim1[1])) * float(dim[1])/float(dim[1])
     xgrid *= float(dim1[0]) / max(xgrid)
     ygrid *= float(dim1[1]) / max(ygrid)
     xsi = dim1[0] * 0.5
     ysi = dim1[1] * 0.5
     
     dx = cos(angle[0]) * (xgrid - xsi - sdx) -  sin(angle[0]) * (ygrid - ysi-sdy) +  xsi
     dy = sin(angle[0])  * (xgrid - xsi - sdx) + cos(angle[0]) * (ygrid - ysi-sdy) +  ysi
     ima = fltarr(dim1) + median(img)
     ima[xmin, ymin] = img
  endelse

  ;; Interpolation onto new grid
  if keyword_set(linear) then begin
     return, interpolate(ima, dx, dy, missing = median(img))
  endif else begin
     return, interpolate(ima, dx, dy, missing = median(img), cubic = -0.5)
  endelse
  

end
