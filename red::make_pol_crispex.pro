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
; 
; :Keywords:
; 
;    rot_dir  : 
;   
;   
;   
;    scans_only  : 
;   
;   
;   
;    overwrite  : 
;   
;   
;   
;    float : 
;   
;   
;   
;    filter : 
;   
;   
;   
; 
; 
; :history:
; 
;   2013-06-04 : Split from monolithic version of crispred.pro.
; 
;   2013-07-11 : MGL. Use red_intepf, not intepf.
; 
; 
; 
;-
pro red::make_pol_crispex, rot_dir = rot_dir, scans_only = scans_only, overwrite = overwrite, float=float, filter=filter
  inam = 'red::make_pol_crispex : '
  if(n_elements(rot_dir) eq 0) then rot_dir = 0B
  if(keyword_set(float)) then exten = '.fcube' else exten='.icube'
  if(n_elements(filter) gt 0) then cfilter = dcomplex(filter,filter)

  ;;
  ;; select folder
  ;;
  search = self.out_dir +'/momfbd/'
  f = file_search(search+'*', count = ct, /test_dir)
  if(ct eq 0) then begin
     print, inam + 'No sub-folders found in: ' + search
     return
  endif

  if(ct gt 1) then begin
     print, inam + 'Found folders(s): '
     for ii = 0L, ct-1 do print, red_stri(ii) + '  -> '+f[ii]
     idx = 0L
     read, idx, prompt = inam + 'Select folder ID: '
     idx = idx>0 < (ct-1)
     f = f[idx]
  endif

  print, inam + 'Selected -> '+ f
  time_stamp = strsplit(f, '/', /extract)
  time_stamp = time_stamp[n_elements(time_stamp)-1]

  ;;
  ;; Search prefilters in folder
  ;;
  search = f
  f = file_search(f+'/*', /test_dir, count = ct)
  if(ct eq 0) then begin
     print, inam + 'No sub-folders found in: ' + search
     return
  endif
  
  if(ct gt 1) then begin
     print, inam + 'Found prefilters(s): '
     for ii = 0L, ct-1 do print, red_stri(ii) + '  -> '+file_basename(f[ii])
     idx = 0L
     read, idx, prompt = inam + 'Select folder ID: '
     idx = idx>0 < (ct-1)
     f = f[idx]
  endif
  print, inam + 'Selected -> '+ f
  pref = strsplit(f, '/', /extract)
  pref = pref[n_elements(pref)-1]


  f += '/cfg/results/'
  
  ;;
  ;; Look for time-series calib file
  ;;
  if(~keyword_set(scans_only)) then begin
     cfile = self.out_dir + '/calib_tseries/tseries.'+pref+'.'+time_stamp+'.calib.sav'
     if(~file_test(cfile)) then begin
        print, inam + 'Could not find calibration file: ' + cfile
        print, inam + 'Try to execute red::polish_tseries on this dataset first!'
        return
     endif else print, inam + 'Loading calibration file -> '+file_basename(cfile)
     restore, cfile
     tmean = mean(tmean) / tmean
  endif else tmean = replicate(1.0, 10000) ; Dummy time correction

  ;;
  ;; Camera tags
  ;;
  self->getcamtags, dir = self.data_dir


  ;;
  ;; Load prefilter
  ;;
  tpfile = self.out_dir + '/prefilter_fits/'+self.camttag+'.'+pref+'.prefilter.f0'
  tpwfile = self.out_dir + '/prefilter_fits/'+self.camttag+'.'+pref+'.prefilter_wav.f0'
  rpfile = self.out_dir + '/prefilter_fits/'+self.camrtag+'.'+pref+'.prefilter.f0'
  rpwfile = self.out_dir + '/prefilter_fits/'+self.camrtag+'.'+pref+'.prefilter_wav.f0'

  if(file_test(tpfile) AND file_test(tpwfile)) then begin
     print, inam + 'Loading:'
     print, '  -> ' + file_basename(tpfile)
     tpref = f0(tpfile)
     print, '  -> ' + file_basename(tpwfile)
     twav = f0(tpwfile)
  endif else begin
     print, inam + 'prefilter files not found!'
     return
  endelse

  if(file_test(rpfile) AND file_test(rpwfile)) then begin
     print, inam + 'Loading:'
     print, '  -> ' + file_basename(rpfile)
     rpref = f0(tpfile)
     print, '  -> ' + file_basename(rpwfile)
     rwav = f0(tpwfile)
  endif else begin
     print, inam + 'prefilter files not found!'
     return
  endelse

  tfiles = file_search(f+'/stokes/'+'stokesIQUV.?????.'+pref+'.????_*f0', count=tf)
