; docformat = 'rst'

;+
; 
; 
; :Categories:
;
;    CRISP pipeline
; 
; 
; :Author:
; 
; 
; 
; 
; 
; :Keywords:
; 
;    wb_states : 
;   
;   
;   
;    numpoints : in, optional, type=integer, default=88
;   
;      The size of MOMFBD subfields.
;   
;    modes : in, optional, type=string, default= '2-45,50,52-55,65,66'
;   
;      The modes to include in the expansions of the wavefront phases.
;   
;    nmodes : in, optional, type=integer, default=51
;
;      If keyword modes is not given, use the Nmodes most significant
;      KL modes.
;
;    date_obs : in, optional, type=string
;   
;      The date of observations in ISO (YYYY-MM-DD) format. If not
;      given, prepmomfbd will try to deduce it from the directory name
;      or, failing that, ask the user.
;   
;    state : 
;   
;   
;   
;    no_descatter : in, optional, type=boolean
;   
;       Set this if your data is from a near-IR (777 or 854 nm) line
;       and you do not want to do backscatter corrections.
;   
;    global_keywords : in, optional, type=strarr
;   
;      Any global keywords that you want to add to the momfbd config file.
;   
;    unpol : 
;   
;   
;   
;    skip : 
;   
;   
;   
;    pref : 
;   
;   
;   
;    escan : 
;   
;   
;   
;    div : 
;   
;   
;   
;    nremove : 
;   
;   
;   
;    oldgains :
; 
;
;
;    margin : in, optional, type=integer, default=5
; 
;      A margin (in pixels) to disregard from the FOV edges when
;      constructing the grid of MOMFBD subfields.
;
;
; :History:
; 
;   2013-06-04 : Split from monolithic version of crispred.pro.
;
;   2013-06-13 : JdlCR. Added support for scan-dependent gains ->
;                using keyword "/newgains".
;
;   2013-06-28 : JdlCR. Added NF (object) option 
; 
;   2013-08-27 : MGL. Added support for logging. Let the subprogram
;                find out its own name.
;
;   2013-12-19   PS. Work based on the link directory guess date
;                before asking adapt to changed link directory names
;                NEWGAINS is the default now (removed), use OLDGAINS
;
;   2014-01-10   PS. Remove keyword outformat, use self.filetype. to
;                not be a string.
;
;   2016-02-15 : MGL. Use red_loadbackscatter. Remove keyword descatter,
;                new keyword no_descatter.
;
;   2016-02-15 : MGL. Get just the file names from
;                red_loadbackscatter, do not read the files.
;
;   2016-04-18 : THI. Added margin keyword to allow for user-defined
;                edge trim Changed numpoints keyword to be a number
;                rather than a string.
;
;   2016-04-21 : MGL. Added some documentation. Use n_elements, not
;                keyword_set, to find out if a keyword needs to be set
;                to a default value.
;
;   2017-06-19 : THI. Added extraclip keyword to allow for
;                user-defined edge trim for each edge Changed default
;                margin from 5 to 0.
;
;   2017-10-10 : THI. Bugfix: the extraclip was wrongly applied to
;                mirrored channels
;
;   2017-10-11 : MGL. New keyword, Nmodes.
;
;   2017-11-28 : THI. Bugfix: the patch-positions were generated in global
;                coordinates, should be relative to the align-clip.
;
;-
pro red::prepmomfbd, wb_states = wb_states $
                     , numpoints = numpoints $
                     , modes = modes $
                     , date_obs = date_obs $
                     , state = state $
                     , no_descatter = no_descatter $
                     , global_keywords = global_keywords $
                     , unpol = unpol $
                     , skip = skip $
                     , pref = pref $
                     , escan = escan $
                     , div = div $
                     , nremove = nremove $
                     , oldgains = oldgains $
                     , nf = nfac $
                     , weight = weight $
                     , maxshift = maxshift $
                     , extraclip = extraclip $
                     , margin = margin $
                     , nmodes = nmodes

  ;; Name of this method
  inam = strlowcase((reverse((scope_traceback(/structure)).routine))[0])

  ;; Logging
  help, /obj, self, output = selfinfo 
  red_writelog, selfinfo = selfinfo


  if n_elements(maxshift) eq 0 then maxshift='30'
  ;; Get keywords
  IF ~keyword_set(date_obs) THEN BEGIN
        ;;; guess it from root_dir
      date_obs = strjoin(strsplit(file_basename(self.root_dir), '.', /extract), '-')
      IF ~strmatch(date_obs, '????-??-??') THEN $
        read, date_obs, prompt = inam+' : type date_obs (YYYY-MM-DD): '
  ENDIF
  if n_elements(numpoints) eq 0 then numpoints = 88
  if( size(numpoints, /type) eq 7 ) then numpoints = fix(numpoints)    ; convert strings, just to avoid breaking existing codes.

  ;; If the modes are specified, then use them. Otherwise look for Nmodes.
  if n_elements(modes) eq 0 then begin
     ;; Is the number of modes specified or do we need a default number?
     if n_elements(Nmodes) eq 0 then Nmodes = 51
     ;; KL modes in variance order:
     manymodes = red_expandrange('2-6,9,10,7,8,14,15,11-13,20,21,18,19,16,17,27,28,25,26,22-24,35,36,33,34,44,45,31,32,29,30,54,55,42,43,40,41,37-39,65,66,52,53,50,51,77,78,48,49,46,47,63,64,61,62,90,91,75,76,59,60,56-58,104,105,73,74,88,89,71,72,69,70,67,68,119,120,86,87,102,103,84,85,135,136,82,83,79-81,100,101,117,118,152,153,98,99,96,97,115,116,133,134,94,95,92,93,170,171,113,114,150,151,131,132,111,112,189,190,109,110,106-108,129,130,168,169,148,149,209,210,127,128,125,126,123,124,121,122,146,147,187,188,230,231,166,167,144,145,142,143,207,208,164,165,252,253,140,141,137-139,185,186,162,163,275,276,228,229,160,161,183,184,205,206,158,159,156,157,154,155,181,182,299,300,250,251,203,204,179,180,226,227,177,178,175,176,324,325,172-174,201,202,273,274,224,225,248,249,199,200,350,351,197,198,297,298,222,223,195,196,193,194,191,192,246,247,271,272,220,221,377,378,322,323,218,219,244,245,216,217,295,296,269,270,214,215,211-213,405,406,242,243,348,349,240,241,267,268,320,321,293,294,434,435,238,239,236,237,375,376,265,266,234,235,232,233,291,292,346,347,263,264,464,465,318,319,261,262,403,404,289,290,259,260,257,258,254-256,495,496,373,374,316,317,344,345,287,288,432,433,285,286,314,315,527,528,283,284,401,402,342,343,281,282,371,372,279,280,277,278,462,463,312,313,560,561,310,311,340,341,430,431,308,309,369,370,399,400,493,494,306,307,338,339,304,305,301-303,594,595,367,368,336,337,460,461,397,398,525,526,428,429,334,335,629,630,365,366,332,333,330,331,328,329,326,327,491,492,395,396,363,364,558,559,458,459,426,427,665,666,361,362,393,394,359,360,523,524,357,358,592,593,424,425,355,356,352-354,489,490,391,392,456,457,702,703,389,390,422,423,556,557,627,628,387,388,454,455,521,522,740,741,385,386,487,488,420,421,383,384,381,382,379,380,590,591,418,419,452,453,663,664,779,780,485,486,416,417,554,555,519,520,450,451,414,415,412,413,625,626,410,411,700')
     ;; Use the Nmodes most significant modes:
     if Nmodes le n_elements(manymodes) then modes = red_collapserange(manymodes[0:Nmodes-1], ld = '', rd = '') else stop
  endif

  if n_elements(nremove) eq 0 then nremove=0
  if n_elements(nfac) gt 0 then begin
     if(n_elements(nfac) eq 1) then nfac = replicate(nfac,3)
  endif
  if n_elements(margin) eq 0 then margin = 0
  
  ;; Get states from the data folder
  d_dirs = file_search(self.out_dir+'/data/*', /TEST_DIR, count = nd)
  IF nd EQ 0 THEN BEGIN
      print, inam + ' : ERROR -> no frames found in '+self.out_dir+'/data'
      print, inam + '   Did you run link_data?'
      return
  ENDIF
  
  self -> getcamtags, dir = self.data_dir

  case n_elements(extraclip) of
    0 : eclip = [0L, 0L, 0L, 0L]
    1 : eclip = replicate(extraclip, 4)
    2 : eclip = [ replicate(extraclip[0], 2), $
                  replicate(extraclip[1], 2) ]
    4 : eclip = extraclip               ; Leave as it is.
    else : begin
      print, inam + "ERROR: Don't know how to use keyword extraclip with " $
             + strtrim(n_elements(extraclip), 2) + ' elements.'
      stop
    end
  endcase
  eclip = abs(eclip)    ; force positive values in extraclip
  eclip += abs(margin)  ; add margin to extraclip along all edges.
   
  for fff = 0, nd - 1 do begin

     folder_tag = file_basename(d_dirs[fff])
     
     search = self.out_dir+'/data/'+folder_tag+'/'+self.camt
     files = file_search(search+'/*', count = nf)
     
     IF nf EQ 0 THEN BEGIN
         print, inam + ' : ERROR -> no frames found in '+search
         print, inam + '   Did you run link_data?'
         return
     ENDIF 

     files = red_sortfiles(temporary(files))
     
     ;; Get image unique states
     stat = red_getstates(files, /LINKS)
      ;;; skip leading frames?
     IF nremove GT 0 THEN red_flagtuning, stat, nremove
     
     states = stat.hscan+'.'+stat.state
     pos = uniq(states, sort(states))
     ustat = stat.state[pos]
     ustatp = stat.pref[pos]
                                ;ustats = stat.scan[pos]

     ntt = n_elements(ustat)
     hscans = stat.hscan[pos]

     ;; Get unique prefilters
     upref = stat.pref[uniq(stat.pref, sort(stat.pref))]
     np = n_elements(upref)

     ;; Get scan numbers
     uscan = stat.rscan[uniq(stat.rscan, sort(stat.rscan))]
     ns = n_elements(uscan)

     ;; Create a reduc file per prefilter and scan number?
     outdir = self.out_dir + '/momfbd/' + folder_tag
     file_mkdir, outdir

     ;; Print cams
     print, inam + ' : cameras found:'
     print, ' WB   -> '+self.camwbtag
     print, ' NB_T -> '+self.camttag
     print, ' NB_R -> '+self.camrtag

     ;; Choose offset state
     for ss = 0L, ns - 1 do begin
         IF n_elements(escan) NE 0 THEN IF ss NE escan THEN CONTINUE 

        scan = uscan[ss]

        for pp = 0L, np - 1 do begin
           if(keyword_set(pref)) then begin
              if(upref[pp] NE pref) then begin
                 print, inam + ' : Skipping prefilter -> ' + upref[pp]
                 continue
              endif
           endif

           ;; Load align clips
           clipfile = self.out_dir + '/calib/align_clips.'+upref[pp]+'.sav'
           IF(~file_test(clipfile)) THEN BEGIN
              print, inam + ' : ERROR -> align_clip file not found'
              print, inam + ' : -> you must run red::getalignclps first!'
              continue
           endif
           restore, clipfile
           wclip = acl[0]
           tclip = acl[1]
           rclip = acl[2]

           sim_roi = intarr(4)
           sim_roi[0] = min(cl[0:1,0])          ; sim_roi has to be normal-ordered, i.e. firstVal < lastVal
           sim_roi[1] = max(cl[0:1,0])
           sim_roi[2] = min(cl[2:3,0])
           sim_roi[3] = max(cl[2:3,0])
           sim_roi[[0,2]] += eclip[[0,2]]       ; shrink the common FOV by extraclip.
           sim_roi[[1,3]] -= eclip[[1,3]]

           ; the patch coordinates are relative to the align-clip area
           sim_x = rdx_segment( 0, sim_roi[1]-sim_roi[0], numpoints, /momfbd )
           sim_y = rdx_segment( 0, sim_roi[3]-sim_roi[2], numpoints, /momfbd )
           sim_x += eclip[0]
           sim_y += eclip[2]
           sim_x_string = strjoin(strtrim(sim_x,2), ',')
           sim_y_string = strjoin(strtrim(sim_y,2), ',')

           lam = strmid(string(float(upref[pp]) * 1.e-10), 2)

           cfg_file = 'momfbd.reduc.'+upref[pp]+'.'+scan+'.cfg'
           outdir = self.out_dir + '/momfbd/'+folder_tag+'/'+upref[pp]+'/cfg/'
           file_mkdir, outdir
           rdir = self.out_dir + '/momfbd/'+folder_tag+'/'+upref[pp]+'/cfg/results/'
           file_mkdir, rdir
           ddir = self.out_dir + '/momfbd/'+folder_tag+'/'+upref[pp]+'/cfg/data/'
           file_mkdir, ddir
           if(n_elements(lun) gt 0) then free_lun, lun
           openw, lun, outdir + cfg_file, /get_lun, width=2500

           ;; Image numbers
           numpos = where((stat.rscan eq uscan[ss]) AND (stat.star eq 0B) AND (stat.pref eq upref[pp]), ncount)
           if(ncount eq 0) then continue
           n0 = stat.nums[numpos[0]]
           n1 = stat.nums[numpos[ncount-1]]
           nall = strjoin(stat.nums[numpos],',')
           print, inam+' : Prefilter = '+upref[pp]+' -> scan = '+uscan[ss]+' -> image range = ['+n0+' - '+n1+']'

           ;; WB anchor channel
           printf, lun, 'object{'
           printf, lun, '  WAVELENGTH=' + lam
           printf, lun, '  OUTPUT_FILE=results/'+self.camwbtag+'.'+scan+'.'+upref[pp]
           if(n_elements(weight) eq 3) then printf, lun, '  WEIGHT='+string(weight[0])
           printf, lun, '  channel{'
           printf, lun, '    IMAGE_DATA_DIR='+self.out_dir+'/data/'+folder_tag+ '/' +self.camwb+'_nostate/'
           printf, lun, '    FILENAME_TEMPLATE='+self.camwbtag+'.'+scan+'.'+upref[pp]+'.%07d'
           printf, lun, '    GAIN_FILE=' + file_search(self.out_dir+'gaintables/'+self.camwbtag + $
                                                       '.' + upref[pp]+'*.gain')
           printf, lun, '    DARK_TEMPLATE='+self.out_dir+'darks/'+self.camwbtag+'.summed.0000001'
           printf, lun, '    DARK_NUM=0000001'
           printf, lun, '    ' + wclip
           if (upref[pp] EQ '8542' OR upref[pp] EQ '7772' ) AND ~keyword_set(no_descatter) then begin
              self -> loadbackscatter, self.camwbtag, upref[pp], bgfile = bgf, bpfile = psff
