ARCH     = $(shell uname -m)
ARCHF    = $(shell uname -a)
CXX = g++
MDIR = /usr/
CPPFLAGS = -O4 -O5 -ffast-math -fPIC -fopenmp -I$(MDIR)/include #-no-cpp-precomp -dynamic -m64
#CPPFLAGS = -O0 -g3 -fPIC -fopenmp -I$(MDIR)/include
OFILES = mpfit.o fpi.o creduc.o creduc_wrap.o
INSTFILES = creduc.so
IDIR = $(HOME)/idl/dlm/$(ARCH)  

ifneq (,$(findstring Darwin,$(ARCH))) #
  CPPFLAGS += -arch x86_64
  LIBTOOL = /usr/bin/glibtool
  INSTALL = install
  MACOSX_DEPLOYMENT_TARGET=10.7
  export MACOSX_DEPLOYMENT_TARGET
endif

creduc.so: $(OFILES)
	$(CXX) -shared -o creduc.so $(OFILES) -L$(MDIR)/lib -lfftw3 -lfftw3_threads -lpthread -fopenmp

#install: $(INSTFILES)
#	cp $(INSTFILES) $(IDIR)
#
clean:
	rm *.o #*.so
