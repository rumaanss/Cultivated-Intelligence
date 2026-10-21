#include <exception>
#include <iostream>
int runApplication(int,char**);
int main(int argc,char**argv){try{return runApplication(argc,argv);}catch(const std::exception&e){std::cerr<<"[CI] "<<e.what()<<'\n';return 1;}}
