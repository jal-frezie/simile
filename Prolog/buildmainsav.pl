% buildmainsav.pl
% For Windows especially. Builds main.sav.
% run from <Simile>/Prolog
% sicstus -l buildmainsav.pl
:-compile('smain.pl').
:-save_program('../System/bin/main.sav').
:-halt. 

