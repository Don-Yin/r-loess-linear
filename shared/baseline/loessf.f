C
C     Copyright (C) 1998--2020  The R Core Team

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

C     Modified by Don Yin on 2026-11-06: add inverse-neighbor caching.
C     Modified by Don Yin on 2026-11-11: capture local-fit factors and
C     replay ordered influence blocks, derived from R-devel r90840.
C     Experimental reductions retain the original scalar and BLAS order.

C       altered by B.D. Ripley to
C
C       remove unused variables
C       make phi in ehg139 double precision to match calling sequence
C       pass integer not logical from C
C
C       by M. Maechler, renaming ehg182() to loesswarn()

C     Note that  loesswarn(errormsg_code)  is in ./loessc.c

      subroutine ehg126(d,n,vc,x,v,nvmax)
      integer d,execnt,i,j,k,n,nvmax,vc
      DOUBLE PRECISION machin,alpha,beta,mu,t
      DOUBLE PRECISION v(nvmax,d), x(n,d)

      DOUBLE PRECISION D1MACH
      external D1MACH
      save machin,execnt
      data execnt /0/
c     MachInf -> machin
      execnt=execnt+1
      if(execnt.eq.1)then
c     initialize  d1mach(2) === DBL_MAX:
         machin=D1MACH(2)
      end if
c     fill in vertices for bounding box of $x$
c     lower left, upper right
      do 3 k=1,d
         alpha=machin
         beta=-machin
         do 4 i=1,n
            t=x(i,k)
            alpha=min(alpha,t)
            beta=max(beta,t)
    4    continue
c        expand the box a little
         mu=0.005D0*max(beta-alpha,1.d-10*max(DABS(alpha),DABS(beta))+
     +        1.d-30)
         alpha=alpha-mu
         beta=beta+mu
         v(1,k)=alpha
         v(vc,k)=beta
    3 continue
c     remaining vertices
      do 5 i=2,vc-1
         j=i-1
         do 6 k=1,d
            v(i,k)=v(1+mod(j,2)*(vc-1),k)
c    Integer division would do here
            j=INT(DBLE(j)/2.D0)
    6    continue
    5 continue
      return
      end

      subroutine ehg125(p,nv,v,vhit,nvmax,d,k,t,r,s,f,l,u)
      logical i1,i2,match
      integer d,h,i,i3,j,k,m,mm,nv,nvmax,p,r,s
      integer f(r,0:1,s),l(r,0:1,s),u(r,0:1,s),vhit(nvmax)
      DOUBLE PRECISION t
      DOUBLE PRECISION v(nvmax,d)
      external loesswarn
      h=nv
      do 3 i=1,r
         do 4 j=1,s
            h=h+1
            do 5 i3=1,d
               v(h,i3)=v(f(i,0,j),i3)
    5       continue
            v(h,k)=t
c           check for redundant vertex
            match=.false.
            m=1
c           top of while loop
    6       if(.not.match)then
               i1=(m.le.nv)
            else
               i1=.false.
            end if
            if(.not.(i1))goto 7
               match=(v(m,1).eq.v(h,1))
               mm=2
c              top of while loop
    8          if(match)then
                  i2=(mm.le.d)
               else
                  i2=.false.
               end if
               if(.not.(i2))goto 9
                  match=(v(m,mm).eq.v(h,mm))
                  mm=mm+1
                  goto 8
c              bottom of while loop
    9          m=m+1
               goto 6
c           bottom of while loop
    7       m=m-1
            if(match)then
               h=h-1
            else
               m=h
               if(vhit(1).ge.0)then
                  vhit(m)=p
               end if
            end if
            l(i,0,j)=f(i,0,j)
            l(i,1,j)=m
            u(i,0,j)=m
            u(i,1,j)=f(i,1,j)
    4    continue
    3 continue
      nv=h
      if(.not.(nv.le.nvmax))then
         call loesswarn(180)
      end if
      return
      end

      integer function ehg138(i,z,a,xi,lo,hi,ncmax)
      logical i1
      integer i,j,ncmax
      integer a(ncmax),hi(ncmax),lo(ncmax)
      DOUBLE PRECISION xi(ncmax),z(8)
c     descend tree until leaf or ambiguous
      j=i
c     top of while loop
    3 if(a(j).ne.0)then
         i1=(z(a(j)).ne.xi(j))
      else
         i1=.false.
      end if
      if(.not.(i1))goto 4
         if(z(a(j)).le.xi(j))then
            j=lo(j)
         else
            j=hi(j)
         end if
         goto 3
c     bottom of while loop
    4 ehg138=j
      return
      end

      subroutine ehg106(il,ir,k,nk,p,pi,n)

c Partial sorting of p(1, il:ir) returning the sort indices pi() only
c such that p(1, pi(k)) is correct

c     implicit none
c Arguments
c  Input:
      integer il,ir,k,nk,n
      DOUBLE PRECISION p(nk,n)
c     using only       p(1, pi(*))
c  Output:
      integer pi(n)

c Variables
      DOUBLE PRECISION t
      integer i,ii,j,l,r

c     find the $k$-th smallest of $n$ elements
c     Floyd+Rivest, CACM Mar '75, Algorithm 489
      l=il
      r=ir
c     while (l < r )
    3 if(.not.(l.lt.r))goto 4
c        to avoid recursion, sophisticated partition deleted
c        partition $x sub {l..r}$ about $t$
         t=p(1,pi(k))
         i=l
         j=r
         ii=pi(l)
         pi(l)=pi(k)
         pi(k)=ii
         if(t.lt.p(1,pi(r)))then
            ii=pi(l)
            pi(l)=pi(r)
            pi(r)=ii
         end if
c        top of while loop
    5    if(.not.(i.lt.j))goto 6
            ii=pi(i)
            pi(i)=pi(j)
            pi(j)=ii
            i=i+1
            j=j-1
c           top of while loop
    7       if(.not.(p(1,pi(i)).lt.t))goto 8
               i=i+1
               goto 7
c           bottom of while loop
    8       continue
c           top of while loop
    9       if(.not.(t.lt.p(1,pi(j))))goto 10
               j=j-1
               goto 9
c           bottom of while loop
   10       goto 5
c        bottom of while loop
    6    if(p(1,pi(l)).eq.t)then
            ii=pi(l)
            pi(l)=pi(j)
            pi(j)=ii
         else
            j=j+1
            ii=pi(r)
            pi(r)=pi(j)
            pi(j)=ii
         end if
         if(j.le.k)then
            l=j+1
         end if
         if(k.le.j)then
            r=j-1
         end if
         goto 3
c     bottom of while loop
    4 return
      end


      subroutine ehg127(q,n,d,nf,f,x,psi,y,rw,kernel,k,dist,eta,b,od,w,
     +     rcond,sing,sigma,u,e,dgamma,qraux,work,tol,dd,tdeg,cdeg,s)
      integer column,d,dd,execnt,i,i3,i9,info,inorm2,j,jj,jpvt,k,kernel,
     +     n,nf,od,sing,tdeg
      integer cdeg(8),psi(n)
      double precision machep,f,i1,i10,i2,i4,i5,i6,i7,i8,rcond,rho,scal,
     +     tol
      double precision g(15),sigma(15),u(15,15),e(15,15),b(nf,k),
     +     colnor(15),dist(n),eta(nf),dgamma(15),q(d),qraux(15),rw(n),
     +     s(0:od),w(nf),work(15),x(n,d),y(n)

      integer idamax
      double precision d1mach, ddot

      external ehg106,loesswarn,ehg184,dqrdc,dqrsl,dsvdc
      external idamax, d1mach, ddot

      save machep,execnt
      data execnt /0/
c     colnorm -> colnor
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
      if(rho .le. 0)then
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
      if(dabs(w(idamax(nf,w,1))).eq.0)then
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
      do 16 i3=1,nf
         eta(i3)=w(i3)*y(psi(i3))
   16 continue
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
            colnor(j)=scal
         else
            colnor(j)=1
         end if
   17 continue
c     singular value decomposition
      call dqrdc(b,nf,nf,k,qraux,jpvt,work,0)
      call dqrsl(b,nf,nf,k,qraux,eta,work,eta,eta,work,work,1000,info)
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
      if(.not.(info.eq.0))then
         call loesswarn(182)
      end if
      tol=sigma(1)*(100*machep)
      rcond=min(rcond,sigma(k)/sigma(1))
      if(sigma(k).le.tol)then
         sing=sing+1
         if(sing.eq.1)then
            call ehg184('pseudoinverse used at',q(1),d,1)
            call ehg184('neighborhood radius',dsqrt(rho),1,1)
            call ehg184('reciprocal condition number ',rcond,1,1)
         else
            if(sing.eq.2)then
               call ehg184('There are other near singularities as well.'
     +,rho,1,1)
            end if
         end if
      end if
c     compensate for equilibration
      do 24 j=1,k
         i10=colnor(j)
         do 25 i3=1,k
            e(j,i3)=e(j,i3)/i10
   25    continue
   24 continue
c     solve least squares problem
      do 26 j=1,k
         if(tol.lt.sigma(j))then
            i2=ddot(k,u(1,j),1,eta,1)/sigma(j)
         else
            i2=0.d0
         end if
         dgamma(j)=i2
   26 continue
      do 27 j=0,od
c        bug fix 2006-07-04 for k=1, od>1.   (thanks btyner@gmail.com)
         if(j.lt.k)then
            s(j)=ddot(k,e(j+1,1),15,dgamma,1)
         else
            s(j)=0.d0
         end if
   27 continue
      return
      end

      subroutine ehg131(x,y,rw,trl,diagl,kernel,k,n,d,nc,ncmax,vc,nv,
     +     nvmax,nf,f,a,c,hi,lo,pi,psi,v,vhit,vval,xi,dist,eta,b,ntol,
     +     fd,w,vval2,rcond,sing,dd,tdeg,cdeg,lq,lf,setlf)
      logical setlf
      integer identi,d,dd,i1,i2,j,k,kernel,n,nc,ncmax,nf,ntol,nv,
     +     nvmax,sing,tdeg,vc
      integer lq(nvmax,nf),a(ncmax),c(vc,ncmax),cdeg(8),hi(ncmax),
     +     lo(ncmax),pi(n),psi(n),vhit(nvmax)
      double precision f,fd,rcond,trl
      double precision lf(0:d,nvmax,nf),b(*),delta(8),diagl(n),dist(n),
     +     eta(nf),rw(n),v(nvmax,d),vval(0:d,nvmax),vval2(0:d,nvmax),
     +     w(nf),x(n,d),xi(ncmax),y(n)
      external ehg126,loesswarn,ehg139,ehg124
      double precision dnrm2
      external dnrm2
c     Identity -> identi
c     X -> b
      if(.not.(d.le.8))then
         call loesswarn(101)
      end if
c     build $k$-d tree
      call ehg126(d,n,vc,x,v,nvmax)
      nv=vc
      nc=1
      do 3 j=1,vc
         c(j,nc)=j
         vhit(j)=0
    3 continue
      do 4 i1=1,d
         delta(i1)=v(vc,i1)-v(1,i1)
    4 continue
      fd=fd*dnrm2(d,delta,1)
      do 5 identi=1,n
         pi(identi)=identi
    5 continue
      call ehg124(1,n,d,n,nv,nc,ncmax,vc,x,pi,a,xi,lo,hi,c,v,vhit,nvmax,
     +ntol,fd,dd)
c     smooth
      if(trl.ne.0)then
         do 6 i2=1,nv
            do 7 i1=0,d
               vval2(i1,i2)=0
    7       continue
    6    continue
      end if
      call ehg139(v,nvmax,nv,n,d,nf,f,x,pi,psi,y,rw,trl,kernel,k,dist,
     +     dist,eta,b,d,w,diagl,vval2,nc,vc,a,xi,lo,hi,c,rcond,
     +     sing,dd,tdeg,cdeg,lq,lf,setlf,vval)
      return
      end

c called from  lowese()  only :
      subroutine ehg133(d,vc,nvmax,ncmax, a,c,hi,lo, v,vval,xi,m,z,s)
      integer           d,vc,nvmax,ncmax,                      m
      integer           a(ncmax),c(vc,ncmax),hi(ncmax),lo(ncmax)
      double precision v(nvmax,d),vval(0:d,nvmax),xi(ncmax),z(m,d),s(m)
c Var
      double precision delta(8)
      integer i,i1

      double precision ehg128
      external ehg128

      do 3 i=1,m
         do 4 i1=1,d
            delta(i1)=z(i,i1)
    4    continue
         s(i)=ehg128(delta,d,ncmax,vc,a,xi,lo,hi,c,v,nvmax,vval)
    3 continue
      return
      end

      subroutine ehg140(iw,i,j)
      integer i,j
      integer iw(i)
      iw(i)=j
      return
      end

      subroutine ehg141(trl,n,deg,k,d,nsing,dk,delta1,delta2)
      double precision trl,delta1,delta2
      integer n,deg,k,d,nsing,dk

      double precision c(48), c1, c2, c3, c4,  corx,z,zz(1)
      integer i

      external ehg176
      double precision ehg176