;  rfiles = file_search(f+'/'+self.camrtag+'.?????.'+pref+'.????_*momfbd', count=rf)
  if(tf eq 0) then begin
     print, inam + 'Error, no images found in:'
     print, f+'/stokes'
  endif
  
  st = red_get_stkstates(tfiles)

  
  nwav = st.nwav
  nscan = st.nscan
  wav = st.uiwav * 1.e-3

  ;;
  ;; Interpolate prefilters to the observed grid 
  ;;
  tpref = 1./(red_intepf(twav, tpref, wav) + red_intepf(rwav, rpref, wav))

  ;;
  ;; Create temporary cube and open output file
  ;;
  if(n_elements(crop) eq 0) then crop = [0,0,0,0]
  dimim = size(f0(tfiles[0]), /dim)
  x0 = 0L + crop[0]
  x1 = dimim[0]-crop[1]-1
  y0 = 0L + crop[2]
  y1 = dimim[1]-crop[3]-1
  dimim[0] = x1 - x0 + 1
  dimim[1] = y1 - y0 + 1

  print, 'nscan = ', nscan
  print, 'nwav = ', nwav
  print, 'nx = ', dimim[0]
  print, 'ny = ', dimim[1]

  d = fltarr(dimim[0], dimim[1], 4, nwav)  
  if(~keyword_set(scans_only)) then begin
     head =  red_pol_lpheader(dimim[0], dimim[1], nwav*nscan*4L, float=float)
  endif else begin
     head = red_pol_lpheader(dimim[0], dimim[1], nwav*4L, float=float)
  endelse
  print, string(head)

  if(n_elements(odir) eq 0) then odir = self.out_dir + '/crispex/' + time_stamp + '/'
  file_mkdir, odir

  if(~keyword_set(scans_only)) then begin
     ofile = 'crispex.stokes.'+pref+'.'+time_stamp+'.time_corrected'+exten
     
     if file_test(odir + '/' + ofile) then begin
        if keyword_set(overwrite) then begin
           print, 'Overwriting existing data cube:'
           print, odir + '/' + ofile
        endif else begin
           print, 'This data cube exists already:'
           print, odir + '/' + ofile
           return
        endelse
     endif

     openw, lun, odir + '/' + ofile, /get_lun
     writeu, lun, head
                                ;point_lun, lun, 0L
     if(keyword_set(float)) then begin
        dat = assoc(lun, fltarr(dimim[0], dimim[1], nwav,4,/nozero), 512)
     endif else begin
        dat = assoc(lun, intarr(dimim[0], dimim[1], nwav,4,/nozero), 512)
     endelse
  endif 
  ;;
  ;; start processing data
  ;; 
  for ss = 0L, nscan-1 do begin

     if(keyword_set(scans_only)) then begin
        ofile = 'crispex.stokes.'+pref+'.'+time_stamp+'_scan='+st.uscan[ss]+exten
        if file_test(odir + '/' + ofile) then begin
           if keyword_set(overwrite) then begin
              print, 'Overwriting existing data cube:'
              print, odir + '/' + ofile
           endif else begin
              print, 'Skip to next scan, this one exists already:'
              print, odir + '/' + ofile
              continue          ; Skip to next iteration of "for ss ..." loop.
           endelse
        endif
     endif
     

     for ww = 0L, nwav - 1 do begin 
        state = strjoin((strsplit(file_basename(st.ofiles[ww,ss]),'.',/extract))[1:*],'.')
        
        ;;
        ;; Load image and apply prefilter correction
        ;;
        print, inam + 'loading -> '+file_basename(st.ofiles[ww,ss])
        tmp = (f0(st.ofiles[ww,ss]))[x0:x1,y0:y1,*] * tpref[ww]
        if(keyword_set(filter)) then begin
           tmp = red_fftfilt(temporary(tmp), filter)
        endif 

        ;;
        ;; Apply derot, align, dewarp
        ;;
        if(~keyword_set(scans_only)) then begin
           for stk = 0,3 do begin
              d[*,*,stk,ww] = rotate(stretch(red_rotation(tmp[*,*,stk], ang[ss], total(shift[0,ss]), total(shift[1,ss])), reform(grid[ss,*,*,*])), rot_dir) 
           endfor
        endif else for stk=0,3 do d[*,*,stk,ww] = rotate(tmp[*,*,stk], rot_dir)
        
     endfor
     
     if(ss eq 0) then begin
        imean = fltarr(nwav)
        for ii = 0, nwav-1 do imean[ii] = median(d[*,*,0,ii])
        if(~keyword_set(float)) then cscl = 15000./max(imean) else cscl = 1.0
     endif
     
     if(~keyword_set(scans_only)) then begin
        ;; Write this scan's data cube to assoc file
        if(keyword_set(float)) then begin
           dat[ss] = transpose(float(d), [0,1,3,2]) 
        endif else begin
           dat[ss] = transpose(fix(round(d*cscl)), [0,1,3,2]) 
        endelse
     end else begin
        ;; Write this scan's data cube as an individual file.
        openw, lun, odir + '/' + ofile, /get_lun
        writeu, lun, head
        if(keyword_set(float)) then begin
           writeu, lun, transpose(float(d), [0,1,3,2])
        endif else begin
           writeu, lun, transpose(fix(round(d*cslc)), [0,1,3,2])
        endelse
        free_lun, lun
     endelse
  endfor

  if(~keyword_set(scans_only)) then begin
     free_lun, lun
     print, inam + 'done'
     print, inam + 'result saved to -> '+odir+'/'+ofile 
     if(keyword_set(float)) then begin
        flipthecube, odir+'/'+ofile, nt = nscan, nw=nwav
     endif else flipthecube, odir+'/'+ofile, nt = nscan, nw=nwav,/icube
  endif
  
  
  
  return
end
