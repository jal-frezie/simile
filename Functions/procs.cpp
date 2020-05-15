double factorial(int n) {
  if (n>1) 
    return n*factorial(n-1);
  else
    return 1;
}

double spare;
BOOLEAN have_spare = 0;
double inst_gaussian(double mean, double sd) {
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

// version taking only one random number, for generating deterministic seq
  
int poidev_1rand(double lambda, double u) {
  double p, s;
  int x = 0;

  p = exp(-lambda);
  s = p;
  while (s < u) {
    p = p*lambda/++x;
    s += p;
  }
  return x;
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

  JAT: 'register' class removed as incompatible with newer c++
  ------------------------------------------------------------*/
static double			/* direct method for integer order */
GammaDeviate_direct (unsigned long order)
{
  double x;
  unsigned long n;

/*    assert (order > 0); */

  x = ame_rand(0,1);
  for (n = order - 1; n; n--) x *= ame_rand(0,1);
  return -log(x);
}


/*------------------------------------------------------------*/
static double			/* rejection method for float order */
GammaDeviate_rejection (double order)
{
    double x, s, y, v;

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
  unsigned long i, a, b, k = 0;
  double x, x1, x2;
  /* check for parameters out of range */
  if (p<0 || p>1) return stop(51);
  if (n<0) return stop(52);

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

/*
 * algorithm as241  appl. statist. (1988) 37(3):
 *
 * produces the normal deviate z corresponding to a given lower
 * tail area of p; z is accurate to about 1 part in 10**16.
 *
 * the hash sums below are the sums of the mantissas of the
 * coefficients.   they are included for use in checking
 * transcription.

 * (JAT: not as svelte as my 2-from-2 algorithm, but if generating a
 * deterministic sequence wee need one variate from one random)
 */
double ppnd16(double p)
{
    static double zero = 0.0, one = 1.0, half = 0.5;
    static double split1 = 0.425, split2 = 5.0;
    static double const1 = 0.180625, const2 = 1.6;

    /* coefficients for p close to 0.5 */
    static double a[8] = {
        3.3871328727963666080e0,
        1.3314166789178437745e+2,
        1.9715909503065514427e+3,
        1.3731693765509461125e+4,
        4.5921953931549871457e+4,
        6.7265770927008700853e+4,
        3.3430575583588128105e+4,
        2.5090809287301226727e+3
    };
    static double b[8] = { 0.0,
        4.2313330701600911252e+1,
        6.8718700749205790830e+2,
        5.3941960214247511077e+3,
        2.1213794301586595867e+4,
        3.9307895800092710610e+4,
        2.8729085735721942674e+4,
        5.2264952788528545610e+3
    };

    /* hash sum ab    55.8831928806149014439 */
    /* coefficients for p not close to 0, 0.5 or 1. */
    static double c[8] = {
        1.42343711074968357734e0,
        4.63033784615654529590e0,
        5.76949722146069140550e0,
        3.64784832476320460504e0,
        1.27045825245236838258e0,
        2.41780725177450611770e-1,
        2.27238449892691845833e-2,
        7.74545014278341407640e-4
    };
    static double d[8] = { 0.0,
        2.05319162663775882187e0,
        1.67638483018380384940e0,
        6.89767334985100004550e-1,
        1.48103976427480074590e-1,
        1.51986665636164571966e-2,
        5.47593808499534494600e-4,
        1.05075007164441684324e-9
    };

    /* hash sum cd    49.33206503301610289036 */
    /* coefficients for p near 0 or 1. */
    static double e[8] = {
        6.65790464350110377720e0,
        5.46378491116411436990e0,
        1.78482653991729133580e0,
        2.96560571828504891230e-1,
        2.65321895265761230930e-2,
        1.24266094738807843860e-3,
        2.71155556874348757815e-5,
        2.01033439929228813265e-7
    };
    static double f[8] = { 0.0,
        5.99832206555887937690e-1,
        1.36929880922735805310e-1,
        1.48753612908506148525e-2,
        7.86869131145613259100e-4,
        1.84631831751005468180e-5,
        1.42151175831644588870e-7,
        2.04426310338993978564e-15
    };

    /* hash sum ef    47.52583317549289671629 */
    double q, r, ret;

    q = p - half;
    if (fabs(q) <= split1) {
        r = const1 - q * q;
        ret = q * (((((((a[7] * r + a[6]) * r + a[5]) * r + a[4]) * r + a[3])
                     * r + a[2]) * r + a[1]) * r + a[0]) /
            (((((((b[7] * r + b[6]) * r + b[5]) * r + b[4]) * r + b[3])
               * r + b[2]) * r + b[1]) * r + one);

        return ret;
    }
    /* else */

    if (q < zero)
        r = p;
    else
        r = one - p;

    if (r <= zero)
        return zero;

    r = sqrt(-log(r));
    if (r <= split2) {
        r -= const2;
        ret = (((((((c[7] * r + c[6]) * r + c[5]) * r + c[4]) * r + c[3])
                 * r + c[2]) * r + c[1]) * r + c[0]) /
            (((((((d[7] * r + d[6]) * r + d[5]) * r + d[4]) * r + d[3])
               * r + d[2]) * r + d[1]) * r + one);
    }
    else {
        r -= split2;
        ret = (((((((e[7] * r + e[6]) * r + e[5]) * r + e[4]) * r + e[3])
                 * r + e[2]) * r + e[1]) * r + e[0]) /
            (((((((f[7] * r + f[6]) * r + f[5]) * r + f[4]) * r + f[3])
               * r + f[2]) * r + f[1]) * r + one);
    }

    if (q < zero)
        ret = -ret;

    return ret;
}