c     coef, d, deg, del
      data c / .2971620d0,.3802660d0,.5886043d0,.4263766d0,.3346498d0,
     +.6271053d0,.5241198d0,.3484836d0,.6687687d0,.6338795d0,.4076457d0,
     +.7207693d0,.1611761d0,.3091323d0,.4401023d0,.2939609d0,.3580278d0,
     +.5555741d0,.3972390d0,.4171278d0,.6293196d0,.4675173d0,.4699070d0,
     +.6674802d0,.2848308d0,.2254512d0,.2914126d0,.5393624d0,.2517230d0,
     +.3898970d0,.7603231d0,.2969113d0,.4740130d0,.9664956d0,.3629838d0,
     +.5348889d0,.2075670d0,.2822574d0,.2369957d0,.3911566d0,.2981154d0,
     +.3623232d0,.5508869d0,.3501989d0,.4371032d0,.7002667d0,.4291632d0,
     +.4930370d0 /

      if(deg.eq.0) dk=1
      if(deg.eq.1) dk=d+1
      if(deg.eq.2) dk=int(dble((d+2)*(d+1))/2.d0)
      corx=dsqrt(k/dble(n))
      z=(dsqrt(k/trl)-corx)/(1-corx)
      if(nsing .eq. 0 .and. 1 .lt. z) then
         call ehg184('Chernobyl! trL<k',trl,1,1)
      else if(z .lt. 0) then
         call ehg184('Chernobyl! trL>n',trl,1,1)
      endif
      z=min(1.0d0,max(0.0d0,z))
c R fix
      zz(1)=z
      c4=dexp(ehg176(zz))
      i=1+3*(min(d,4)-1+4*(deg-1))
      if(d.le.4)then
         c1=c(i)
         c2=c(i+1)
         c3=c(i+2)
      else
         c1=c(i)+(d-4)*(c(i)-c(i-3))
         c2=c(i+1)+(d-4)*(c(i+1)-c(i-2))
         c3=c(i+2)+(d-4)*(c(i+2)-c(i-1))
      endif
      delta1=n-trl*dexp(c1*z**c2*(1-z)**c3*c4)
      i=i+24
      if(d.le.4)then
         c1=c(i)
         c2=c(i+1)
         c3=c(i+2)
      else
         c1=c(i)+(d-4)*(c(i)-c(i-3))
         c2=c(i+1)+(d-4)*(c(i+1)-c(i-2))
         c3=c(i+2)+(d-4)*(c(i+2)-c(i-1))
      endif
      delta2=n-trl*dexp(c1*z**c2*(1-z)**c3*c4)
      return
      end

      subroutine lowesc(n,l,ll,trl,delta1,delta2)
      integer i,j,n
      double precision delta1,delta2,trl
      double precision l(n,n),ll(n,n)
      double precision ddot
      external ddot
c     compute $LL~=~(I-L)(I-L)'$
      do 3 i=1,n
         l(i,i)=l(i,i)-1
    3 continue
      do 4 i=1,n
         do 5 j=1,i
            ll(i,j)=ddot(n,l(i,1),n,l(j,1),n)
    5    continue
    4 continue
      do 6 i=1,n
         do 7 j=i+1,n
            ll(i,j)=ll(j,i)
    7    continue
    6 continue
      do 8 i=1,n
         l(i,i)=l(i,i)+1
    8 continue
c     accumulate first two traces
      trl=0
      delta1=0
      do 9 i=1,n
         trl=trl+l(i,i)
         delta1=delta1+ll(i,i)
    9 continue
c     $delta sub 2 = "tr" LL sup 2$
      delta2=0
      do 10 i=1,n
         delta2=delta2+ddot(n,ll(i,1),n,ll(1,i),1)
   10 continue
      return
      end

      subroutine ehg169(d,vc,nc,ncmax,nv,nvmax,v,a,xi,c,hi,lo)
      integer           d,vc,nc,ncmax,nv,nvmax
      integer           a(ncmax), c(vc,ncmax), hi(ncmax), lo(ncmax)
      DOUBLE PRECISION v(nvmax,d),xi(ncmax)

      integer novhit(1),i,j,k,mc,mv,p
      external ehg125,loesswarn
      integer ifloor
      external ifloor

c     as in bbox
c     remaining vertices
      do 3 i=2,vc-1
         j=i-1
         do 4 k=1,d
            v(i,k)=v(1+mod(j,2)*(vc-1),k)
            j=ifloor(DBLE(j)/2.D0)
    4    continue
    3 continue
c     as in ehg131
      mc=1
      mv=vc
      novhit(1)=-1
      do 5 j=1,vc
         c(j,mc)=j
    5 continue
c     as in rbuild
      p=1
c     top of while loop
    6 if(.not.(p.le.nc))goto 7
         if(a(p).ne.0)then
            k=a(p)
c           left son
            mc=mc+1
            lo(p)=mc
c           right son
            mc=mc+1
            hi(p)=mc
            call ehg125(p,mv,v,novhit,nvmax,d,k,xi(p),2**(k-1),2**(d-k),
     +           c(1,p),c(1,lo(p)),c(1,hi(p)))
         end if
         p=p+1
         goto 6
c     bottom of while loop
    7 if(.not.(mc.eq.nc))then
         call loesswarn(193)
      end if
      if(.not.(mv.eq.nv))then
         call loesswarn(193)
      end if
      return
      end

      DOUBLE PRECISION function ehg176(z)
c
      DOUBLE PRECISION z(*)
c
      integer d,vc,nv,nc
      integer a(17), c(2,17)
      integer hi(17), lo(17)
      DOUBLE PRECISION v(10,1)
      DOUBLE PRECISION vval(0:1,10)
      DOUBLE PRECISION xi(17)
      double precision ehg128
      external ehg128

      data d,vc,nv,nc /1,2,10,17/
      data a(1) /1/
      data hi(1),lo(1),xi(1) /3,2,0.3705D0/
      data c(1,1) /1/
      data c(2,1) /2/
      data a(2) /1/
      data hi(2),lo(2),xi(2) /5,4,0.2017D0/
      data c(1,2) /1/
      data c(2,2) /3/
      data a(3) /1/
      data hi(3),lo(3),xi(3) /7,6,0.5591D0/
      data c(1,3) /3/
      data c(2,3) /2/
      data a(4) /1/
      data hi(4),lo(4),xi(4) /9,8,0.1204D0/
      data c(1,4) /1/
      data c(2,4) /4/
      data a(5) /1/
      data hi(5),lo(5),xi(5) /11,10,0.2815D0/
      data c(1,5) /4/
      data c(2,5) /3/
      data a(6) /1/
      data hi(6),lo(6),xi(6) /13,12,0.4536D0/
      data c(1,6) /3/
      data c(2,6) /5/
      data a(7) /1/
      data hi(7),lo(7),xi(7) /15,14,0.7132D0/
      data c(1,7) /5/
      data c(2,7) /2/
      data a(8) /0/
      data c(1,8) /1/
      data c(2,8) /6/
      data a(9) /0/
      data c(1,9) /6/
      data c(2,9) /4/
      data a(10) /0/
      data c(1,10) /4/
      data c(2,10) /7/
      data a(11) /0/
      data c(1,11) /7/
      data c(2,11) /3/
      data a(12) /0/
      data c(1,12) /3/
      data c(2,12) /8/
      data a(13) /0/
      data c(1,13) /8/
      data c(2,13) /5/
      data a(14) /0/
      data c(1,14) /5/
      data c(2,14) /9/
      data a(15) /1/
      data hi(15),lo(15),xi(15) /17,16,0.8751D0/
      data c(1,15) /9/
      data c(2,15) /2/
      data a(16) /0/
      data c(1,16) /9/
      data c(2,16) /10/
      data a(17) /0/
      data c(1,17) /10/
      data c(2,17) /2/
      data vval(0,1) /-9.0572D-2/
      data v(1,1) /-5.D-3/
      data vval(1,1) /4.4844D0/
      data vval(0,2) /-1.0856D-2/
      data v(2,1) /1.005D0/
      data vval(1,2) /-0.7736D0/
      data vval(0,3) /-5.3718D-2/
      data v(3,1) /0.3705D0/
      data vval(1,3) /-0.3495D0/
      data vval(0,4) /2.6152D-2/
      data v(4,1) /0.2017D0/
      data vval(1,4) /-0.7286D0/
      data vval(0,5) /-5.8387D-2/
      data v(5,1) /0.5591D0/
      data vval(1,5) /0.1611D0/
      data vval(0,6) /9.5807D-2/
      data v(6,1) /0.1204D0/
      data vval(1,6) /-0.7978D0/
      data vval(0,7) /-3.1926D-2/
      data v(7,1) /0.2815D0/
      data vval(1,7) /-0.4457D0/
      data vval(0,8) /-6.4170D-2/
      data v(8,1) /0.4536D0/
      data vval(1,8) /3.2813D-2/
      data vval(0,9) /-2.0636D-2/
      data v(9,1) /0.7132D0/
      data vval(1,9) /0.3350D0/
      data vval(0,10) /4.0172D-2/
      data v(10,1) /0.8751D0/
      data vval(1,10) /-4.1032D-2/
      ehg176=ehg128(z,d,nc,vc,a,xi,lo,hi,c,v,nv,vval)
      end

      subroutine lowesa(trl,n,d,tau,nsing,delta1,delta2)
      integer               n,d,tau,nsing
      double precision  trl, delta1,delta2

      integer dka,dkb
      double precision alpha,d1a,d1b,d2a,d2b
      external ehg141

      call ehg141(trl,n,1,tau,d,nsing,dka,d1a,d2a)
      call ehg141(trl,n,2,tau,d,nsing,dkb,d1b,d2b)
      alpha=dble(tau-dka)/dble(dkb-dka)
      delta1=(1-alpha)*d1a+alpha*d1b
      delta2=(1-alpha)*d2a+alpha*d2b
      return
      end

      subroutine ehg191(m,z,l,d,n,nf,nv,ncmax,vc,a,xi,lo,hi,c,v,nvmax,
     +                  vval2,lf,lq,cache,inv)
c Args
      integer m,d,n,nf,nv,ncmax,nvmax,vc,cache
      integer inv(nv,n)
      double precision z(m,d), l(m,n), xi(ncmax), v(nvmax,d),
     +     vval2(0:d,nvmax), lf(0:d,nvmax,nf)
      integer lq(nvmax,nf),a(ncmax),c(vc,ncmax),lo(ncmax),hi(ncmax)
c Var
      integer lq1,i,i1,i2,j,p
      logical found
      double precision zi(8)
      double precision ehg128
      external ehg128

c Inverse neighbour positions, using workspace allocated by the C caller.
c Ascending p preserves the original search's last-match semantics.
      if(cache.ne.0)then
         do 20 j=1,n
            do 21 i=1,nv
               inv(i,j)=0
   21       continue
   20    continue
         do 22 p=1,nf
            do 23 i=1,nv
               inv(i,lq(i,p))=p
   23       continue
   22    continue
      end if

      do 3 j=1,n
         do 4 i2=1,nv
            do 5 i1=0,d
               vval2(i1,i2)=0
    5       continue
    4    continue
         do 6 i=1,nv
            if(cache.ne.0)then
               p=inv(i,j)
               found=p.ne.0
            else
c              linear search for i in Lq
               lq1=lq(i,1)
               lq(i,1)=j
               p=nf
c              top of while loop
    7          if(.not.(lq(i,p).ne.j))goto 8
                  p=p-1
                  goto 7
c              bottom of while loop
    8          lq(i,1)=lq1
               found=lq(i,p).eq.j
            end if
            if(found)then
               do 9 i1=0,d
                  vval2(i1,i)=lf(i1,i,p)
    9          continue
            end if
    6    continue
         do 10 i=1,m
            do 11 i1=1,d
               zi(i1)=z(i,i1)
   11       continue
            l(i,j)=ehg128(zi,d,ncmax,vc,a,xi,lo,hi,c,v,nvmax,vval2)
   10    continue
    3 continue
      return
      end

      subroutine ehg196(tau,d,f,trl)
      integer d,dka,dkb,tau
      double precision alpha,f,trl,trla,trlb
      external ehg197
      call ehg197(1,d,f,dka,trla)
      call ehg197(2,d,f,dkb,trlb)
      alpha=dble(tau-dka)/dble(dkb-dka)
      trl=(1-alpha)*trla+alpha*trlb
      return
      end

      subroutine ehg197(deg,d,f,dk,trl)
      integer deg,d,dk
      double precision f, trl

      double precision g1
      dk = 0
      if(deg.eq.1) dk=d+1
      if(deg.eq.2) dk=int(dble((d+2)*(d+1))/2.d0)
      g1 = (-0.08125d0*d+0.13d0)*d+1.05d0
      trl = dk*(1+max(0.d0,(g1-f)/f))
      return
      end

      subroutine ehg192(y,d,n,nf,nv,nvmax,vval,lf,lq)
      integer d,i,i1,i2,j,n,nf,nv,nvmax
      integer lq(nvmax,nf)
      DOUBLE PRECISION i3
      DOUBLE PRECISION lf(0:d,nvmax,nf),vval(0:d,nvmax),y(n)

      do 3 i2=1,nv
         do 4 i1=0,d
            vval(i1,i2)=0
    4    continue
    3 continue
      do 5 i=1,nv
         do 6 j=1,nf
            i3=y(lq(i,j))
            do 7 i1=0,d
               vval(i1,i)=vval(i1,i)+i3*lf(i1,i,j)
    7       continue
    6    continue
    5 continue
      return
      end

      DOUBLE PRECISION function ehg128(z,d,ncmax,vc,a,xi,lo,hi,c,v,
     +     nvmax,vval)

c     implicit none
c Args
      integer d,ncmax,nvmax,vc
      integer a(ncmax),c(vc,ncmax),hi(ncmax),lo(ncmax)
      DOUBLE PRECISION z(d),xi(ncmax),v(nvmax,d), vval(0:d,nvmax)
