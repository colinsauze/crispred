; docformat = 'rst'

;+
; Makes a pipeline config file.
; 
; :Categories:
;
;    SST observations
; 
; 
; :Author:
; 
;    Mats Löfdahl, 2013-07-08
; 
; 
; :Params:
; 
;    root_dir : in, string
; 
;      The top directory of your saved data (or a regular expression
;      that matches it). If this directory name does not contain a
;      date, an attempt will be made to get the date from out_dir.
; 
; :Keywords:
; 
;    cfgfile : in, optional, type=string, default='config.txt'
; 
;      The name of the generated config file.
; 
;    scriptfile : in, optional, type=string, default='doit.pro'
; 
;      The name of the generated script file. The script file can be
;      run in an idl session with "@doit.pro" (assuming the default
;      name). It will perform the basic things, like co-adding of
;      darks, flats, etc. Later commands, that involve human
;      interaction are present in the file but commented out.
; 
;    date : in, optional, type=string
; 
;      The date (in iso format) the data was collected.
; 
;    out_dir : in, optional, type=string, default='current directory'
; 
;      The output directory to be used by crispred.
; 
;    lapalma : in, optional, type=boolean
; 
;       If this is set, will search for root_dir's date in
;       "/data/disk?/*/" and "/data/store?/*/" (where data is usually
;       found in La Palma)'
; 
;    stockholm : in, optional, type=boolean
; 
;       If this is set, will search for out_dir's date in
;       "/mnt/sand??/Incoming" (where data is usually found in
;       Stockholm). If no other information is given about where to
;       look for data, stockholm is assumed. 
; 
; 
; :History:
; 
;    2013-07-10 : MGL. Will now get a date from out_dir if none is
;                 present in root_dir.
; 
;    2013-08-29 : MGL. Any subdirectory that is not a known
;                 calibration data directory (darks, flats, etc.) is a
;                 potential science data directory.
; 
;    2013-08-30 : MGL. Take care of prefilter scans.
; 
;    2013-11-25 : MGL. Renamed from original name sst_makeconfig and
;                 moved to Crispred repository. You can now use
;                 regular expressions for root_dir. New keywords
;                 "date", "lapalma" and "stockholm". Made root_dir a
;                 keyword. 
; 
;    2013-11-26 : MGL. Various improvements. The "new" flat field
;                 procedure. Find out which cameras and wavelengths
;                 are present in the raw flats directories.
; 
;    2013-11-29 : MGL. Changed the order of some commands in the
;                 doit.pro file. Add "/descatter" keyword to
;                 sum_data_intdif call only for wavelengths > 7700. 
; 
; 
;-
pro red_setupworkdir, root_dir = root_dir $
                      , out_dir = out_dir $
                      , cfgfile = cfgfile $
                      , scriptfile = scriptfile $
                      , sand = sand $
                      , date = date $
                      , stockholm = stockholm $
                      , lapalma = lapalma

  if n_elements(cfgfile) eq 0 then cfgfile = 'config.txt'
  if n_elements(scriptfile) eq 0 then scriptfile = 'doit.pro'

  if n_elements(out_dir) eq 0 then out_dir = getenv('PWD')  
  if ~strmatch(out_dir,'*/') then out_dir += '/'
  
  if n_elements(date) eq 0 then begin
     ;; Date not specified. Does root_dir include the date?
     if n_elements(root_dir) eq 0 then begin
        date_known = 0
     endif else begin
        pos = stregex(root_dir,'/[0-9][0-9][0-9][0-9][.-][0-9][0-9][.-][0-9][0-9]')
        if pos ne -1 then begin
           ;; Date present in root_dir
           date = strmid(root_dir, pos+1, 10)
           date_known = 1
        endif else begin
           date_known = 0
        endelse
     endelse
  endif

  if n_elements(date) eq 0 then begin
     ;; Get the date from out_dir?
     pos = stregex(out_dir,'/[0-9][0-9][0-9][0-9][.-][0-9][0-9][.-][0-9][0-9]')
     if pos eq -1 then begin
        print, 'sst_makeconfig : No date in either root_dir or out_dir.'
        retall
     endif
     date = strmid(out_dir, pos+1, 10)
     date = strreplace(date, '-', '.', n = 2)
