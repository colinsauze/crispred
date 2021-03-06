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
;    mmt  : 
;   
;   
;   
;    mmr  : 
;   
;   
;   
;    filter  : 
;   
;   
;   
;    destretch  : 
;   
;   
;   
;    dir  : 
;   
;   
;   
;    square  : 
;   
;   
;   
; 
; 
; :history:
; 
;   2013-06-04 : Split from monolithic version of crispred.pro.
; 
;   2015-03-31 : MGL. Use red_download to get turret log file.
; 
; 
;-
function red::polarim, mmt = mmt, mmr = mmr, filter = filter, destretch = destretch $
                       , dir = dir, square = square, newflats = newflats $
                       , no_ccdtabs = no_ccdtabs, smooth = smooth
  inam = 'red::polarim : '
                                ;
                                ; Search for folders with reduced data
                                ;
  if(~keyword_set(dir)) then begin
     dir = file_search(self.out_dir + '/momfbd/*', /test_dir, count = ndir)
                                ;
     if(ndir eq 0) then begin
        print, inam+'no directories found in '+self.out_dir+'/momfbd'
        return, 0
     endif
                                ;
     idx = 0L
     if(ndir gt 1) then begin
        print, inam + 'found '+red_stri(ndir)+' sub-folders:'
        for jj = 0, ndir - 1 do print, red_stri(jj,ni='(I2)')+' -> '+dir[jj]
        read,idx,prompt = inam+'Please select state ID: '
        dir = dir[idx]
     endif

     dir = file_search(dir + '/*', /test_dir, count = ndir)
     idx = 0L
     if(ndir gt 1) then begin
        print, inam + 'found '+red_stri(ndir)+' sub-folders:'
        for jj = 0, ndir - 1 do print, red_stri(jj,ni='(I2)')+' -> '+file_basename(dir[jj])
        read,idx,prompt = inam+'Please select state ID: '
        dir = dir[idx]
     endif

     dir+= '/cfg/results/' 
     print, inam + 'Processing state -> '+dir
  endif
  self -> getcamtags, dir = self.data_dir
                                ;
                                ; get files (right now, only momfbd is supported)

                                ;
  filetype = 'momfbd'
  if(self.filetype eq 'ANA') then filetype = 'f0'
  tfiles = file_search(dir+'/'+self.camttag+'.*.'+filetype, count = nimt)
  rfiles = file_search(dir+'/'+self.camrtag+'.*.'+filetype, count = nimr)
                                ;
  if(nimt NE nimr) then begin
                                ;
     print, inam + 'WARNING, different number of images found for each camera:'
     print, self.camttag+' -> '+red_stri(nimt)
     print, self.camrtag+' -> '+red_stri(nimr)
                                ;
  endif
                                ;
                                ; get states that are common to both cameras (object)
                                ;
  pol = red_getstates_polarim(tfiles, rfiles, self.out_dir $
                              , camt = self.camttag, camr = self.camrtag, camwb = self.camwbtag $
                              , newflats = newflats, ftype=filetype)
  nstat = n_elements(pol)
  
  pref = pol[0]->getvar(7)
  restore, self.out_dir+'/calib/align_clips.'+pref+'.sav'
  
                                ;
                                ; Modulations matrices
                                ;
                                ; T-Cam
  If(~keyword_set(mmt)) then begin
                                ;
     
     
     search = self.out_dir+'/polcal/'+self.camttag+'.'+pol[0]->getvar(7)+'.polcal.f0'
     if(file_test(search)) then begin
        immt = (f0(search))[0:15,*,*]
   
        
        
        ;; interpolate CCD tabs?
        if(~keyword_set(no_ccdtabs)) then begin
           for ii = 0, 15 do immt[ii,*,*] = red_mask_ccd_tabs(reform(immt[ii,*,*]))
        endif

        ;; Check NaNs
        for ii = 0, 15 do begin
           mask = 1B -( ~finite(reform(immt[ii,*,*])))
           idx = where(mask, count)
           if count gt 0 then immt[ii,*,*] = red_fillpix(reform(immt[ii,*,*]), mask=mask)
        endfor


        if(n_elements(smooth) gt 0) then begin
           dpix = round(smooth)*3
           if((dpix/2)*2 eq dpix) then dpix -= 1
           dpsf = double(smooth)
           psf = red_get_psf(dpix, dpix, dpsf, dpsf)
           psf /= total(psf, /double)
           for ii=0,15 do immt[ii,*,*] = red_convolve(reform(immt[ii,*,*]), psf)
        endif

        if(filetype eq 'f0') then begin
           pfiles = file_search(self.out_dir+'/calib/'+self.camttag+'.*'+pref+'*.xoffs', count = npf)
           
           pidx = 0
           if(npf gt 1) then begin
              for ii=0, npf-1 do print, string(ii, format='(I4)')+'  ->  ', pfiles[ii]
              read, pidx, prompt='Select calibration file ID to clip the modulation matrix:'
           endif
           
           pfiles = pfiles[pidx]
           xoff = f0(pfiles)
           pfiles = strjoin([(strsplit(pfiles, '.', /extract))[0:-2], 'yoffs'], '.')
           yoff = f0(pfiles)
           
           for ii=0,15 do begin
              tmpo = red_applyoffsets(reform(immt[ii,*,*]), xoff,yoff, clips=cl[*,1])
              if(ii eq 0) then immt0 = fltarr([16,size(tmpo, /dim)])
              immt0[ii,*,*] = temporary(tmpo)
           endfor
           immt = immt0
        endif
           
        immt = ptr_new(red_invert_mmatrix(temporary(immt)))
     endif else begin
        print, inam + 'ERROR, polcal data not found in ' + self.out_dir + '/polcal/'
        return, 0
     endelse
                                ;
  endif else begin
     immt = red_invert_mmatrix(temporary(mmt))
  endelse
                                ;
                                ; R-Cam
  If(~keyword_set(mmr)) then begin
                                ;
     search = self.out_dir+'/polcal/'+self.camrtag+'.'+pol[0]->getvar(7)+'.polcal.f0'
     if(file_test(search)) then begin
        immr = (f0(search))[0:15,*,*]

        ;; interpolate CCD tabs?
        if(~keyword_set(no_ccdtabs)) then begin
           for ii = 0, 15 do immr[ii,*,*] = red_mask_ccd_tabs(reform(immr[ii,*,*]))
        endif


        ;; Check NaNs
        for ii = 0, 15 do begin
           mask = 1B - ( ~finite(reform(immr[ii,*,*])))
           idx = where(mask, count)
           if count gt 0 then immr[ii,*,*] = red_fillpix(reform(immr[ii,*,*]), mask=mask)
        endfor


        ;;smooth?
       if(n_elements(smooth) gt 0) then begin
           dpix = round(smooth)*3
           if((dpix/2)*2 eq dpix) then dpix -= 1
           dpsf = double(smooth)
           psf = red_get_psf(dpix, dpix, dpsf, dpsf)
           psf /= total(psf, /double)
           for ii=0,15 do immr[ii,*,*] = red_convolve(reform(immr[ii,*,*]), psf)
        endif
        

        if(filetype eq 'f0') then begin
           pfiles = file_search(self.out_dir+'/calib/'+self.camrtag+'.*'+pref+'*.xoffs', count = npf)
           
           pidx = 0
           if(npf gt 1) then begin
              for ii=0, npf-1 do print, string(ii, format='(I4)')+'  ->  ', pfiles[ii]
              read, pidx, prompt='Select calibration file ID to clip the modulation matrix: '
           endif
           pfiles = pfiles[pidx]
           xoff = f0(pfiles)
           pfiles = strjoin([(strsplit(pfiles, '.', /extract))[0:-2], 'yoffs'], '.')
           yoff = f0(pfiles)
           
           for ii=0,15 do begin
              tmpo = red_applyoffsets(reform(immr[ii,*,*]), xoff,yoff, clips=cl[*,2])
              if(ii eq 0) then immr0 = fltarr([16,size(tmpo, /dim)])
              immr0[ii,*,*] = temporary(tmpo)
           endfor
           immr = immr0
        endif
       
        

        
        immr = ptr_new(red_invert_mmatrix(temporary(immr)))
     endif else begin
        print, inam + 'ERROR, polcal data not found in ' + self.out_dir+'/polcal/'
        return, 0
     endelse
                                ;
  endif else begin
     immr = red_invert_mmatrix(temporary(mmr))
  endelse
                                ;
                                ; Pointers to immt and immr
                                ;
  for ii = 0L, nstat - 1 do begin
     pol[ii]->setvar, 5, value = ptr_new(immt)
     pol[ii]->setvar, 6, value = ptr_new(immr)
     pol[ii]->setvar, 25, value = cl[*,0]
  endfor
                                ;
                                ; fill border information (based on 1st image)
                                ;
  print, inam + 'reading file -> ' + (pol[0]->getvar(9))[0]
  if(self.filetype eq 'MOMFBD') then tmp = red_mozaic(momfbd_read((pol[0]->getvar(9))[0])) else $
     tmp = f0((pol[0]->getvar(9))[0])

  dimim = red_getborder(tmp, x0, x1, y0, y1, square=square)
  for ii = 0L, nstat - 1 do pol[ii]->fillclip, x0, x1, y0, y1
                                ;
                                ; telog
                                ;
  red_download, date = self.isodate, /turret, pathturret = turretfile
  if turretfile then begin
     print, inam + 'Using SST position LOG -> ' + turretfile
     for ii = 0L, nstat - 1 do pol[ii]->setvar, 18, value = turretfile
  endif else begin
     print, 'red__polarim : No Turret log file'
     stop
  endelse 
                                ;
                                ; Print states
                                ;
  print, inam + 'Found '+red_stri(nstat)+' state(s) to demodulate:'
  for ii = 0L, nstat-1 do print, red_stri(ii, ni='(I5)') + ' -> ' + pol[ii] -> state()
                                ;
  return, pol

end