c Vars
      logical i2,i3,i4,i5,i6,i7,i8,i9,i10
      integer i,i1,i11,i12,ig,ii,j,lg,ll,m,nt,ur
      integer t(20)
      DOUBLE PRECISION ge,gn,gs,gw,gpe,gpn,gps,gpw,h,phi0,phi1,
     +     psi0,psi1,s,sew,sns,v0,v1,xibar
      DOUBLE PRECISION g(0:8,256),g0(0:8),g1(0:8)

      external loesswarn,ehg184
c     locate enclosing cell
      nt=1
      t(nt)=1
      j=1
c     top of while loop
    3 if(.not.(a(j).ne.0))goto 4
         nt=nt+1
         if(z(a(j)).le.xi(j))then
            i1=lo(j)
         else
            i1=hi(j)
         end if
         t(nt)=i1
         if(.not.(nt.lt.20))then
            call loesswarn(181)
         end if
         j=t(nt)
         goto 3
c     bottom of while loop
    4 continue
c     tensor
      do 5 i12=1,vc
         do 6 i11=0,d
            g(i11,i12)=vval(i11,c(i12,j))
    6    continue
    5 continue
      lg=vc
      ll=c(1,j)
      ur=c(vc,j)
      do 7 i=d,1,-1
         h=(z(i)-v(ll,i))/(v(ur,i)-v(ll,i))
         if(h.lt.-.001D0)then
            call ehg184('eval ',z(1),d,1)
            call ehg184('lowerlimit ',v(ll,1),d,nvmax)
         else
            if(1.001D0.lt.h)then
               call ehg184('eval ',z(1),d,1)
               call ehg184('upperlimit ',v(ur,1),d,nvmax)
            end if
         end if
         if(-.001D0.le.h)then
            i2=(h.le.1.001D0)
         else
            i2=.false.
         end if
         if(.not.i2)then
            call loesswarn(122)
         end if
         lg=int(DBLE(lg)/2.D0)
         do 8 ig=1,lg
c           Hermite basis
            phi0=(1-h)**2*(1+2*h)
            phi1=h**2*(3-2*h)
            psi0=h*(1-h)**2
            psi1=h**2*(h-1)
            g(0,ig)=phi0*g(0,ig) + phi1*g(0,ig+lg) +
     +           (psi0*g(i,ig)+psi1*g(i,ig+lg)) * (v(ur,i)-v(ll,i))
            do 9 ii=1,i-1
               g(ii,ig)=phi0*g(ii,ig)+phi1*g(ii,ig+lg)
    9       continue
    8    continue
    7 continue
      s=g(0,1)
c     blending
      if(d.eq.2)then
c        ----- North -----
         v0=v(ll,1)
         v1=v(ur,1)
         do 10 i11=0,d
            g0(i11)=vval(i11,c(3,j))
   10    continue
         do 11 i11=0,d
            g1(i11)=vval(i11,c(4,j))
   11    continue
         xibar=v(ur,2)
         m=nt-1
c        top of while loop
   12    if(m.eq.0)then
            i4=.true.
         else
            if(a(t(m)).eq.2)then
               i3=(xi(t(m)).eq.xibar)
            else
               i3=.false.
            end if
            i4=i3
         end if
         if(.not.(.not.i4))goto 13
            m=m-1
c           voidp junk
            goto 12
c        bottom of while loop
   13    if(m.ge.1)then
            m=hi(t(m))
c           top of while loop
   14       if(.not.(a(m).ne.0))goto 15
               if(z(a(m)).le.xi(m))then
                  m=lo(m)
               else
                  m=hi(m)
               end if
               goto 14
c           bottom of while loop
   15       if(v0.lt.v(c(1,m),1))then
               v0=v(c(1,m),1)
               do 16 i11=0,d
                  g0(i11)=vval(i11,c(1,m))
   16          continue
            end if
            if(v(c(2,m),1).lt.v1)then
               v1=v(c(2,m),1)
               do 17 i11=0,d
                  g1(i11)=vval(i11,c(2,m))
   17          continue
            end if
         end if
         h=(z(1)-v0)/(v1-v0)
c        Hermite basis
         phi0=(1-h)**2*(1+2*h)
         phi1=h**2*(3-2*h)
         psi0=h*(1-h)**2
         psi1=h**2*(h-1)
         gn=phi0*g0(0)+phi1*g1(0)+(psi0*g0(1)+psi1*g1(1))*(v1-v0)
         gpn=phi0*g0(2)+phi1*g1(2)
c        ----- South -----
         v0=v(ll,1)
         v1=v(ur,1)
         do 18 i11=0,d
            g0(i11)=vval(i11,c(1,j))
   18    continue
         do 19 i11=0,d
            g1(i11)=vval(i11,c(2,j))
   19    continue
         xibar=v(ll,2)
         m=nt-1
c        top of while loop
   20    if(m.eq.0)then
            i6=.true.
         else
            if(a(t(m)).eq.2)then
               i5=(xi(t(m)).eq.xibar)
            else
               i5=.false.
            end if
            i6=i5
         end if
         if(.not.(.not.i6))goto 21
            m=m-1
c           voidp junk
            goto 20
c        bottom of while loop
   21    if(m.ge.1)then
            m=lo(t(m))
c           top of while loop
   22       if(.not.(a(m).ne.0))goto 23
               if(z(a(m)).le.xi(m))then
                  m=lo(m)
               else
                  m=hi(m)
               end if
               goto 22
c           bottom of while loop
   23       if(v0.lt.v(c(3,m),1))then
               v0=v(c(3,m),1)
               do 24 i11=0,d
                  g0(i11)=vval(i11,c(3,m))
   24          continue
            end if
            if(v(c(4,m),1).lt.v1)then
               v1=v(c(4,m),1)
               do 25 i11=0,d
                  g1(i11)=vval(i11,c(4,m))
   25          continue
            end if
         end if
         h=(z(1)-v0)/(v1-v0)
c        Hermite basis
         phi0=(1-h)**2*(1+2*h)
         phi1=h**2*(3-2*h)
         psi0=h*(1-h)**2
         psi1=h**2*(h-1)
         gs=phi0*g0(0)+phi1*g1(0)+(psi0*g0(1)+psi1*g1(1))*(v1-v0)
         gps=phi0*g0(2)+phi1*g1(2)
c        ----- East -----
         v0=v(ll,2)
         v1=v(ur,2)
         do 26 i11=0,d
            g0(i11)=vval(i11,c(2,j))
   26    continue
         do 27 i11=0,d
            g1(i11)=vval(i11,c(4,j))
   27    continue
         xibar=v(ur,1)
         m=nt-1
c        top of while loop
   28    if(m.eq.0)then
            i8=.true.
         else
            if(a(t(m)).eq.1)then
               i7=(xi(t(m)).eq.xibar)
            else
               i7=.false.
            end if
            i8=i7
         end if
         if(.not.(.not.i8))goto 29
            m=m-1
c           voidp junk
            goto 28
c        bottom of while loop
   29    if(m.ge.1)then
            m=hi(t(m))
c           top of while loop
   30       if(.not.(a(m).ne.0))goto 31
               if(z(a(m)).le.xi(m))then
                  m=lo(m)
               else
                  m=hi(m)
               end if
               goto 30
c           bottom of while loop
   31       if(v0.lt.v(c(1,m),2))then
               v0=v(c(1,m),2)
               do 32 i11=0,d
                  g0(i11)=vval(i11,c(1,m))
   32          continue
            end if
            if(v(c(3,m),2).lt.v1)then
               v1=v(c(3,m),2)
               do 33 i11=0,d
                  g1(i11)=vval(i11,c(3,m))
   33          continue
            end if
         end if
         h=(z(2)-v0)/(v1-v0)
c        Hermite basis
         phi0=(1-h)**2*(1+2*h)
         phi1=h**2*(3-2*h)
         psi0=h*(1-h)**2
         psi1=h**2*(h-1)
         ge=phi0*g0(0)+phi1*g1(0)+(psi0*g0(2)+psi1*g1(2))*(v1-v0)
         gpe=phi0*g0(1)+phi1*g1(1)
c        ----- West -----
         v0=v(ll,2)
         v1=v(ur,2)
         do 34 i11=0,d
            g0(i11)=vval(i11,c(1,j))
   34    continue
         do 35 i11=0,d
            g1(i11)=vval(i11,c(3,j))
   35    continue
         xibar=v(ll,1)
         m=nt-1
c        top of while loop
   36    if(m.eq.0)then
            i10=.true.
         else
            if(a(t(m)).eq.1)then
               i9=(xi(t(m)).eq.xibar)
            else
               i9=.false.
            end if
            i10=i9
         end if
         if(.not.(.not.i10))goto 37
            m=m-1
c           voidp junk
            goto 36
c        bottom of while loop
   37    if(m.ge.1)then
            m=lo(t(m))
c           top of while loop
   38       if(.not.(a(m).ne.0))goto 39
               if(z(a(m)).le.xi(m))then
                  m=lo(m)
               else
                  m=hi(m)
               end if
               goto 38
c           bottom of while loop
   39       if(v0.lt.v(c(2,m),2))then
               v0=v(c(2,m),2)
               do 40 i11=0,d
                  g0(i11)=vval(i11,c(2,m))
   40          continue
            end if
            if(v(c(4,m),2).lt.v1)then
               v1=v(c(4,m),2)
               do 41 i11=0,d
                  g1(i11)=vval(i11,c(4,m))
   41          continue
            end if
         end if
         h=(z(2)-v0)/(v1-v0)
c        Hermite basis
         phi0=(1-h)**2*(1+2*h)
         phi1=h**2*(3-2*h)
         psi0=h*(1-h)**2
         psi1=h**2*(h-1)
         gw=phi0*g0(0)+phi1*g1(0)+(psi0*g0(2)+psi1*g1(2))*(v1-v0)
         gpw=phi0*g0(1)+phi1*g1(1)
c        NS
         h=(z(2)-v(ll,2))/(v(ur,2)-v(ll,2))
c        Hermite basis
         phi0=(1-h)**2*(1+2*h)
         phi1=h**2*(3-2*h)
         psi0=h*(1-h)**2
         psi1=h**2*(h-1)
         sns=phi0*gs+phi1*gn+(psi0*gps+psi1*gpn)*(v(ur,2)-v(ll,2))
c        EW
         h=(z(1)-v(ll,1))/(v(ur,1)-v(ll,1))
c        Hermite basis
         phi0=(1-h)**2*(1+2*h)
         phi1=h**2*(3-2*h)
         psi0=h*(1-h)**2
         psi1=h**2*(h-1)
         sew=phi0*gw+phi1*ge+(psi0*gpw+psi1*gpe)*(v(ur,1)-v(ll,1))
         s=(sns+sew)-s
      end if
      ehg128=s
      return
      end

      integer function ifloor(x)
      DOUBLE PRECISION x
      ifloor=int(x)
      if(ifloor.gt.x) ifloor=ifloor-1
      end

c DSIGN is unused, causes conflicts on some platforms
c       DOUBLE PRECISION function DSIGN(a1,a2)
c       DOUBLE PRECISION a1, a2
c       DSIGN=DABS(a1)
c       if(a2.ge.0)DSIGN=-DSIGN
c       end


c ehg136()  is the workhorse of lowesf(.)
c     n = number of observations
c     m = number of x values at which to evaluate
c     f = span
c     nf = min(n, floor(f * n))
      subroutine ehg136(u,lm,m,n,d,nf,f,x,psi,y,rw,kernel,k,dist,eta,b,
     +     od,o,ihat,w,rcond,sing,dd,tdeg,cdeg,s)
      integer identi,d,dd,i,i1,ihat,info,j,k,kernel,l,lm,m,n,nf,
     +     od,sing,tdeg
      integer cdeg(8),psi(n)
      double precision f,i2,rcond,scale,tol
      double precision o(m,n),sigma(15),e(15,15),g(15,15),b(nf,k),
     $     dist(n),eta(nf),dgamma(15),q(8),qraux(15),rw(n),s(0:od,m),
     $     u(lm,d),w(nf),work(15),x(n,d),y(n)

      external ehg127,loesswarn,dqrsl
      double precision ddot
      external ddot

c     V -> g
c     U -> e
c     Identity -> identi
c     L -> o
c     X -> b
      if(k .gt. nf-1) call loesswarn(104)
      if(k .gt. 15)   call loesswarn(105)
      do 3 identi=1,n
         psi(identi)=identi
    3 continue
      do 4 l=1,m
         do 5 i1=1,d
            q(i1)=u(l,i1)
    5    continue
         call ehg127(q,n,d,nf,f,x,psi,y,rw,kernel,k,dist,eta,b,od,w,
     +        rcond,sing,sigma,e,g,dgamma,qraux,work,tol,dd,tdeg,cdeg,
     +        s(0,l))
         if(ihat.eq.1)then
c           $L sub {l,l} =
c           V sub {1,:} SIGMA sup {+} U sup T
c           (Q sup T W e sub i )$
            if(.not.(m.eq.n))then
               call loesswarn(123)
            end if
c           find $i$ such that $l = psi sub i$
            i=1
c           top of while loop
    6       if(.not.(l.ne.psi(i)))goto 7
               i=i+1
               if(.not.(i.lt.nf))then
                  call loesswarn(123)
c next line is not in current dloess
                  goto 7
               end if
               goto 6
c           bottom of while loop
    7       do 8 i1=1,nf
               eta(i1)=0
    8       continue
            eta(i)=w(i)
c           $eta = Q sup T W e sub i$
            call dqrsl(b,nf,nf,k,qraux,eta,eta,eta,eta,eta,eta,1000,
     +           info)
c           $gamma = U sup T eta sub {1:k}$
            do 9 i1=1,k
               dgamma(i1)=0
    9       continue
            do 10 j=1,k
               i2=eta(j)
               do 11 i1=1,k
                  dgamma(i1)=dgamma(i1)+i2*e(j,i1)
   11          continue
   10       continue