;     root_dir = root_dir+date+'/'
  endif

  date_momfbd = strreplace(date, '.', '-', n = 2)
  date = strreplace(date_momfbd, '-', '.', n = 2)
  
  ;; Where to look for data?
  if ~keyword_set(lapalma) and ~keyword_set(stockholm) and n_elements(root_dir) eq 0 then stockholm = 1
  if keyword_set(lapalma) then begin
     search_dir = "/data/disk?/*/"
     found_dir = file_search(search_dir+date, count=Nfound)
     if Nfound eq 0 then begin
        search_dir = "/data/store?/*/"
        found_dir = file_search(search_dir+date, count=Nfound)
     endif
  endif else begin
     if keyword_set(stockholm) then begin
        search_dir = "/mnt/sand??/Incoming/"
     endif else begin
        if ~strmatch(root_dir,'*/') then root_dir += '/'
        search_dir = root_dir
     endelse
     found_dir = file_search(search_dir+date, count=Nfound)
  endelse
  
  if Nfound eq 1 then begin
     root_dir = found_dir
  endif else if Nfound eq 0 then begin
     print, 'Cannot fine data from '+date+' in '+search_dir
     return
  endif else begin
     print, 'The root directory is not unique.'
     print, '"'+search_dir+'" matches: '
     print, found_dir
     stop
     ;; And here we need to figure out what to do...
     ;; Could happen in La Palma
  endelse



