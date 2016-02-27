LUA= $(LUA_SRC)
LUAINC= $(LUA)/include
LUALIB= $(LUA)/lib
LUABIN= $(LUA)/bin
CFLAGS= $(INCS) $(WARN) -O2 -g $G
WARN= -pedantic -Wall
INCS= -I$(LUAINC)

MYNAME= wifimanager
MYLIB= $(MYNAME)
T= $(MYLIB).so
OBJS= $(MYLIB).o
TEST= test.lua

default: all

all:	test

test:	$T

o:	$(MYLIB).o

so:	$T

$T:	$(OBJS)
	$(CC) -o $@ -shared $(OBJS)

clean:
	rm -f $(OBJS) $T core core.* a.out
