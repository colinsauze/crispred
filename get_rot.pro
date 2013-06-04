function get_rot,az,el,dec
; Gives the image rotation as a function of telescope
; coordinates and observation table at the Swedish Solar
; Observatory, La Palma.

; Looking at the projected primary image the rotation is
; clockwise during the morning up the meridian passage
; and then counterclockwise during the afernoon.

; Input parameters: AZ  azimuth of Sun in radians
;                   EL  elevation of Sun in radians
;		    TC  table constant in radians
;			a constant depending on which observation
;			table is used. TC is about 48 to give
;			the angle between the table surface
;			and the N-S direction at the first 
;			observation table.
; Adapted from Goran Hosinsky
  drrat=!pi/180.d0              ;deg to rad rate
  LAT=28.758d0*drrat            ;observatory latitude (La Palma)
  TC=318.0d0*drrat              ;table constant

; According to spherical astronomy the angle between the N-S
; great circle and the vertical great circle in an AZ-EL 
; telescope varies as:

  ra1=asin(cos(LAT)*sin(AZ)/cos(dec*drrat))
; In the image plane the angle of the movement in Elevation
; varies as:

  ra=az+(atan(cos(EL),sin(EL)))+TC-ra1
  return,ra
end
