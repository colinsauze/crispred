FUNCTION red_m_linpol, K

H = 2*sqrt(K)

LP = 0.5 * [[1.+K, 1.-K, 0., 0.], $
            [1.-K, 1.+k, 0., 0.], $
            [0.,   0.,   H,  0.], $
            [0.,   0.,   0., H ]]

return, LP
END