c           $gamma = SIGMA sup {+} gamma$
            do 12 j=1,k
               if(tol.lt.sigma(j))then
                  dgamma(j)=dgamma(j)/sigma(j)
               else
                  dgamma(j)=0.d0
               end if
   12       continue
c           voidp junk
c           voidp junk
            o(l,1)=ddot(k,g(1,1),15,dgamma,1)
         else
            if(ihat.eq.2)then
c              $L sub {l,:} =
c              V sub {1,:} SIGMA sup {+}
c              ( U sup T Q sup T ) W $
               do 13 i1=1,n
                  o(l,i1)=0
   13          continue
               do 14 j=1,k
                  do 15 i1=1,nf
                     eta(i1)=0
   15             continue
                  do 16 i1=1,k
                     eta(i1)=e(i1,j)
   16             continue
                  call dqrsl(b,nf,nf,k,qraux,eta,eta,work,work,work,work
     +                 ,10000,info)
                  if(tol.lt.sigma(j))then
                     scale=1.d0/sigma(j)
                  else
                     scale=0.d0
                  end if
                  do 17 i1=1,nf
                     eta(i1)=eta(i1)*(scale*w(i1))
   17             continue
                  do 18 i=1,nf
                     o(l,psi(i))=o(l,psi(i))+g(1,j)*eta(i)
   18             continue
   14          continue
            end if
         end if
    4 continue
      return
      end

c called from lowesb() ... compute fit ..?..?...
c somewhat similar to ehg136
      subroutine ehg139(v,nvmax,nv,n,d,nf,f,x,pi,psi,y,rw,trl,kernel,k,
     +     dist,phi,eta,b,od,w,diagl,vval2,ncmax,vc,a,xi,lo,hi,c,
     +     rcond,sing,dd,tdeg,cdeg,lq,lf,setlf,s)
      logical setlf
      integer identi,d,dd,i,i2,i3,i5,i6,ii,ileaf,info,j,k,kernel,
     +     l,n,ncmax,nf,nleaf,nv,nvmax,od,sing,tdeg,vc
      integer lq(nvmax,nf),a(ncmax),c(vc,ncmax),cdeg(8),hi(ncmax),
     +     leaf(256),lo(ncmax),pi(n),psi(n)
      DOUBLE PRECISION f,i1,i4,i7,rcond,scale,term,tol,trl
      DOUBLE PRECISION lf(0:d,nvmax,nf),sigma(15),u(15,15),e(15,15),
     +     b(nf,k),diagl(n),dist(n),eta(nf),DGAMMA(15),q(8),qraux(15),
     +     rw(n),s(0:od,nv),v(nvmax,d),vval2(0:d,nv),w(nf),work(15),
     +     x(n,d),xi(ncmax),y(n),z(8)
      DOUBLE PRECISION phi(n)

      external ehg127,loesswarn,DQRSL,ehg137
      DOUBLE PRECISION ehg128
      external ehg128
      DOUBLE PRECISION DDOT
      external DDOT

c     V -> e
c     Identity -> identi
c     X -> b
c     l2fit with trace(L)
      if(k .gt. nf-1) call loesswarn(104)
      if(k .gt. 15)   call loesswarn(105)
      if(trl.ne.0)then
         do 3 i5=1,n
            diagl(i5)=0
    3    continue
         do 4 i6=1,nv
            do 5 i5=0,d
               vval2(i5,i6)=0
    5       continue
    4    continue
      end if
      do 6 identi=1,n
         psi(identi)=identi
    6 continue
      do 7 l=1,nv
         do 8 i5=1,d
            q(i5)=v(l,i5)
    8    continue
         call ehg127(q,n,d,nf,f,x,psi,y,rw,kernel,k,dist,eta,b,od,w,
     +        rcond,sing,sigma,u,e,DGAMMA,qraux,work,tol,dd,tdeg,cdeg,
     +        s(0,l))
         if(trl.ne.0)then
c           invert $psi$
            do 9 i5=1,n
               phi(i5)=0
    9       continue
            do 10 i=1,nf
               phi(psi(i))=i
   10       continue
            do 11 i5=1,d
               z(i5)=v(l,i5)
   11       continue
            call ehg137(z,leaf,nleaf,d,ncmax,a,xi,
     +           lo,hi)
            do 12 ileaf=1,nleaf
               do 13 ii=lo(leaf(ileaf)),hi(leaf(ileaf))
                  i=int(phi(pi(ii)))
                  if(i.ne.0)then
                     if(.not.(psi(i).eq.pi(ii)))then
                        call loesswarn(194)
                     end if
                     do 14 i5=1,nf
                        eta(i5)=0
   14                continue
                     eta(i)=w(i)
c                    $eta = Q sup T W e sub i$
                     call DQRSL(b,nf,nf,k,qraux,eta,work,eta,eta,work,
     +                    work,1000,info)
                     do 15 j=1,k
                        if(tol.lt.sigma(j))then
                           i4=DDOT(k,u(1,j),1,eta,1)/sigma(j)
                        else
                           i4=0.D0
                        end if
                       DGAMMA(j)=i4
   15                continue
                     do 16 j=1,d+1
c                       bug fix 2006-07-15 for k=1, od>1.   (thanks btyner@gmail.com)
                        if(j.le.k)then
                           vval2(j-1,l)=DDOT(k,e(j,1),15,DGAMMA,1)
                        else
                           vval2(j-1,l)=0.0d0
                        end if
   16                continue
                     do 17 i5=1,d
                        z(i5)=x(pi(ii),i5)
   17                continue
                     term=ehg128(z,d,ncmax,vc,a,xi,lo,hi,c,v,nvmax,
     +                    vval2)
                     diagl(pi(ii))=diagl(pi(ii))+term
                     do 18 i5=0,d
                        vval2(i5,l)=0
   18                continue
                  end if
   13          continue
   12       continue
         end if
         if(setlf)then
c           $Lf sub {:,l,:} = V SIGMA sup {+} U sup T Q sup T W$
            if(.not.(k.ge.d+1))then
               call loesswarn(196)
            end if
            do 19 i5=1,nf
               lq(l,i5)=psi(i5)
   19       continue
            do 20 i6=1,nf
               do 21 i5=0,d
                  lf(i5,l,i6)=0
   21          continue
   20       continue
            do 22 j=1,k
               do 23 i5=1,nf
                  eta(i5)=0
   23          continue
               do 24 i5=1,k
                  eta(i5)=u(i5,j)
   24          continue
               call DQRSL(b,nf,nf,k,qraux,eta,eta,work,work,work,work,
     +              10000,info)
               if(tol.lt.sigma(j))then
                  scale=1.D0/sigma(j)
               else
                  scale=0.D0
               end if
               do 25 i5=1,nf
                  eta(i5)=eta(i5)*(scale*w(i5))
   25          continue
               do 26 i=1,nf
                  i7=eta(i)
                  do 27 i5=0,d
                     if(i5.lt.k)then
                        lf(i5,l,i)=lf(i5,l,i)+e(1+i5,j)*i7
                     else
                        lf(i5,l,i)=0
                     end if
   27             continue
   26          continue
   22       continue
         end if
    7 continue
      if(trl.ne.0)then
         if(n.le.0)then
            trl=0.D0
         else
            i3=n
            i1=diagl(i3)
            do 28 i2=i3-1,1,-1
               i1=diagl(i2)+i1
   28       continue
            trl=i1
         end if
      end if
      return
      end

      subroutine lowesb(xx,yy,ww,diagl,infl,iv,wv)
      integer infl
      integer iv(*)
      DOUBLE PRECISION xx(*),yy(*),ww(*),diagl(*),wv(*)
c Var
      DOUBLE PRECISION trl
      logical setlf

      integer ifloor
      external ifloor
      external ehg131,loesswarn,ehg183

      if(.not.(iv(28).ne.173))then
         call loesswarn(174)
      end if
      if(iv(28).ne.172)then
         if(.not.(iv(28).eq.171))then
            call loesswarn(171)
         end if
      end if
      iv(28)=173
      if(infl.ne.0)then
         trl=1.D0
      else
         trl=0.D0
      end if
      setlf=(iv(27).ne.iv(25))
      call ehg131(xx,yy,ww,trl,diagl,iv(20),iv(29),iv(3),iv(2),iv(5),
     +     iv(17),iv(4),iv(6),iv(14),iv(19),wv(1),iv(iv(7)),iv(iv(8)),
     +     iv(iv(9)),iv(iv(10)),iv(iv(22)),iv(iv(27)),wv(iv(11)),
     +     iv(iv(23)),wv(iv(13)),wv(iv(12)),wv(iv(15)),wv(iv(16)),
     +     wv(iv(18)),ifloor(iv(3)*wv(2)),wv(3),wv(iv(26)),wv(iv(24)),
     +     wv(4),iv(30),iv(33),iv(32),iv(41),iv(iv(25)),wv(iv(34)),
     +     setlf)
      if(iv(14).lt.iv(6)+DBLE(iv(4))/2.D0)then
         call ehg183('k-d tree limited by memory; nvmax=',
     +        iv(14),1,1)
      else
         if(iv(17).lt.iv(5)+2)then
            call ehg183('k-d tree limited by memory. ncmax=',
     +           iv(17),1,1)
         end if
      end if
      return
      end

c lowesd() : Initialize iv(*) and v(1:4)
c ------     called only by loess_workspace()  in ./loessc.c
      subroutine lowesd(iv, liv,lv, v, d,n,f,ideg,nf,nvmax, setlf)
      integer               liv,lv,    d,n,  ideg,nf,nvmax, setlf
c           setlf if(true) need  L [nf x nvmax] matrices
      integer iv(liv)
      double precision f, v(lv)

c  had  nf = min(n,ifloor(n*f))

      integer bound,i,i1,i2,j,ncmax,vc
      external loesswarn
      integer ifloor
      external ifloor
c
c     unnecessary initialization of i1 to keep g77 -Wall happy
c
      i1 = 0
cc    version -> versio
c     if(.not.(versio.eq.106))then
c        call loesswarn(100)
c     end if
      iv(28)=171
      iv(2)=d
      iv(3)=n
      vc=2**d
      iv(4)=vc
      if(.not.(0.lt.f))then
         call loesswarn(120)
      end if

      iv(19)=nf
      iv(20)=1
      if(ideg.eq.0)then
         i1=1
      else
         if(ideg.eq.1)then
            i1=d+1
         else
            if(ideg.eq.2)then
               i1=int(dble((d+2)*(d+1))/2.d0)
            end if
         end if
      end if
      iv(29)=i1
      iv(21)=1
      iv(14)=nvmax
      ncmax=nvmax
      iv(17)=ncmax
      iv(30)=0
      iv(32)=ideg
      if(.not.(ideg.ge.0))then
         call loesswarn(195)
      end if
      if(.not.(ideg.le.2))then
         call loesswarn(195)
      end if
      iv(33)=d
      do 3 i2=41,49
         iv(i2)=ideg
    3 continue
      iv(7)=50
      iv(8)=iv(7)+ncmax
      iv(9)=iv(8)+vc*ncmax
      iv(10)=iv(9)+ncmax
      iv(22)=iv(10)+ncmax
c     initialize permutation
      j=iv(22)-1
      do 4 i=1,n
         iv(j+i)=i
    4 continue
      iv(23)=iv(22)+n
      iv(25)=iv(23)+nvmax
      if(setlf.ne.0)then
         iv(27)=iv(25)+nvmax*nf
      else
         iv(27)=iv(25)
      end if
      bound=iv(27)+n
      if(.not.(bound-1.le.liv))then
         call loesswarn(102)
      end if
      iv(11)=50
      iv(13)=iv(11)+nvmax*d
      iv(12)=iv(13)+(d+1)*nvmax
      iv(15)=iv(12)+ncmax
      iv(16)=iv(15)+n
      iv(18)=iv(16)+nf
      iv(24)=iv(18)+iv(29)*nf
      iv(34)=iv(24)+(d+1)*nvmax
      if(setlf.ne.0)then
         iv(26)=iv(34)+(d+1)*nvmax*nf
      else
         iv(26)=iv(34)
      end if
      bound=iv(26)+nf
      if(.not.(bound-1.le.lv))then
         call loesswarn(103)
      end if
      v(1)=f
      v(2)=0.05d0
      v(3)=0.d0
      v(4)=1.d0
      return
      end

      subroutine lowese(iv,wv,m,z,s)
      integer m
      integer iv(*)
      double precision s(m),wv(*),z(m,1)

      external ehg133,loesswarn

      if(.not.(iv(28).ne.172))then
         call loesswarn(172)
      end if
      if(.not.(iv(28).eq.173))then
         call loesswarn(173)
      end if
      call ehg133(iv(2),iv(4),iv(14),iv(17),iv(iv(7)),iv(iv(
     +8)),iv(iv(9)),iv(iv(10)),wv(iv(11)),wv(iv(13)),wv(iv(12)),m,z,s)
      return
      end

c "direct" (non-"interpolate") fit aka predict() :
      subroutine lowesf(xx,yy,ww,iv,wv,m,z,l,ihat,s)
      integer m,ihat
c     m = number of x values at which to evaluate
      integer iv(*)
      double precision xx(*),yy(*),ww(*),wv(*),z(m,1),l(m,*),s(m)

      logical i1

      external loesswarn,ehg136
      if(171.le.iv(28))then
         i1=(iv(28).le.174)
      else
         i1=.false.
      end if
      if(.not.i1)then
         call loesswarn(171)
      end if
      iv(28)=172
      if(.not.(iv(14).ge.iv(19)))then
         call loesswarn(186)
      end if