;              psff = self.descatter_dir+'/'+self.camwbtag+'.psf.f0'
;              bgf = self.descatter_dir+'/'+self.camwbtag+'.backgain.f0'
;              if(file_test(psff) AND file_test(bgf)) then begin
              printf, lun, '    PSF='+psff
              printf, lun, '    BACK_GAIN='+bgf
;              endif
           endif 

           if(keyword_set(div)) then begin
              printf, lun, '    DIVERSITY='+string(div[0])+' mm'
           endif

           xofile = (file_search(self.out_dir+'/calib/'+self.camwbtag+'.*.xoffs'))[0]
           yofile = (file_search(self.out_dir+'/calib/'+self.camwbtag+'.*.yoffs'))[0]
           
           if(file_test(xofile)) then printf, lun, '    XOFFSET='+xofile
           if(file_test(yofile)) then printf, lun, '    YOFFSET='+yofile
           
           if(n_elements(nfac) gt 0) then printf,lun,'    NF=',red_stri(nfac[0])
           printf, lun, '  }'
           printf, lun, '}'

           ;; Loop all wavelengths
           pos1 = where((ustatp eq upref[pp]), count)
           if(count eq 0) then continue
           ustat1 = ustat[pos1]

           for ii = 0L, count - 1 do BEGIN
              
              ;; External states?
              if(keyword_set(state)) then begin
                 dum = where(state eq ustat1[ii], cstate)
                 if(cstate eq 0) then continue
                 print, inam+' : found '+state+' -> scan = '+uscan[ss]
              endif

              self -> whichoffset, ustat1[ii], xoff = xoff, yoff = yoff

              ;; Trans. camera
              istate = red_encode_scan(hscans[pos1[ii]], scan)+'.'+ustat1[ii]

              ;; lc4?
              tmp = strsplit(istate,'.', /extract)
              ntmp = n_elements(tmp)

              idx = strsplit(ustat1[ii],'.')
              nidx = n_elements(idx)
              iwavt = strmid(ustat1[ii], idx[0], idx[nidx-1]-1)

              if(keyword_set(skip)) then begin
                 dum = where(iwavt eq skip, ccout)
                 if ccout ne 0 then begin
                    print, inam+' : skipping state -> '+ustat1[ii]
                    continue
                 endif
              endif

              printf, lun, 'object{'
              printf, lun, '  WAVELENGTH=' + lam
              printf, lun, '  OUTPUT_FILE=results/'+self.camttag+'.'+istate 
              if(n_elements(weight) eq 3) then printf, lun, '  WEIGHT='+string(weight[1])
              printf, lun, '  channel{'
              printf, lun, '    IMAGE_DATA_DIR='+self.out_dir+'/data/'+folder_tag+ '/' +self.camt+'/'
              printf, lun, '    FILENAME_TEMPLATE='+self.camttag+'.'+istate+'.%07d'

              if(~keyword_set(unpol)) then begin
                 if(keyword_set(oldgains)) then begin
                    search = self.out_dir+'/gaintables/'+self.camttag + '.' + ustat1[ii] + '*.gain'
                 endif else begin
                    search = self.out_dir+'/gaintables/'+folder_tag+'/'+self.camttag + '.' + istate+'.gain'
                 endelse
              endif Else begin

                 search = self.out_dir+'/gaintables/'+self.camttag + $
                          '.' + strmid(ustat1[ii], idx[0], $
                                       idx[nidx-1])+ '*unpol.gain'
                                ;if tmp[ntmp-1] eq 'lc4' then search = self.out_dir+'/gaintables/'+$
                                ;                                      self.camttag + '.' + ustat[pos[ii]] + $
                                ;                                      '*.gain'
                                ;
              endelse
              printf, lun, '    GAIN_FILE=' + file_search(search)
              printf, lun, '    DARK_TEMPLATE='+self.out_dir+'/darks/'+self.camttag+'.summed.0000001'
              printf, lun, '    DARK_NUM=0000001'
              printf, lun, '    ' + tclip

              xofile = self.out_dir+'/calib/'+self.camttag+'.'+xoff
              yofile = self.out_dir+'/calib/'+self.camttag+'.'+yoff
              if(file_test(xofile)) then printf, lun, '    XOFFSET='+xofile
              if(file_test(yofile)) then printf, lun, '    YOFFSET='+yofile

              if (upref[pp] EQ '8542' OR upref[pp] EQ '7772' ) AND ~keyword_set(no_descatter) then begin
                 self -> loadbackscatter, self.camttag, upref[pp], bgfile = bgf, bpfile = psff