;  ;; Download position log
;  pfile = 'positionLog_'+date
;  tmp = file_search(pfile, count = Nlog)
;  if Nlog eq 0 then spawn, "scp obs@royac27.royac.iac.es:/usr/turret/logs/position/"+pfile+" ./"

  ;; Open two files for writing. Use logical unit Clun for a Config
  ;; file and Slun for a Script file.
  openw, Clun, cfgfile, /get_lun
  openw, Slun, scriptfile, /get_lun

  ;; printf, Slun, '.r crispred'
  printf, Slun, 'a = crispred("config.txt")' 
  printf, Slun, 'root_dir = "' + root_dir + '"'
  printf, Slun, 'a -> sumdark, /check' 
  

  print, 'Cameras'
  printf, Clun, '#'
  printf, Clun, '# --- Cameras'
  printf, Clun, '#'
  printf, Clun, 'cam_t = Crisp-T'
  printf, Clun, 'cam_r = Crisp-R'
  printf, Clun, 'cam_wb = Crisp-W'
  printf, Clun, '#'
  printf, Clun, 'root_dir = ' + root_dir
  printf, Clun, '#'

  print, 'Output'
  printf, Clun, '#'
  printf, Clun, '# --- Output'
  printf, Clun, '#'
  printf, Clun, 'out_dir = ' + out_dir

  print, 'Darks'
  printf, Clun, '#'
  printf, Clun, '# --- Darks'
  printf, Clun, '#'
  darkdirs = file_search(root_dir+'/dark*/*', count = Ndirs, /fold)
  for i = 0, Ndirs-1 do begin
     darksubdirs = file_search(darkdirs[i]+'/crisp*', count = Nsubdirs, /fold)
     if Nsubdirs gt 0 then begin
        printf, Clun, 'dark_dir = '+strreplace(darkdirs[i], root_dir, '')
     endif
  endfor

  print, 'Flats'
  printf, Clun, '#'
  printf, Clun, '# --- Flats'
  printf, Clun, '#'
  flatdirs = file_search(root_dir+'/flat*/*', count = Ndirs, /fold)
  dirarr = strarr(1)
  Nflat = 0
  prefilters = strarr(1)
  Nprefilters = 0
  for i = 0, Ndirs-1 do begin
     flatsubdirs = file_search(flatdirs[i]+'/crisp*', count = Nsubdirs, /fold)
     if Nsubdirs gt 0 then begin
        dirarr = [dirarr, strreplace(flatdirs[i], root_dir, '')]
        Nflat += 1
        printf, Clun, 'flat_dir = '+strreplace(flatdirs[i], root_dir, '')
        ;; Camera dirs and wavelengths to print to script file
        camdirs = strarr(Nsubdirs)
        wavelengths = strarr(Nsubdirs)
        for idir = 0, Nsubdirs-1 do begin
           camdirs[idir] = (strsplit(flatsubdirs[idir],  '/',/extract,count=nn))[nn-1]
           if camdirs[idir] eq 'Crisp-W' then rf = '3' else rf = '5'
           spawn, "ls "+flatsubdirs[idir]+"|rev|cut -d. -f"+rf+"|uniq|rev", wls
           wavelengths[idir] = strjoin(wls, ' ')
        endfor
        ;; Print to script file
        printf, Slun, 'a -> setflatdir, root_dir+"' + strreplace(flatdirs[i], root_dir, '') $
                + '"  ; ' + strjoin(camdirs+' ('+wavelengths+')', ' ')
        printf, Slun, 'a -> sumflat, /check'
     endif else begin
        flatsubdirs = file_search(flatdirs[i]+'/*', count = Nsubdirs)
        for j = 0, Nsubdirs-1 do begin
           flatsubsubdirs = file_search(flatsubdirs[j]+'/crisp*', count = Nsubsubdirs, /fold)
           if Nsubsubdirs gt 0 then begin
              dirarr = [dirarr, strreplace(flatsubdirs[j], root_dir, '')]
              Nflat += 1
              printf, Clun, 'flat_dir = '+strreplace(flatsubdirs[j], root_dir, '')
              ;; Camera dirs and wavelengths to print to script file
              camdirs = strarr(Nsubsubdirs)
              wavelengths = strarr(Nsubsubdirs)
              for idir = 0, Nsubsubdirs-1 do begin
                 camdirs[idir] = (strsplit(flatsubsubdirs[idir],  '/',/extract,count=nn))[nn-1]
                 if camdirs[idir] eq 'Crisp-W' then rf = '3' else rf = '5'
                 spawn, "ls "+flatsubsubdirs[idir]+"|rev|cut -d. -f"+rf+"|uniq|rev", wls
                 wavelengths[idir] = strjoin(wls, ' ')
              endfor
              ;; Print to script file
              printf, Slun, 'a -> setflatdir, root_dir+"' + strreplace(flatsubdirs[j], root_dir, '') $
                      + '" ; ' + strjoin(camdirs+' ('+wavelengths+')', ' ')
              printf, Slun, 'a -> sumflat, /check'
              ;; The following does not give the right result, 6300
              ;; instead of 6302! 
              prefilters = [prefilters, (strsplit(flatdirs[i],'/',/extract, count = nn))[nn-1]]
              Nprefilters += 1
           endif
        endfor
     endelse
  endfor
  prefilters = prefilters[1:*]
  printf, Slun, 'a -> makegains' 


  print, 'Pinholes'
  printf, Clun, '#'
  printf, Clun, '# --- Pinholes'
  printf, Clun, '#'
  pinhdirs = file_search(root_dir+'/pinh*/*', count = Ndirs, /fold)
  for i = 0, Ndirs-1 do begin
     pinhsubdirs = file_search(pinhdirs[i]+'/crisp*', count = Nsubdirs, /fold)
     if Nsubdirs gt 0 then begin
        printf, Clun, 'pinh_dir = '+strreplace(pinhdirs[i], root_dir, '')
        printf, Slun, 'a -> setpinhdir, root_dir+"'+strreplace(pinhdirs[i], root_dir, '')+'"'
        printf, Slun, 'a -> sumpinh_new'
     endif else begin
        pinhsubdirs = file_search(pinhdirs[i]+'/*', count = Nsubdirs)
        for j = 0, Nsubdirs-1 do begin
           pinhsubsubdirs = file_search(pinhsubdirs[j]+'/crisp*', count = Nsubsubdirs, /fold)
           if Nsubsubdirs gt 0 then begin
              printf, Clun, 'pinh_dir = '+strreplace(pinhsubdirs[j], root_dir, '')
              printf, Slun, 'a -> setpinhdir, root_dir+"'+strreplace(pinhsubdirs[j], root_dir, '')+'"'
              printf, Slun, 'a -> sumpinh_new'
           endif
        endfor
     endelse
  endfor
  
  print, 'Polcal'
  printf, Clun, '#'
  printf, Clun, '# --- Polcal'
  printf, Clun, '#'
  Npol = 0
  polcaldirs = file_search(root_dir+'/polc*/*', count = Ndirs, /fold)
  for i = 0, Ndirs-1 do begin
     polcalsubdirs = file_search(polcaldirs[i]+'/crisp*', count = Nsubdirs, /fold)
     if Nsubdirs gt 0 then begin
        printf, Clun, 'polcal_dir = '+strreplace(polcaldirs[i], root_dir, '')
        Npol += 1
     endif else begin
        polcalsubdirs = file_search(polcaldirs[i]+'/*', count = Nsubdirs)
        for j = 0, Nsubdirs-1 do begin
           polcalsubsubdirs = file_search(polcalsubdirs[j]+'/crisp*', count = Nsubsubdirs, /fold)
           if Nsubsubdirs gt 0 then begin
              printf, Clun, 'polcal_dir = '+strreplace(polcalsubdirs[j], root_dir, '')
              Npol += 1
           endif
        endfor
     endelse
  endfor

  print, 'PSF scan'
  printf, Clun, '#'
  printf, Clun, '# --- Prefilter scan'
  printf, Clun, '#'
  Npfs = 0
  pfscandirs = file_search(root_dir+'/pfscan*/*', count = Ndirs, /fold)
  for i = 0, Ndirs-1 do begin
     pfscansubdirs = file_search(pfscandirs[i]+'/crisp*', count = Nsubdirs, /fold)
     if Nsubdirs gt 0 then begin
        printf, Clun, '# pfscan_dir = '+strreplace(pfscandirs[i], root_dir, '')
        Npfs += 1
     endif else begin
        pfscansubdirs = file_search(pfscandirs[i]+'/*', count = Nsubdirs)
        for j = 0, Nsubdirs-1 do begin
           pfscansubsubdirs = file_search(pfscansubdirs[j]+'/crisp*', count = Nsubsubdirs, /fold)
           if Nsubsubdirs gt 0 then begin
              printf, Clun, '# pfscan_dir = '+strreplace(pfscansubdirs[j], root_dir, '')
              Npfs += 1
           endif
        endfor
     endelse
  endfor
  ;; If we implement dealing with prefilter scans in the pipeline,
  ;; here is where the command should be written to the script file.

  print, 'Science'
  printf, Clun, '#'
  printf, Clun, '# --- Science data'
  printf, Clun, '# '

  ;;  sciencedirs = file_search(root_dir+'/sci*/*', count = Ndirs, /fold)
  nonsciencedirs = [darkdirs, flatdirs, pinhdirs, polcaldirs, pfscandirs]
  sciencedirs = file_search(root_dir+'/*/*', count = Ndirs)
  dirarr = strarr(1)
  Nsci = 0

  for i = 0, Ndirs-1 do begin

     if total(sciencedirs[i] eq nonsciencedirs) eq 0 then begin

        sciencesubdirs = file_search(sciencedirs[i]+'/crisp*', count = Nsubdirs, /fold)
        if Nsubdirs gt 0 then begin
           dirarr = [dirarr, strreplace(sciencedirs[i], root_dir, '')]
           Nsci += 1
        endif else begin
           sciencesubdirs = file_search(sciencedirs[i]+'/*', count = Nsubdirs)
           for j = 0, Nsubdirs-1 do begin
              sciencesubsubdirs = file_search(sciencesubdirs[j]+'/crisp*', count = Nsubsubdirs, /fold)
              if Nsubsubdirs gt 0 then begin
                 dirarr = [dirarr, strreplace(sciencesubdirs[j], root_dir, '')]
                 Nsci += 1
              endif
           endfor               ; j
        endelse 
     endif
  endfor
  if Nsci gt 0 then printf, Clun, "data_dir = ['"+strjoin(dirarr[1:*], "','")+"']"

  printf, Slun, 'a -> link_data' 

  if Npol gt 0 then begin
     printf, Slun, 'a -> sumpolcal,/check, ucam="Crisp-T"' 
     printf, Slun, 'a -> polcalcube, cam = "Crisp-T"' 
     printf, Slun, 'a -> sumpolcal,/check, ucam="Crisp-R"' 
     printf, Slun, 'a -> polcalcube, cam = "Crisp-R"' 
     printf, Slun, 'a -> polcal' 
  endif

  printf, Slun, ''
  printf, Slun, ';; -----------------------------------------------------'
  printf, Slun, ';; This is how far we should be able to run unsupervised'
  printf, Slun, 'stop'          
  printf, Slun, ''

  printf, Slun, 'a -> getalignclips' 
  printf, Slun, 'a -> getoffsets' 

  printf, Slun, ''
  printf, Slun, ';; Outside IDL:'
  printf, Slun, ';; $ cd calib'
  printf, Slun, ';; $ pinholecalib.py -s N *.cfg' 
  printf, Slun, ';; $ cd ..'
  printf, Slun, ''

  print, 'Descatter (not implemented yet)'
  printf, Clun, '#'
  printf, Clun, '# --- 8542 descatter'
  printf, Clun, '#'
  printf, Clun, '#descatter_dir = '
  printf, Clun, '#'

  if Npol gt 0 then begin
     printf, Slun, 'a -> prepflatcubes          ; For polarimetry data sets' 
  endif
  if Npol ne Nprefilters then begin
     printf, Slun, 'a -> prepflatcubes_lc4      ; For non-polarimetry data sets' 
  endif

  printf, Slun, 'a -> fitgains_ng, npar = 3' 
  for iline = 0, Nprefilters-1 do begin
     if long(prefilters[iline]) gt 7700 then maybedescatter = ', /descatter' else maybedescatter = ''
     printf, Slun, "a -> sum_data_intdif, pref = '" + prefilters[iline] $
             + "', cam = 'Crisp-T', /verbose, /show, /overwrite" + maybedescatter
     printf, Slun, "a -> sum_data_intdif, pref = '" + prefilters[iline] $
             + "', cam = 'Crisp-R', /verbose, /show, /overwrite" + maybedescatter
     printf, Slun, "a -> make_intdif_gains3, pref = '" + prefilters[iline] $
             + "', min=0.1, max=4.0, bad=1.0, smooth=3.0, timeaver=1L, /smallscale"
     if strmid(prefilters[iline], 0, 2) eq '63' then begin
        printf, Slun, "a -> fitprefilter, fixcav = 2.0d, pref = '"+prefilters[iline]+"', shift=-0.5"
     endif else begin
        printf, Slun, "a -> fitprefilter, fixcav = 2.0d, pref = '"+prefilters[iline]+"'"
     endelse
     printf, Slun, "a -> prepmomfbd, /newgains, /wb_states, date_obs = " + date_momfbd $
             + ", numpoints = '88', outformat = 'MOMFBD', pref = '"+prefilters[iline]+"'"
  endfor


  printf, Slun, ''
  printf, Slun, ';; Run MOMFBD outside IDL.'
  printf, Slun, ''

  printf, Slun, ';; Post-MOMFBD stuff:' 
  printf, Slun, 'a -> make_unpol_crispex, /noflat [, /scans_only,/wbwrite]        ; For unpolarized data'
  if Npol gt 0 then begin
     printf, Slun, 'pol = a->polarim(/new)' 
     printf, Slun, 'for i = 0, n_elements(pol)-1, 1 do pol[i]->demodulate2,/noflat' 
     printf, Slun, 'a -> make_pol_crispex [, /scans_only,/wbwrite]          ; For polarized data'
  endif
  printf, Slun, 'a -> polish_tseries, np = 3 [, /negangle, xbd =, ybd =, tstep = ...]'
  
  free_lun, Clun
  free_lun, Slun
  
end