c do the work; in ehg136()  give the argument names as they are there:
c          ehg136(u,lm,m, n,    d,    nf,   f,   x,   psi,     y ,rw,
      call ehg136(z,m,m,iv(3),iv(2),iv(19),wv(1),xx,iv(iv(22)),yy,ww,
c          kernel,  k,     dist,       eta,       b,     od,o,ihat,
     +     iv(20),iv(29),wv(iv(15)),wv(iv(16)),wv(iv(18)),0,l,ihat,
c              w,     rcond,sing,    dd,    tdeg,cdeg,  s)
     +     wv(iv(26)),wv(4),iv(30),iv(33),iv(32),iv(41),s)
      return
      end

c Called either from loess_raw() only for case [surf_stat = "interpolate/exact"], or
c               from loess_ise() {used only when 'se = TRUE' and surface = "interpolate"}
      subroutine lowesl(iv,wv,m,z,l,cache,inv)
      integer m,cache
      integer iv(*),inv(*)
      double precision l(m,*), wv(*), z(m,1)

      external loesswarn,ehg191

      if(.not.(iv(28).ne.172))then
         call loesswarn(172)
      end if
      if(.not.(iv(28).eq.173))then
         call loesswarn(173)
      end if
      if(.not.(iv(26).ne.iv(34)))then
         call loesswarn(175)
      end if
      call ehg191(m,z,l,iv(2),iv(3),iv(19),iv(6),iv(17),iv(4),iv(iv(7)),
     +     wv(iv(12)),iv(iv(10)),iv(iv(9)),iv(iv(8)),wv(iv(11)),iv(14),
     +     wv(iv(24)),wv(iv(34)),iv(iv(25)),cache,inv)
      return
      end

c  Not used
      subroutine lowesr(yy,iv,wv)
      integer iv(*)
      DOUBLE PRECISION yy(*),wv(*)

      external loesswarn,ehg192
      if(.not.(iv(28).ne.172))then
         call loesswarn(172)
      end if
      if(.not.(iv(28).eq.173))then
         call loesswarn(173)
      end if
      call ehg192(yy,iv(2),iv(3),iv(19),iv(6),iv(14),wv(iv(13)),
     +     wv(iv(34)),iv(iv(25)))
      return
      end

c Update Robustness Weights -- called via .Fortran() from R's simpleLoess() in ../R/loess.R
c
      subroutine lowesw(res,n,rw,pi)
c Tranliterated from Devlin's ratfor

c     implicit none
c Args
      integer n
      double precision res(n), rw(n)
      integer pi(n)
c Var
      integer identi,i,i1,nh
      double precision cmad,rsmall

      integer ifloor
      double precision d1mach

      external ehg106
      external ifloor
      external d1mach

c     Identity -> identi

c     find median of absolute residuals
      do 3 i1=1,n
         rw(i1)=dabs(res(i1))
    3 continue
      do 4 identi=1,n
         pi(identi)=identi
    4 continue
      nh=ifloor(dble(n)/2.d0)+1
c     partial sort to find 6*mad
      call ehg106(1,n,nh,1,rw,pi,n)
      if((n-nh)+1.lt.nh)then
         call ehg106(1,nh-1,nh-1,1,rw,pi,n)
         cmad=3*(rw(pi(nh))+rw(pi(nh-1)))
      else
         cmad=6*rw(pi(nh))
      end if
      rsmall=d1mach(1)
      if(cmad.lt.rsmall)then
         do 5 i1=1,n
            rw(i1)=1
    5    continue
      else
         do 6 i=1,n
            if(cmad*0.999d0.lt.rw(i))then
               rw(i)=0
            else
               if(cmad*0.001d0.lt.rw(i))then
                  rw(i)=(1-(rw(i)/cmad)**2)**2
               else
                  rw(i)=1
               end if
            end if
    6    continue
      end if
      return
      end

c Compute Pseudovalues -- called via .Fortran() from R's simpleLoess() in ../R/loess.R
c                         in the case of robustness iterations
      subroutine lowesp(n,y,yhat,pwgts,rwgts,pi,ytilde)
      integer n
      integer pi(n)
      double precision y(n),yhat(n),pwgts(n),rwgts(n),ytilde(n)
c Var
      double precision c,i1,i4,mad
      integer i2,i3,i,m

      external ehg106
      integer ifloor
      external ifloor
c     median absolute deviation (using partial sort):
      do 3 i=1,n
         ytilde(i)=dabs(y(i)-yhat(i))*dsqrt(pwgts(i))
         pi(i) = i
    3 continue
      m=ifloor(dble(n)/2.d0)+1
      call ehg106(1,n,m,1,ytilde,pi,n)
      if((n-m)+1.lt.m)then
         call ehg106(1,m-1,m-1,1,ytilde,pi,n)
         mad=(ytilde(pi(m-1))+ytilde(pi(m)))/2
      else
         mad=ytilde(pi(m))
      end if
c     magic constant
      c=(6*mad)**2/5
      do 5 i=1,n
         ytilde(i)= 1 - ((y(i)-yhat(i))**2 * pwgts(i))/c
    5 continue
      do 6 i=1,n
         ytilde(i)=ytilde(i)*dsqrt(rwgts(i))
    6 continue
      if(n.le.0)then
         i4=0.d0
      else
         i3=n
         i1=ytilde(i3)
         do 7 i2=i3-1,1,-1
            i1=ytilde(i2)+i1
    7    continue
         i4=i1
      end if
      c=n/i4
c     pseudovalues
      do 8 i=1,n
         ytilde(i)=yhat(i) + (c*rwgts(i))*(y(i)-yhat(i))
    8 continue
      return
      end

      subroutine ehg124(ll,uu,d,n,nv,nc,ncmax,vc,x,pi,a,xi,lo,hi,c,v,
     +     vhit,nvmax,fc,fd,dd)

      integer ll,uu,d,n,nv,nc,ncmax,vc,nvmax,fc,dd
      integer a(ncmax),c(vc,ncmax),hi(ncmax),lo(ncmax),pi(n),vhit(nvmax)
      DOUBLE PRECISION fd, v(nvmax,d),x(n,d),xi(ncmax)

      logical i1,i2,leaf
      integer i4,inorm2,k,l,m,p,u, upper, lower, check, offset
      DOUBLE PRECISION diam,diag(8),sigma(8)

      external ehg125,ehg106,ehg129
      integer IDAMAX
      external IDAMAX
      p=1
      l=ll
      u=uu
      lo(p)=l
      hi(p)=u
c     top of while loop
    3 if(.not.(p.le.nc))goto 4
         do 5 i4=1,dd
            diag(i4)=v(c(vc,p),i4)-v(c(1,p),i4)
    5    continue
         diam=0
         do 6 inorm2=1,dd
            diam=diam+diag(inorm2)**2
    6    continue
         diam=DSQRT(diam)
         if((u-l)+1.le.fc)then
            i1=.true.
         else
            i1=(diam.le.fd)
         end if
         if(i1)then
            leaf=.true.
         else
            if(ncmax.lt.nc+2)then
               i2=.true.
            else
               i2=(nvmax.lt.nv+DBLE(vc)/2.D0)
            end if
            leaf=i2
         end if
         if(.not.leaf)then
            call ehg129(l,u,dd,x,pi,n,sigma)
            k=IDAMAX(dd,sigma,1)
            m=int(DBLE(l+u)/2.D0)
            call ehg106(l,u,m,1,x(1,k),pi,n)

c           all ties go with hi son
c           top of while loop
c     bug fix from btyner@gmail.com 2006-07-20
            offset = 0
 7          if(((m+offset).ge.u).or.((m+offset).lt.l))goto 8
            if(offset .lt. 0)then
               lower = l
               check = m + offset
               upper = check
            else
               lower = m + offset + 1
               check = lower
               upper = u
            end if
            call ehg106(lower,upper,check,1,x(1,k),pi,n)
            if(x(pi(m + offset),k).eq.x(pi(m+offset+1),k))then
               offset = -offset
               if(offset .ge. 0) then
                  offset = offset + 1
               end if
               goto 7
            else
               m = m + offset
               goto 8
            end if

c           bottom of while loop
    8       if(v(c(1,p),k).eq.x(pi(m),k))then
               leaf=.true.
            else
               leaf=(v(c(vc,p),k).eq.x(pi(m),k))
            end if
         end if
         if(leaf)then
            a(p)=0
         else
            a(p)=k
            xi(p)=x(pi(m),k)
c           left son
            nc=nc+1
            lo(p)=nc
            lo(nc)=l
            hi(nc)=m
c           right son
            nc=nc+1
            hi(p)=nc
            lo(nc)=m+1
            hi(nc)=u
            call ehg125(p,nv,v,vhit,nvmax,d,k,xi(p),2**(k-1),2**(d-k),
     +                  c(1,p),c(1,lo(p)),c(1,hi(p)))
         end if
         p=p+1
         l=lo(p)
         u=hi(p)
         goto 3
c     bottom of while loop
    4 return
      end

      subroutine ehg129(l,u,d,x,pi,n,sigma)
      integer d,execnt,i,k,l,n,u
      integer pi(n)
      DOUBLE PRECISION machin,alpha,beta,t
      DOUBLE PRECISION sigma(d),x(n,d)
      DOUBLE PRECISION D1MACH
      external D1MACH
      save machin,execnt
      data execnt /0/
c     MachInf -> machin
      execnt=execnt+1
      if(execnt.eq.1)then
c     initialize  d1mach(2) === DBL_MAX:
         machin=D1MACH(2)
      end if
      do 3 k=1,d
         alpha=machin
         beta=-machin
         do 4 i=l,u
            t=x(pi(i),k)
            alpha=min(alpha,x(pi(i),k))
            beta=max(beta,t)
    4    continue
         sigma(k)=beta-alpha
    3 continue
      return
      end

c {called only from ehg127}  purpose...?...
      subroutine ehg137(z,leaf,nleaf,d,ncmax,a,xi,lo,hi)
      integer d,nleaf,ncmax
      integer leaf(256),a(ncmax),hi(ncmax),lo(ncmax),pstack(20)
      DOUBLE PRECISION z(d),xi(ncmax)

      integer p,stackt

      external loesswarn
c     stacktop -> stackt
c     find leaf cells affected by $z$
      stackt=0
      p=1
      nleaf=0
c     top of while loop
    3 if(.not.(0.lt.p))goto 4
         if(a(p).eq.0)then
c           leaf
            nleaf=nleaf+1
            leaf(nleaf)=p
c           Pop
            if(stackt.ge.1)then
               p=pstack(stackt)
            else
               p=0
            end if
            stackt=max(0,stackt-1)
         else
            if(z(a(p)).eq.xi(p))then
c              Push
               stackt=stackt+1
               if(.not.(stackt.le.20))then
                  call loesswarn(187)
               end if
               pstack(stackt)=hi(p)
               p=lo(p)
            else
               if(z(a(p)).le.xi(p))then
                  p=lo(p)
               else
                  p=hi(p)
               end if
            end if
         end if
         goto 3
c     bottom of while loop
    4 if(.not.(nleaf.le.256))then
         call loesswarn(185)
      end if
      return
      end

C-- For Error messaging, call the "a" routines at the bottom of  ./loessc.c  :
      subroutine ehg183(s, i, n, inc)
      character s*(*)
      integer i, n, inc
      call ehg183a(s, len(s), i, n, inc)
      end

      subroutine ehg184(s, x, n, inc)
      character s*(*)
      double precision x
      integer n, inc
      call ehg184a(s, len(s), x, n, inc)
      end

      DOUBLE PRECISION function ehg128dep(z,d,ncmax,vc,a,xi,lo,hi,c,
     +     v,
     +     nvmax,vval)

c     implicit none
c Args
      integer d,ncmax,nvmax,vc
      integer a(ncmax),c(vc,ncmax),hi(ncmax),lo(ncmax)
      DOUBLE PRECISION z(d),xi(ncmax),v(nvmax,d), vval(0:d,nvmax)
c Vars
      logical i2,i3,i4,i5,i6,i7,i8,i9,i10
      integer i,i1,i11,i12,ig,ii,j,lg,ll,m,nt,ur
      integer t(20)
      DOUBLE PRECISION ge,gn,gs,gw,gpe,gpn,gps,gpw,h,phi0,phi1,
     +     psi0,psi1,s,sew,sns,v0,v1,xibar
      DOUBLE PRECISION g(0:8,256),g0(0:8),g1(0:8)

      double precision fdepread
      external fdepread,fdepbegin
      external fdepwarn
      call fdepbegin()
c     locate enclosing cell
      nt=1
      t(nt)=1
      j=1
c     top of while loop
    3 if(.not.(a(j).ne.0))goto 4
         nt=nt+1
         if(z(a(j)).le.xi(j))then
            i1=lo(j)
         else
            i1=hi(j)
         end if
         t(nt)=i1
         if(.not.(nt.lt.20))then
            call fdepwarn()
         end if
         j=t(nt)
         goto 3
c     bottom of while loop
    4 continue
c     tensor
      do 5 i12=1,vc
         do 6 i11=0,d
            g(i11,i12)=fdepread(vval(i11,c(i12,j)),
     +                         c(i12,j))
    6    continue
    5 continue
      lg=vc
      ll=c(1,j)
      ur=c(vc,j)
      do 7 i=d,1,-1
         h=(z(i)-v(ll,i))/(v(ur,i)-v(ll,i))
         if(h.lt.-.001D0)then
            call fdepwarn()
            call fdepwarn()
         else
            if(1.001D0.lt.h)then
               call fdepwarn()
               call fdepwarn()
            end if
         end if
         if(-.001D0.le.h)then
            i2=(h.le.1.001D0)
         else
            i2=.false.
         end if
         if(.not.i2)then
            call fdepwarn()
         end if
         lg=int(DBLE(lg)/2.D0)
         do 8 ig=1,lg