;                 psff = self.descatter_dir+'/'+self.camttag+'.psf.f0'
;                 bgf = self.descatter_dir+'/'+self.camttag+'.backgain.f0'
;                 if(file_test(psff) AND file_test(bgf)) then begin
                 printf, lun, '    PSF='+psff
                 printf, lun, '    BACK_GAIN='+bgf
;              endif
              endif 

              if(keyword_set(div)) then begin
                 printf, lun, '    DIVERSITY='+string(div[1])+' mm'
              endif
              if(n_elements(nfac) gt 0) then printf,lun,'    NF=',red_stri(nfac[1])
           
              printf, lun, '    INCOMPLETE'
              printf, lun, '  }'
              printf, lun, '}'  

              ;; Reflected camera
              printf, lun, 'object{'
              printf, lun, '  WAVELENGTH=' + lam
              printf, lun, '  OUTPUT_FILE=results/'+self.camrtag+'.'+istate 
              if(n_elements(weight) eq 3) then printf, lun, '  WEIGHT='+string(weight[2])
              printf, lun, '  channel{'
              printf, lun, '    IMAGE_DATA_DIR='+self.out_dir+'/data/'+folder_tag+ '/' +self.camr+'/'
              printf, lun, '    FILENAME_TEMPLATE='+self.camrtag+'.'+istate+'.%07d'
                                ;   printf, lun, '    DIVERSITY=0.0 mm' 
              if(~keyword_set(unpol)) then begin
                 if(keyword_set(oldgains)) then begin
                    search = self.out_dir+'/gaintables/'+self.camrtag + '.' + ustat1[ii] + '*.gain'
                 endif else begin
                    search = self.out_dir+'/gaintables/'+folder_tag+'/'+self.camrtag + '.' + istate+'.gain'
                 endelse
              endif Else begin
                 idx = strsplit(ustat1[ii],'.')
                 nidx = n_elements(idx)
                 search = file_search(self.out_dir+'/gaintables/'+self.camrtag + $
                                      '.' + strmid(ustat1[ii], idx[0], $
                                                   idx[nidx-1])+ '*unpol.gain')
                                ;if tmp[ntmp-1] eq 'lc4' then search = self.out_dir+'/gaintables/'+$
                                ;                                      self.camrtag + '.' + ustat[pos[ii]] + $
                                ;                                      '*.gain'
              endelse
              printf, lun, '    GAIN_FILE=' + file_search(search)
              printf, lun, '    DARK_TEMPLATE='+self.out_dir+'/darks/'+self.camrtag+'.summed.0000001'
              printf, lun, '    DARK_NUM=0000001'
              printf, lun, '    ' + rclip
              xofile = self.out_dir+'/calib/'+self.camrtag+'.'+xoff
              yofile = self.out_dir+'/calib/'+self.camrtag+'.'+yoff
              if(file_test(xofile)) then printf, lun, '    XOFFSET='+xofile
              if(file_test(yofile)) then printf, lun, '    YOFFSET='+yofile
                                ;
              if (upref[pp] EQ '8542' OR upref[pp] EQ '7772' ) AND ~keyword_set(no_descatter) then begin
                 self -> loadbackscatter, self.camrtag, upref[pp], bgfile = bgf, bpfile = psff
