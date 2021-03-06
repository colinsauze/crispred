; docformat = 'rst'

;+
; Return the average (sum/number) of the image frames defined by a
; list of file names. 
;
; 
; :Categories:
;
;    CRISP pipeline
; 
; 
; :author:
; 
;    Mats Löfdahl, ISP
; 
; 
; :returns:
; 
;    The average image. 
; 
; 
; :Params:
; 
;    files_list : in, type=strarr
;   
;      The list of image files, the contents of which to sum.
;   
; 
; :Keywords:
; 
;    time  : out, optional, type=double
;   
;   
;    summed  : out, optional, type=dblarr
;   
;       The summed frames, without division with the number of summed frames.
;   
;    nsum : out, optional, number of frames actually summed
;
;    old :  in, optional, type=boolean 
;   
;       Set this for data with the "old" header format.
;   
;    check  : in, optional, type=boolean
;   
;       Check for bad frames before summing.
;   
;    lun : in, optional, type=integer 
;   
;       Logical unit number for where to store checking results.
;   
;    gain : in, optional
; 
;       Gain frame with bad pixels zeroed. If backscatter correction
;       is supposed to be performed, the gain must have been
;       calculated from a backscatter corrected flat.
; 
;    dark : in, optional
; 
;       Dark frame.
; 
;    select_align : in, optional, type=boolean
; 
;       Align before summing if set. User gets to select feature to
;       align on. 
;
;    pinhole_align : in, optional, type=boolean
; 
;       Align before summing if set. Use brightest feature (assumed to
;       be a pinhole) to align on. If both select_align and
;       pinhole_align are set, pinhole_align is ignored.
;
;    nthreads  : in, optional, type=integer
;   
;       The number of threads to use for backscatter correction.
;   
;    backscatter_gain : in, optional
;   
;       The gain needed to do backscatter correction. Iff
;       backscatter_gain and backscatter_psf are given, do the
;       correction. 
;   
;    backscatter_psf : in, optional
;   
;       The psf needed to do backscatter correction. Iff
;       backscatter_gain and backscatter_psf are given, do the
;       correction.
;   
;   xyc : out, optional, type="lonarr(2)" 
;   
;       The (x,y) coordinates of the feature used for alignment.
;   
; 
; :history:
; 
;   2013-06-04 : Split from monolithic version of crispred.pro.
; 
;   2013-08-15 : MGL. Added documentation. Code from last year that
;                allows subpixel alignment before summing.
;
;   2013-08-16 : MGL. New code to optionally do backscatter
;                correction, as well as gain and dark correction, and
;                filling of bad pixels. Removed unused keyword
;                "notime". Use red_time2double rather than
;                time2double.
; 
;   2013-08-27 : MGL. Let the subprogram find out its own name.
; 
;   2013-09-09 : MGL. Move per-frame correction for dark, gain, and
;                back scatter to inside of conditional for pinhole
;                alignment. 
; 
;   2013-09-13 : MGL. Lower the limit for least number of frames
;                needed to do checking from 10 to 3.
; 
;   2013-12-10 : PS  keyword lim
; 
;   2013-12-11 : PS  also pass back the number of summed frames
; 
;   2014-01-27 : MGL. Use red_com rather than red_centroid.
; 
;   2014-04-11 : MGL. New keywords select_align and xyc. Limit number
;                of repeats in the alignment so bad data can
;                terminate.
; 
; 
;-
function red_sumfiles, files_list $
                       , time = time $
                       , summed = summed $
                       , nsum = nsum $
                       , old = old $     
                       , check = check $ 
                       , lim = lim $
                       , lun = lun $ 
                       , pinhole_align = pinhole_align $ 
                       , select_align = select_align $ 
                       , gain = gain $   
                       , dark = dark $   
                       , xyc = xyc $   
                       , backscatter_gain = backscatter_gain $
                       , backscatter_psf = backscatter_psf $
                       , nthreads = nthreads 
 
  ;; Name of this subprogram
  inam = strlowcase((reverse((scope_traceback(/structure)).routine))[0])
  
  new = ~keyword_set(old)

  if n_elements(nthreads) eq 0 then nthreads = 2 else nthreads = nthreads

  DoDescatter = n_elements(backscatter_gain) gt 0 and n_elements(backscatter_psf) gt 0

  Nfiles = n_elements(files_list)
  fzread, tmp, files_list[0], h
  dim = size(tmp, /dim)
  tmp = long(tmp)

  dum = fzhead(files_list[0])
  dum = strsplit(dum, ' =', /extract)
  if(new) then begin
     t1 = dum[18]
     t2 = dum[21]
     time = (red_time2double(t1) + red_time2double(t2)) * 0.5d0
  endif else time = red_time2double(dum[2])

  if keyword_set(check) then docheck = 1B else docheck = 0B
  if docheck and Nfiles lt 3 then begin
     print, inam+" : Not enough statistics, don't do checking."
     docheck = 0B
  endif

  if keyword_set(pinhole_align) or keyword_set(select_align) then begin
     if n_elements(gain) eq 0 or n_elements(dark) eq 0 then begin
        print, inam+' : Need to specify gain and dark when doing /pinhole_align or /select_align'
        help, gain, dark
        stop
     endif
  endif

  if n_elements(gain) eq 0 then begin
     ;; Default gain is unity
     gain = dblarr(dim)+1D
  endif else begin
     ;; Make a mask for fillpixing. We want to exclude really large
     ;; areas along the border of the image and therefore irrelevant
     ;; for pinhole calibration.
     mask = red_cleanmask(gain)
  endelse 

  if n_elements(dark) eq 0 then begin
     ;; Default zero dark correction
     dark = dblarr(dim)
  endif 

  ;; If just a single frame, return it now! 
  if Nfiles eq 1 then begin
     ;; Include gain, dark, fillpix, backscatter here? This case
     ;; should really never happen...
     return, tmp
  endif

  ;; Needed for warning messages and progress bars.
  ntot = 100. / (Nfiles - 1.0)
  bb = string(13B)

  times = dblarr(Nfiles)

  if docheck then begin

     ;; Set up for checking
     cub = intarr(dim[0], dim[1], Nfiles)
     mval = fltarr(Nfiles)
     for ii = 0L, Nfiles-1 do begin

        cub[*,*,ii] = f0(files_list[ii])
        mval[ii] = mean(cub[*,*,ii])
                                
        dum = fzhead(files_list[ii])
        dum = strsplit(dum, ' =', /extract)
        
        if(new) then begin
           t1 = dum[18]
           t2 = dum[21]
           times[ii] = (red_time2double(t1) + red_time2double(t2)) * 0.5d0
        endif else times[ii] = red_time2double(dum[2])
        print, bb, inam+' : loading files in memory -> ', ntot * ii, '%' $
               , FORMAT = '(A,A,F5.1,A,$)'

     endfor                     ; ii
     print, ' '

     ;; Find bad frames
     if n_elements(lim) eq 0 then lim = 0.0175 ; Allow 2% deviation from the mean value
     tmean = median(mval)
     mmval = median( mval, 3)
     mmval[0] = mmval[1]                        ; Set edges to neighbouring values since the median filter does not modify endpoints.
     mmval[Nfiles-1] = mmval[Nfiles-2]          ;
     goodones = abs(mval - mmval) LE lim * tmean ; Unity for frames that are OK.
     idx = where(goodones, Nsum, complement = idx1)
     
     if(Nsum ne Nfiles) then begin
        print, inam+' : rejected frames :'
        print, transpose((files_list[idx1]))
        if(keyword_set(lun)) then begin
           printf, lun, files_list[idx1]
        endif
     endif else print, inam+' : all files seem to be fine'

  endif else begin              ; docheck

     ;; Set up for NOT checking
     times[0] = time
     for ii = 1L, Nfiles -1 do begin
        dum = fzhead(files_list[ii])
        dum = strsplit(dum, ' =', /extract)
        if(new) then begin
           t1 = dum[18]
           t2 = dum[21]
           times[ii] = (red_time2double(t1) + red_time2double(t2)) * 0.5d0
        endif else times[ii] = red_time2double(dum[2])

     endfor                     ; ii

     ;; If no checking, all frames are considered OK.
     goodones = replicate(1, Nfiles) 
     idx = where(goodones, Nsum, complement = idx1)

  endelse                       ; docheck

  ;; Do the summing
  summed = dblarr(dim)
  time = 0.0d

  firstframe = 1B               ; When doing alignment we use the first (good) frame as reference.
  dc_sum = [0.0, 0.0]
  for ii = 0L, Nfiles-1 do begin
     
     if goodones[ii] then begin ; Sum only OK frames

        if docheck then begin
           thisframe = double(cub[*,*,ii])
           print, bb, inam+' : summing checked frames -> ' $
                  , ntot * ii, '%' $
                  , FORMAT='(A,A,F5.1,A,$)'
        endif else begin
           thisframe = double(f0(files_list[ii]))
           print, bb, inam+' : adding files -> ' $
                  , ntot * ii, '%' $
                  , FORMAT = '(A,A,F5.1,A,$)'
        endelse

  
        if keyword_set(pinhole_align) or keyword_set(select_align) then begin
           
           ;; If we are doing sub-pixel alignment, then we need to
           ;; correct each frame for dark and gain.
           thisframe = (thisframe - dark)*gain

           ;; We also need to do any descattering correction of each frame.
           if DoDescatter then begin
              thisframe = red_cdescatter(thisframe $
                                         , backscatter_gain, backscatter_psf $
                                         , /verbose, nthreads = nthreads)
           endif

           ;; And fill the bad pixels 
           thisframe = red_fillpix(thisframe, mask = mask)

           if firstframe then begin
              
              marg = 100
              if keyword_set(select_align) then begin
                 ;; Select feature to align on with mouse.
                 if max(dim) gt 1000 then fac = max(dim)/1000. else fac = 1
                 window, 0, xs = 1000, ys = 1000
                 tvscl, congrid(thisframe, dim[0]/fac, dim[1]/fac, cubic = -0.5)
                 print, 'Use the mouse to click on feature to align on.'
                 cursor, xc, yc, /device
                 xyc = round([xc, yc]*fac) >marg <(dim-marg-1)
                 subsz = 300
                 subim = thisframe[xyc[0]-subsz/2:xyc[0]+subsz/2-1, xyc[1]-subsz/2:xyc[1]+subsz/2-1]
                 tvscl, subim
              end else begin
                 ;; Find brightest pinhole spot that is reasonably centered in
                 ;; the FOV.
                 subim = thisframe[marg:dim[0]-marg, marg:dim[1]-marg]
                 mx = max(subim, maxloc)
                 ncol = dim[1]-2*marg+1
                 xyc = lonarr(2)
                 xyc[0] = maxloc MOD ncol
                 xyc[1] = maxloc / ncol
                 xyc += marg    ; Position of brightest spot in original image
              endelse

              ;; Establish subfield size sz, shrunk to fit.
              sz = 99              
              subim = thisframe[xyc[0]-sz/2:xyc[0]+sz/2, xyc[1]-sz/2:xyc[1]+sz/2]
              tot_init = total(subim/max(subim) gt 0.2)
              repeat begin
                 sz -= 2
                 subim = thisframe[xyc[0]-sz/2:xyc[0]+sz/2, xyc[1]-sz/2:xyc[1]+sz/2]
                 tot = total(subim/max(subim) gt 0.2)
              endrep until tot lt tot_init

              sz += 4           ; A bit of margin

           endif                ; firstframe

           ;; Iteratively calculate centroid of thisframe, and then
           ;; shift the frame so it aligns with the first frame.
           
           ;; Iteratively shift the image to get the spot centered in
           ;; the subfield, because that's where the centroiding is
           ;; most accurate.
           dc1 = [0.0,0.0]
           Nrep = 0
           repeat begin
              ;print, 'Shift:', dc1
              im_shifted = red_shift_im(thisframe, dc1[0], dc1[1])                  ; Shift the image
              subim0 = im_shifted[xyc[0]-sz/2:xyc[0]+sz/2, xyc[1]-sz/2:xyc[1]+sz/2] ; New subimage

              subim0 = subim0 / stdev(subim0)
              cnt = red_com(subim0) ; Centroid after shift
              dcold = dc1           ; Old shift
              dc1 = dc1 + (sz/2.0 - cnt)
                                ;print, 'Shift change vector length:',
                                ;sqrt(total((dc1-dcold)^2))
              Nrep += 1
           endrep until sqrt(total((dc1-dcold)^2)) lt 0.01 or Nrep eq 100
           ;; Iterate until shift changes less than 0.01 pixel

           if firstframe then begin
              ;; Keep as reference
              dc0 = dc1
           endif else begin
              dc = dc1-dc0      ; This is the shift!
              dc_sum += dc      ; ...add it to the total
              thisframe = red_shift_im(thisframe, dc[0], dc[1]) 
           endelse

        endif                   ; keyword_set(pinhole_align)

        summed += thisframe
        time += times[ii]

        firstframe = 0B
     endif                      ; goodones[ii] 

  endfor                        ; ii
  print, ' '

  average = summed
  if Nsum gt 1 then begin
    average /= Nsum;
    time /= Nsum
  endif
  
  if total(abs(dc_sum)) gt 0 then begin ; shift average image back, to ensure an average shift of 0.
    average = red_shift_im( average, -dc_sum[0]/Nsum, -dc_sum[1]/Nsum )
  endif
  
  time = red_time2double( time, /dir )

  if ~keyword_set(pinhole_align) and ~keyword_set(select_align) then begin

     ;; Some actions already done for each frame in the case of
     ;; pinhole alignment.

     ;; Dark and gain correction 
     average = (average - dark)*gain

     if DoDescatter then begin
        ;; Backscatter correction (done already for pinholes)
        average = red_cdescatter(average, backscatter_gain, backscatter_psf $
                                 , /verbose, nthreads = nthreads)
     endif

     ;; Fill the bad pixels 
     if n_elements(mask) gt 0 then  average = red_fillpix(average, mask = mask)

  endif

  return, average
 
end                             ; red_sumfiles
