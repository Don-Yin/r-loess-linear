C     Copyright (C) 1998--2020 The R Core Team
C     Copyright (C) 2026 Don Yin
C
C  The authors of this software are Cleveland, Grosse, and Shyu.
C  Copyright (c) 1989, 1992 by AT&T.
C  Permission to use, copy, modify, and distribute this software for any
C  purpose without fee is hereby granted, provided that this entire notice
C  is included in all copies of any software which is or includes a copy
C  or modification of this software and in all copies of the supporting
C  documentation for such software.
C  THIS SOFTWARE IS BEING PROVIDED "AS IS", WITHOUT ANY EXPRESS OR IMPLIED
C  WARRANTY.  IN PARTICULAR, NEITHER THE AUTHORS NOR AT&T MAKE ANY
C  REPRESENTATION OR WARRANTY OF ANY KIND CONCERNING THE MERCHANTABILITY
C  OF THIS SOFTWARE OR ITS FITNESS FOR ANY PARTICULAR PURPOSE.

C     Derived from ehg127 in R-devel revision 90840, stats/loessf.f.
C     Modified by Don Yin on 2026-11-11: extract the response-independent
C     QR/SVD path, capture its scalars and retain ordered diagnostics.

c The SE operator is response-independent. Preserve QR/SVD and diagnostics,
c but do not compute a second, unused fitted value at every tree vertex.
      subroutine fhg127(q,n,d,nf,f,x,psi,rw,kernel,k,dist,b,w,
     +     rcond,sing,sigma,u,e,qraux,work,tol,dd,tdeg,cdeg,
     +     norms,alphas,qrt,diagnose)
      logical diagnose
      integer column,d,dd,execnt,i,i3,i9,info,inorm2,j,jj,jpvt,k,kernel,
     +     n,nf,sing,tdeg
      integer cdeg(8),psi(n)
      double precision machep,f,i1,i10,i4,i5,i6,i7,i8,rcond,rho,scal,
     +     tol
      double precision g(15),sigma(15),u(15,15),e(15,15),b(nf,k),
     +     dist(n),q(d),qraux(15),rw(n),w(nf),work(15),x(n,d)

      double precision norms(15),alphas(15),qrt(15,15)
      integer idamax
      double precision d1mach

      external ehg106,loesswarn,ehg184,dqrdcx,dsvdc
      external idamax, d1mach

      save machep,execnt
      data execnt /0/
c     normsm -> norms
c     E -> g
c     MachEps -> machep
c     V -> e
c     X -> b
      execnt=execnt+1
      if(execnt.eq.1)then
c     initialize  d1mach(4) === 1 / DBL_EPSILON === 2^52  :
         machep=d1mach(4)
      end if
c     sort by distance
      do 3 i3=1,n
         dist(i3)=0
    3 continue
      do 4 j=1,dd
         i4=q(j)
         do 5 i3=1,n
            dist(i3)=dist(i3)+(x(i3,j)-i4)**2
    5    continue
    4 continue
      call ehg106(1,n,nf,1,dist,psi,n)
      rho=dist(psi(nf))*max(1.d0,f)
      if(rho .le. 0.and.diagnose)then
         call loesswarn(120)
      end if
c     compute neighborhood weights
      if(kernel.eq.2)then
         do 6 i=1,nf
            if(dist(psi(i)).lt.rho)then
               i1=dsqrt(rw(psi(i)))
            else
               i1=0
            end if
            w(i)=i1
    6    continue
      else
         do 7 i3=1,nf
            w(i3)=dsqrt(dist(psi(i3))/rho)
    7    continue
         do 8 i3=1,nf
            w(i3)=dsqrt(rw(psi(i3))*(1-w(i3)**3)**3)
    8    continue
      end if
      if(dabs(w(idamax(nf,w,1))).eq.0.and.diagnose)then
         call ehg184('at ',q(1),dd,1)
         call ehg184('radius ',rho,1,1)
         if(.not..false.)then
            call loesswarn(121)
         end if
      end if
c     fill design matrix
      column=1
      do 9 i3=1,nf
         b(i3,column)=w(i3)
    9 continue
      if(tdeg.ge.1)then
         do 10 j=1,d
            if(cdeg(j).ge.1)then
               column=column+1
               i5=q(j)
               do 11 i3=1,nf
                  b(i3,column)=w(i3)*(x(psi(i3),j)-i5)
   11          continue
            end if
   10    continue
      end if
      if(tdeg.ge.2)then
         do 12 j=1,d
            if(cdeg(j).ge.1)then
               if(cdeg(j).ge.2)then
                  column=column+1
                  i6=q(j)
                  do 13 i3=1,nf
                     b(i3,column)=w(i3)*(x(psi(i3),j)-i6)**2
   13             continue
               end if
               do 14 jj=j+1,d
                  if(cdeg(jj).ge.1)then
                     column=column+1
                     i7=q(j)
                     i8=q(jj)
                     do 15 i3=1,nf
                        b(i3,column)=w(i3)*(x(psi(i3),j)-i7)*(x(psi(i3),
     +jj)-i8)
   15                continue
                  end if
   14          continue
            end if
   12    continue
         k=column
      end if
c     equilibrate columns
      do 17 j=1,k
         scal=0
         do 18 inorm2=1,nf
            scal=scal+b(inorm2,j)**2
   18    continue
         scal=dsqrt(scal)
         if(0.lt.scal)then
            do 19 i3=1,nf
               b(i3,j)=b(i3,j)/scal
   19       continue
            norms(j)=scal
         else
            norms(j)=1
         end if
   17 continue
c     singular value decomposition
      call dqrdcx(b,nf,nf,k,qraux,jpvt,work,0,alphas,qrt)
      do 20 i9=1,k
         do 21 i3=1,k
            u(i3,i9)=0
   21    continue
   20 continue
      do 22 i=1,k
         do 23 j=i,k
c FIXME: this has i = 3 vs bound 2 in a ggplot2 test
            u(i,j)=b(i,j)
   23    continue
   22 continue
      call dsvdc(u,15,k,k,sigma,g,u,15,e,15,work,21,info)
      if(.not.(info.eq.0).and.diagnose)then
         call loesswarn(182)
      end if
      tol=sigma(1)*(100*machep)
      rcond=min(rcond,sigma(k)/sigma(1))
      if(sigma(k).le.tol)then
         sing=sing+1
         if(sing.eq.1.and.diagnose)then
            call ehg184('pseudoinverse used at',q(1),d,1)
            call ehg184('neighborhood radius',dsqrt(rho),1,1)
            call ehg184('reciprocal condition number ',rcond,1,1)
         else
            if(sing.eq.2.and.diagnose)then
               call ehg184('There are other near singularities as well.'
     +,rho,1,1)
            end if
         end if
      end if
c     compensate for equilibration
      do 24 j=1,k
         i10=norms(j)
         do 25 i3=1,k
            e(j,i3)=e(j,i3)/i10
   25    continue
   24 continue
      return
      end