;                 psff = self.descatter_dir+'/'+self.camrtag+'.psf.f0'
;                 bgf = self.descatter_dir+'/'+self.camrtag+'.backgain.f0'
;                 if(file_test(psff) AND file_test(bgf)) then begin
                 printf, lun, '    PSF='+psff
                 printf, lun, '    BACK_GAIN='+bgf
;                 endif
              endif 

              if(keyword_set(div)) then begin
                 printf, lun, '    DIVERSITY='+string(div[2])+' mm'
              endif
              if(n_elements(nfac) gt 0) then printf,lun,'    NF=',red_stri(nfac[2])

              printf, lun, '    INCOMPLETE'
              printf, lun, '  }'
              printf, lun, '}'

              ;; WB with states (for de-warping to the anchor, only to
              ;; remove rubbersheet when differential seeing is
              ;; strong)
              if(keyword_set(wb_states)) then begin
                 printf, lun, 'object{'
                 printf, lun, '  WAVELENGTH=' + lam
                 printf, lun, '  WEIGHT=0.00'
                 printf, lun, '  OUTPUT_FILE=results/'+self.camwbtag+'.'+istate 
                 printf, lun, '  channel{'
                 printf, lun, '    IMAGE_DATA_DIR='+self.out_dir+'/data/'+folder_tag+ '/' +self.camwb+'/'
                 printf, lun, '    FILENAME_TEMPLATE='+self.camwbtag+'.'+istate+'.%07d'
                                ; printf, lun, '    DIVERSITY=0.0 mm'
                 printf, lun, '    GAIN_FILE=' + file_search(self.out_dir+'/gaintables/'+self.camwbtag + $
                                                             '.' + upref[pp] + '*.gain')
                 printf, lun, '    DARK_TEMPLATE='+self.out_dir+'/darks/'+self.camwbtag+'.summed.0000001'
                 printf, lun, '    DARK_NUM=0000001'
                 printf, lun, '    ' + wclip
                 
                 if (upref[pp] EQ '8542' OR upref[pp] EQ '7772' ) AND ~keyword_set(no_descatter) then begin
                    self -> loadbackscatter, self.camwbtag, upref[pp], bgfile = bgf, bpfile = psff
