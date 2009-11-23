double factorial(int n) {
  if (n>1) 
    return n*factorial(n-1);
  else
    return 1;
}

double spare;
BOOLEAN have_spare = 0;
double gaussian_var(double mean, double sd) {
  double v1,v2,r,fac,norm;
  if (have_spare) {
    norm = spare;
  } else {
    do {
      v1 = ame_rand(-1,1);
      v2 = ame_rand(-1,1);
      r = v1*v1 + v2*v2;
    } while (r>=1);
    fac = sqrt(-2*log(r)/r);
    spare = v1*fac;
    norm = v2*fac;
  }
  have_spare=!have_spare;
  return(mean+sd*norm);
}

double gammln(double xx) {
  double stp = 2.50662827465, x, tmp, ser;

  x=xx-1;
  tmp=x+5.5;
  tmp=(x+0.5)*log(tmp)-tmp;
  ser=1+76.18009173/(x+1)-86.50532033/(x+2)+24.01409822/(x+3)\
    -1.231739516/(x+4)+1.20858003e-3/(x+5)-5.36382e-6/(x+6);
  return tmp+log(stp+ser);
}

double ame_pi = 3.141592653589793;

int poidev(double xm) {
  /* Returns an integer value that is a random deviate drawn from a Poisson 
  distribution of mean xm, using random01 to get a random value between 0 and 1
  Thanks to "Numerical Recipes", CUP */
  double PoidevG, t, PoidevSq, PoidevAlxm, y;
  int em;

  if (xm<12) {
    PoidevG=exp(-xm);
    em=-1;
    t=1;
    while (t>=PoidevG) {
      ++em;
      t=t*ame_rand(0,1);
    }
  } else {
    PoidevSq=sqrt(2*xm);
    PoidevAlxm=log(xm);
    PoidevG=xm*PoidevAlxm-gammln(xm+1);

    do {
      do { 
	y=tan(ame_rand(0,1)*ame_pi);
	em=int(PoidevSq*y+xm);
      } while (em<0);
      t=0.9*(1+y*y)*exp(em*PoidevAlxm-gammln(em+1)-PoidevG);
    } while (!(ame_rand(0,1)<=t)); // comparison false if t is nan
  }
  return em;
}

/* translated from "Numerical Recipes" by Simulistics: gives wrong results
int bnldev (double pp, int n) {
  double p, pc, am, Oldg, Plog, Pclog, Sq, t, y, em;
  int bnl, j, emc;

  if (pp<0.5) {
    p=pp;
    pc=1-pp;
  } else {
    pc=pp;
    p=1-pp;
  }
  am=n*p;
  if (n<25) {
    bnl=0;
    for (j=0; j<n; ++j) {
      bnl+=(ame_rand(0,1)<p);
    }
  } else if (am<1) {
    bnl=poidev(am);
  } else {
    Oldg=gammln(n+1);
    Plog=log(p);
    Pclog=log(pc);

    Sq=sqrt(2*am*pc);
    do {
      do {
	y=tan(ame_rand(0,1)*ame_pi);
	em=Sq*y+am;
      } while (em<0 || em>=n+1);
      bnl = int(em);
      emc=n-bnl;
      t=1.2*Sq*(1+y*y)*exp(Oldg+bnl*Plog+emc*Pclog-gammln(bnl+1)-gammln(emc+1));
    } while (ame_rand(0,1)>t);
  }
  if (pp<0.5) {
    return bnl;
  } else {
    return n-bnl;
  }
}
This is a utility for delay functions that write an array, wrapping around
when they reach the end. To find out if a particular element in the array is to
be written, work out whether it is between the lower and higher values, or 
outside them if the higher has wrapped below the lower. */

BOOLEAN wrapped(int lo, int hi, int here) {
  return (hi<lo)==(hi<here)==(lo<here);
}

/* version of fmod with behaviour that does not invite the comment "Derr" 
   when args go negative */

double simile_mod(double point, double span) {
  return point-span*floor(point/span);
}

/* extract from crng: Random-number generators as Python extension types 
  coded in C.

  See the file doc.html for documentation.

  Copyright (C) 2000-2002 Per J. Kraulis

  This program is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 2 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program (see file gpl.txt); if not, write to the
  Free Software Foundation, Inc., 59 Temple Place, Suite 330, Boston,
  MA  02111-1307  USA

/*------------------------------------------------------------*/
static double			/* direct method for integer order */
GammaDeviate_direct (unsigned long order)
{
  register double x;
  register unsigned long n;

/*    assert (order > 0); */

  x = ame_rand(0,1);
  for (n = order - 1; n; n--) x *= ame_rand(0,1);
  return -log(x);
}


/*------------------------------------------------------------*/
static double			/* rejection method for float order */
GammaDeviate_rejection (double order)
{
    register double x, s, y, v;

    s = sqrt(2.0 * order - 1.0);
    do {
      do {
	y = tan(ame_pi * ame_rand(0,1));
	x = s * y + order - 1.0;
      } while (x <= 0.0);
      v = ame_rand(0,1);
    } while (v > (1.0 + y * y) * exp((order - 1.0) *
				     log(x / (order - 1.0)) - s * y));

    return x;
}

/*------------------------------------------------------------*/
static int			/* actually compute the next value */
binome(double p, int n)
{
  register unsigned long i, a, b, k = 0;
  register double x, x1, x2;
  /* check for parameters out of range */
  if (p<0 || p>1) return stop(51);
  if (n<0) return 52;

  while (n > 20) {		/* tunable parameter; make member? */
    a = 1 + (n / 2);
    b = 1 + n - a;

    if (a < 12) {		/* more efficient than using BetaDeviate */
      x1 = GammaDeviate_direct(a);
    } else {
      x1 = GammaDeviate_rejection((double) a);
    }
    if (b < 12) {
      x2 = GammaDeviate_direct(b);
    } else {
      x2 = GammaDeviate_rejection((double) b);
    }
    x = x1 / (x1 + x2);

    if (x >= p) {
      n = a - 1;
      p /= x;
    } else {
      k += a;
      n = b - 1;
      p = (p - x) / (1.0 - x);
    }
  }

  for (i = 0; i < n; i++) {
    x = ame_rand(0,1);
    if (x < p) k++;
  }

  return (int)k;
}

double binome_equiv(double p, double n) {
  return n*p;
}

int trinome(int pop, int marked, int sample) {
  int fished=0;
  if (sample<20) {
    while (sample>0) {
      if (ame_rand(0,pop)<marked) {
	--marked;
	++fished;
      }
      --pop;
      --sample;
    }
  } else {
    fished = binome(1.0*marked/pop,sample);
  }
  return fished;
}


int hypergeom(int pop, int seln1, int seln2) {
  BOOLEAN flip1, flip2;
  int out;
  /* Random deviates from a hypergeometric distribution. This is the 
     distribution resulting from selecting a number of individuals from a
     population, some of whom have already been selected. How many from the
     first selection will appear in the second?

     Method is first to rearrange the problem to make as few selections as
     possible, then do it iteratively if less than 20, or by approximating
     with binomial distribution if more. */

  flip1 = (seln1>pop/2);
  flip2 = (seln2>pop/2);
  if (flip1) seln1=pop-seln1;
  if (flip2) seln2=pop-seln2;

  out = trinome(pop, max(seln1,seln2), min(seln1,seln2));

  if (flip2) {out=seln1-out;seln2=pop-seln2;}
  if (flip1) out=seln2-out;
  return out;
}

double hypergeom_equiv(double pop, double seln1, double seln2) {
  if (pop) 
    return seln1*seln2/pop;
  return 0;
}
