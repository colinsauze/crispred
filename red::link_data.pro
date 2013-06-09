pro red::link_data, no_remove = noremove, link_dir = link_dir, uscan = uscan, nremove=nremove
  if(n_elements(nremove) eq 0) then nremove=1
  inam = 'red::link_data : '
  if(~self.dodata) then begin
     print, 'red::link_data : ERROR : undefined data_dir'
     return
  endif
  if(~keyword_set(link_dir)) then link_dir = 'data/'
                                ;
                                ;
                                ; create file list
  for ff = 0L, self.ndir - 1 do begin
     print, inam + 'Folder -> ' + self.data_list[ff]
     data_dir = self.data_list[ff]
     folder_tag = strsplit(data_dir,'/',/extract)
     nn = n_elements(folder_tag) - 1
     folder_tag = folder_tag[nn]

     for ic = 0L, 2 do begin
        case ic of
           0: begin
              if(self.docamt eq 0B) then begin
                 print, 'red::link_data : Nothing to do for ', self.camt
              endif
              cam = self.camt
              doit = self.docamt
              wb = 0B
           end
           1: begin
              if(self.docamr eq 0B) then begin
                 print, 'red::link_data : Nothing to do for '+ self.camr
              endif
              cam = self.camr
              doit = self.docamr
              wb = 0B
           end
           2: begin
              if(self.docamwb eq 0B) then begin
                 print, 'red::link_data : Nothing to do for '+ self.camwb
              endif
              cam = self.camwb
              doit = self.docamwb
              wb = 1B
           end
        endcase
        
        
        
        if(~doit) then continue
                                ;
        spawn, 'find ' + data_dir + '/' + cam + '/ | grep im.ex', files
        nf = n_elements(files)
                                ;
        if(files[0] eq '') then begin
           print, 'red::sumflat : ERROR : '+cam+': no files found in: '+$
                  data_dir +' : skipping camera!'
           continue
        endif
                                ;
                                ; sort files by image number
        files = red_sortfiles(files)
                                ;
                                ; get states
        stat = red_getstates(files)
        
                                ;
                                ; flag first frame after tunning
        if(~keyword_set(noremove)) then begin
           print, 'red::link_data : Flagging first frame after tunning'
           red_flagtunning, stat, nremove
        endif
                                ;
        camtag = (strsplit(file_basename(files[0]), '.', /extract))[0]
        
                                ;
                                ; Create linker script
        nt = n_elements(files)
                                ;
        linkername = self.out_dir + '/' + camtag + '_science_linker_'+folder_tag+'.sh'
        openw, lun, linkername, /get_lun
        printf, lun, '#!/bin/bash'
        
                                ;
                                ; print links
        ntot = 100. / (nt - 1.0)
        bb = string(13b)
                                ;
        outdir = self.out_dir + '/' + link_dir + '/' + folder_tag+ '/' + camtag + '/'
        outdir1 = self.out_dir + '/' + link_dir + '/' + folder_tag+ '/' + camtag + '_nostate/'
                                ;
        for ii = 0L, nt - 1 do begin
           if(stat.star[ii]) then continue
           if(keyword_set(uscan)) then if(stat.scan[ii] NE uscan) then continue
                                ;
           namout = outdir + camtag + '.' + stat.scan[ii] +'.'+ stat.state[ii] + '.' +stat.nums[ii]
                                ;
           printf, lun, 'ln -s '+ files[ii] + ' ' + namout
                                ;
           if(wb) then begin
              namout = outdir1 + camtag + '.' + stat.scan[ii]+ '.' +stat.pref[ii] + '.' +stat.nums[ii]
              printf, lun, 'ln -s '+ files[ii] + ' ' + namout
           endif
                                ;
           print, bb, 'red::link_data : creating linker for '+camtag+$
                  ' -> ', ii * ntot, '%', FORMAT = '(A,A,F5.1,A,$)'
        endfor
        free_lun, lun
        print, ' '
                                ;
                                ; create folder and link data
        file_mkdir, outdir
        if(wb) then file_mkdir, outdir1
                                ;
        print, 'red::link_data : executing '+  linkername
        spawn, '/bin/bash ' + linkername
                                ;
     endfor
  endfor
                                ;
  return
end