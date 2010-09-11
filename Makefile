PARROTPATH=/home/ryan/SVNROOT/parrot/
PARROT=$(PARROTPATH)/parrot
LUAC=$(PARROTPATH)/languages/lua/luac.pl
PBC2EXE=$(PARROTPATH)/pbc_to_exe
PBCMERGE=$(PARROTPATH)/pbc_merge

EXE=parmud
EXEPBC=$(EXE).pbc

#Source files, LUA goes into $LSources, but so far i think i can only have one in there
#PIR goes into $PIR
LSOURCES=hello.lua
LPIR=$(LSOURCES:.lua=.pir)
PIR=$(LPIR) sockets.pir
OBJECTS=$(PIR:.pir=.pbc)

all: $(PIR) $(EXE)

$(EXE): $(EXEPBC)
#	$(PBC2EXE) $(EXEPBC)
	touch $(EXE)
	
$(EXEPBC): $(OBJECTS)
	$(PBCMERGE) -o $@ $(OBJECTS)

%.pir: %.lua
	$(LUAC) $<

%.pbc: %.pir
	$(PARROT) -o $@ $<

.PHONY: clean
clean:
	rm -f $(OBJECTS) $(LPIR) $(EXE).o $(EXE).c $(EXEPBC)
