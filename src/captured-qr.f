C     LINPACK dqrdc and dqrsl, version dated 08/14/78.
C     G. W. Stewart, University of Maryland, Argonne National Lab.
C     Source: R-devel revision 90840, src/appl/dqrdc.f and dqrsl.f.
C     Copyright (C) 2026 Don Yin for the modifications.
C     Modified by Don Yin on 2026-11-11: retain only unpivoted QR and Q*y,
C     capturing the Householder and projection scalars as dqrdcx/dqrslx.
C     BLAS calls and scalar operations retain the LINPACK order.
C     Distributed with loesslin under GPL version 2 or version 3.
C     R's doc/COPYRIGHTS describes LINPACK's copyright status as unclear;
C     it reports that the routines are said to be public domain in the USA.

c Capture the unpivoted Householder QR used by vertex records.
c BLAS calls and scalar operations retain the LINPACK order.

      subroutine dqrdcx(x,ldx,n,p,qraux,alphas,qrts)
      integer ldx,n,p,j,l,ii0,jj0
      double precision x(ldx,p),qraux(p),alphas(15),qrts(15,15)
      double precision dnrm2,ddot,nrmxl,t
      external dnrm2,ddot
      do ii0=1,15
         alphas(ii0)=0.D0
         do jj0=1,15
            qrts(ii0,jj0)=0.D0
         end do
      end do
      do l=1,min(n,p)
         qraux(l)=0.0d0
         if(l.ne.n)then
            nrmxl=dnrm2(n-l+1,x(l,l),1)
            if(nrmxl.ne.0.0d0)then
               if(x(l,l).ne.0.0d0)nrmxl=dsign(nrmxl,x(l,l))
               alphas(l)=1.0d0/nrmxl
               call dscal(n-l+1,alphas(l),x(l,l),1)
               x(l,l)=1.0d0+x(l,l)
               do j=l+1,p
                  t=-ddot(n-l+1,x(l,l),1,x(l,j),1)/x(l,l)
                  qrts(l,j)=t
                  call daxpy(n-l+1,t,x(l,l),1,x(l,j),1)
               end do
               qraux(l)=x(l,l)
               x(l,l)=-nrmxl
            end if
         end if
      end do
      return
      end

c Apply Q, retaining the projection scalars and restoring X's diagonal.
      subroutine dqrslx(x,ldx,n,k,qraux,y,qy,ts)
      integer ldx,n,k,i,j,jj,ju
      double precision x(ldx,k),qraux(k),y(n),qy(n),ts(15)
      double precision ddot,t,temp
      external ddot
      do i=1,15
         ts(i)=0.D0
      end do
      ju=min(k,n-1)
      if(ju.eq.0)then
         qy(1)=y(1)
      else
         call dcopy(n,y,1,qy,1)
         do jj=1,ju
            j=ju-jj+1
            if(qraux(j).ne.0.0d0)then
               temp=x(j,j)
               x(j,j)=qraux(j)
               t=-ddot(n-j+1,x(j,j),1,qy(j),1)/x(j,j)
               ts(j)=t
               call daxpy(n-j+1,t,x(j,j),1,qy(j),1)
               x(j,j)=temp
            end if
         end do
      end if
      return
      end