c           Hermite basis
            phi0=(1-h)**2*(1+2*h)
            phi1=h**2*(3-2*h)
            psi0=h*(1-h)**2
            psi1=h**2*(h-1)
            g(0,ig)=phi0*g(0,ig) + phi1*g(0,ig+lg) +
     +           (psi0*g(i,ig)+psi1*g(i,ig+lg)) * (v(ur,i)-v(ll,i))
            do 9 ii=1,i-1
               g(ii,ig)=phi0*g(ii,ig)+phi1*g(ii,ig+lg)
    9       continue
    8    continue
    7 continue
      s=g(0,1)
c     blending
      if(d.eq.2)then
c        ----- North -----
         v0=v(ll,1)
         v1=v(ur,1)
         do 10 i11=0,d
            g0(i11)=fdepread(vval(i11,c(3,j)),
     +                         c(3,j))
   10    continue
         do 11 i11=0,d
            g1(i11)=fdepread(vval(i11,c(4,j)),
     +                         c(4,j))
   11    continue
         xibar=v(ur,2)
         m=nt-1
c        top of while loop
   12    if(m.eq.0)then
            i4=.true.
         else
            if(a(t(m)).eq.2)then
               i3=(xi(t(m)).eq.xibar)
            else
               i3=.false.
            end if
            i4=i3
         end if
         if(.not.(.not.i4))goto 13
            m=m-1
c           voidp junk
            goto 12
c        bottom of while loop
   13    if(m.ge.1)then
            m=hi(t(m))
c           top of while loop
   14       if(.not.(a(m).ne.0))goto 15
               if(z(a(m)).le.xi(m))then
                  m=lo(m)
               else
                  m=hi(m)
               end if
               goto 14
c           bottom of while loop
   15       if(v0.lt.v(c(1,m),1))then
               v0=v(c(1,m),1)
               do 16 i11=0,d
                  g0(i11)=fdepread(vval(i11,c(1,m)),
     +                         c(1,m))
   16          continue
            end if
            if(v(c(2,m),1).lt.v1)then
               v1=v(c(2,m),1)
               do 17 i11=0,d
                  g1(i11)=fdepread(vval(i11,c(2,m)),
     +                         c(2,m))
   17          continue
            end if
         end if
         h=(z(1)-v0)/(v1-v0)
c        Hermite basis
         phi0=(1-h)**2*(1+2*h)
         phi1=h**2*(3-2*h)
         psi0=h*(1-h)**2
         psi1=h**2*(h-1)
         gn=phi0*g0(0)+phi1*g1(0)+(psi0*g0(1)+psi1*g1(1))*(v1-v0)
         gpn=phi0*g0(2)+phi1*g1(2)
c        ----- South -----
         v0=v(ll,1)
         v1=v(ur,1)
         do 18 i11=0,d
            g0(i11)=fdepread(vval(i11,c(1,j)),
     +                         c(1,j))
   18    continue
         do 19 i11=0,d
            g1(i11)=fdepread(vval(i11,c(2,j)),
     +                         c(2,j))
   19    continue
         xibar=v(ll,2)
         m=nt-1
c        top of while loop
   20    if(m.eq.0)then
            i6=.true.
         else
            if(a(t(m)).eq.2)then
               i5=(xi(t(m)).eq.xibar)
            else
               i5=.false.
            end if
            i6=i5
         end if
         if(.not.(.not.i6))goto 21
            m=m-1
c           voidp junk
            goto 20
c        bottom of while loop
   21    if(m.ge.1)then
            m=lo(t(m))
c           top of while loop
   22       if(.not.(a(m).ne.0))goto 23
               if(z(a(m)).le.xi(m))then
                  m=lo(m)
               else
                  m=hi(m)
               end if
               goto 22
c           bottom of while loop
   23       if(v0.lt.v(c(3,m),1))then
               v0=v(c(3,m),1)
               do 24 i11=0,d
                  g0(i11)=fdepread(vval(i11,c(3,m)),
     +                         c(3,m))
   24          continue
            end if
            if(v(c(4,m),1).lt.v1)then
               v1=v(c(4,m),1)
               do 25 i11=0,d
                  g1(i11)=fdepread(vval(i11,c(4,m)),
     +                         c(4,m))
   25          continue
            end if
         end if
         h=(z(1)-v0)/(v1-v0)
c        Hermite basis
         phi0=(1-h)**2*(1+2*h)
         phi1=h**2*(3-2*h)
         psi0=h*(1-h)**2
         psi1=h**2*(h-1)
         gs=phi0*g0(0)+phi1*g1(0)+(psi0*g0(1)+psi1*g1(1))*(v1-v0)
         gps=phi0*g0(2)+phi1*g1(2)
c        ----- East -----
         v0=v(ll,2)
         v1=v(ur,2)
         do 26 i11=0,d
            g0(i11)=fdepread(vval(i11,c(2,j)),
     +                         c(2,j))
   26    continue
         do 27 i11=0,d
            g1(i11)=fdepread(vval(i11,c(4,j)),
     +                         c(4,j))
   27    continue
         xibar=v(ur,1)
         m=nt-1
c        top of while loop
   28    if(m.eq.0)then
            i8=.true.
         else
            if(a(t(m)).eq.1)then
               i7=(xi(t(m)).eq.xibar)
            else
               i7=.false.
            end if
            i8=i7
         end if
         if(.not.(.not.i8))goto 29
            m=m-1
c           voidp junk
            goto 28
c        bottom of while loop
   29    if(m.ge.1)then
            m=hi(t(m))
c           top of while loop
   30       if(.not.(a(m).ne.0))goto 31
               if(z(a(m)).le.xi(m))then
                  m=lo(m)
               else
                  m=hi(m)
               end if
               goto 30
c           bottom of while loop
   31       if(v0.lt.v(c(1,m),2))then
               v0=v(c(1,m),2)
               do 32 i11=0,d
                  g0(i11)=fdepread(vval(i11,c(1,m)),
     +                         c(1,m))
   32          continue
            end if
            if(v(c(3,m),2).lt.v1)then
               v1=v(c(3,m),2)
               do 33 i11=0,d
                  g1(i11)=fdepread(vval(i11,c(3,m)),
     +                         c(3,m))
   33          continue
            end if
         end if
         h=(z(2)-v0)/(v1-v0)
c        Hermite basis
         phi0=(1-h)**2*(1+2*h)
         phi1=h**2*(3-2*h)
         psi0=h*(1-h)**2
         psi1=h**2*(h-1)
         ge=phi0*g0(0)+phi1*g1(0)+(psi0*g0(2)+psi1*g1(2))*(v1-v0)
         gpe=phi0*g0(1)+phi1*g1(1)
c        ----- West -----
         v0=v(ll,2)
         v1=v(ur,2)
         do 34 i11=0,d
            g0(i11)=fdepread(vval(i11,c(1,j)),
     +                         c(1,j))
   34    continue
         do 35 i11=0,d
            g1(i11)=fdepread(vval(i11,c(3,j)),
     +                         c(3,j))
   35    continue
         xibar=v(ll,1)
         m=nt-1
c        top of while loop
   36    if(m.eq.0)then
            i10=.true.
         else
            if(a(t(m)).eq.1)then
               i9=(xi(t(m)).eq.xibar)
            else
               i9=.false.
            end if
            i10=i9
         end if
         if(.not.(.not.i10))goto 37
            m=m-1
c           voidp junk
            goto 36
c        bottom of while loop
   37    if(m.ge.1)then
            m=lo(t(m))
c           top of while loop
   38       if(.not.(a(m).ne.0))goto 39
               if(z(a(m)).le.xi(m))then
                  m=lo(m)
               else
                  m=hi(m)
               end if
               goto 38
c           bottom of while loop
   39       if(v0.lt.v(c(2,m),2))then
               v0=v(c(2,m),2)
               do 40 i11=0,d
                  g0(i11)=fdepread(vval(i11,c(2,m)),
     +                         c(2,m))
   40          continue
            end if
            if(v(c(4,m),2).lt.v1)then
               v1=v(c(4,m),2)
               do 41 i11=0,d
                  g1(i11)=fdepread(vval(i11,c(4,m)),
     +                         c(4,m))
   41          continue
            end if
         end if
         h=(z(2)-v0)/(v1-v0)
c        Hermite basis
         phi0=(1-h)**2*(1+2*h)
         phi1=h**2*(3-2*h)
         psi0=h*(1-h)**2
         psi1=h**2*(h-1)
         gw=phi0*g0(0)+phi1*g1(0)+(psi0*g0(2)+psi1*g1(2))*(v1-v0)
         gpw=phi0*g0(1)+phi1*g1(1)
c        NS
         h=(z(2)-v(ll,2))/(v(ur,2)-v(ll,2))
c        Hermite basis
         phi0=(1-h)**2*(1+2*h)
         phi1=h**2*(3-2*h)
         psi0=h*(1-h)**2
         psi1=h**2*(h-1)
         sns=phi0*gs+phi1*gn+(psi0*gps+psi1*gpn)*(v(ur,2)-v(ll,2))
c        EW
         h=(z(1)-v(ll,1))/(v(ur,1)-v(ll,1))
c        Hermite basis
         phi0=(1-h)**2*(1+2*h)
         phi1=h**2*(3-2*h)
         psi0=h*(1-h)**2
         psi1=h**2*(h-1)
         sew=phi0*gw+phi1*ge+(psi0*gpw+psi1*gpe)*(v(ur,1)-v(ll,1))
         s=(sns+sew)-s
      end if
      ehg128dep=s
      return
      end

      subroutine ehg130(x,n,d,nc,ncmax,vc,nv,nvmax,a,c,hi,lo,pi,v,
     +     vhit,xi,ntol,fd,dd)
      integer identi,d,dd,i1,j,n,nc,ncmax,ntol,nv,nvmax,vc
      integer a(ncmax),c(vc,ncmax),hi(ncmax),lo(ncmax),pi(n),
     +     vhit(nvmax)
      double precision fd,delta(8),v(nvmax,d),x(n,d),xi(ncmax)
      external ehg126,loesswarn,ehg124
      double precision dnrm2
      external dnrm2
      if(.not.(d.le.8))then
         call loesswarn(101)
      end if
c     build $k$-d tree
      call ehg126(d,n,vc,x,v,nvmax)
      nv=vc
      nc=1
      do 3 j=1,vc
         c(j,nc)=j
         vhit(j)=0
    3 continue
      do 4 i1=1,d
         delta(i1)=v(vc,i1)-v(1,i1)
    4 continue
      fd=fd*dnrm2(d,delta,1)
      do 5 identi=1,n
         pi(identi)=identi
    5 continue
      call ehg124(1,n,d,n,nv,nc,ncmax,vc,x,pi,a,xi,lo,hi,c,v,vhit,nvmax,
     +ntol,fd,dd)
      return
      end


      subroutine lowesv(xx,iv,wv)
      integer iv(*),ifloor
      double precision xx(*),wv(*)
      external ifloor,ehg130,loesswarn
      if(.not.(iv(28).ne.173))then
         call loesswarn(174)
      end if
      if(iv(28).ne.172)then
         if(.not.(iv(28).eq.171))then
            call loesswarn(171)
         end if
      end if
      iv(28)=173
      call ehg130(xx,iv(3),iv(2),iv(5),iv(17),iv(4),iv(6),iv(14),
     +     iv(iv(7)),iv(iv(8)),iv(iv(9)),iv(iv(10)),iv(iv(22)),
     +     wv(iv(11)),iv(iv(23)),wv(iv(12)),ifloor(iv(3)*wv(2)),
     +     wv(3),iv(33))
      return
      end



c D1 geometric plan: basis expressions are copied verbatim from ehg128.
c No combined linear weights: lowesgeval retains the original arithmetic tree.
      subroutine lowesgp(iv,wv,m,z,ids,basis,iwarn)
      integer iv(*),m,ids(2,m),iwarn(m)
      double precision wv(*),z(m),basis(5,m)
      external ehgplan
      call ehgplan(m,z,iv(14),iv(17),iv(iv(7)),iv(iv(8)),
     +     iv(iv(9)),iv(iv(10)),wv(iv(11)),wv(iv(12)),
     +     ids,basis,iwarn)
      return
      end

      subroutine ehgplan(m,z,nvmax,ncmax,a,c,hi,lo,v,xi,
     +     ids,basis,iwarn)
      integer m,nvmax,ncmax,a(ncmax),c(2,ncmax),hi(ncmax),
     +     lo(ncmax),ids(2,m),iwarn(m),i,j,nt,ll,ur
      double precision z(m),v(nvmax),xi(ncmax),basis(5,m),h,
     +     phi0,phi1,psi0,psi1
      do 1 i=1,m
         iwarn(i)=0
         nt=1
         j=1
    2    if(a(j).ne.0)then
            nt=nt+1
            if(z(i).le.xi(j))then
               j=lo(j)
            else
               j=hi(j)
            end if
            if(nt.ge.20)iwarn(i)=1
            goto 2
         end if
         ll=c(1,j)
         ur=c(2,j)
         ids(1,i)=ll
         ids(2,i)=ur
         h=(z(i)-v(ll))/(v(ur)-v(ll))
         if(.not.(-.001D0.le.h.and.h.le.1.001D0))iwarn(i)=1
         phi0=(1-h)**2*(1+2*h)
         phi1=h**2*(3-2*h)
         psi0=h*(1-h)**2
         psi1=h**2*(h-1)
         basis(1,i)=phi0
         basis(2,i)=phi1
         basis(3,i)=psi0
         basis(4,i)=psi1
         basis(5,i)=v(ur)-v(ll)
    1 continue
      return
      end

