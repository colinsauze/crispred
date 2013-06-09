pro red::quicklook_movie, dark = dark, gain =  gain, clip = clip, overwrite = overwrite, x_flip = xflip, y_flip = y_flip, cam = cam
                                ;
  inam = 'quicklook_movie : '

  toread = 0
  if(~keyword_set(cam)) then cam = self.camt
                                ;
                                ; list files
  if(self.ndir GT 1) then begin
     print, inam + 'found folders:'
     for ii=0,self.ndir-1 do print, string(ii,format='(I3)')+' -> '+self.data_list[ii]
     ichoice = 0L
     read, ichoice, promp = 'Choose ID of the data folder: '
     folder = self.data_list[ichoice]
  endif else folder = self.data_dir


  spawn, 'find ' + folder + '/' + cam + '/ | grep im', files
  nf = n_elements(files)
  if(files[0] eq '') then begin
     print, 'red::quicklook_movie : ERROR -> no frames found in '+folder
  endif
                                ;
  files = red_sortfiles(files)
  camtag = (strsplit(file_basename(files[0]), '.',/extract))[0]
                                ;
                                ; WB cam? States are different
                                ;
  if(cam eq self.camwb) then begin
     stat = {state:strarr(nf), star:bytarr(nf), scan:strarr(nf)}
     for ii = 0L, nf -1 do begin
        tmp = strsplit(file_basename(files[ii]), '.', /extract)
        stat.state[ii] = tmp[4]
        stat.scan[ii] = tmp[1]
     endfor
     ustat = stat.state[uniq(stat.state, sort(stat.state))]
  endif else begin
     stat = red_getstates(files)
     ustat = stat.state[uniq(stat.state, sort(stat.state))]
  endelse
                                ;
  ns = n_elements(ustat)
                                ;
  for ii = 0L, ns - 1 do begin
     print, red_stri(ii, ni = '(I4)' ), ' -> ',ustat[ii]
  endfor
                                ;
  read, toread, prompt = 'red::quicklook_movie : select state number for movie: '
  print, 'red::quicklook_movie : selected state ->' + ustat[toread]
                                ;
                                ; Load dark if not provided externally
  if(~keyword_set(dark)) then begin
     df = self.out_dir+'/darks/'+camtag+'.dark'
     edark = file_test(df)
     if(~edark) then begin
        print, 'red::quickmovie : ERROR -> darkfile not found -> '+df
        print, 'red::quickmovie : using dark = 0.0!'
        dd = 0.0
     endif else begin
        dd = f0(df)
        print, 'red::quicklook_movie : darkfile : ' + df
     endelse
  endif else dd = dark
                                ;
                                ; load gain if not provided externally
  if(~keyword_set(gain)) then begin
     gf = self.out_dir+'/gaintables/'+camtag+'.'+ ustat[toread]+'.gain'
     egain = file_test(gf)
     if(~egain) then begin
        print, 'red::quickmovie : ERROR -> gainfile not found -> '+gf
        print, 'red::quickmovie : using gain = 1.0!'
        gg = 1.0
     endif else begin
        gg = f0(gf)
        print, 'red::quicklook_movie : gainfile : ' + gf
     endelse
  endif else gg = gain
                                ;
                                ;
                                ; states
                                ;
  if(cam ne self.camwb) then red_flagtunning, stat
                                ;
  pos = where((stat.state eq ustat[toread]) AND (stat.star eq 0B), count)
  scan = stat.scan[pos]
  uscan = scan[uniq(scan, sort(scan))]
  nscan = n_elements(uscan)
  myfiles = files[pos]
  print, 'red::quicklook_movie : found scans -> '+red_stri(nscan)
  

                                ;
                                ; Detect time stamp (if any)
                                ;
  dum = strsplit(folder,'/',/extract)
  dum = dum[n_elements(dum)-1]
  dum1 = strsplit(dum,':',/extract)


                                ;
                                ; Add time stamp to folder name (if any)
                                ;
  outdir = self.out_dir +'/movies/'+ustat[toread]+'/'
  if(n_elements(dum1) eq 3) then outdir += dum +'/'
  
                                ;
  file_mkdir, outdir
  print, outdir
                                ;
  ntot = 100. / (nscan -1.0)
  bb = string(13B)
                                ;
  print, 'red::quicklook_movie : saving to folder -> '+outdir 
  firsttime = 1B
                                ;
  for ii = 0L, nscan -1 do begin
     pos = where(scan eq uscan[ii], ctt)
     if(ctt eq 0) then continue
                                ;
     namout = 'img_'+ustat[toread]+'.'+red_stri(ii, ni = '(I05)')+'.png'
                                ;
     if(file_test(outdir+namout) AND ~keyword_set(overwrite)) then begin
        print, bb,'red::quicklook_movie : done -> ',ii*ntot,$
               '%, skipping existing frames!', format='(A,A,F5.1,A,$)'
        continue
     endif
                                ;
     im = (f0(myfiles[pos[0]]) - dd) * gg
     if size(gg,/n_dim) eq 2 then im = red_fillpix(im, mask=red_cleanmask(gg ne 0),nthreads=6) ; MLö 2012-10-07
                                ;
     idx1 = where(im eq 0.0, bla, complement = idx)
     if(bla gt 0L) then im[idx1] = mean(im[idx])
                                ;
                                ; Clip image
     if(firsttime) then begin
        if(keyword_set(clip)) then begin
           x0 = clip[0]
           x1 = clip[1]
           y0 = clip[2]
           y1 = clip[3]
        endif else begin
           dim = size(im,/dim)
           x0 = 0
           x1 = dim[0] - 1
           y0 = 0
           y1 = dim[1] - 1
        endelse
        firsttime = 0B
     endif
                                ;
     if(keyword_set(x_flip)) then im = reverse(temporary(im), 1)
     if(keyword_set(y_flip)) then im = reverse(temporary(im), 2)
                                ;
     write_png, outdir+namout, bytscl(histo_opt((temporary(im))[x0:x1, y0:y1]))
                                ;
     print, bb,'red::quicklook_movie : done -> ',ii*ntot,'%', format='(A,A,F5.1,A,$)'
  endfor
  print, ' '
                                ;
  return
end