;                    psff = self.descatter_dir+'/'+self.camwbtag+'.psf.f0'
;                    bgf = self.descatter_dir+'/'+self.camwbtag+'.backgain.f0'
;                    if(file_test(psff) AND file_test(bgf)) then begin
                    printf, lun, '    PSF='+psff
                    printf, lun, '    BACK_GAIN='+bgf
;                    endif
                 endif 

                 if(keyword_set(div)) then begin
                    printf, lun, '    DIVERSITY='+string(div[0])+' mm'
                 endif
                 xofile = self.out_dir+'/calib/'+self.camwbtag+'.'+xoff
                 yofile = self.out_dir+'/calib/'+self.camwbtag+'.'+yoff
                 if(file_test(xofile)) then printf, lun, '    XOFFSET='+xofile
                 if(file_test(yofile)) then printf, lun, '    YOFFSET='+yofile
                 if(n_elements(nfac) gt 0) then printf,lun,'    NF=',red_stri(nfac[0])

                 printf, lun, '    INCOMPLETE'
                 printf, lun, '  }'
                 printf, lun, '}'
              endif          
           endfor

           ;; Global keywords
           printf, lun, 'PROG_DATA_DIR=./data/'
           printf, lun, 'DATE_OBS='+date_obs
           printf, lun, 'IMAGE_NUMS='+nall       ;;  n0+'-'+n1
           printf, lun, 'BASIS=Karhunen-Loeve'
           printf, lun, 'MODES='+modes
           printf, lun, 'NUM_POINTS='+strtrim(numpoints,2)
           printf, lun, 'TELESCOPE_D=0.97'
           printf, lun, 'ARCSECPERPIX='+self.image_scale
           printf, lun, 'PIXELSIZE=16.0E-6'
           printf, lun, 'GETSTEP=getstep_conjugate_gradient'
           printf, lun, 'GRADIENT=gradient_diff'
           printf, lun, 'MAX_LOCAL_SHIFT='+string(maxshift,format='(I0)')
           printf, lun, 'NEW_CONSTRAINTS'
           printf, lun, 'FILE_TYPE='+self.filetype
           if self.filetype eq 'ANA' then begin
               printf, lun, 'DATA_TYPE=FLOAT'
           endif 
           printf, lun, 'FAST_QR'
           IF self.filetype EQ 'MOMFBD' THEN BEGIN
               printf, lun, 'GET_PSF'
               printf, lun, 'GET_PSF_AVG'
           ENDIF
           printf, lun, 'FPMETHOD=horint'
           printf, lun, 'SIM_X='+sim_x_string
           printf, lun, 'SIM_Y='+sim_y_string

           ;; External keywords?
           if(keyword_set(global_keywords)) then begin
              nk = n_elements(global_keywords)
              for ki = 0L, nk -1 do printf, lun, global_keywords[ki]
           endif

           free_lun, lun
        endfor
     endfor
  endfor

  print, inam+' : done!'
  return
end
