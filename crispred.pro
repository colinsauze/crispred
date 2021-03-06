; docformat = 'rst'
;+
; Class crispred and subroutines, class polarim and subroutines.
; 
; Reduction pipeline for the SST. Steps prior to momfbd. The "pol"
; class takes care of the demodulation of the momfbd-ed data.
;
; :Categories:
;
;    CRISP pipeline
; 
; 
; :author:
; 
;   Jaime de la Cruz Rodriguez (IFA-UU 2011),
;         Department of Physics and Astronomy, Uppsala University,
;         jaime.cruz@physics.uu.se, jaime@astro.uio.no
;
;   Michiel van Noort (Max Plank - Lindau):
;         red_matrix2momfbd (adapted),
;         C++ polcal curves (adapted),
;         MOMFBD image format DLMm
;         fillpix adapted from Mats' (IDL) and Michiel's (c++)
;
;   Pit Suetterlin (ISP-KVA):
;         red::polcal (interface for the C++ code),
;         red::getalignclips,
;         red::getoffsets,
;         and dependencies
;
;   Tomas Berger (LMSAL):
;         destretch IDL module and routines.
;
;   Mats Löfdahl (ISP-KVA):
;         red::taper,
;         red::offsets,
;         red_findpinholegrid,
;         fillpix adapted from Mats' (IDL) and Michiel's (c++),
;         shift-and-sum in red_sumfiles for summing pinholes
;
; 
; :returns:
; 
; 
; :Params:
; 
;   filename : in, optional, type=string, default="config.txt"
;   
;     The name of the configuration file, that describes the location
;     of the science and calibration data (and a few other things).
;   
; 
; :Keywords:
; 
; 
; :dependencies:
;
;    The external C++ module must be compiled and the system variable
;    CREDUC point to creduc.so.
;
; 
; :history:
; 
;    2012-03-08 : JdlCR, The c++ routine red_cconvolve seemed to shift
;                 the convolved data by dx,dy > 0.5 < 2 pixels.
;                 Re-using the old IDL convolution routine (much
;                 slower, yet it works better). Must check the c++
;                 version.
;
;   2012-03-21 : JdlCR, red_matrix2momfbd -> Corrected clips,
;                pol::demodulate -> some extra features like
;                (/noclip)
;  
;   2012-05-26 : JdlCR, added new IDL polcal routines. Using my C++
;                with Pit's modifications and his interface.
;
;   2013-06-04 : Split from monolithic version of crispred.pro.
; 
;   2013-06-09 : MGL. Added red::setpinhdir.pro to list of included
;                files.
; 
;   2013-09-04 : MGL. Added red::pinholecalib.pro to list of included
;                files.
; 
;   2013-09-06 : MGL. Added red::prepmfbd.pro to list of included
;                files.
; 
;   2013-12-10 : PS  adapt for multiple flat_dir
; 
;-
function crispred, filename

  tmp = obj_new('red')
                                ;
                                ; check input file
                                ;
  if((n_params() eq 0) AND file_test('config.txt')) then filename = 'config.txt'
  if(~file_test(filename)) then begin
     print, 'reduc : ERROR, cannot find '+filename
     return, 0
  endif
                                ;
  tmp -> initialize, filename
                                ;
  return, tmp
end