c Original ehg128 is the diagnostic authority, in original column/point order.
      subroutine lowesgwarn(iv,wv,z,zero)
      integer iv(*)
      double precision wv(*),z(*),zero(*),ignored,ehg128
      external ehg128
      ignored=ehg128(z,iv(2),iv(17),iv(4),iv(iv(7)),wv(iv(12)),
     +     iv(iv(10)),iv(iv(9)),iv(iv(8)),wv(iv(11)),iv(14),zero)
      return
      end


c Geometry plans for D=2..4 only. D1 has its independently checked plan.f.
c All stored constants are original scalar subexpressions, not final weights.
      subroutine lowesgnp(d,m,z,nvmax,ncmax,vc,a,c,hi,lo,v,xi,
     +     ids,basis,edgeids,edgebasis,diag)
      integer d,m,nvmax,ncmax,vc,a(ncmax),c(vc,ncmax),hi(ncmax),
     +     lo(ncmax),ids(vc,m),edgeids(2,4,m),diag(m),
     +     p,j,nt,t(20),child,ll,ur,i,k,q,e
      logical inside
      double precision z(m,d),v(nvmax,d),xi(ncmax),basis(5,d,m),
     +     edgebasis(5,4,m),h,phi0,phi1,psi0,psi1,zz(4)
      external lowesg2edge
      do 1 p=1,m
         diag(p)=0
         nt=1
         t(1)=1
         j=1
    2    if(a(j).ne.0)then
            nt=nt+1
            if(z(p,a(j)).le.xi(j))then
               child=lo(j)
            else
               child=hi(j)
            end if
            if(nt.le.20)t(nt)=child
            if(.not.(nt.lt.20))diag(p)=1
            j=child
            goto 2
         end if
         do 3 k=1,vc
            ids(k,p)=c(k,j)
    3    continue
         ll=c(1,j)
         ur=c(vc,j)
         if(diag(p).ne.0)goto 8
         do 4 i=d,1,-1
            h=(z(p,i)-v(ll,i))/(v(ur,i)-v(ll,i))
            if(-.001D0.le.h)then
               inside=(h.le.1.001D0)
            else
               inside=.false.
            end if
            if(.not.inside)then
               diag(p)=1
               goto 8
            end if
            phi0=(1-h)**2*(1+2*h)
            phi1=h**2*(3-2*h)
            psi0=h*(1-h)**2
            psi1=h**2*(h-1)
            basis(1,i,p)=phi0
            basis(2,i,p)=phi1
            basis(3,i,p)=psi0
            basis(4,i,p)=psi1
            basis(5,i,p)=v(ur,i)-v(ll,i)
    4    continue
         if(d.eq.2)then
            zz(1)=z(p,1)
            zz(2)=z(p,2)
            do 5 e=1,4
               call lowesg2edge(e,zz,j,ll,ur,nt,t,nvmax,ncmax,
     +              a,c,hi,lo,v,xi,edgeids(1,e,p),edgebasis(1,e,p))
    5       continue
         end if
         goto 1
    8    do 6 i=1,d
            do 7 q=1,5
               basis(q,i,p)=0.D0
    7       continue
    6    continue
    1 continue
      return
      end

c Original North/South/East/West geometry, parameterized in that order.
c Base corners: N=3,4 S=1,2 E=2,4 W=1,3.
c Neighbor replacement corners: N=1,2 S=3,4 E=1,3 W=2,4.
      subroutine lowesg2edge(e,z,j,ll,ur,nt,t,nvmax,ncmax,
     +     a,c,hi,lo,v,xi,ids,basis)
      integer e,j,ll,ur,nt,t(20),nvmax,ncmax,a(ncmax),
     +     c(4,ncmax),hi(ncmax),lo(ncmax),ids(2),
     +     initial0(4),initial1(4),next0(4),next1(4),
     +     axis,normal,m,node
      double precision z(2),v(nvmax,2),xi(ncmax),basis(5),
     +     v0,v1,xibar,h,phi0,phi1,psi0,psi1
      data initial0 /3,1,2,1/,initial1 /4,2,4,3/
      data next0 /1,3,1,2/,next1 /2,4,3,4/
      axis=1
      if(e.ge.3)axis=2
      normal=3-axis
      v0=v(ll,axis)
      v1=v(ur,axis)
      ids(1)=c(initial0(e),j)
      ids(2)=c(initial1(e),j)
      if(e.eq.1.or.e.eq.3)then
         xibar=v(ur,normal)
      else
         xibar=v(ll,normal)
      end if
      m=nt-1
    1 if(m.eq.0)goto 2
      if(a(t(m)).eq.normal)then
         if(xi(t(m)).eq.xibar)goto 2
      end if
      m=m-1
      goto 1
    2 if(m.ge.1)then
         if(e.eq.1.or.e.eq.3)then
            node=hi(t(m))
         else
            node=lo(t(m))
         end if
    3    if(a(node).ne.0)then
            if(z(a(node)).le.xi(node))then
               node=lo(node)
            else
               node=hi(node)
            end if
            goto 3
         end if
         if(v0.lt.v(c(next0(e),node),axis))then
            v0=v(c(next0(e),node),axis)
            ids(1)=c(next0(e),node)
         end if
         if(v(c(next1(e),node),axis).lt.v1)then
            v1=v(c(next1(e),node),axis)
            ids(2)=c(next1(e),node)
         end if
      end if
      h=(z(axis)-v0)/(v1-v0)
      phi0=(1-h)**2*(1+2*h)
      phi1=h**2*(3-2*h)
      psi0=h*(1-h)**2
      psi1=h**2*(h-1)
      basis(1)=phi0
      basis(2)=phi1
      basis(3)=psi0
      basis(4)=psi1
      basis(5)=v1-v0
      return
      end

c Same tensor reductions and D2 edge arithmetic tree as original ehg128.
c Flagged points retain the original evaluator, result and diagnostic order.
      subroutine lowesgne(d,m,z,nvmax,ncmax,vc,a,c,hi,lo,v,xi,
     +     ids,basis,edgeids,edgebasis,diag,vval,out)
      integer d,m,nvmax,ncmax,vc,a(ncmax),c(vc,ncmax),hi(ncmax),
     +     lo(ncmax),ids(vc,m),edgeids(2,4,m),diag(m),
     +     p,i,i11,i12,ig,ii,lg,e,axis,normal
      double precision z(m,d),v(nvmax,d),xi(ncmax),basis(5,d,m),
     +     edgebasis(5,4,m),vval(0:d,nvmax),out(m),
     +     g(0:8,256),g0(0:8),g1(0:8),zz(4),
     +     edgevalue(4),edgenormal(4),phi0,phi1,psi0,psi1,width,
     +     s,gn,gs,ge,gw,gpn,gps,gpe,gpw,sns,sew,ehg128
      external ehg128
      do 1 p=1,m
         if(diag(p).ne.0)then
            do 2 i=1,d
               zz(i)=z(p,i)
    2       continue
            out(p)=ehg128(zz,d,ncmax,vc,a,xi,lo,hi,c,v,nvmax,vval)
         else
            do 3 i12=1,vc
               do 4 i11=0,d
                  g(i11,i12)=vval(i11,ids(i12,p))
    4          continue
    3       continue
            lg=vc
            do 5 i=d,1,-1
               phi0=basis(1,i,p)
               phi1=basis(2,i,p)
               psi0=basis(3,i,p)
               psi1=basis(4,i,p)
               width=basis(5,i,p)
               lg=int(DBLE(lg)/2.D0)
               do 6 ig=1,lg
                  g(0,ig)=phi0*g(0,ig) + phi1*g(0,ig+lg) +
     +                 (psi0*g(i,ig)+psi1*g(i,ig+lg)) * width
                  do 7 ii=1,i-1
                     g(ii,ig)=phi0*g(ii,ig)+phi1*g(ii,ig+lg)
    7             continue
    6          continue
    5       continue
            s=g(0,1)
            if(d.eq.2)then
               do 8 e=1,4
                  do 9 i11=0,d
                     g0(i11)=vval(i11,edgeids(1,e,p))
                     g1(i11)=vval(i11,edgeids(2,e,p))
    9             continue
                  phi0=edgebasis(1,e,p)
                  phi1=edgebasis(2,e,p)
                  psi0=edgebasis(3,e,p)
                  psi1=edgebasis(4,e,p)
                  width=edgebasis(5,e,p)
                  axis=1
                  if(e.ge.3)axis=2
                  normal=3-axis
                  edgevalue(e)=phi0*g0(0)+phi1*g1(0)+
     +                 (psi0*g0(axis)+psi1*g1(axis))*width
                  edgenormal(e)=phi0*g0(normal)+phi1*g1(normal)
    8          continue
               gn=edgevalue(1)
               gs=edgevalue(2)
               ge=edgevalue(3)
               gw=edgevalue(4)
               gpn=edgenormal(1)
               gps=edgenormal(2)
               gpe=edgenormal(3)
               gpw=edgenormal(4)
               phi0=basis(1,2,p)
               phi1=basis(2,2,p)
               psi0=basis(3,2,p)
               psi1=basis(4,2,p)
               width=basis(5,2,p)
               sns=phi0*gs+phi1*gn+(psi0*gps+psi1*gpn)*width
               phi0=basis(1,1,p)
               phi1=basis(2,1,p)
               psi0=basis(3,1,p)
               psi1=basis(4,1,p)
               width=basis(5,1,p)
               sew=phi0*gw+phi1*ge+(psi0*gpw+psi1*gpe)*width
               s=(sns+sew)-s
            end if
            out(p)=s
         end if
    1 continue
      return
      end

c Compact production: all original vertex/psi/QR diagnostics are retained.
c Q*U projections are formed only for the actual interpolation read union.
      subroutine lowesfp(xx,ww,iv,wv,k,rs,rec,first,which,
     +     keepof,kept)
      integer iv(*),k,rs,first(k,*),which(*),keepof(*),i,j,l,ll,
     +     n,nf,nv,nvmax,d,sing,info,sv,iqt,iq,ipt,iu,ie,isc,irho,
     +     slot,id,comp
      double precision xx(*),ww(*),wv(*),rec(rs,*),q(8),
     +     kept(0:iv(2),iv(3),*),term,
     +     sigma(15),u(15,15),e(15,15),qraux(15),
     +     work(15),norms(15),alphas(15),qrt(15,15),
     +     proj(15,15),scales(15),tol,rho
      external fhg127,dqrslx,loesswarn,ehg183
      n=iv(3)
      d=iv(2)
      nf=iv(19)
      nv=iv(6)
      nvmax=iv(14)
      if(iv(29).gt.nf-1)call loesswarn(104)
      if(iv(29).gt.15)call loesswarn(105)
      do 1 i=1,n
         iv(iv(27)+i-1)=i
    1 continue
      sing=0
      iqt=2*k
      iq=2*k+k*k
      ipt=3*k+k*k
      iu=3*k+2*k*k
      ie=3*k+3*k*k
      isc=(d+4)*k+3*k*k
      irho=(d+5)*k+3*k*k+1
      do 2 l=1,nv
         do 9 j=1,d
            q(j)=wv(iv(11)+l-1+(j-1)*nvmax)
    9    continue
         call fhg127(q,n,d,nf,wv(1),xx,iv(iv(27)),ww,
     +        iv(20),k,wv(iv(15)),wv(iv(18)),wv(iv(26)),wv(4),
     +        sing,sigma,u,e,qraux,work,tol,iv(33),iv(32),iv(41),
     +        norms,alphas,qrt,.true.)
         if(k.lt.d+1)call loesswarn(196)
         ll=which(l)
         if(ll.eq.0)goto 2
         do 3 sv=1,k
            do 4 i=1,nf
               wv(iv(16)+i-1)=0.D0
    4       continue
            do 5 i=1,k
               wv(iv(16)+i-1)=u(i,sv)
    5       continue
            call dqrslx(wv(iv(18)),nf,nf,k,qraux,wv(iv(16)),
     +           wv(iv(16)),work,work,work,work,10000,info,proj(1,sv))
            if(tol.lt.sigma(sv))then
               scales(sv)=1.D0/sigma(sv)
            else
               scales(sv)=0.D0
            end if
            slot=keepof(l)
            if(slot.gt.0)then
c Original setlf arithmetic, singular component then neighborhood row.
               do 10 i=1,nf
                  wv(iv(16)+i-1)=wv(iv(16)+i-1)*
     +                 (scales(sv)*wv(iv(26)+i-1))
   10          continue
               do 11 i=1,nf
                  id=iv(iv(27)+i-1)
                  term=wv(iv(16)+i-1)
                  do 12 comp=0,d
                     if(comp.lt.k)then
                        kept(comp,id,slot)=kept(comp,id,slot)+
     +                       e(1+comp,sv)*term
                     else
                        kept(comp,id,slot)=0.D0
                     end if
   12             continue
   11          continue
            end if
    3    continue
         rho=wv(iv(15)+iv(iv(27)+nf-1)-1)*max(1.D0,wv(1))
         rec(irho,ll)=rho
         do 6 i=1,k
            rec(i,ll)=norms(i)
            rec(k+i,ll)=alphas(i)
            rec(iq+i,ll)=qraux(i)
            rec(isc+i,ll)=scales(i)
            first(i,ll)=iv(iv(27)+i-1)
            do 7 j=1,k
               rec(iqt+i+k*(j-1),ll)=qrt(i,j)
               rec(ipt+i+k*(j-1),ll)=proj(i,j)
               rec(iu+i+k*(j-1),ll)=u(i,j)
    7       continue
            do 8 j=1,d+1
               rec(ie+j+(d+1)*(i-1),ll)=0.D0
               if(j.le.k)rec(ie+j+(d+1)*(i-1),ll)=e(j,i)
    8       continue
    6    continue
    2 continue
      iv(30)=sing
      if(iv(14).lt.iv(6)+DBLE(iv(4))/2.D0)then
         call ehg183('k-d tree limited by memory; nvmax=',iv(14),1,1)
      else if(iv(17).lt.iv(5)+2)then
         call ehg183('k-d tree limited by memory. ncmax=',iv(17),1,1)
      end if
      return
      end

