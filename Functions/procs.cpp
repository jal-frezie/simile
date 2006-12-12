double spare;
BOOLEAN have_spare = 0;
double gaussian(double random, double mean, double sd) {
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

/* This is a utility for delay functions that write an array, wrapping around
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
