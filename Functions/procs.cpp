//#include <iostream>
//using namespace std;

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
    
double grate(double x)
{
  if (x < 5){
    //cout << 0.01 << endl;
    return 0.01;
  }
  else{
    //cout << 0.1 << endl;;
    return 0.1;
  }  
}

double gratea(double x)
{
  //cout << 0.11 << endl;;
  return 0.11;
}

