pro red::fitgains_ng, npar = npar, niter = niter, rebin = rebin, xl = xl, yl = yl, densegrid = densegrid, res = res, thres = thres, initcmap = initcmap, x0 = x0, x1 = x1, state = state, nosave = nosave, myg = myg, w0 = w0, w1 = w1
                                ;
  inam = 'red::fitgains_ng : '
  device, decompose = 0
                                ;
  if(~keyword_set(npar)) then npar = 3L 
  if(~keyword_set(niter)) then niter = 3L
  if(~keyword_set(rebin)) then rebin = 10L
                                ;
                                ; Restore data
                                ;
  files = self.out_dir + 'flats/spectral_flats/cam*.flats.sav'
;  if(~file_test(file)) then begin
;     print, inam + 'ERROR, file not found -> ' + file
;     print, inam + '(have you executed red::prepflatcubes first?)'
;     return
;  endif
                                ; print, inam + 'restoring file -> ' + file
                                ; restore, file

  files = file_search(files, count = ct)
  prefs = strarr(ct)
  cams = strarr(ct)
  states = strarr(ct)

  print, inam + 'found states:'
  for ii = 0, ct - 1 do begin
     tmp = strsplit(file_basename(files[ii]), '.',/extract)
     cams[ii] = tmp[0]
     prefs[ii] = tmp[1]
     states[ii] = strjoin(tmp[0:1],'.')
     print, ii, ' -> ',states[ii], FORMAT='(I3,A,A)'
  endfor

  if(~keyword_set(state)) then begin
     idx = 0
     if(ct gt 1) then read, idx, prompt =  inam + 'select state ID to be processed: '
  endif else begin
     idx = where(states eq state, count)
     if count eq 0 then begin
        print, inam + 'ERROR, external state -> '+state+' not found'
        return
     endif
  endelse
                                ;
                                ; Load data
                                ;
  cam = cams[idx]
  pref = prefs[idx]
  print, inam + 'selected -> '+states[idx]
  restore, files[idx]
  if(keyword_set(w0)) then begin
     cub = (temporary(cub))[w0:*,*,*]
     wav = wav[w0:*]
     namelist = namelist[w0:*]
  endif else w0=0
  if(keyword_set(w1)) then begin
     cub = (temporary(cub))[0:w1-w0,*,*]
     wav = wav[0:w1-w0]
     namelist = namelist[0:w1-w0]
  endif




  wav = float(wav)
  if(n_elements(dat) eq 0) then begin 
     dat = temporary(cub)
  endif
                                ;
                                ; init output vars
                                ;
  dim = size(dat, /dim)
  res = dblarr(npar, dim[1], dim[2])
  ratio = fltarr(dim[0], dim[1], dim[2])
  nwav = dim[0]
                                ;
  res[0,*,*] = total(dat,1) / nwav
                                ;
                                ; Init cavity map?
                                ;
  if(keyword_set(initcmap)) then begin
     print, inam + 'Initializing cavity-errors with parabola-fit'
     res[1,*,*] = red_initcmap(wav, dat, x0 = x0, x1 = x1)
  endif
  
                                ;
                                ; Loop niter
                                ;
  for it = 0L, niter - 1 do begin
                                ;
                                ; Get mean spectrum using Hermitian Spline
                                ;
     yl = red_get_imean(wav, dat, res, npar, it, xl = xl, rebin = rebin, densegrid = densegrid, thres = thres, myg = myg)
                                ;
                                ; Pixel-to-pixel fits using a C++ routine to speed-up things
                                ;
     red_cfitgain, res, wav, dat, xl, yl, ratio
                                ;
  endfor
  yl = red_get_imean(wav, dat, res, npar, it, xl = xl, rebin = rebin, densegrid = densegrid, thres = thres, myg = myg)

                                ;
                                ; create cavity-error-free flat (save in "ratio" variable)
                                ;
  print, inam + 'Recreating cavity-error-free flats ... ', FORMAT='(A,$)'
                                ;
  for ii = 0L, nwav - 1 do ratio[ii,*,*] *= reform(res[0,*,*]) * $
     reform(red_get_linearcomp(wav[ii], res, npar))
                                ;
  print, 'done'
                                ; stop
                                ;
                                ; save results
                                ;
  if(~keyword_set(nosave)) then begin

     outdir = self.out_dir + '/flats/'
     for ii = 0L, nwav - 1 do begin
        namout =  outdir + namelist[ii]
        fzwrite, reform(ratio[ii,*,*]), namout, 'npar='+red_stri(npar)
        print, inam + 'saving file -> '+namout
     endfor
                                ;
     fit = {pars:res, yl:yl, xl:xl, oname:namelist}
     save, file = outdir+'spectral_flats/'+cam+'.'+pref+'.fit_results.sav', fit
     fit = 0B
  endif
                                ;
  return
end