c Pack independent ordinary rows before the original first-k special rows.
c Each reflector updates contiguous ordinary rows at its innermost loop;
c special rows retain exact rank-based skips, never additions of zero.
      subroutine lowesfb(iv,wv,x,rw,k,rs,rec,first,j0,nb,coef,which,
     +     keepof,kept,exceptional)
      integer exceptional(*)
      integer iv(*),k,rs,first(k,*),which(*),keepof(*),id,j0,nb,
     +     jb,l,ll,nv,slot,rank,i,j,jj,h,sv,comp,iqt,iq,ipt,iu,ie,
     +     isc,irho,ju,d,n,col,nt,ns,na,b,map(nb),special(nb),ranks(nb)
      double precision wv(*),x(*),rw(*),rec(rs,*),
     +     kept(0:iv(2),iv(3),*),
     +     coef(0:iv(2),iv(14),nb),q(8),disti,rho,w,
     +     feature(nb,k),house(nb,k),value(nb),eta(nb),weight(nb),
     +     lf(nb,0:iv(2)),t,i5,i6,i7,i8
      nv=iv(6)
      d=iv(2)
      n=iv(3)
      iqt=2*k
      iq=2*k+k*k
      ipt=3*k+k*k
      iu=3*k+2*k*k
      ie=3*k+3*k*k
      isc=(d+4)*k+3*k*k
      irho=(d+5)*k+3*k*k+1
      ju=min(k,iv(19)-1)
      do 1 l=1,nv
         ll=which(l)
         if(ll.eq.0)goto 1
         slot=keepof(l)
         if(slot.gt.0)then
            do 37 jb=1,nb
               do 38 comp=0,d
                  coef(comp,l,jb)=kept(comp,j0+jb-1,slot)
   38          continue
   37       continue
            goto 1
         end if
         if(exceptional(l).ne.0)goto 1
         do 2 j=1,d
            q(j)=wv(iv(11)+l-1+(j-1)*iv(14))
    2    continue
         rho=rec(irho,ll)
c Rank lookup is integer metadata shared by all rows in this block.
c Ascending i preserves the original last-match rule, including duplicates.
         do 35 jb=1,nb
            ranks(jb)=k+1
   35    continue
         do 36 i=1,k
            id=first(i,ll)-j0+1
            if(id.ge.1.and.id.le.nb)ranks(id)=i
   36    continue
         nt=0
         ns=0
         do 3 jb=1,nb
            id=j0+jb-1
            do 4 comp=0,d
               coef(comp,l,jb)=0.D0
    4       continue
            disti=0.D0
            do 5 j=1,iv(33)
               disti=disti+(x(id+(j-1)*n)-q(j))**2
    5       continue
            rank=ranks(jb)
            if(.not.(disti.lt.rho.or.rank.le.k))goto 3
            w=dsqrt(disti/rho)
            weight(jb)=dsqrt(rw(id)*(1-w**3)**3)
            if(rank.gt.k)then
               nt=nt+1
               map(nt)=jb
            else
               ns=ns+1
               special(ns)=jb
            end if
    3    continue
         na=nt+ns
         do 7 b=1,ns
            map(nt+b)=special(b)
    7    continue
         do 8 b=1,na
            jb=map(b)
            id=j0+jb-1
            w=weight(jb)
            do 9 comp=0,d
               lf(b,comp)=0.D0
    9       continue
            col=1
            feature(b,1)=w
            if(iv(32).ge.1)then
               do 10 j=1,d
                  if(iv(40+j).ge.1)then
                     col=col+1
                     i5=q(j)
                     feature(b,col)=w*(x(id+(j-1)*n)-i5)
                  end if
   10          continue
            end if
            if(iv(32).ge.2)then
               do 11 j=1,d
                  if(iv(40+j).ge.1)then
                     if(iv(40+j).ge.2)then
                        col=col+1
                        i6=q(j)
                        feature(b,col)=w*(x(id+(j-1)*n)-i6)**2
                     end if
                     do 12 jj=j+1,d
                        if(iv(40+jj).ge.1)then
                           col=col+1
                           i7=q(j)
                           i8=q(jj)
                           feature(b,col)=w*(x(id+(j-1)*n)-i7)*
     +                          (x(id+(jj-1)*n)-i8)
                        end if
   12                continue
                  end if
   11          continue
            end if
    8    continue
         do 13 j=1,k
            do 14 b=1,na
               house(b,j)=0.D0
   14       continue
            do 15 b=nt+1,na
               if(ranks(map(b)).eq.j)house(b,j)=rec(iq+j,ll)
   15       continue
            if(rec(iq+j,ll).eq.0.D0)goto 13
            do 16 b=1,nt
               value(b)=feature(b,j)/rec(j,ll)
   16       continue
            do 17 b=nt+1,na
               if(ranks(map(b)).gt.j)value(b)=feature(b,j)/rec(j,ll)
   17       continue
            do 18 h=1,j-1
               if(rec(iq+h,ll).eq.0.D0)goto 18
               t=rec(iqt+h+k*(j-1),ll)
               if(t.eq.0.D0)goto 18
               do 19 b=1,nt
                  value(b)=t*house(b,h)+value(b)
   19          continue
               do 20 b=nt+1,na
                  if(ranks(map(b)).gt.j)
     +                 value(b)=t*house(b,h)+value(b)
   20          continue
   18       continue
            do 21 b=1,nt
               house(b,j)=rec(k+j,ll)*value(b)
   21       continue
            do 22 b=nt+1,na
               if(ranks(map(b)).gt.j)house(b,j)=rec(k+j,ll)*value(b)
   22       continue
   13    continue
         do 23 sv=1,k
            do 24 b=1,nt
               eta(b)=0.D0
   24       continue
            do 25 b=nt+1,na
               eta(b)=rec(iu+ranks(map(b))+k*(sv-1),ll)
   25       continue
            do 26 j=1,ju
               h=ju-j+1
               if(rec(iq+h,ll).eq.0.D0)goto 26
               t=rec(ipt+h+k*(sv-1),ll)
               if(t.eq.0.D0)goto 26
               do 27 b=1,nt
                  eta(b)=t*house(b,h)+eta(b)
   27          continue
               do 28 b=nt+1,na
                  if(ranks(map(b)).ge.h)eta(b)=t*house(b,h)+eta(b)
   28          continue
   26       continue
            do 29 b=1,na
               eta(b)=eta(b)*(rec(isc+sv,ll)*weight(map(b)))
   29       continue
            do 30 comp=0,d
               if(comp.lt.k)then
                  t=rec(ie+comp+1+(d+1)*(sv-1),ll)
                  do 31 b=1,na
                     lf(b,comp)=lf(b,comp)+t*eta(b)
   31             continue
               else
                  do 32 b=1,na
                     lf(b,comp)=0.D0
   32             continue
               end if
   30       continue
   23    continue
         do 33 b=1,na
            do 34 comp=0,d
               coef(comp,l,map(b))=lf(b,comp)
   34       continue
   33    continue
    1 continue
      return
      end

c Nonfinite records must retain the original selected membership and NaNs.
c Replay selection through every vertex in order, repeating QR/SVD only for
c exceptional unretained vertices. Full-length DQRSL preserves BLAS tails.
c The first producer pass owns diagnostics; replay is explicitly silent.
      subroutine lowesfz(iv,wv,x,rw,k,j0,nb,coef,exceptional)
      integer iv(*),k,j0,nb,exceptional(*),n,d,nf,nv,nvmax,
     +     l,j,i,jb,comp,sv,sing,info
      double precision wv(*),x(*),rw(*),
     +     coef(0:iv(2),iv(14),nb),q(8),sigma(15),u(15,15),
     +     e(15,15),qraux(15),work(15),norms(15),
     +     alphas(15),qrt(15,15),tol,scale,i7,i4
      external fhg127,ehg106,dqrsl
      n=iv(3)
      d=iv(2)
      nf=iv(19)
      nv=iv(6)
      nvmax=iv(14)
      do 1 i=1,n
         iv(iv(27)+i-1)=i
    1 continue
      sing=0
      do 2 l=1,nv
         do 3 j=1,d
            q(j)=wv(iv(11)+l-1+(j-1)*nvmax)
    3    continue
         if(exceptional(l).eq.0)then
            do 4 i=1,n
               wv(iv(15)+i-1)=0.D0
    4       continue
            do 5 j=1,iv(33)
               i4=q(j)
               do 6 i=1,n
                  wv(iv(15)+i-1)=wv(iv(15)+i-1)+
     +                 (x(i+(j-1)*n)-i4)**2
    6          continue
    5       continue
            call ehg106(1,n,nf,1,wv(iv(15)),iv(iv(27)),n)
         else
            call fhg127(q,n,d,nf,wv(1),x,iv(iv(27)),rw,
     +           iv(20),k,wv(iv(15)),wv(iv(18)),wv(iv(26)),wv(4),
     +           sing,sigma,u,e,qraux,work,tol,iv(33),iv(32),iv(41),
     +           norms,alphas,qrt,.false.)
            do 7 jb=1,nb
               do 8 comp=0,d
                  coef(comp,l,jb)=0.D0
    8          continue
    7       continue
            do 9 sv=1,k
               do 10 i=1,nf
                  wv(iv(16)+i-1)=0.D0
   10          continue
               do 11 i=1,k
                  wv(iv(16)+i-1)=u(i,sv)
   11          continue
               call dqrsl(wv(iv(18)),nf,nf,k,qraux,wv(iv(16)),
     +              wv(iv(16)),work,work,work,work,10000,info)
               if(tol.lt.sigma(sv))then
                  scale=1.D0/sigma(sv)
               else
                  scale=0.D0
               end if
               do 12 i=1,nf
                  wv(iv(16)+i-1)=wv(iv(16)+i-1)*
     +                 (scale*wv(iv(26)+i-1))
   12          continue
               do 13 i=1,nf
                  jb=iv(iv(27)+i-1)-j0+1
                  if(jb.ge.1.and.jb.le.nb)then
                     i7=wv(iv(16)+i-1)
                     do 14 comp=0,d
                        if(comp.lt.k)then
                           coef(comp,l,jb)=coef(comp,l,jb)+
     +                          e(1+comp,sv)*i7
                        else
                           coef(comp,l,jb)=0.D0
                        end if
   14                continue
                  end if
   13          continue
    9       continue
         end if
    2 continue
      return
      end

c D1 already has a verified geometric plan. Other dimensions keep ehg128.
      subroutine lowesfpeval(m,nvmax,ids,basis,coef,block)
      integer m,nvmax,ids(2,m),i,ll,ur
      double precision basis(5,m),coef(0:1,nvmax),block(m)
      do 1 i=1,m
         ll=ids(1,i)
         ur=ids(2,i)
         block(i)=basis(1,i)*coef(0,ll) + basis(2,i)*coef(0,ur) +
     +        (basis(3,i)*coef(1,ll)+basis(4,i)*coef(1,ur))*basis(5,i)
    1 continue
      return
      end

      subroutine lowesfnp(iv,wv,m,z,ids,basis,edgeids,edgebasis,
     +     diag)
      integer iv(*),m,ids(*),edgeids(*),diag(*)
      double precision wv(*),z(*),basis(*),edgebasis(*)
      external lowesgnp
      call lowesgnp(iv(2),m,z,iv(14),iv(17),iv(4),iv(iv(7)),
     +     iv(iv(8)),iv(iv(9)),iv(iv(10)),wv(iv(11)),wv(iv(12)),
     +     ids,basis,edgeids,edgebasis,diag)
      return
      end

      subroutine lowesfne(iv,wv,m,z,ids,basis,edgeids,edgebasis,
     +     diag,coef,block)
      integer iv(*),m,ids(*),edgeids(*),diag(*)
      double precision wv(*),z(*),basis(*),edgebasis(*),coef(*),
     +     block(*)
      external lowesgne
      call lowesgne(iv(2),m,z,iv(14),iv(17),iv(4),iv(iv(7)),
     +     iv(iv(8)),iv(iv(9)),iv(iv(10)),wv(iv(11)),wv(iv(12)),
     +     ids,basis,edgeids,edgebasis,diag,coef,block)
      return
      end

c This geometry-only pass uses the actual ehg128 read sites, instrumented at
c build time, with explicit diagnostic markers; no numerical call is replaced.
      subroutine lowesfdep(iv,wv,m,z,zero,diag)
      integer iv(*),m,i,j,diag(m)
      double precision wv(*),z(m,*),zero(*),q(8),ignored,ehg128dep
      external ehg128dep,fdepset
      do 1 i=1,m
         if(diag(i).eq.0)goto 1
         call fdepset(i)
         do 2 j=1,iv(2)
            q(j)=z(i,j)
    2    continue
         ignored=ehg128dep(q,iv(2),iv(17),iv(4),iv(iv(7)),
     +        wv(iv(12)),iv(iv(10)),iv(iv(9)),iv(iv(8)),
     +        wv(iv(11)),iv(14),zero)
    1 continue
      return
      end
